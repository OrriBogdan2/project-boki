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
    party: frozenset            # this player's name plus the friends named in the request
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


def new_ticket(mode: str, name: str, version: str, party: list, now: float) -> Ticket:
    """A fresh waiting ticket with a random id."""
    names = frozenset([name] + [str(p) for p in party])
    return Ticket(secrets.token_urlsafe(12), mode, name, version, names, now)


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
        the fill timeout (bots fill the rest; at least one human is always in).
        """
        line = self.waiting.get(mode, [])
        slots = self.modes[mode].slots
        if not line:
            return []
        if len(line) < slots and now - line[0].created_at < self.fill_timeout[mode]:
            return []
        picked = line[:slots]
        del line[:slots]
        return picked


def assign_slots(tickets: list, mode: Mode) -> dict:
    """Ticket -> slot, team-major. Tickets that name each other as a party share a team when it fits."""
    n_teams = mode.slots // mode.team_size
    teams = [[] for _ in range(n_teams)]
    for group in _party_groups(tickets):
        rest = list(group)
        while rest:
            team = _team_with_room(teams, mode.team_size, len(rest))
            room = mode.team_size - len(team)
            team.extend(rest[:room])
            rest = rest[room:]
    out = {}
    for team_index, team in enumerate(teams):
        for seat, ticket in enumerate(team):
            out[ticket] = team_index * mode.team_size + seat
    return out


def _party_groups(tickets: list) -> list:
    groups = {}
    for ticket in tickets:
        groups.setdefault(ticket.party, []).append(ticket)
    return sorted(groups.values(), key=lambda g: g[0].created_at)


def _team_with_room(teams: list, team_size: int, wanted: int) -> list:
    """The emptiest team that fits `wanted` players, else just the emptiest team (a big party gets split)."""
    open_teams = [t for t in teams if len(t) < team_size]
    fitting = [t for t in open_teams if team_size - len(t) >= wanted]
    pool = fitting or open_teams
    return min(pool, key=len)
