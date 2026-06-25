# HP Laptop Firmware Hotkey Bug Investigation Report

## System Information

Laptop: HP Laptop

Wireless Adapter: Realtek RTL8852AE

Driver: rtw89_8852ae

Desktop Environment: KDE Plasma (Wayland)

Distribution: Nobara Linux

---

# Issue 1: Wi-Fi Turns Off When Opening the Lid

## Symptoms

The laptop was configured so that closing the lid performed no action.

Expected behavior:

- Close lid → screen turns off
- Open lid → Wi-Fi remains connected

Actual behavior:

- Close lid → screen turns off
- Open lid → Wi-Fi disconnects immediately

The disconnect occurred every time the lid was opened.

---

## Initial Hypotheses

Several possible causes were investigated:

### NetworkManager Wi-Fi Power Saving

Checked:

```bash
iw dev wlo1 get power_save
```

Result:

```text
Power save: off
```

Wi-Fi power saving was not the cause.

### KDE Power Management

Verified that lid actions were configured correctly.

Checked:

```bash
grep -R HandleLidSwitch /etc/systemd/logind.conf /etc/systemd/logind.conf.d/*
```

Result:

```text
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
```

Lid actions were already disabled.

### Suspend / Sleep Trigger

Checked logs for suspend activity.

Result:

No suspend operation occurred.

The machine was not entering sleep.

---

## Breakthrough

Kernel logs revealed:

```text
Lid opened
wlo1: deauthenticating
rfkill: WLAN soft blocked
NetworkManager: Wi-Fi disabled by radio killswitch
```

Important finding:

```text
rfkill: WLAN soft blocked
```

Wi-Fi was not disconnecting naturally.

Something was explicitly disabling it.

---

## rfkill Investigation

Monitoring rfkill events:

```bash
rfkill event
```

Closing and reopening the lid produced:

```text
idx 1 type 1 op 2 soft 1 hard 0
```

Meaning:

```text
Wi-Fi soft blocked
```

The question became:

"What is triggering rfkill?"

---

## ACPI Event Investigation

Monitored ACPI events:

```bash
acpi_listen
```

Closing and opening the lid produced:

```text
button/lid LID close
button/lid LID open
button/wlan WLAN 00000080 00000000
```

Critical discovery:

Opening the lid generated a WLAN button event.

The laptop firmware incorrectly behaved as if a Wi-Fi toggle key had been pressed.

---

## Root Cause

HP firmware generated:

```text
button/wlan
```

during lid-open events.

That WLAN event triggered:

```text
rfkill
```

which disabled Wi-Fi.

---

## Fix

Unknown HP scan codes were identified:

```text
e057
e058
```

They were remapped to KEY_UNKNOWN:

```bash
setkeycodes e057 240 e058 240
```

---

## Permanent Solution

Created:

```text
/etc/systemd/system/hp-keycodes.service
```

with:

```ini
[Unit]
Description=HP laptop firmware hotkey fixes

[Service]
Type=oneshot
ExecStart=/usr/bin/setkeycodes e057 240 e058 240

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
```

Enabled:

```bash
sudo systemctl enable hp-keycodes.service
```

---

## Verification

After reboot:

- Close lid
- Open lid

Result:

```text
Wi-Fi remained connected
```

Issue resolved.

---

# Issue 2: Microphone Mute Key Toggles Twice

## Symptoms

Fn+F8 should:

```text
Unmuted → Muted
```

Instead:

```text
Unmuted → Muted → Unmuted
```

The mute indicator briefly appeared and immediately disappeared.

The microphone never stayed muted.

---

## Initial Hypotheses

### KDE Shortcut Conflict

Tested by directly invoking KDE mute actions.

Result:

KDE mute worked correctly.

Not the cause.

### PipeWire / WirePlumber

Monitored microphone state:

```bash
wpctl get-volume 62
```

Observed:

```text
Volume: 1.00
Volume: 1.00 [MUTED]
Volume: 1.00
```

The microphone was genuinely toggling twice.

Not a visual bug.

### ALSA Capture Switch

Checked:

```bash
amixer get Capture
```

No changes occurred during key presses.

Not an ALSA capture switch issue.

---

## Input Layer Investigation

Checked HP WMI events:

```bash
sudo evtest /dev/input/event18
```

Observed:

```text
KEY_MICMUTE
```

once per press.

At first this suggested normal behavior.

---

## Breakthrough

Using:

```bash
sudo libinput debug-events --show-keycodes
```

produced:

```text
event3  KEY_MICMUTE
```

followed approximately 200 ms later by:

```text
event18 KEY_MICMUTE
```

Important finding:

The same physical key generated events from two different devices.

---

## Device Sources

### Device 1

```text
AT Translated Set 2 keyboard
event3
```

Generated:

```text
MSC_SCAN value 82
KEY_MICMUTE
```

### Device 2

```text
HP WMI hotkeys
event18
```

Generated:

```text
MSC_SCAN value 270
KEY_MICMUTE
```

---

## Root Cause

One physical key press generated:

```text
KEY_MICMUTE
```

twice.

Sequence:

```text
Fn+F8
↓
Keyboard event
↓
Mute
↓
HP WMI event
↓
Unmute
```

The microphone returned to its original state.

---

## Fix

Ignore the keyboard copy.

Temporary test:

```bash
sudo setkeycodes 82 240
```

Result:

```text
Fn+F8
↓
Muted
```

Microphone stayed muted.

Problem solved.

---

## Permanent Solution

Updated:

```text
/etc/systemd/system/hp-keycodes.service
```

to:

```ini
[Unit]
Description=HP laptop firmware hotkey fixes

[Service]
Type=oneshot
ExecStart=/usr/bin/setkeycodes e057 240 e058 240 82 240

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
```

Reloaded:

```bash
sudo systemctl daemon-reload
sudo systemctl restart hp-keycodes.service
```

---

## Verification

After reboot:

Press:

```text
Fn+F8
```

Result:

```text
Unmuted → Muted
```

Press again:

```text
Muted → Unmuted
```

Behavior became correct.

Issue resolved.

---

# Final hp-keycodes.service

```ini
[Unit]
Description=HP laptop firmware hotkey fixes

[Service]
Type=oneshot
ExecStart=/usr/bin/setkeycodes e057 240 e058 240 82 240

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
```

---

# Summary

## Wi-Fi Bug

Cause:

```text
Lid open generated a bogus WLAN event.
```

Fix:

```text
e057 → KEY_UNKNOWN
e058 → KEY_UNKNOWN
```

## Microphone Bug

Cause:

```text
Fn+F8 generated KEY_MICMUTE twice from two devices.
```

Fix:

```text
82 → KEY_UNKNOWN
```

Both bugs were caused by HP firmware exposing duplicate or incorrect input events.

The permanent solution was implemented through a single systemd service that remaps the problematic scan codes during boot.
