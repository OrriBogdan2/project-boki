"""The matchmaker end to end on a fake launcher: tickets, matches, tokens, crashes, ports."""
import unittest

from helpers import VERSION, Clock, make_core, ready_all


class LifecycleTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.core = make_core(self.clock)

    def queue(self, mode: str, name: str, **extra) -> str:
        out = self.core.enqueue(mode, name, extra.pop("version", VERSION), extra.pop("party", []))
        self.assertIn("ticket", out, out)
        return out["ticket"]

    def test_duel_waits_then_both_get_the_same_port_and_own_tokens(self):
        a = self.queue("duel", "Ana")
        self.core.tick()
        self.assertEqual(self.core.status(a), {"state": "waiting", "position": 1, "eta_s": 20})
        b = self.queue("duel", "Ben")
        self.core.tick()
        self.assertEqual(self.core.status(a)["state"], "waiting")   # server still booting
        self.assertEqual(self.core.health()["matches"], 1)
        ready_all(self.core)
        sa, sb = self.core.status(a), self.core.status(b)
        self.assertEqual(sa["state"], "ready")
        self.assertEqual((sa["host"], sa["port"]), ("203.0.113.5", 27777))
        self.assertEqual(sb["port"], 27777)
        self.assertNotEqual(sa["token"], sb["token"])
        proc = self.core.launcher.started[0]
        self.assertEqual(proc.tokens[sa["token"]], {"name": "Ana", "slot": 0, "team": 0})
        self.assertEqual(proc.tokens[sb["token"]], {"name": "Ben", "slot": 1, "team": 1})
        self.assertEqual(proc.extra["slots"], 2)
        self.assertAlmostEqual(proc.extra["expires"], self.clock.t + 60)

    def test_fill_timeout_starts_a_solo_duel_with_a_bot(self):
        a = self.queue("duel", "Ana")
        self.clock.advance(19.9)
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 0)
        self.clock.advance(0.2)
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 1)
        self.assertEqual(len(self.core.launcher.started[0].tokens), 1)
        ready_all(self.core)
        self.assertEqual(self.core.status(a)["state"], "ready")

    def test_arena_needs_eight_slots(self):
        tickets = [self.queue("arena", f"p{i}") for i in range(7)]
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 0)
        tickets.append(self.queue("arena", "p7"))
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 1)
        ready_all(self.core)
        slots = sorted(t["slot"] for t in self.core.launcher.started[0].tokens.values())
        self.assertEqual(slots, list(range(8)))
        self.assertEqual({self.core.status(t)["state"] for t in tickets}, {"ready"})

    def test_arena_fill_timeout_is_thirty_seconds(self):
        self.queue("arena", "p0")
        self.clock.advance(25)
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 0)
        self.clock.advance(5.1)
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 1)

    def test_trio_fills_with_bots_and_parties_share_a_team(self):
        a = self.queue("trio", "Ana", party=["Ben"])
        b = self.queue("trio", "Ben", party=["Ana"])
        c = self.queue("trio", "Cid")
        self.clock.advance(20.1)
        self.core.tick()
        ready_all(self.core)
        tokens = self.core.launcher.started[0].tokens
        team_of = {v["name"]: v["team"] for v in tokens.values()}
        self.assertEqual(team_of["Ana"], team_of["Ben"])
        self.assertNotEqual(team_of["Ana"], team_of["Cid"])
        self.assertEqual({self.core.status(t)["state"] for t in (a, b, c)}, {"ready"})

    def test_version_mismatch_is_rejected(self):
        out = self.core.enqueue("duel", "Old", "0.1.0", [])
        self.assertEqual(out, {"error": "version", "server_version": VERSION})
        self.assertEqual(self.core.enqueue("coop", "X", VERSION, []).get("error"), "mode")
        self.assertEqual(self.core.status("nope"), {"state": "gone"})

    def test_cancel(self):
        a = self.queue("duel", "Ana")
        self.assertTrue(self.core.cancel(a))
        self.assertFalse(self.core.cancel(a))
        self.assertEqual(self.core.status(a), {"state": "gone"})
        self.clock.advance(60)
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 0)

    def test_token_is_handed_once_then_spent_by_the_join(self):
        a, b = self.queue("duel", "Ana"), self.queue("duel", "Ben")
        self.core.tick()
        ready_all(self.core)
        first = self.core.status(a)
        self.assertEqual(self.core.status(a), first)   # polling again repeats the same hand-out
        proc = self.core.launcher.started[0]
        proc.events.put(("joined", 0))
        self.core.tick()
        self.assertEqual(self.core.status(a), {"state": "gone"})
        self.assertEqual(self.core.status(b)["state"], "ready")
        self.assertEqual(self.core.tickets[a].why, "joined")

    def test_unused_token_expires_after_sixty_seconds(self):
        a, b = self.queue("duel", "Ana"), self.queue("duel", "Ben")
        self.core.tick()
        ready_all(self.core)
        self.clock.advance(59)
        self.core.tick()
        self.assertEqual(self.core.status(a)["state"], "ready")
        self.clock.advance(1.5)
        self.core.tick()
        self.assertEqual(self.core.status(a), {"state": "gone"})
        self.assertEqual(self.core.status(b), {"state": "gone"})
        self.assertEqual(self.core.tickets[a].why, "expired")

    def test_match_end_frees_the_port_and_closes_the_tickets(self):
        a, b = self.queue("duel", "Ana"), self.queue("duel", "Ben")
        self.core.tick()
        ready_all(self.core)
        proc = self.core.launcher.started[0]
        proc.events.put(("end", "win"))
        proc.events.put(("exit", 0))
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 0)
        self.assertEqual(self.core.ports.used, set())
        self.assertEqual(self.core.status(a), {"state": "gone"})
        self.assertEqual(self.core.tickets[b].why, "match_over")
        self.assertEqual(self.core.launcher.running, {})

    def test_crash_before_ready_requeues_once_then_gives_up(self):
        a, b = self.queue("duel", "Ana"), self.queue("duel", "Ben")
        self.core.tick()
        self.core.launcher.started[0].events.put(("exit", 3))
        self.core.tick()   # exit handled, tickets back in line, a new server spawned in the same tick
        self.assertEqual(len(self.core.launcher.started), 2)
        self.assertEqual(self.core.launcher.started[1].port, 27777)
        self.assertEqual(self.core.status(a)["state"], "waiting")
        self.core.launcher.started[1].events.put(("exit", 3))
        self.core.tick()
        self.assertEqual(len(self.core.launcher.started), 2)
        self.assertEqual(self.core.status(a), {"state": "gone"})
        self.assertEqual(self.core.tickets[b].why, "crashed")
        self.assertEqual(self.core.ports.used, set())

    def test_server_that_never_says_ready_is_killed(self):
        self.queue("duel", "Ana")
        self.queue("duel", "Ben")
        self.core.tick()
        proc = self.core.launcher.started[0]
        self.clock.advance(31)
        self.core.tick()
        self.assertTrue(proc.terminated)
        self.core.tick()
        self.assertEqual(len(self.core.launcher.started), 2)   # retried once

    def test_port_exhaustion_keeps_the_tickets_waiting(self):
        for i in range(23):
            self.queue("duel", f"a{i}")
            self.queue("duel", f"b{i}")
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 23)
        late = self.queue("duel", "late")
        self.queue("duel", "later")
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 23)
        self.assertEqual(self.core.status(late)["state"], "waiting")
        proc = self.core.launcher.started[0]
        proc.events.put(("exit", 0))
        self.core.tick()
        self.assertEqual(self.core.health()["matches"], 23)
        self.assertEqual(self.core.launcher.started[-1].port, proc.port)
        self.assertEqual(self.core.status(late)["state"], "waiting")   # its server is booting
        ready_all(self.core)
        self.assertEqual(self.core.status(late)["port"], proc.port)

    def test_gone_tickets_are_forgotten_after_a_while(self):
        a = self.queue("duel", "Ana")
        self.core.cancel(a)
        self.clock.advance(301)
        self.core.tick()
        self.assertNotIn(a, self.core.tickets)
        self.assertEqual(self.core.status(a), {"state": "gone"})


if __name__ == "__main__":
    unittest.main()
