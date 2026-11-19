#!/usr/bin/env python3
"""Userspace stand-in for `tc netem delay` on loopback (no root needed): a UDP proxy that holds every
packet for DELAY_MS each way. Used by --online-feel-check (tools/online_feel_check.gd).
Usage: online_feel_proxy.py LISTEN_PORT TARGET_PORT DELAY_MS [MAX_SECS]
It never outlives its parent: it exits when the process that started it is gone (the check was killed or timed
out, so no cleanup ran) or after MAX_SECS (default 1200), and on SIGTERM. An orphan kept the jobq ssh pipe open
and stuck gate jobs for ~90 min (11-14)."""
import asyncio
import os
import signal
import sys


class Leg(asyncio.DatagramProtocol):
    """The proxy's own socket toward the target for one client."""

    def __init__(self, front, client, delay):
        self.front, self.client, self.delay = front, client, delay

    def datagram_received(self, data, addr):
        asyncio.get_running_loop().call_later(self.delay, self.front.transport.sendto, data, self.client)


class Front(asyncio.DatagramProtocol):
    def __init__(self, target, delay):
        self.target, self.delay, self.legs, self.transport = target, delay, {}, None

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        loop = asyncio.get_running_loop()
        if addr not in self.legs:
            self.legs[addr] = loop.create_task(loop.create_datagram_endpoint(
                lambda: Leg(self, addr, self.delay), remote_addr=self.target))
        loop.create_task(self._forward(addr, data))

    async def _forward(self, addr, data):
        leg, _ = await self.legs[addr]
        asyncio.get_running_loop().call_later(self.delay, leg.sendto, data)


async def watch_parent(max_secs):
    """Return when the parent is gone (we were re-parented) or the lifetime cap is hit."""
    parent, t0 = os.getppid(), asyncio.get_running_loop().time()
    while os.getppid() == parent and asyncio.get_running_loop().time() - t0 < max_secs:
        await asyncio.sleep(0.5)


async def main(listen, target, delay_ms, max_secs=1200.0):
    loop = asyncio.get_running_loop()
    stop = asyncio.Event()
    loop.add_signal_handler(signal.SIGTERM, stop.set)
    await loop.create_datagram_endpoint(lambda: Front(("127.0.0.1", target), delay_ms / 1000.0),
                                        local_addr=("127.0.0.1", listen))
    waiter = loop.create_task(watch_parent(max_secs))
    waiter.add_done_callback(lambda _t: stop.set())
    await stop.wait()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3]),
                     float(sys.argv[4]) if len(sys.argv) > 4 else 1200.0))
