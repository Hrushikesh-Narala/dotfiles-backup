# register-map

The EC block at physical `0xFE0B0000`, reached through `/dev/mem`. This is not
a standard ACPI EC interface - it is a `SystemMemory` operation region that
only the AML and `/dev/mem` can touch. It does not appear in `/proc/iomem`.

    OperationRegion (ECMP, SystemMemory, 0xFE0B0000, 0x1000)

The standard LPC EC (`OperationRegion (ECPR, EmbeddedControl, Zero, 0xFF)` in
the DSDT) is a completely different thing and carries only battery and AC
fields. It has no fan registers at all, which is why `ec_sys` and every
`/dev/port` style approach dead-ended.

## Addressing

All fan registers live at `0xFE0B0800` + offset. The trap here is real and I
fell into it: a tool that reads from `BASE + 0x800 + off` but writes to
`BASE + off` will report every write as successful and change nothing. Both
paths must use the same base.

    read   dd if=/dev/mem  bs=1 skip=$((0xFE0B0800 + off)) count=1
    write  printf "\\$(printf '%03o' "$v")" | dd of=/dev/mem bs=1 seek=$((0xFE0B0800 + off)) conv=notrunc

## Map

Offsets relative to `0xFE0B0800`. Names are the AML field names.

| Offset | Name   | Meaning                                          |
|--------|--------|--------------------------------------------------|
| 0x808  | PSPD   |                                                  |
| 0x809  | CSRT   |                                                  |
| 0x80A  | MINL   |                                                  |
| 0x80B  | FPPT   |                                                  |
| 0x80C  | SPPT   | package power thresholds                          |
| 0x80D  | SAPU   |                                                  |
| 0x80E  | SADP   |                                                  |
| 0x80F  | flags  | see below                                        |
| 0x810  | SAD2   |                                                  |
| 0x811  | FRPM   | fan speed, units of 100 RPM - see caveat          |
| 0x812  | FNMX   | fan maximum, the ceiling (observed 59 = 5900)     |
| 0x813  | FNMN   | fan minimum                                      |
| 0x814  | FWPM   | **fan target, units of 100 RPM**                  |
| 0x815+ | RSTV CPTV GPTV PHTV FNTV BTTV HDTV | thresholds, not fan control |

## The flags register, 0x80F

| Bit | Name | Meaning                                                  |
|-----|------|----------------------------------------------------------|
| 0   | FANE | Fan enable. Set by EC firmware, never by the AML.        |
| 1   | CPUO |                                                       |
| 2   | M4GO |                                                       |
| 3   | **FNSW** | **Fan target latch. This is the whole mechanism.**  |
| 4   | SBTC |                                                       |
| 5   | VGAP |                                                       |
| 6   | WPFM | Appears to mean "write PWM fan". Turns out to be irrelevant. |
| 7   | EHP1 |                                                       |

`FANE` and `WPFM` are not required. `FNSW` alone is sufficient - verified by
`tests/fanlatch`.

## Units

`0x814` is in units of 100 RPM. Confirmed directly: commanding 59 produced
5900 RPM, and commanding 255 produced a reported 25500.

## The caveat that matters

`0x811` (FRPM) reports the **commanded** value, not a measured speed.
Commanding 255 reported 25500 RPM, which this fan cannot physically spin. So
`0x811` is echoing the target rather than reading a tachometer.

This means there is no way to read the true fan speed on this machine. The
hwmon `fan1_input` and `fan2_input` are permanently 0 because the hp-wmi
driver addresses a dead path. The only ground truth is to put a hand on the
exhaust.

## Provenance

`docs/aml/DSDT.dsl.gz` and `docs/aml/SSDT6.dsl.gz` are the decompiled tables
from this machine, with the field names above. To re-derive anything:

    gunzip -c docs/aml/DSDT.dsl.gz | grep -n -A4 -B4 FNSW
