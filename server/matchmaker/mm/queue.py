"""Tickets and the per-mode queues: who is waiting, when a match can start, who sits in which slot."""
import secrets
from dataclasses import dataclass, field

from .config import Mode

MAX_START_TRIES = 2   # a ticket whose server died before `ready` is re-queued this many times, then dropped


@dataclass(eq=False)   # identity: tickets are dict keys and list members
class Ticket:
    id: str
    mode: str
    name: str
    version: str
    party: str                  # the party code, "" for a solo player
    created_at: float
    state: str = "waiting"      # waiting | starting | ready | gone
    why: str = ""               # for gone tickets: joined | expired | cancelled | crashed | match_over
    match_id: str = ""
    slot: int = -1
    token: str = ""
    port: int = 0
    ready_at: float = 0.0
    failed_starts: int = 0
    gone_at: float = 0.0


def new_ticket(mode: str, name: str, version: str, party: str, now: float) -> Ticket:
    """A fresh waiting ticket with a random id; `party` is the party code or ""."""
    return Ticket(secrets.token_urlsafe(12), mode, name, version, party, now)


@dataclass
class TicketQueue:
    modes: dict
    fill_timeout: dict
    waiting: dict = field(default_factory=dict)   # mode -> [Ticket] in arrival order

    def add(self, ticket: Ticket) -> None:
        """Append (or re-add, keeping the original arrival time so it starts next)."""
        line = self.waiting.setdefault(ticket.mode, [])
        line.append(ticket)
        line.sort(key=lambda t: t.created_at)
        ticket.state = "waiting"

    def remove(self, ticket: Ticket) -> None:
        line = self.waiting.get(ticket.mode, [])
        if ticket in line:
            line.remove(ticket)

    def position(self, ticket: Ticket) -> int:
        """1-based place in its mode's line, 0 when it is not waiting."""
        line = self.waiting.get(ticket.mode, [])
        return line.index(ticket) + 1 if ticket in line else 0

    def eta_s(self, ticket: Ticket, now: float) -> int:
        """Seconds until a match holding this ticket starts at the latest (the fill timeout fires for its batch)."""
        line = self.waiting.get(ticket.mode, [])
        if ticket not in line:
            return 0
        timeout = self.fill_timeout[ticket.mode]
        head_left = max(0.0, timeout - (now - line[0].created_at))
        batches_ahead = (self.position(ticket) - 1) // self.modes[ticket.mode].slots
        return int(round(head_left + batches_ahead * timeout))

    def pick(self, mode: str, now: float) -> list:
        """The tickets that make the next match in this mode, or [] when none can start yet.

        A match starts when the line holds a full match of humans, or when the oldest ticket has waited
        the fill timeout (bots fill the rest; at least one human is always in). Whole units are taken,
        oldest first: a party's tickets together or one solo ticket. A unit that does not fit (no seats
        left, or every team already holds a party) is skipped and keeps its place for the next batch.
        """
        line = self.waiting.get(mode, [])
        shape = self.modes[mode]
        if not line:
            return []
        if len(line) < shape.slots and now - line[0].created_at < self.fill_timeout[mode]:
            return []
        picked, parties = [], 0
        for unit in _units(line):
            is_party = bool(unit[0].party)
            if len(picked) + len(unit) > shape.slots or (is_party and parties >= shape.slots // shape.team_size):
                continue
            picked.extend(unit)
            parties += is_party
        for ticket in picked:
            line.remove(ticket)
        return picked


def _units(line: list) -> list:
    """The line as units in order of their oldest ticket: each party's tickets together, solos on their own."""
    by_party, units = {}, []
    for ticket in line:
        if ticket.party and ticket.party in by_party:
            by_party[ticket.party].append(ticket)
            continue
        unit = [ticket]
        units.append(unit)
        if ticket.party:
            by_party[ticket.party] = unit
    return units


def assign_slots(tickets: list, mode: Mode) -> dict:
    """Ticket -> slot, team-major. A party never splits: parties go first, largest first, each onto an empty
    team. Solos then fill the fullest team with room, so a duo gets a stranger before a new team is opened."""
    teams = [[] for _ in range(mode.slots // mode.team_size)]
    parties = {}
    for ticket in tickets:
        if ticket.party:
            parties.setdefault(ticket.party, []).append(ticket)
    for group in sorted(parties.values(), key=lambda g: (-len(g), g[0].created_at)):
        min(teams, key=len).extend(group)
    for ticket in sorted((t for t in tickets if not t.party), key=lambda t: t.created_at):
        max((t for t in teams if len(t) < mode.team_size), key=len).append(ticket)
    return {ticket: team_index * mode.team_size + seat
            for team_index, team in enumerate(teams) for seat, ticket in enumerate(team)}
