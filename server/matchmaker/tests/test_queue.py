"""Queue rules: when a match starts, how many fit, who sits where, port bookkeeping."""
import unittest

from helpers import Clock

from mm.config import Config
from mm.launcher import PortPool
from mm.queue import TicketQueue, assign_slots, new_ticket


def ticket(mode: str, name: str, at: float, party: str = ""):
    return new_ticket(mode, name, "v", party, at)


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
        a, b = ticket("arena", "a", 1, "AAAAA"), ticket("arena", "b", 1, "AAAAA")
        c, d = ticket("arena", "c", 3, "CCCCC"), ticket("arena", "d", 4)
        slots = assign_slots([d, c, a, b], arena)
        self.assertEqual(slots[a] // 4, slots[b] // 4)
        self.assertNotEqual(slots[a] // 4, slots[c] // 4)
        self.assertEqual(slots[d] // 4, slots[a] // 4)   # the solo packs the fullest team (the duo)
        self.assertEqual(len(set(slots.values())), 4)

    def test_duo_gets_a_stranger_before_a_new_team_opens(self):
        trio = Config().modes()["trio"]
        duo = [ticket("trio", "d1", 1, "DDDDD"), ticket("trio", "d2", 1, "DDDDD")]
        solos = [ticket("trio", f"s{i}", 2 + i) for i in range(2)]
        slots = assign_slots(solos + duo, trio)
        self.assertEqual({slots[t] // 3 for t in duo + solos[:1]}, {slots[duo[0]] // 3})
        self.assertNotEqual(slots[solos[1]] // 3, slots[duo[0]] // 3)

    def test_parties_get_empty_teams_largest_first(self):
        trio = Config().modes()["trio"]
        small = [ticket("trio", "s", 1, "SSSSS")]
        big = [ticket("trio", f"b{i}", 5, "BBBBB") for i in range(3)]
        slots = assign_slots(small + big, trio)
        self.assertEqual({slots[t] for t in big}, {0, 1, 2})
        self.assertEqual(slots[small[0]], 3)


class PartyPickTest(unittest.TestCase):
    def setUp(self):
        cfg = Config()
        self.q = TicketQueue(cfg.modes(), cfg.fill_timeout)

    def test_a_party_never_straddles_two_batches(self):
        n = Config().trio_slots
        for i in range(n - 1):
            self.q.add(ticket("trio", f"s{i}", 100 + i))
        trio = [ticket("trio", f"t{i}", 200, "TTTTT") for i in range(3)]
        for t in trio:
            self.q.add(t)
        first = self.q.pick("trio", 100)
        self.assertEqual(len(first), n - 1)
        self.assertFalse(any(t.party for t in first))
        self.assertEqual(self.q.waiting["trio"], trio)   # kept its place for the next batch

    def test_start_rule_counts_tickets_not_units(self):
        self.q.add(ticket("trio", "a", 100, "AAAAA"))
        self.assertEqual(self.q.pick("trio", 119), [])
        self.assertEqual(len(self.q.pick("trio", 120)), 1)

    def test_one_party_per_team_at_most(self):
        teams = Config().trio_slots // 3
        for i in range(teams + 1):
            self.q.add(ticket("trio", f"p{i}", 100 + i, f"PARTY{i:03d}"))
        self.assertEqual(len(self.q.pick("trio", 125)), teams)
        self.assertEqual(len(self.q.waiting["trio"]), 1)


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
