#!/usr/bin/env bash
# Generate the JLCPCB upload set (gerbers+drill zip, BOM, placement file), a
# schematic PDF and board renders under Fabrication/. Notes:
#   - BOM and placement cover the populated parts (DNP excluded) bar fab
#     helpers (test points, fiducials, mounting holes); parts without an LCSC
#     code are kept so JLC flags them on upload rather than dropping them
#     silently
#
# Usage: scripts/fab.sh   (run from the repo root)
set -euo pipefail

proj=$(basename ./*.kicad_pro .kicad_pro)
sch="$proj.kicad_sch"
pcb="$proj.kicad_pcb"

out="Fabrication"
mkdir -p "$out"/{PDFs,JLCPCB,pcb_images}
out=$(cd "$out" && pwd)                       # absolute, for the zip subshell

LAYERS="F.Cu,In1.Cu,In2.Cu,B.Cu,F.SilkS,B.SilkS,F.Mask,B.Mask,F.Paste,B.Paste,Edge.Cuts"

# --- schematic PDF ---------------------------------------------------------
# No --theme: default to the schematic's own colors so wires, net labels,
# junctions and buses plot in their net-class colors.
kicad-cli sch export pdf \
  --draw-hop-over -o "$out/PDFs/$proj-schematic.pdf" "$sch"

# --- gerbers + drill, zipped (gerber-first ordering for JLC's uploader) -----
tmp=$(mktemp -d)
kicad-cli pcb export gerbers -l "$LAYERS" \
  --no-x2 --no-netlist --disable-aperture-macros --subtract-soldermask \
  --exclude-value --precision 6 -o "$tmp" "$pcb"
kicad-cli pcb export drill --format excellon --excellon-separate-th \
  --excellon-units in -o "$tmp" "$pcb"
rm -f "$tmp"/*.gbrjob
rm -f "$out/JLCPCB/$proj-jlcpcb.zip"
( cd "$tmp" && zip -q "$out/JLCPCB/$proj-jlcpcb.zip" $(ls | sort) )
rm -rf "$tmp"

# --- BOM -------------------------------------------------------------------
# JLCPCB column format. The ';' field delimiter keeps the comma-separated
# designators in one field for awk, and the sed converts back to a comma CSV.
bom_tmp=$(mktemp)
kicad-cli sch export bom --exclude-dnp \
  --fields "Value,Reference,Footprint,LCSC,QUANTITY" \
  --labels "Comment,Designator,Footprint,LCSC part number,QTY" \
  --group-by "Value,Footprint,LCSC" \
  --field-delimiter ";" --ref-delimiter "," --ref-range-delimiter "" \
  -o "$bom_tmp" "$sch"
awk -F';' 'NR==1 || ($2 !~ /^"(TP|FID)/ \
  && tolower($1 $3) !~ /mount.*hole|solder.*bridge|solder.*jump|test.*point/)' \
  "$bom_tmp" | sed 's/";"/","/g' > "$out/JLCPCB/$proj-bom.csv"
rm -f "$bom_tmp"

# --- pick-and-place --------------------------------------------------------
pos_tmp=$(mktemp)
kicad-cli pcb export pos --format csv --units mm --side both --exclude-dnp \
  -o "$pos_tmp" "$pcb"
{
  echo "Designator,Val,Package,Mid X,Mid Y,Rotation,Layer"
  tail -n +2 "$pos_tmp"
} > "$out/JLCPCB/$proj-cpl.csv"
rm -f "$pos_tmp"

# --- board renders ---------------------------------------------------------
# Transparent background (no backdrop/floor) and a zoomed-out camera so 3D
# models that overhang the board edge (connectors etc.) are not clipped.
# --quality basic (OpenGL, no raytracing): the raytraced shadows make the
# board harder to inspect, and basic renders far faster.
for side in top bottom; do
  kicad-cli pcb render --side "$side" --background transparent --quality basic \
    --preset follow_pcb_editor --zoom 1 --width 1600 --height 1200 \
    -o "$out/pcb_images/$proj-$side.png" "$pcb"
done

echo "done -> $out"
