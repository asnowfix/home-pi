#!/bin/bash
# Diagnostic MITM capture of the Roomba, scoped to its IP only. Run ON the Pi
# (192.168.1.2). Positions the Pi as man-in-the-middle for just the robot via
# ARP spoofing, enables forwarding so the robot keeps working, and captures all
# its traffic. Requires: tcpdump, dsniff (arpspoof). See README.md.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
IFACE="${IFACE:-eth0}"
ROOMBA="${ROOMBA:-192.168.1.74}"
GW="${GW:-192.168.1.1}"
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
sudo nohup /usr/sbin/arpspoof -i "$IFACE" -t "$ROOMBA" "$GW" >"$DIR/arp-roomba.log" 2>&1 &
sudo nohup /usr/sbin/arpspoof -i "$IFACE" -t "$GW" "$ROOMBA" >"$DIR/arp-gw.log" 2>&1 &
sudo nohup tcpdump -i "$IFACE" -nn -s 0 -w "$DIR/roomba.pcap" host "$ROOMBA" >"$DIR/tcpdump.log" 2>&1 &
sleep 1
echo "started: $(pgrep -c arpspoof) arpspoof, tcpdump -> $DIR/roomba.pcap"
