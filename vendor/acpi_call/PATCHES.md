# acpi_call - local patches for kernel 7.x

Upstream is Michal Kottman's `acpi_call` (2010/2013), vendored here as
`acpi_call.c` with two changes needed to build against a modern kernel.
Upstream `README.md` is preserved alongside.

The `.ko` is deliberately **not** committed. A module only loads against the
exact kernel it was built for, so committing one is actively misleading. Build
it on the machine that will use it.

```sh
make
sudo insmod acpi_call.ko
```

Re-verify the module is actually present before reading anything into a
failure:

```sh
ls -l /proc/acpi/call && lsmod | grep acpi_call
```

## patch 1: ACPI header include

```diff
-#include <acpi/acpi.h>
+#include <linux/acpi.h>
```

Modern kernels do not install `acpi/acpi.h` as a separate header, so the
upstream include fails to resolve.

## patch 2: procfs operations

Upstream declares its procfs entry with `struct file_operations`. That type
was removed from the procfs interface; the replacement is
`struct proc_ops`, whose read and write members are renamed.

```diff
-static struct file_operations acpi_operations = {
-        .owner   = THIS_MODULE,
-        .write   = acpi_proc_write,
-        .read    = acpi_proc_read,
-};
+static const struct proc_ops proc_acpi_operations = {
+        .proc_read  = acpi_proc_read,
+        .proc_write = acpi_proc_write,
+};
```

The read and write callbacks themselves need no changes - the
`ssize_t(struct file *, ...)` signatures are still correct. Only the
operations struct and its member names differ.

`acpi_call.c` in this directory already has both changes applied, so
`make && sudo insmod acpi_call.ko` works as-is. This file is here so the
modifications are legible and reviewable rather than hidden in a binary.

## why the file is a patched copy, not a patch

Both edits are small and mechanical, but rather than ship a `.patch` that may
fail to apply against a slightly different upstream snapshot, the working
source is committed directly with the diffs documented above. The two edits
are the *only* differences from upstream; everything else is verbatim.

## note on reading results

This matters more than it looks. The module returns a **fixed 256-byte
buffer**. The value is at the front, NUL-terminated, and the bytes after the
NUL are stale leftovers from the module's own initialisation string
`"not called"`.

A successful call to `\_TZ.TSZ0.FRSP` reads roughly:

```
"0x1194" NUL "led" ...stale garbage...
```

So the result is not `"0x1194led"`. Cut at the first NUL:

```sh
printf '%s\n' '\\_TZ.TSZ0.FRSP' > /proc/acpi/call
cat /proc/acpi/call | tr '\000' '\n' | head -n1 | tr -cd '[:print:]'
```

Using `tr -d '\000'` instead is wrong - it removes the NUL and glues the stale
tail onto the answer.

## does anything depend on this?

`fanctl` does not. It uses `/dev/mem` only, deliberately, so that it keeps
working across reboots and kernel updates without a module that has to be
rebuilt every time.

`fanrpm` uses it for a second opinion alongside its raw `/dev/mem` reading.
That column is optional; if the module is missing, `fanrpm` degrades to the raw
column rather than failing.
