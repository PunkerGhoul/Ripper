#!/bin/sh

for iface in eth0 ens33 ens3 enp0s3 enp3s0 enp2s0 en0; do
  ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
  if [ -n "$ip" ]; then
    echo "%{F#ffffff}  %{F#ffffff}${ip}%{u-}"
    exit 0
  fi
done

echo "%{F#ff0000}  disconnected%{u-}"
