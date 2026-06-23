#!/bin/sh
date >> /tmp/lid-script-run.log
/usr/bin/rfkill unblock wifi
/usr/bin/nmcli radio wifi on
sleep 2
ACTIVE=$(/usr/bin/nmcli -t -f name connection show --active | head -n1)
if [ -n "$ACTIVE" ]; then
    /usr/bin/nmcli connection up "$ACTIVE"
fi
/usr/bin/systemctl restart systemd-rfkill.service
