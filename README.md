# wch-probe

KiCad hardware for a CH347F-based JTAG & SWD debug probe: USB-C on one end, a
10-pin 1.27 mm Cortex debug header on the other, plus a UART on the bottom-side
TX/RX/GND pads. The I/O voltage (VIO) tracks the target's VTref (valid range
1.8 V to 3.3 V), and defaults to 3.3 V when the target does not drive VTref.

<p align="center">
  <img src="docs/render-top.png" width="49%" alt="Board top" />
  <img src="docs/render-bottom.png" width="49%" alt="Board bottom" />
</p>

## Fabrication

The fabrication outputs (gerber zip, BOM, placement file, schematic PDF) for
each board revision are attached to the
[releases](https://github.com/korken89/wch-probe/releases). To generate them
locally, `make fab` writes the same set to `Fabrication/` and `make check`
runs ERC and DRC; both need KiCad 10's `kicad-cli`.

## Ordering

JLCPCB, 4 layers, 1.6 mm thick. Order options:

- Stackup: JLC04161H-7628 with impedance control (the USB pair is 90 ohm
  differential)
- Surface finish: HASL lead-free
- Remove order number: yes

## USB identity

Stock CH347s ship with a blank config and all enumerate with the same default serial.
Use [wch-cfg](https://github.com/korken89/wch-cfg) to write each board's USB identity
(serial number, product and manufacturer strings):

```sh
wch-cfg version --min 1.01 && wch-cfg write --init --random-serial --product wch-probe --manufacturer korken89
# replug the board (the chip reads the strings at power-on), then
wch-cfg verify --serial <the printed serial> --product wch-probe --manufacturer korken89
```

`write` prints the serial for the label on stdout once the OS has enumerated it.

## Gotchas

**Several probes behind one hub can fail to enumerate.** The CH347 declares
its interrupt endpoints with 125/250 us polling, and the host controller
reserves that bandwidth at enumeration whether the endpoints are used or not.
On Intel xHCs roughly three probes fill a root port's periodic budget, so
further ones fail with `can't set config #1, error -28` ("Not enough
bandwidth"). Work around it on Linux by treating the bInterval values as
milliseconds (~8x smaller reservation; UART, JTAG and SWD run on bulk
endpoints and are unaffected):

```sh
echo '1a86:55de:l' | sudo tee /sys/module/usbcore/parameters/quirks
```

then replug the probes (quirks apply at enumeration). To make it permanent,
add `usbcore.quirks=1a86:55de:l` to the kernel command line. `dmesg` printing
`endpoint 0x85 has an invalid bInterval 1, changing to 4` for each probe
confirms the quirk is active.

## License

CERN-OHL-P-2.0, see [LICENSE](LICENSE).
