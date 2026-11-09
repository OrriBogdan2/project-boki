"""The matchmaker proper: tickets in, matches started, host/port/token out. One lock around all state;
`tick()` runs every half second from a thread and is where matches start, tokens expire and processes get reaped."""
import secrets
import threading
import time

from .config import Config
from .launcher import Launcher, PortPool, new_token
from .log import log
from .queue import MAX_START_TRIES, TicketQueue, Ticket, assign_slots, new_ticket

FORGET_GONE_S = 300.0   # a gone ticket answers `gone` for this long, then is dropped from memory


class Match:
    def __init__(self, match_id: str, mode: str, port: int, by_slot: dict, started_at: float):
        self.id = match_id
        self.mode = mode
        self.port = port
        self.by_slot = by_slot       # slot -> Ticket
        self.started_at = started_at
        self.ready = False
        self.proc = None


class Matchmaker:
    def __init__(self, cfg: Config, launcher: Launcher, version: str, clock=time.time):
        self.cfg = cfg
        self.launcher = launcher
        self.version = version
        self.clock = clock
        self.lock = threading.RLock()
        self.modes = cfg.modes()
        self.queue = TicketQueue(self.modes, cfg.fill_timeout)
        self.ports = PortPool(cfg.port_min, cfg.port_max)
        self.tickets = {}    # id -> Ticket
        self.matches = {}    # match id -> Match

    # -- HTTP-facing --------------------------------------------------------------------------------

    def health(self) -> dict:
        with self.lock:
            return {"ok": True, "version": self.version, "region": self.cfg.region, "matches": len(self.matches)}

    def enqueue(self, mode: str, name: str, version: str, party: list) -> dict:
        """`{"ticket": id}` or `{"error": "version"|"mode", ...}`."""
        if version != self.version:
            return {"error": "version", "server_version": self.version}
        if mode not in self.modes:
            return {"error": "mode", "modes": sorted(self.modes)}
        with self.lock:
            ticket = new_ticket(mode, name, version, party, self.clock())
            self.tickets[ticket.id] = ticket
            self.queue.add(ticket)
            log("queue_join", ticket=ticket.id, mode=mode, name=name, waiting=len(self.queue.waiting[mode]))
            return {"ticket": ticket.id}

    def status(self, ticket_id: str) -> dict:
        with self.lock:
            ticket = self.tickets.get(ticket_id)
            now = self.clock()
            if ticket is None or ticket.state == "gone":
                return {"state": "gone"}
            if ticket.state == "waiting":
                position, eta = self.queue.position(ticket), self.queue.eta_s(ticket, now)
                return {"state": "waiting", "position": position, "eta_s": eta}
            if ticket.state == "starting":
                return {"state": "waiting", "position": 1, "eta_s": 2}
            return {"state": "ready", "host": self.cfg.public_host, "port": ticket.port, "token": ticket.token}

    def cancel(self, ticket_id: str) -> bool:
        """Leave the queue. A ticket that already has a match keeps its slot empty (a bot takes it)."""
        with self.lock:
            ticket = self.tickets.get(ticket_id)
            if ticket is None or ticket.state == "gone":
                return False
            self.queue.remove(ticket)
            self._gone(ticket, "cancelled")
            return True

    # -- periodic -----------------------------------------------------------------------------------

    def tick(self) -> None:
        with self.lock:
            now = self.clock()
            for match in list(self.matches.values()):
                self._drain(match, now)
            self._expire(now)
            for mode in self.modes:
                self._start_matches(mode, now)

    def shutdown(self) -> None:
        with self.lock:
            self.launcher.stop_all()

    def _start_matches(self, mode: str, now: float) -> None:
        while True:
            picked = self.queue.pick(mode, now)
            if not picked:
                return
            port = self.ports.acquire()
            if port is None:
                log("ports_exhausted", mode=mode, waiting=len(picked))
                for ticket in picked:
                    self.queue.add(ticket)
                return
            self._spawn(mode, picked, port, now)

    def _spawn(self, mode: str, picked: list, port: int, now: float) -> None:
        shape = self.modes[mode]
        match_id = f"{mode}-{secrets.token_hex(4)}"
        slots = assign_slots(picked, shape)
        tokens, by_slot = {}, {}
        for ticket, slot in slots.items():
            ticket.token = new_token()
            ticket.slot = slot
            ticket.port = port
            ticket.match_id = match_id
            ticket.state = "starting"
            tokens[ticket.token] = {"name": ticket.name, "slot": slot, "team": slot // shape.team_size}
            by_slot[slot] = ticket
        match = Match(match_id, mode, port, by_slot, now)
        extra = {"slots": shape.slots, "team_size": shape.team_size, "expires": now + self.cfg.token_ttl_s}
        match.proc = self.launcher.start(match_id, mode, port, tokens, extra)
        self.matches[match_id] = match
        log("match_start", match=match_id, mode=mode, port=port, humans=len(picked), bots=shape.slots - len(picked))

    def _drain(self, match: Match, now: float) -> None:
        while not match.proc.events.empty():
            kind, value = match.proc.events.get()
            if kind == "ready":
                self._ready(match, now)
            elif kind == "joined":
                self._joined(match, value)
            elif kind == "end":
                log("match_end", match=match.id, result=value)
            elif kind == "exit":
                self._exited(match, value)
                return
        if not match.ready and now - match.started_at > self.cfg.ready_timeout_s:
            log("server_ready_timeout", match=match.id)
            match.proc.terminate()
            match.started_at = now   # let the exit event come in instead of killing again every tick

    def _ready(self, match: Match, now: float) -> None:
        match.ready = True
        for ticket in match.by_slot.values():
            if ticket.state == "starting":
                ticket.state = "ready"
                ticket.ready_at = now
        log("match_ready", match=match.id, port=match.port)

    def _joined(self, match: Match, slot: int) -> None:
        ticket = match.by_slot.get(slot)
        log("player_joined", match=match.id, slot=slot, name=ticket.name if ticket else "bot")
        if ticket is not None and ticket.state != "gone":
            self._gone(ticket, "joined")   # the token is spent: this ticket never hands it out again

    def _exited(self, match: Match, code: int) -> None:
        log("server_exit", match=match.id, code=code, ready=match.ready)
        self.launcher.forget(match.proc)
        self.ports.release(match.port)
        del self.matches[match.id]
        for ticket in match.by_slot.values():
            if ticket.state == "gone":
                continue
            if match.ready:
                self._gone(ticket, "match_over")
            else:
                self._requeue_after_crash(ticket)

    def _requeue_after_crash(self, ticket: Ticket) -> None:
        ticket.failed_starts += 1
        if ticket.failed_starts >= MAX_START_TRIES:
            self._gone(ticket, "crashed")
            return
        ticket.token, ticket.match_id, ticket.port, ticket.slot = "", "", 0, -1
        self.queue.add(ticket)

    def _expire(self, now: float) -> None:
        for ticket in list(self.tickets.values()):
            if ticket.state == "ready" and now - ticket.ready_at > self.cfg.token_ttl_s:
                self._gone(ticket, "expired")
            elif ticket.state == "gone" and now - ticket.gone_at > FORGET_GONE_S:
                del self.tickets[ticket.id]

    def _gone(self, ticket: Ticket, why: str) -> None:
        ticket.state = "gone"
        ticket.why = why
        ticket.gone_at = self.clock()
        ticket.token = ""
        log("ticket_gone", ticket=ticket.id, why=why, match=ticket.match_id)
