#!/bin/bash
set -euo pipefail

cp /tmp/overlay/*.service /etc/systemd/system/
systemctl enable case-led-boot.service
systemctl enable case-led-reboot.service
systemctl enable case-led-shutoff.service