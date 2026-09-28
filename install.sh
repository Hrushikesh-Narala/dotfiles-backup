#!/usr/bin/env bash
# install.sh - put fanctl and fanrpm on PATH.
#
# Idempotent. Does not touch anything outside ~/.local/bin unless you ask it to.

set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN=${1:-$HOME/.local/bin}

mkdir -p "$BIN"
for f in fanctl fanrpm; do
  install -m 0755 "$HERE/bin/$f" "$BIN/$f"
  echo "  installed $BIN/$f"
done

echo
echo "Verify with:  $BIN/fanctl list"
echo "Fan control needs root, since it writes /dev/mem."
echo
echo "The ACPI cross-check in fanrpm needs a kernel module that is not packaged"
echo "for most distros. It is optional. To build it:"
echo
echo "    make -C $HERE/vendor/acpi_call"
echo "    sudo insmod $HERE/vendor/acpi_call/acpi_call.ko"
echo
echo "It must be rebuilt and reloaded after every kernel update, and it does not"
echo "survive a reboot. fanctl itself does not need it."
