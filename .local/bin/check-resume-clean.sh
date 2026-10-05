#!/bin/bash
#
# check-resume-clean.sh -- did NetworkManager tear the Wi-Fi connection down and
# rebuild it when the machine woke, or was it left alone?
#
# PASS (CONTINUOUS) means the association, the IP lease and the wpa_supplicant
#      session all survived the whole sleep: no deauth, no interface deinit, no
#      DHCP restart, no reactivation. This is what stops a phone hotspot from
#      showing the laptop as briefly disconnected on wake.
# FAIL (REASSOCIATED) means NetworkManager took wlo1 down and rebuilt it, which
#      is what that brief disconnect actually is.
#
# Usage:
#   check-resume-clean.sh            # newest boot that has a resume
#   check-resume-clean.sh -b -1      # a specific boot
#   check-resume-clean.sh -w 40      # post-resume window in seconds (default 25)
#
# Read-only. Changes nothing.

set -u

boot=""
win=25

usage() { sed -n '3,18p' "$0" | sed 's/^# \?//'; }

while getopts "b:w:h" opt; do
	case "$opt" in
		b) boot=$OPTARG ;;
		w) win=$OPTARG ;;
		h) usage; exit 0 ;;
		*) usage; exit 2 ;;
	esac
done

# The machine may well have rebooted since the sleep cycle, so find the newest
# boot that actually contains a resume rather than assuming the current one.
if [ -z "$boot" ]; then
	for b in 0 -1 -2 -3 -4 -5; do
		if journalctl -b "$b" --no-pager -o cat 2>/dev/null | grep -qm1 "PM: suspend exit"; then
			boot=$b
			break
		fi
	done
	if [ -z "$boot" ]; then
		echo "No boot on this machine has a 'PM: suspend exit' record -- nothing to check."
		exit 1
	fi
fi

raw=$(mktemp)
trap 'rm -f "$raw"' EXIT

# Monotonic clock (not wall time) so deltas survive clock steps across resume.
journalctl -b "$boot" --no-pager -o short-monotonic 2>/dev/null \
	| sed -E 's/^\[ *([0-9]+\.[0-9]+)\] +/\1\t/' >"$raw"

if ! grep -q "PM: suspend exit" "$raw"; then
	echo "Boot $boot contains no 'PM: suspend exit' record -- nothing to check."
	exit 1
fi

# Pass 1: locate the most recent resume, so that pass 2 cannot be contaminated
# by an earlier cycle (two sleeps can easily be less than one window apart).
t0=$(awk -F'\t' '/PM: suspend exit/ { t = $1 + 0 } END { printf "%.6f", t }' "$raw")

echo "=== Wi-Fi continuity across the most recent resume (boot $boot, +${win}s) ==="
echo
# Pass 2: strictly (t0, t0+win].
awk -v t0="$t0" -v win="$win" -F'\t' '
function row(label, v) {
	if (v == "") printf "  %-30s none      OK\n", label
	else            printf "  %-30s %6.2fs  PRESENT\n", label, v - t0
}
{
	t = $1 + 0
	if (t <= t0 || t > t0 + win) next
	m = $2
	if (da == "" && m ~ /wlo1: deauthenticating/)                                 da = t
	if (de == "" && m ~ /nl80211: deinit ifname=wlo1/)                            de = t
	if (bl == "" && m ~ /CTRL-EVENT-BEACON-LOSS/)                                bl = t
	if (dh == "" && m ~ /dhcp4 \(wlo1\): canceled DHCP/)                         dh = t
	if (re == "" && m ~ /device \(wlo1\): Activation: starting connection/)      re = t
	if (um == "" && m ~ /device \(wlo1\): state change: activated -> unmanaged/) um = t
	if (ls == "" && m ~ /dhcp4 \(wlo1\): state changed new lease/)                ls = t
	next
}
END {
	print "  --- signals that mean the radio was torn down and rebuilt ---"
	row("802.11 deauthentication",  da)
	row("supplicant iface deinit",  de)
	row("beacon loss",              bl)
	row("DHCP transaction restart", dh)
	row("connection reactivation",  re)
	row("forced to unmanaged",      um)
	bad = 0
	if (da != "") bad = 1
	if (de != "") bad = 1
	if (bl != "") bad = 1
	if (dh != "") bad = 1
	if (re != "") bad = 1
	if (um != "") bad = 1
	printf "\n  --- time from resume to usable ---\n"
	row("new DHCP lease (wlo1)",    ls)
	if (bad) verdict = "REASSOCIATED -- the link was torn down and rebuilt on resume."
	else      verdict = "CONTINUOUS -- Wi-Fi was never taken down across this sleep."
	printf "\n  VERDICT: %s\n", verdict
	if (!bad && ls == "") printf "            (no DHCP lease either -- the old lease survived untouched)\n"
}
' "$raw"

echo
echo "=== every resume in this boot ==="
# Each cycle's window ends at the next resume, so cycles cannot bleed into one
# another. A teardown within 10s of the resume is the resume blip; one later is
# NetworkManager unmanaging the radio at the *next* suspend because the hook's
# re-arm had not landed yet -- a different, separate failure.
awk -v win="$win" -F'\t' '
{ ts[NR] = $1 + 0; msg[NR] = $2 }
END {
	k = 0
	for (i = 1; i <= NR; i++)
		if (msg[i] ~ /PM: suspend exit/) { k++; rt[k] = ts[i] }
	if (k == 0) { print "  no resume found"; exit }
	for (c = 1; c <= k; c++) {
		lo = rt[c]
		hi = lo + win
		if (c < k && rt[c + 1] < hi) hi = rt[c + 1]
		ls = ""; da = ""
		for (i = 1; i <= NR; i++) {
			t = ts[i]
			if (t <= lo || t > hi) continue
			if (ls == "" && msg[i] ~ /dhcp4 \(wlo1\): state changed new lease/) ls = t
			if (da == "" && msg[i] ~ /wlo1: deauthenticating/)                  da = t
		}
		l = "none (lease survived)"
		if (ls != "") l = sprintf("+%.2fs", ls - lo)
		d = "-"
		if (da != "") {
			d = sprintf("+%.2fs", da - lo)
			if (da - lo > 10) d = d "  <- next suspend, re-arm was late"
			else             d = d "  <- RESUME BLIP"
		}
		printf "  %-3s resume at monotonic %-11.3f  new lease %-18s teardown %s\n", c, lo, l, d
	}
}
' "$raw"

echo
echo "=== state now ==="
echo "  wowlan : $(iw phy phy0 wowlan show 2>&1 | tr '\n' ' ')"
echo "  addr   : $(ip -4 -o addr show dev wlo1 scope global 2>/dev/null | awk '{print $4}')"
if [ -x /usr/lib/systemd/system-sleep/wifi-wowlan-resume.sh ]; then
	echo "  hook   : installed"
else
	echo "  hook   : NOT installed"
fi