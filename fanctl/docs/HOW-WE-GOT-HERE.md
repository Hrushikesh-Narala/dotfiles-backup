# how we got here

The short version: the fan is controlled by a single latch bit and a single
register, neither of which is documented, neither of which the AML uses for
speed control, and neither of which any Linux fan tool knows about. Finding
them took a long chain of mostly dead ends. This is the chain, including the
places it went wrong, because the wrong turns are as informative as the right
ones.

## the machine

    HP Envy x360 Convertible 13-ay1xxx
    board 8929, BIOS F.14 (07/2025, Insyde)
    Ryzen 5 5600U, 12 threads
    Nobara 44, kernel 7.2.6-201.nobara.fc44.x86_64

`lockdown` is `[none]` and Secure Boot is off. Both of those matter and both
must stay that way, for reasons that only became clear later.

## the goal

Terminal fan profiles - auto, manual RPM, max, balanced, silent, quiet -
behaving the same on AC and battery, with real speed feedback. Not a GUI.

## dead end 1: WMI

Every fan tool for HP laptops goes through WMI. It does not work here, and the
reason is worth stating precisely because it is not what it looks like.

SSDT6 defines `\_SB.WMID` with 48 method aliases, `GC01` through `GC2F`. In
the raw AML, **every one of them** is a stub whose body is
`Return (Package(0x02){Zero, Zero})`. A constant. No register access, no EC
write, nothing.

So the WMI protocol is fully present in the tables and completely inert. This
is not a driver-support problem that a newer kernel or a patched module could
fix - the firmware is returning a literal. No amount of correct OS-side
sequencing will make a stub call hardware.

This is also why `fan1_input` and `fan2_input` read 0 forever. The hp-wmi
driver is functioning; it is reading a path that returns a constant.

Along the way I made an error worth recording: I initially reported that WMI
method `0x29` (power limits) was real and un-stubbed. It was not. `GC29`
returns the same `Package(0x02){Zero,Zero}` as everything else. I had inferred
it from the driver's board list rather than reading the AML, and corrected it
once I disassembled the actual bytes.

## dead end 2: everything that needs pwm1

`/sys/class/hwmon/hwmon7/` has `fan1_input`, `fan2_input`, and a writable
`pwm1_enable` - but no `pwm1`. Which rules out:

- **fancontrol / lm-sensors** - need a `pwm1` to write
- **power-profiles-daemon** - CPU policy only, no fan control at all
- **NBFC** - the Linux port only speaks the LPC EC at 0x62/0x66, and there is
  no 13-ay configuration
- **ryzenadj** - needs Secure Boot enabled, which we cannot do (see below)

## dead end 3: the standard EC

`ec_sys` and the `/dev/port`/`/sys/kernel/debug/ec` interfaces reach the
standard LPC EC, declared in the DSDT as
`OperationRegion (ECPR, EmbeddedControl, Zero, 0xFF)`.

That EC contains battery and AC fields. No fan registers. None. So the entire
`ec_sys` avenue is irrelevant to this problem, no matter how it is configured.

The fan registers live somewhere else entirely: a `SystemMemory` region at
physical `0xFE0B0000`, declared as `ECMP` in the AML. It is invisible to
`ec_sys`, absent from `/proc/iomem`, and reachable only by the AML or by
`/dev/mem`.

## the read path

`/sys` was no help, so the registers had to be read directly. Reading
`0xFE0B0800` + offset via `/dev/mem` worked immediately, and the values were
sensible - a fan block with target, min, max, current, and a flags byte.

For a second opinion I wanted the AML's own view, which means calling
`\_TZ.TSZ0.FRSP`. That needs `acpi_call`, which is not packaged for Nobara. So
it was built from source (see `vendor/acpi_call`), with two changes for kernel
7.x, and cross-checked:

    FRSP  0x1194  = 4500 RPM
    FMAX  0x170c  = 5900 RPM
    FMIN  0x12c0  = 4800 RPM
    _TMP  0xc64   = 44.05 C   (k10temp said 43.9 C)

Two independent paths agreeing to within 0.15 C is what made it reasonable to
trust the `/dev/mem` read.

## getting the value out of acpi_call

A parsing trap, and it is a good one to know.

`acpi_call` returns a fixed 256-byte buffer. The useful value is at the front,
NUL-terminated. The bytes after the NUL are stale leftovers from the module's
own initialisation string `"not called"`. A successful call to `FRSP` reads:

    "0x1194" NUL "led" ...stale...

