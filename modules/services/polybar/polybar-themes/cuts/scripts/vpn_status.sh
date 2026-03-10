#!/bin/sh

IFACE=$(ifconfig | grep tun0 | awk '{print $1}' | tr -d ':')

if [ "$IFACE" = "tun0" ]; then
	echo "%{F#ffffff} $(ifconfig tun0 | grep "inet " | awk '{print $2}')%{F-}"
else
	echo "%{F#ffffff}  Disconnected%{F-}"
fi
