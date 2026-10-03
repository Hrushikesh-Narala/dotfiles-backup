# Safety audit

Findings from a review of `bin/fanctl` and `bin/fanrpm` for input handling,
error paths, concurrency and resource lifetime. Every entry was reproduced
before it was fixed, and each has a test in `tests/harness` or
`tests/fanrpm-display` that fails if the bug comes back.

Run the regression suite (no root, no hardware, touches nothing real):

    bash tests/run-all

---

## Bugs found and fixed

### 1. A large RPM value silently stopped the fan — CRITICAL

`fanctl manual 18446744073709551615` divided by 100 in bash integer
arithmetic wraps 64-bit unsigned to exactly **0**. Zero is not an error path,
it is the command to *stop the fan*. The `FNMX` clamp could not catch it,
because the wrapped value is below the ceiling, so it passed straight through.

The result: a normal-looking profile command stopped the fan, armed the guard
at the ordinary 85 °C instead of the 70 °C that a stopped fan requires, and
printed a reassuring `0 RPM commanded`.

Fixed by rejecting anything implausible before the division, and by validating
the range again in `putb` and `command_units` so no caller can bypass it.

### 2. `guard` accepted a command as its argument — privilege escalation

`fanctl guard '$(anything)'` wrote that value into `/etc/fanctl.conf`, which
`apply` then read with `.` (source) as root. Demonstrated: the command executed.

The config is now parsed with `sed` and strict pattern matching, and `guard`
validates its argument. Three independent barriers: reject, parse-not-source,
and re-validate at the point of use.

### 3. `exec 9>"$LOCK" 2>/dev/null` silenced the whole program

A bare `exec` with a redirection and no command applies it to the current shell
**permanently**. So the `2>/dev/null` intended for one line discarded stderr
for the entire run. Running as root, `/run` is writable, the exec succeeds, and
every subsequent error message — refused writes, unreadable EC, failed latch —
vanished. `fanctl apply` printed nothing at all and exited 1.

This one was found *by* the harness, after being introduced *by* the fix for
concurrency. Never put a redirection on a bare `exec`.

### 4. An armed guard held the lock forever

The guard is a background subshell, so it inherited the lock file descriptor.
`flock` locks live on the open file description, not the process, so the guard
held the lock for as long as it ran — and every later `fanctl`, including a
read-only `status`, stalled for the full 5 s timeout. Measured: 5.02 s per
command, forever.

The guard now closes the descriptor before it starts polling.

### 5. Concurrent invocations orphaned guards — leak, and worse

`stop_guard` kills the pid in the pid file, but concurrent invocations all read
the same file, all kill the same pid, and the losers are never killed by anyone.
Measured: **43 live guards** after one harness run. Each was polling forever,
holding a stale trip point, and any of them could release the fan to `auto` at
a temperature the current profile never agreed to.

Guards are now self-fencing: each one re-checks every poll that it is still the
guard named in the pid file, and exits within 2 s if it is not. Measured after
the fix: exactly 1.

### 6. An unknown command did nothing and reported success

The `case` statement had no default, so `fanctl silnet` — a typo — printed
nothing, changed nothing, and **exited 0**. A tool that reports success for a
command it did not understand is worse than one that complains, because you
believe the fan is set how you asked and it is not.

There is now a default branch that names the problem and exits 1.

### 7. Empty arguments produced raw bash errors

`fanctl set` and `fanctl ondc` with no argument indexed an associative array
with an empty subscript, printing `PROFILE: bad array subscript` instead of a
sentence. Both now explain what is missing.

### 8. `putb` could write more than one byte

`printf '%03o' 256` is `400` — three octal digits — and `dd` would have written
three bytes, smearing into registers 0x815 and 0x816. Latent rather than live,
because every caller clamped to `FNMX` first, but `putb` now refuses anything
outside 0–255 so a caller-side bug can never become register corruption.

### 9. A failed read flowed onward as arithmetic

`getb` returns `-1` on failure. That `-1` reached `$(( f | FNSW_BIT ))`, and
the "preserve the other flag bits" logic would write `-1` to the EC. The write
is now refused with a message that names the real problem, and the failure
check happens before the arithmetic, not after.

### 10. Speeds were commanded with no known ceiling

If `FNMX` (0x812) could not be read there was no clamp, so a large request went
straight to the register. Now refused outright, with a message saying why.

### 11. `fanrpm` displayed failed reads as measurements

- An unreadable register became `-100 RPM` on screen.
- An unreadable flags byte became `FANE=1 FNSW=1 WPFM=1` — bit extractions of
  `-1`, presented as a confident claim that the fan was faulted and latched.
- The AML value was parsed with a "starts with 0x" test that let `0x` through
  into `$(( ))`, producing a shell error and then a displayed `0 RPM`.
- A failed sample was recorded in the sparkline history, skewing the peak and
  every bar height.
- With all samples failing, `${HIST[0]}` expanded to nothing and every refresh
  printed `integer expected`.

All of these now say `unreadable` and nothing else.

### 12. The guard's trip sidecar outlived the guard

`stop_guard` removed the pid file but not `$GUARDPID.trip`, so `status` could
report a trip temperature belonging to a guard that no longer existed.

### 13. The guard re-executed itself by an unresolvable path

The guard called `"$0" auto` when it tripped, long after the invoking shell was
gone, and discarded the output. If `fanctl` had been invoked as a bare name and
`PATH` differed in the guard's environment, the re-exec failed silently and the
fan stayed latched. It now resolves an absolute path up front and refuses to
start if it cannot.

---

## Why the tests are built this way

`tests/harness` runs the **real** `bin/fanctl`. It does not reimplement it,
because the two bugs that cost the most time debugging both came from a test
and the shipped code disagreeing.

The fake EC is a **sparse** file positioned at the same physical offset the real
one occupies (`0xFE0B0800`), so the shipped offset arithmetic is exercised
unchanged. Only the root check is rewritten; `MEM`, `K10`, `CONF`, `GUARDPID`,
`LOCK` and `PWRDIR` are environment overrides that `fanctl` reads, with the
real paths as the fallback.

The harness asserts on the resulting register bytes, not on the printed output.
A command that prints the right thing while writing the wrong bytes is exactly
the failure that produced bug 3.

Guard processes from a run are cleaned up between runs; the suite has a check
that fails if more than one is alive.

## What the tests cannot tell you

- **True fan RPM is unmeasurable on this machine.** Register 0x811 echoes the
  commanded value, not a tachometer, and both hwmon fan inputs are permanently
  zero. Airflow at the exhaust is the only real sensor. No test here can prove a
  commanded speed equals an actual speed.
- **The thermal guard's real trip behaviour** depends on the real k10temp
  sensor, not the fake one. The harness proves the logic, the timing and the
  release-to-`auto` path; `tests/fanoff` is what measures actual heat.
- **Whether the EC accepts a write at all** is a property of the hardware. The
  harness uses a file. `tests/fanlatch` is the A/B that pins the mechanism.
