# fanctl

Fan control for the **HP Envy x360 Convertible 13-ay1xxx** (board 8929, BIOS
F.14), from the terminal.

No kernel module. No daemon. No firmware patch. Two registers.

```
$ sudo fanctl silent
  silent -> 1200 RPM commanded (0x0C = 12 reg units)

  mode   COMMANDED by fanctl
  target  1200 RPM  (0x0C = 12 reg units x 100)
  fan      1200 RPM  (EC register 0x811)
  limits 0..5900 RPM commanded;  FNMX=59 FNMN=48
  flags  0x09  FANE=1 FNSW=1 WPFM=0
  temp   45.0 C      power AC
  guard  armed at 85 C (pid 379224)
```

## install

```sh
git clone <this repo> ~/fanctl
~/fanctl/install.sh
```

`fanctl` and `fanrpm` go to `~/.local/bin`. Both need `sudo`, since they talk
to `/dev/mem`.

Requirements: root, `lockdown=off` (currently `[none]`). Nothing else. No
`acpi_call` module, no Secure Boot change, no initramfs.

## use

| Command                  | Effect                                            |
|--------------------------|---------------------------------------------------|
| `fanctl list`            | show the profiles                                 |
| `fanctl off`             | **fan stopped** - guard trips at 70 °C, not 85    |
| `fanctl silent`          | 1200 RPM                                          |
| `fanctl quiet`           | 2000 RPM                                          |
| `fanctl balanced`        | 3000 RPM                                          |
| `fanctl performance`     | 4200 RPM                                          |
| `fanctl max`             | 5900 RPM (the firmware ceiling, `FNMX`)           |
| `fanctl manual 2500`     | any speed in 100 RPM steps, clamped to `FNMX`     |
| `fanctl auto`            | release to the firmware temperature curve         |
| `fanctl status`          | what is commanded right now                       |
| `fanctl guard 85`        | release to `auto` at or above this temperature    |
| `fanctl onac balanced`   | profile to use on mains                           |
| `fanctl ondc silent`     | profile to use on battery                         |
| `fanctl apply`           | apply whichever profile matches the power source  |

`fanrpm` is a live monitor with a sparkline. It needs the optional module
below for its AML column; the raw column always works.

## how it works

Two registers in the EC block at physical `0xFE0B0000`, reached through
`/dev/mem`:

    0x80F  bit 3  FNSW   fan target latch
    0x814  FWPM          commanded speed, 100 RPM per unit

To command a speed: **set `FNSW`, write `0x814`, and leave `FNSW` set.**

`FNSW` is a *latch*, not a write strobe. While it is set, `0x814` is the
active command. Clear it and the EC hands the fan straight back to its own
temperature curve.

That single fact is the whole mechanism, it is not documented anywhere, and
getting it backwards produces a tool that reports every write as successful
and does nothing. `docs/HOW-WE-GOT-HERE.md` is the story of how long it took
to establish it, including two wrong theories along the way.
`tests/fanlatch` exists to keep it from regressing.

Full register map, including the `BASE + off` versus `BASE + 0x800 + off` trap:
[`docs/register-map.md`](docs/register-map.md).

## caveats

Read these before trusting the output.

**The RPM number is commanded, not measured.** Commanding 255 reported 25500
RPM, which this fan cannot physically spin, so `0x811` is echoing the target
rather than reading a tachometer. There is no way to read true fan speed on
this machine - both hwmon fan inputs are permanently 0. The only ground truth
is a hand on the exhaust. The tools label this rather than printing an
unmarked number.

**`off` stops the fan, and it is not a normal profile.** A latched `0`
genuinely halts the blades - confirmed by hand on the exhaust, which is the
only trustworthy sensor available here, since `0x811` merely echoes the
command. Because there is no cooling at all, `off` does not use the ordinary
85 °C guard threshold. It arms at **70 °C**, and `fanctl status` shouts if it
ever finds a stopped fan with no guard running. The threshold is a measured
guess, not a validated one: `sudo tests/fanoff` measures how warm the machine
actually gets, and if the load phase peaks well under 70 °C then `off` is fine
for short bursts, while if it hits the limit the threshold needs to come down.

**The latch outlives the process.** That is what makes profiles work, and it
also means a bad command persists until something clears it. Hence the thermal
guard, which calls `fanctl auto` at 85 C. Set your own with `fanctl guard`.

**`/dev/mem` must stay readable** - `lockdown` must not be set to `confidential`
or `integrity`.

**`silent` at 1200 RPM is confirmed working** on this machine, measured over a
14-second settle, not inferred from a peak reading.

## optional: the ACPI cross-check

`fanrpm` can show the AML's own view of fan speed as a second opinion. That
needs `acpi_call`, which is not packaged for most distros and does not survive
a reboot:

```sh
make -C vendor/acpi_call
sudo insmod vendor/acpi_call/acpi_call.ko
```

It must be rebuilt and reloaded after every kernel update. `fanctl` does not
use it, and neither does the mechanism - it is a display nicety and a
cross-check, nothing more. See [`vendor/acpi_call/PATCHES.md`](vendor/acpi_call/PATCHES.md).

## tests

```sh
sudo tests/run-all
```

| Script      | What it proves                                                  |
|-------------|-----------------------------------------------------------------|
| `fanlatch`  | `FNSW` is a latch: same target, released vs latched, must disagree |
| `fantail`   | The low end of the range is reachable, with settle time         |
| `fanoff`    | How warm the machine actually gets with the fan stopped         |
| `fansweep`  | Sweeps flag combinations. Interactive; re-derives the mechanism  |
| `run-all`   | Runs the non-interactive ones, restores state between them      |

All of them restore the firmware curve on exit, including on Ctrl-C, and all
of them need root. Run them one at a time - they share one fan.

## why nothing else works

Every alternative was tested rather than assumed, and all of them address
paths that this firmware leaves inert:

- **WMI** - all 48 methods `GC01`-`GC2F` in SSDT6 are stubs returning
  `Package(0x02){Zero,Zero}`. A literal constant. Not a driver gap; there is
  nothing to call.
- **hp-wmi** - this board is absent from the driver's own feature table.
  `fan1_input`/`fan2_input` are permanently 0 because the driver reads a
  constant.
- **NBFC** - Linux port only speaks the LPC EC at 0x62/0x66. No 13-ay config.
- **fancontrol / lm-sensors** - need a `pwm1` this board does not expose.
- **power-profiles-daemon** - CPU policy only, no fan control.
- **ryzenadj** - requires Secure Boot, which must stay off.
- **`ec_sys`** - the standard LPC EC has no fan registers at all. They are in a
  different region entirely.
- **`FSSP`** - the AML's only fan write. Masks to 0/1, so it is on/off, not
  speed.

Details and evidence in [`docs/HOW-WE-GOT-HERE.md`](docs/HOW-WE-GOT-HERE.md).

## layout

```
bin/fanctl                  the tool
bin/fanrpm                  live monitor
tests/                      verification scripts
docs/register-map.md        EC register map and the addressing trap
docs/HOW-WE-GOT-HERE.md     the investigation, dead ends, and mistakes
docs/aml/                   decompiled DSDT/SSDT6 from this machine
vendor/acpi_call/           kernel module, patched for 7.x
install.sh
```

## after a BIOS update

The register map and the latch behaviour come from the F.14 firmware and could
move. Cheap check:

```sh
sudo tests/fanlatch
```

If "LATCHED" no longer reaches 5900 while "released" still shows the firmware
curve, the mechanism changed and `docs/register-map.md` needs re-deriving.
