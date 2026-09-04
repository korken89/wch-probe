PROJ := wch-probe

.PHONY: all fab check erc drc renders clean

all: fab

fab:
	scripts/fab.sh

# `make -k check` runs both even if ERC fails.
check: erc drc

erc:
	kicad-cli sch erc --severity-error --exit-code-violations \
	  -o $(PROJ)-erc.rpt $(PROJ).kicad_sch

drc:
	kicad-cli pcb drc --refill-zones --schematic-parity \
	  --severity-error --exit-code-violations \
	  -o $(PROJ)-drc.rpt $(PROJ).kicad_pcb

# Raytraced README renders (committed under docs/).
renders:
	kicad-cli pcb render --side top --background transparent --quality high \
	  --preset follow_pcb_editor --perspective --rotate "'-30,0,-25'" \
	  --zoom 0.95 --width 1000 --height 700 \
	  -o docs/render-top.png $(PROJ).kicad_pcb
	kicad-cli pcb render --side bottom --background transparent --quality high \
	  --preset follow_pcb_editor --perspective --rotate "'-30,0,25'" \
	  --zoom 1 --width 1000 --height 700 \
	  -o docs/render-bottom.png $(PROJ).kicad_pcb

clean:
	rm -rf Fabrication *.rpt
