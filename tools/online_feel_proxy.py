#!/usr/bin/env python3
"""Userspace stand-in for `tc netem delay` on loopback (no root needed): a UDP proxy that holds every
packet for DELAY_MS each way. Used by --online-feel-check (tools/online_feel_check.gd).
Usage: online_feel_proxy.py LISTEN_PORT TARGET_PORT DELAY_MS   (stop it by its pid)"""
import asyncio
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


async def main(listen, target, delay_ms):
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(lambda: Front(("127.0.0.1", target), delay_ms / 1000.0),
                                        local_addr=("127.0.0.1", listen))
    await asyncio.Event().wait()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3])))
