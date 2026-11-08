"""Queue rules: when a match starts, how many fit, who sits where, port bookkeeping."""
import unittest

from helpers import Clock

from mm.config import Config
from mm.launcher import PortPool
from mm.queue import TicketQueue, assign_slots, new_ticket


def ticket(mode: str, name: str, at: float, party=()):
    return new_ticket(mode, name, "v", list(party), at)


class QueueTest(unittest.TestCase):
    def setUp(self):
        self.cfg = Config()
        self.q = TicketQueue(self.cfg.modes(), self.cfg.fill_timeout)
        self.clock = Clock(100.0)

    def test_duel_starts_with_two_humans_at_once(self):
        self.q.add(ticket("duel", "a", 100))
        self.assertEqual(self.q.pick("duel", 100), [])
        self.q.add(ticket("duel", "b", 100))
        self.assertEqual(len(self.q.pick("duel", 100)), 2)
        self.assertEqual(self.q.waiting["duel"], [])

    def test_fill_timeout_starts_one_human_with_bots(self):
        self.q.add(ticket("duel", "a", 100))
        self.assertEqual(self.q.pick("duel", 119.9), [])
        picked = self.q.pick("duel", 120)
        self.assertEqual([t.name for t in picked], ["a"])

    def test_empty_line_never_starts(self):
        self.assertEqual(self.q.pick("arena", 10_000), [])

    def test_arena_needs_eight_humans_or_thirty_seconds(self):
        for i in range(7):
            self.q.add(ticket("arena", f"p{i}", 100))
        self.assertEqual(self.q.pick("arena", 129), [])
        self.q.add(ticket("arena", "p7", 129))
        self.assertEqual(len(self.q.pick("arena", 129)), 8)
        self.q.add(ticket("arena", "late", 130))
        self.assertEqual(self.q.pick("arena", 159), [])
        self.assertEqual(len(self.q.pick("arena", 160)), 1)

    def test_trio_takes_up_to_the_match_size_and_leaves_the_rest(self):
        n = self.cfg.trio_slots
        for i in range(n + 2):
            self.q.add(ticket("trio", f"p{i}", 100 + i))
        picked = self.q.pick("trio", 100)
        self.assertEqual(len(picked), n)
        self.assertEqual([t.name for t in self.q.waiting["trio"]], [f"p{n}", f"p{n + 1}"])

    def test_position_and_eta(self):
        first, second = ticket("duel", "a", 100), ticket("duel", "b", 105)
        self.q.add(first)
        self.q.add(second)
        third = ticket("duel", "c", 106)
        self.q.add(third)
        self.assertEqual(self.q.position(second), 2)
        self.assertEqual(self.q.eta_s(first, 110), 10)
        self.assertEqual(self.q.eta_s(third, 110), 30)   # next batch after the first pair's timeout
        self.q.remove(first)
        self.assertEqual(self.q.position(first), 0)
        self.assertEqual(self.q.eta_s(first, 110), 0)

    def test_requeue_keeps_the_old_place(self):
        old, new = ticket("duel", "old", 100), ticket("duel", "new", 150)
        self.q.add(new)
        self.q.add(old)
        self.assertEqual([t.name for t in self.q.waiting["duel"]], ["old", "new"])


class SlotTest(unittest.TestCase):
    def test_duel_slots(self):
        a, b = ticket("duel", "a", 1), ticket("duel", "b", 2)
        self.assertEqual(assign_slots([a, b], Config().modes()["duel"]), {a: 0, b: 1})

    def test_party_shares_a_team(self):
        arena = Config().modes()["arena"]
        a = ticket("arena", "a", 1, party=["b"])
        b = ticket("arena", "b", 2, party=["a"])
        c = ticket("arena", "c", 3)
        slots = assign_slots([c, a, b], arena)
        self.assertEqual(slots[a] // 4, slots[b] // 4)
        self.assertNotEqual(slots[a] // 4, slots[c] // 4)
        self.assertEqual(sorted(slots.values()), sorted(set(slots.values())))

    def test_oversized_party_is_split_not_dropped(self):
        trio = Config().modes()["trio"]
        names = ["p0", "p1", "p2", "p3"]
        party = [ticket("trio", n, i, party=[m for m in names if m != n]) for i, n in enumerate(names)]
        slots = assign_slots(party, trio)
        self.assertEqual(len(slots), 4)
        self.assertEqual(len({s // 3 for s in slots.values()}), 2)


class PortPoolTest(unittest.TestCase):
    def test_exhaustion_and_release(self):
        pool = PortPool(7777, 7799)
        taken = [pool.acquire() for _ in range(23)]
        self.assertEqual(taken[0], 7777)
        self.assertEqual(taken[-1], 7799)
        self.assertIsNone(pool.acquire())
        pool.release(7780)
        pool.release(7780)   # a double release is harmless
        self.assertEqual(pool.acquire(), 7780)
        self.assertIsNone(pool.acquire())


if __name__ == "__main__":
    unittest.main()
