#!/bin/sh
#
# Runs from /usr/lib/systemd/system-sleep as "post suspend": after the machine
# has resumed from suspend-to-RAM, but BEFORE logind emits PrepareForSleep(false)
# to NetworkManager.
#
# Why this is needed
# ------------------
# NetworkManager decides whether to keep a device up across sleep by asking the
# kernel whether Wake-on-LAN is armed on it -- and it asks that question twice:
#
#   before suspend  (nm-manager.c)   armed  -> skip teardown, radio stays up
#   after  resume  (nm-manager.c)   armed  -> deliberately unmanage it again:
#                                     "Belatedly take down Wake-on-LAN devices;
#                                      ideally we wouldn't have to do this but for
#                                      now it's the only way to make sure we
#                                      re-check their connectivity."
#
# Both checks read *live* kernel state (NL80211_CMD_GET_WOWLAN), not a cached
# value, so they are allowed to disagree. Clearing WoWLAN in the gap between
# them means the radio was kept up and associated for the whole sleep, but NM's
# wake-time check now sees "not a wake-on-lan device" and skips the teardown.
# Association, DHCP lease and the wpa_supplicant session all survive, so there
# is no deauth, no reauthentication, no DHCP round trip, and nothing appears on
# the access point as a disconnect/reconnect.
#
# Why WoWLAN is re-armed afterwards
# ---------------------------------
# On this path NM never re-activates the connection -- that is the whole point --
# so it also never re-arms WoWLAN. It must be armed again before the *next*
# suspend, otherwise NM would tear the radio down when the machine next sleeps.
# A transient timer is used rather than sleeping here, because systemd applies
# a timeout to this hook and resume must not be delayed.
#
# Set by /etc/NetworkManager/conf.d/20-wifi-wowlan.conf (wifi.wake-on-wlan=12),
# so the triggers below must stay in sync with that value.

[ "$1" = post ] && [ "$2" = suspend ] || exit 0

dev=wlo1
phy=$(basename "$(readlink -f "/sys/class/net/$dev/phy80211")" 2>/dev/null) || exit 0
[ -n "$phy" ] || exit 0

# 1. Clear it now. NM's wake-time check runs ~2ms after this hook returns, so
#    there is no need to linger here.
iw phy "$phy" wowlan disable || exit 0

# 2. Re-arm for the next sleep, once NM has made the decision above.
#
#    AccuracySec must be pinned explicitly. systemd's default is 1min, which lets
#    it coalesce the timer and fire it arbitrarily later than asked for -- that
#    was measured landing 3.1s after a 10s request, which is fatal here: the
#    whole point of this timer is that it lands *before* the user next sleeps.
#    With AccuracySec=1us it fires at the requested time (measured 3.003s for a
#    3s request, across three cycles).
#
#    3s leaves ~1300x margin against the dangerous side (NM's check is ~2ms after
#    this hook returns) while keeping the window in which a stale timer could
#    survive from the previous cycle as short as possible.
#
#    Nothing else may run inline here. This hook executes inside the sleep job,
#    so every millisecond it spends is added to resume time -- a 'systemctl stop'
#    added here earlier was measured costing 0.2-0.6s of resume, and is why it is
#    gone. Two calls only: one netlink round trip, then one transient timer.
systemd-run --quiet --collect --unit=wifi-wowlan-rearm --on-active=3 \
	--timer-property=AccuracySec=1us \
	/usr/bin/iw phy "$phy" wowlan enable disconnect magic-packet || true

exit 0
