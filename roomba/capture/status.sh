#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "arpspoof procs: $(pgrep -c arpspoof)"
echo "tcpdump: $(pgrep -f 'tcpdump.*roomba.pcap' >/dev/null && echo running || echo stopped)"
ls -la "$DIR/roomba.pcap" 2>/dev/null
[ -f "$DIR/roomba.pcap" ] && sudo tcpdump -nn -r "$DIR/roomba.pcap" 2>/dev/null | wc -l | xargs echo "packets captured:"
