"""Parties: friends who queue as one unit. A party is a 5-character code, up to PARTY_MAX members and a mode.
Everything lives in memory (like tickets). The member secret is the identity: it travels in the `X-Boki-Member`
header, never in the URL. All state is guarded by the core's lock; `tick()` drops idle members."""
import hmac
import secrets
from dataclasses import dataclass, field

from .log import log
from .queue import new_ticket

CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no O/0/I/1/L
CODE_LEN = 5
NAME_MAX = 24                 # characters of a member's display name
STRIKE_WINDOW_S = 60.0        # the bad-code counters reset this often


@dataclass(eq=False)
class Member:
    name: str
    secret: str
    last_seen: float
    ready: bool = False
    ticket: str = ""          # the member's queue ticket while queued or playing


@dataclass(eq=False)
class Party:
    code: str
    mode: str
    members: list = field(default_factory=list)   # join order: the first one is the leader
    state: str = "forming"                        # forming | queued | playing
    grace_until: float = 0.0                      # after a match, idle members survive until then


class Parties:
    def __init__(self, core):
        self.core = core
        self.by_code = {}
        self.strikes = {}          # client address -> wrong codes or secrets in this window
        self.window_start = core.clock()

    # -- HTTP-facing: each returns a JSON-able dict, `{"error": ...}` on failure ---------------------

    def create(self, name: str, version: str) -> dict:
        if version != self.core.version:
            return {"error": "version", "server_version": self.core.version}
        with self.core.lock:
            code = self._new_code()
            member = self._member(name)
            self.by_code[code] = Party(code, "trio", [member])
            log("party_create", code=code, name=member.name)
            return {"code": code, "member": member.secret}

    def join(self, code: str, name: str, version: str, client: str) -> dict:
        if version != self.core.version:
            return {"error": "version", "server_version": self.core.version}
        with self.core.lock:
            if self._limited(client):
                return {"error": "rate_limited"}
            party = self.by_code.get(code.upper())
            if party is None:
                return self._strike(client, "not_found")
            if party.state != "forming":
                return {"error": "busy"}
            if len(party.members) >= self.core.cfg.party_max:
                return {"error": "full"}
            member = self._member(name)
            party.members.append(member)
            self._reset(party)
            log("party_join", code=party.code, name=member.name, size=len(party.members))
            return {"member": member.secret}

    def view(self, code: str, secret: str, client: str) -> dict:
        """The heartbeat: the party as `secret` sees it."""
        with self.core.lock:
            party, me, err = self._find(code, secret, client)
            if err:
                return err
            out = {"state": party.state, "mode": party.mode, "members": [
                {"name": m.name, "ready": m.ready, "leader": m is party.members[0], "you": m is me}
                for m in party.members]}
            if me.ticket:
                out["ticket"] = me.ticket
                status = self.core.status(me.ticket)
                if status["state"] == "waiting":
                    out.update(position=status["position"], eta_s=status["eta_s"])
            return out

    def set_mode(self, code: str, secret: str, mode: str, client: str) -> dict:
        with self.core.lock:
            party, me, err = self._find(code, secret, client)
            if err:
                return err
            if me is not party.members[0]:
                return {"error": "not_leader"}
            if party.state != "forming":
                return {"error": "busy"}
            fitting = self._fitting_modes(len(party.members))
            if mode not in fitting:
                return {"error": "mode", "modes": fitting}
            party.mode = mode
            self._reset(party)
            return {"mode": mode}

    def set_ready(self, code: str, secret: str, ready: bool, client: str) -> dict:
        """A member's Ready. The leader's `true` is Find match: it queues the party once the others are ready."""
        with self.core.lock:
            party, me, err = self._find(code, secret, client)
            if err:
                return err
            if party.state != "forming":
                return {"error": "busy"}
            if me is not party.members[0]:
                me.ready = ready
            elif ready:
                if not all(m.ready for m in party.members[1:]):
                    return {"error": "not_ready"}
                self._queue(party)
            return {"state": party.state}

    def cancel_queue(self, code: str, secret: str, client: str) -> dict:
        with self.core.lock:
            party, me, err = self._find(code, secret, client)
            if err:
                return err
            if me is not party.members[0]:
                return {"error": "not_leader"}
            if party.state == "playing":
                return {"error": "busy"}
            for member in party.members:
                self._cancel_ticket(member)
            self._to_forming(party)
            return {"state": party.state}

    def leave(self, code: str, secret: str, client: str) -> dict:
        with self.core.lock:
            party, me, err = self._find(code, secret, client)
            if err:
                return err
            self._remove(party, me)
            return {"state": "left"}

    # -- driven by the core ---------------------------------------------------------------------------

    def tick(self, now: float) -> None:
        if now - self.window_start >= STRIKE_WINDOW_S:
            self.strikes.clear()
            self.window_start = now
        for party in list(self.by_code.values()):
            if party.state == "queued" and not any(self._alive(m) for m in party.members):
                self._to_forming(party)   # every ticket is gone before a match: cancel, expiry, crash
            if party.state != "playing" and now > party.grace_until:
                for member in list(party.members):
                    if now - member.last_seen > self.core.cfg.party_idle_s:
                        log("party_idle", code=party.code, name=member.name)
                        self._remove(party, member)

    def on_match_start(self, code: str) -> None:
        party = self.by_code.get(code)
        if party:
            party.state = "playing"

    def on_match_end(self, code: str, played: bool, now: float) -> None:
        """The server exited: after a played match the party is back on its card with a grace period;
        a server that crashed before `ready` means the tickets were re-queued, so it is queued again."""
        party = self.by_code.get(code)
        if party is None:
            return
        if not played:
            party.state = "queued"
            return
        self._to_forming(party)
        party.grace_until = now + self.core.cfg.party_after_match_s
        for member in party.members:
            member.last_seen = now

    # -- internals ------------------------------------------------------------------------------------

    def _member(self, name: str) -> Member:
        return Member((name.strip() or "Hunter")[:NAME_MAX], secrets.token_urlsafe(16), self.core.clock())

    def _new_code(self) -> str:
        while True:
            code = "".join(secrets.choice(CODE_CHARS) for _ in range(CODE_LEN))
            if code not in self.by_code:
                return code

    def _limited(self, client: str) -> bool:
        return self.strikes.get(client, 0) >= self.core.cfg.party_bad_codes_per_min

    def _strike(self, client: str, error: str) -> dict:
        self.strikes[client] = self.strikes.get(client, 0) + 1
        return {"error": error}

    def _find(self, code: str, secret: str, client: str):
        """(party, member, None) for a known member, else (None, None, error). Counts as a poll."""
        if self._limited(client):
            return None, None, {"error": "rate_limited"}
        party = self.by_code.get(code.upper())
        if party is None:
            return None, None, self._strike(client, "gone")
        key = secret.encode()
        member = next((m for m in party.members if hmac.compare_digest(m.secret.encode(), key)), None)
        if member is None:
            return None, None, self._strike(client, "not_member")
        member.last_seen = self.core.clock()
        return party, member, None

    def _fitting_modes(self, size: int) -> list:
        return sorted(name for name, shape in self.core.modes.items() if shape.team_size >= size)

    def _reset(self, party: Party) -> None:
        """Membership or mode changed: nobody is ready any more, and the mode must still fit the party."""
        for member in party.members:
            member.ready = False
        if party.mode not in self._fitting_modes(len(party.members)):
            party.mode = "trio"

    def _queue(self, party: Party) -> None:
        """One ticket per member, all with the party's queue time, so the line takes them together."""
        now = self.core.clock()
        for member in party.members:
            ticket = new_ticket(party.mode, member.name, self.core.version, party.code, now)
            self.core.add_ticket(ticket)
            member.ticket = ticket.id
        party.state = "queued"

    def _alive(self, member: Member) -> bool:
        ticket = self.core.tickets.get(member.ticket)
        return ticket is not None and ticket.state != "gone"

    def _cancel_ticket(self, member: Member) -> None:
        if member.ticket:
            self.core.cancel(member.ticket)

    def _to_forming(self, party: Party) -> None:
        party.state = "forming"
        for member in party.members:
            member.ready, member.ticket = False, ""

    def _remove(self, party: Party, member: Member) -> None:
        """A member leaves or is dropped: their ticket goes, the leadership passes, an empty party is deleted."""
        self._cancel_ticket(member)
        party.members.remove(member)
        if not party.members:
            del self.by_code[party.code]
            log("party_end", code=party.code)
        elif party.state == "forming":
            self._reset(party)
