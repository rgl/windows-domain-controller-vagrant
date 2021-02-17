#!/bin/bash
set -euxo pipefail

# bail when not running over hyperv.
dmi_sys_vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor)
if [ "$dmi_sys_vendor" != 'Microsoft Corporation' ]; then
  exit 0
fi

if [ -f /etc/network/interfaces ]; then
  # debian.
  cat >/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto vmbr0
iface vmbr0 inet manual
EOF
  n=0
  for ip in "$@"; do
    ((n=n+1))
    cat >>/etc/network/interfaces <<EOF
auto eth$n
iface eth$n inet static
  address $ip/24
EOF
    ifup eth$n
  done
else
  # ubuntu.
  cat >/etc/netplan/02-hyperv.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF
  n=0
  for ip in "$@"; do
    ((n=n+1))
    cat >>/etc/netplan/02-hyperv.yaml <<EOF
    eth$n:
      addresses:
        - $ip/24
EOF
  done
netplan apply
fi

# show resulting configuration.
ip addr

# wait until we can resolve addresses.
python3 <<'EOF'
import socket
import time

while True:
  try:
    socket.gethostbyname("ruilopes.com")
    break
  except:
    time.sleep(1)
EOF