So the result is not `"0x1194led"` and it is not a clean string. The correct
read is to cut at the first NUL:

    cat /proc/acpi/call | tr '\000' '\n' | head -n1 | tr -cd '[:print:]'

Using `tr -d '\000'` instead is wrong - it deletes the NUL and glues the
stale tail onto the answer.

## the first write attempt, and bug one

The obvious sequence, taken from the shape of the AML's `FSSP` method, is:

    set FNSW -> write target -> clear FNSW

That sequence was implemented. It printed `write verified` and changed
nothing.

**Bug one: the write base was wrong.** `put()` wrote to `BASE + off` while
`block()` read from `BASE + 0x800 + off`. The target register `0x814` is at
offset `0x14` within the block, so writes were landing on `0xFE0B0014` instead
of `0xFE0B0814`. The readback was reading the right address, which is why it
correctly reported that nothing had changed - the write really had gone
somewhere else.

A writability probe settled it: `0xFFF`, `0x815`, `0x81C`, `0x80F` and `0x814`
were all writable and retained. So the register was never read-only. The
register was writable the whole time; the code was writing to the wrong place.

**Bug two, in the fix for bug one.** The verification read through the cached
block array that had been populated at the *start* of the operation, so it
could never observe the value just written. Every write would have been
reported as failed, or worse, as verified. Caught by rehearsing the logic
against a scratch file rather than the real device.

## the second wrong theory

With the address fixed, writes stuck and the fan still ignored them. The
natural guess was that a *mode* bit needed enabling, and `WPFM` (bit 6, which
reads plausibly as "write PWM fan") was the obvious candidate.

A sweep of seven flag combinations was run, each commanding maximum and
watching the tachometer. Results:

| Test | Flags             | Target | Peak     |      |
|------|-------------------|--------|----------|------|
| A    | FNSW only         | 59     | 5900     | yes  |
| B    | WPFM only         | 59     | 3600     | no   |
| C    | FNSW+WPFM         | 59     | 5900     | yes  |
| D    | FANE cleared +both| 59     | 5900     | yes  |
| E    | FNSW+WPFM         | 255    | 25500    | yes  |
| F    | FNSW+WPFM         | 0      | 3600     | no   |
| G    | all bits          | 59     | 5900     | yes  |

`FNSW` alone was sufficient, `WPFM` was irrelevant, and `FANE` was not
required. The scale was confirmed at exactly 100 RPM per unit.

So the sweep *found* the mechanism. And the real tool still did not work.

The mistake was assuming the sweep and the tool did the same thing. They did
not, and the difference was one line.

`fansweep`'s test function set the flags, wrote the target, then sampled for
six seconds and only restored the original state **at the end**. It never
released the latch during the measurement.

`fanctl` set the flags, wrote the target, and immediately cleared the flags -
mirroring the shape of the AML's `FSSP`. Which is what the sweep was
*not* doing, and what the hardware was *not* expecting.

**`FNSW` is a latch, not a write strobe.** While it is set, `0x814` is the
active command. Clear it and the EC hands the fan back to its own temperature
curve immediately.

The lesson, and I got this wrong twice in a row: when an experiment works and
the real code does not, diff the two paths before theorising about
undocumented bits. Instead I built an elaborate theory around `WPFM`, a bit I
had no documentation for, and never once compared the working code to the
broken code sitting next to it.

`tests/fanlatch` now exists solely to make this regression impossible to
reintroduce. It runs the same target twice, differing only in whether `FNSW`
is released, and the two must disagree.

## the A/B, once it was correct

    === A/B: same target 0x3B (5900 RPM), only FNSW release differs ===
      released (FNSW cleared after write)   peak  4500 RPM    (ignored)
      LATCHED (FNSW left set)               peak  5900 RPM    (obeyed)

Then the whole range, and the low end specifically:

    0   -> 0 RPM        reached
    12  -> 1200 RPM     reached
    20  -> 2000 RPM     reached
    30  -> 3000 RPM     reached
    59  -> 5900 RPM     reached

## fan-off, and a bad measurement of it

A commanded `0` genuinely stops the fan. This was confirmed by hand on the
exhaust, not by a register - `0x811` reads `0` whether the blades are stopped
or spinning at 3600, so it cannot answer the question, and both hwmon fan
inputs are dead.

Getting there involved the worst measurement in the whole project. The first
attempt compared temperature rise at 1200 RPM against temperature rise at 0,
and reported "indistinguishable, so the fan probably never stopped". That
verdict was wrong twice over:

