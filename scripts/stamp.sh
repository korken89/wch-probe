#!/usr/bin/env bash
# Fill the {GITHASH}/{GITTAG} placeholders in the schematic and board, and
# {DATEGOESHERE} in the schematic, with the actual revision and generation
# date. CI runs this on its checkout before generating outputs; the
# result is never committed. The grep guards fail the build if the placeholders
# are missing, which catches a stamped file being committed by accident.
#
# Usage: scripts/stamp.sh <hash> <tag>   (run from the repo root)
set -euo pipefail

hash=${1:0:7}
tag=$2
date=$(date -u +%F)

grep -q '{DATEGOESHERE}' wch-probe.kicad_sch
for f in wch-probe.kicad_sch wch-probe.kicad_pcb; do
  grep -q '{GITHASH}' "$f"
  grep -q '{GITTAG}' "$f"
  sed -i "s/{GITHASH}/$hash/g; s/{GITTAG}/$tag/g; s/{DATEGOESHERE}/$date/g" "$f"
done
