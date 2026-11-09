#!/usr/bin/env python3
"""A UDP delay proxy for online-feel runs (tools/online_displace_check.gd), for machines where tc/netem is not allowed.

usage: udp_delay.py LISTEN_PORT RELAY_PORT DELAY_MS
Every datagram in either direction is held DELAY_MS before it is passed on, like `tc qdisc add dev lo root netem delay`
on loopback: a client sees 2 x DELAY_MS of round trip. Order is kept. Stop it by killing its pid."""
import heapq
import select
import socket
import sys
import time

HOST = "127.0.0.1"


def main(listen: int, relay: int, delay_ms: float) -> None:
    delay = delay_ms / 1000.0
    front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    front.bind((HOST, listen))
    ups = {}       # client address -> its socket to the relay
    clients = {}   # that socket -> client address
    held = []      # (due, seq, socket to send on, data, destination)
    seq = 0
    while True:
        wait = max(0.0, held[0][0] - time.monotonic()) if held else 1.0
        ready, _, _ = select.select([front] + list(ups.values()), [], [], wait)
        now = time.monotonic()
        for s in ready:
            data, addr = s.recvfrom(65535)
            if s is front:
                if addr not in ups:
                    ups[addr] = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    ups[addr].bind((HOST, 0))
                    clients[ups[addr]] = addr
                heapq.heappush(held, (now + delay, seq, ups[addr], data, (HOST, relay)))
            else:
                heapq.heappush(held, (now + delay, seq, front, data, clients[s]))
            seq += 1
        now = time.monotonic()
        while held and held[0][0] <= now:
            _, _, s, data, dest = heapq.heappop(held)
            s.sendto(data, dest)


if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3]))