**The A/B was invalid.** The baseline phase ran first and heated the machine
from 56.5 C to 62.6 C. The "off" phase then started at 61.1 C and finished at
62.8 C. Its `+1.7 C` rise was measured against a starting point 4.6 C hotter
than the baseline's, so the two numbers were never comparable. The phase was
really testing "an already-warm machine", not "a stopped fan".

**The conclusion contradicted the evidence.** The trajectory under load was
`... 64.4 64.6 64.8 64.6 64.1 63.8 63.5` - temperature *falling* while two
cores were loaded. With the fan genuinely off, heat can only accumulate, so a
fall meant something else was cooling. The registers still read
`latched=9 target=0x00`, so the EC had not touched our command, and I inferred
that the EC's thermal logic had overridden us internally.

That inference was unsupported, and the correction offered - CPU power
throttling - was no better: the machine reported 99% of max frequency
afterwards and exposed no throttle counters, so that explanation was
unsubstantiated too. The honest position is that the temperature fall is
unexplained. What is not in doubt is that the fan physically stopped, because
a hand was on the exhaust.

The lesson is the same one from the `FNSW` latch, in a different costume:
a single ambiguous number produced a confident theory, and the theory was
acted on before the measurement that would have tested it. A falling
temperature under load is a signal to investigate, not to conclude from.

`tests/fanoff` replaces the invalid A/B: it establishes a genuine cold
baseline, then runs one phase with the fan stopped, reporting the whole
trajectory against the abort temperature. It never leaves a commanded `0`
in place, aborts at 70 C, and detects the EC reclaiming the command by
checking the latch as well as the target - an EC that reclaims by clearing
`FNSW` leaves the target register untouched, so a target-only check would
miss it entirely.

`fanctl off` guards this state more tightly than the other profiles: a
stopped fan arms the thermal guard at 70 C rather than 85, `fanctl guard`
re-arms at whichever threshold matches the current mode, and `fanctl status`
prints a warning if it ever finds a commanded `0` with no guard running. That
combination - fan stopped, no cooling, no guard - is the one genuinely
destructive state available through this interface, so it is the one the tool
refuses to sit in quietly.

One earlier reading of 1200 RPM had come back as "peak 5900" and looked like a
failure. It was a measurement artefact: the metric was a 4-second *peak*, and
the fan had not finished spinning down from the previous step. A peak cannot
distinguish "rejected" from "has not arrived yet". `tests/fantail` samples the
whole trajectory instead and reports a verdict per target.

## what the RPM number actually is

`0x811` reports the **commanded** value, not a measured speed. Commanding 255
produced a reported 25500 RPM, which this fan cannot physically spin. The
register is echoing the target.

So there is no true fan speed available on this machine. Both hwmon fan inputs
are permanently zero. The only ground truth is a hand on the exhaust - which
is what confirmed the mechanism worked before any register readback could.

The tools label this explicitly rather than printing an unmarked number,
because a confidently wrong RPM readout is worse than no readout.

## the AC versus battery question

On AC the fan sits at 4500 RPM from about 31 C upward, including at 76 C. On
battery it runs a real curve - 0, then 1000, 1800, 2400, 3000, 3400, 3800,
4200, 4500 tracking 55 to 64 C - and drops back to 0 at 50 C.

That difference is EC firmware policy, not ACPI. The ACPI query handlers for
the adapter (`_Q2C`, `_Q37`, `_Q38`) touch `ACAD` and never the fan block.
Nothing in the AML writes `FANE`; the EC firmware owns that bit. The one SCI
handler that touches the fan at all, `_Q14`, only raises a fan-fault alarm
when `FANE` is clear.

Which is why the profiles latch rather than negotiate: there is nothing to
negotiate with. You take the register.

## secure boot

Must stay **disabled**. It gates unsigned module loading, and the only way to
read the AML was a hand-built unsigned `acpi_call.ko`. Enabling it would break
the read path entirely.

`/dev/mem` access does not depend on Secure Boot, only on `lockdown`, which is
`[none]`. So `fanctl` itself keeps working either way - which is why it was
rewritten to use `/dev/mem` only and to treat `acpi_call` as an optional
cross-check rather than a dependency.

## what would need redoing after a BIOS update

The register map and the `FNSW` latch come from the F.14 firmware. A BIOS
update could move them. The cheap check:

    sudo tests/fanlatch

If the "LATCHED" line no longer reaches 5900 while the "released" line still
shows the firmware curve, the mechanism changed and `docs/register-map.md`
needs re-deriving. That is what the tests are for.
