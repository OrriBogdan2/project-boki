"""A match's Hunter picks, held by the matchmaker (docs/decisions/0019-prematch-lobby.md; the game's
Prematch runs the same rules). Picking starts once every human slot has joined its game server (or
LOAD_WAIT_S passed); then each team picks in its own turn order, all teams at once, TURN_S seconds a
turn. No two on a team may play the same Hunter; the enemy may mirror. A bot slot picks the moment
its turn comes; a human whose turn runs out gets a random untaken Hunter."""
import random

TURN_S = 10.0        # seconds each Hunter has on their pick turn
LOAD_WAIT_S = 60.0   # seconds picking waits for everyone to load before it starts anyway
# The Hunter ids, Arch.ORDER in the game (scripts/arch/arch.gd); a test checks them against content/archetypes.
HUNTERS = ("archer", "juggernaut", "gunslinger", "bulwark", "ashwick", "tender", "dolm", "dredge", "rimewright",
           "mage", "thief", "ostra", "gil")


class PickPhase:
    def __init__(self, slots: int, team_size: int, humans: set, seed: int, now: float):
        self.humans = set(humans)          # slots a ticket holds; the rest are bots
        self.joined = set()
        self.created_at = now
        self.rng = random.Random(seed)
        self.picks = {}                    # slot -> Hunter id, final
        self.order = []                    # per team: its slots in pick order
        for team in range(slots // team_size):
            seats = list(range(team * team_size, (team + 1) * team_size))
            self.rng.shuffle(seats)
            self.order.append(seats)
        self.turn = [0] * len(self.order)  # per team: index into its order
        self.turn_at = []                  # per team: when its current turn started; empty while loading

    @property
    def phase(self) -> str:
        if not self.turn_at:
            return "loading"
        return "done" if all(t >= len(o) for t, o in zip(self.turn, self.order)) else "picking"

    def join(self, slot: int) -> None:
        self.joined.add(slot)

    def tick(self, now: float) -> None:
        """Start picking once everyone loaded, let bots pick, and pick for a human whose turn ran out."""
        if not self.turn_at:
            if not self.humans <= self.joined and now - self.created_at < LOAD_WAIT_S:
                return
            self.turn_at = [now] * len(self.order)
        for team, order in enumerate(self.order):
            while self.turn[team] < len(order):
                slot = order[self.turn[team]]
                if slot in self.humans and now - self.turn_at[team] < TURN_S:
                    break
                self._lock(team, slot, self._random_free(team), now)

    def choose(self, slot: int, hunter: str, now: float) -> str:
        """A human's pick, final at once: "" when it counts, else why not (unknown | loading | turn | taken)."""
        if hunter not in HUNTERS:
            return "unknown"
        self.tick(now)
        team = self._team_of(slot)
        if not self.turn_at:
            return "loading"
        if team is None or self.turn[team] >= len(self.order[team]) or self.order[team][self.turn[team]] != slot:
            return "turn"
        if hunter in self._taken(team):
            return "taken"
        self._lock(team, slot, hunter, now)
        return ""

    def state(self, now: float) -> dict:
        """What a client shows: the phase, n/N loaded, and per team the order, whose turn, seconds left, picks."""
        teams = []
        for team, order in enumerate(self.order):
            picking = order[self.turn[team]] if self.turn_at and self.turn[team] < len(order) else -1
            left = max(0.0, TURN_S - (now - self.turn_at[team])) if picking >= 0 else 0.0
            picks = {str(s): self.picks[s] for s in order if s in self.picks}
            teams.append({"order": order, "picking": picking, "left_s": round(left, 1), "picks": picks})
        return {"phase": self.phase, "loaded": len(self.humans & self.joined), "of": len(self.humans), "teams": teams}

    def _lock(self, team: int, slot: int, hunter: str, now: float) -> None:
        self.picks[slot] = hunter
        self.turn[team] += 1
        self.turn_at[team] = now

    def _team_of(self, slot: int):
        for team, order in enumerate(self.order):
            if slot in order:
                return team
        return None

    def _taken(self, team: int) -> set:
        return {self.picks[s] for s in self.order[team] if s in self.picks}

    def _random_free(self, team: int) -> str:
        free = [h for h in HUNTERS if h not in self._taken(team)]
        return self.rng.choice(free or list(HUNTERS))
