#!/bin/bash
# Tear down the capture and RESTORE the network. SIGTERM lets arpspoof broadcast
# correct ARP mappings so the robot's cache heals immediately.
sudo pkill -x -TERM arpspoof 2>/dev/null; sleep 3
sudo pkill -9 -x arpspoof 2>/dev/null
sudo pkill -f 'tcpdump.*roomba.pcap' 2>/dev/null
sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null
echo "stopped. arpspoof procs now: $(pgrep -c arpspoof); ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"
