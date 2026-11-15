"""Parties: codes, joining, ready/queue, leaving, idle drops, and the match life cycle, on a fake launcher."""
import unittest

from helpers import VERSION, Clock, make_core, ready_all

from mm.party import CODE_CHARS, CODE_LEN


class PartyTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.core = make_core(self.clock)
        self.p = self.core.parties
        self.polling = []   # (code, secret) of every member created here

    def make(self, *names):
        """A party led by names[0] with the rest joined: (code, [member secrets])."""
        out = self.p.create(names[0], VERSION)
        secrets_ = [out["member"]]
        for name in names[1:]:
            secrets_.append(self.p.join(out["code"], name, VERSION, "1.1.1.1")["member"])
        self.polling += [(out["code"], secret) for secret in secrets_]
        return out["code"], secrets_

    def wait(self, seconds):
        """Time passes while every member keeps polling (the heartbeat); tests that want silence use the clock."""
        while seconds > 0:
            step = min(5.0, seconds)
            self.clock.advance(step)
            seconds -= step
            for code, secret in self.polling:
                self.view(code, secret)

    def view(self, code, secret):
        return self.p.view(code, secret, "1.1.1.1")

    def ready_up(self, code, secrets_):
        for secret in secrets_[1:]:
            self.p.set_ready(code, secret, True, "1.1.1.1")
        return self.p.set_ready(code, secrets_[0], True, "1.1.1.1")

    def start_match(self, code, secrets_):
        self.assertEqual(self.ready_up(code, secrets_), {"state": "queued"})
        self.wait(20.1)
        self.core.tick()

    def test_create_gives_a_five_character_code_and_a_leader(self):
        code, (secret,) = self.make("Ana")
        self.assertEqual(len(code), CODE_LEN)
        self.assertTrue(set(code) <= set(CODE_CHARS))
        v = self.view(code, secret)
        self.assertEqual((v["state"], v["mode"]), ("forming", "trio"))
        self.assertEqual(v["members"], [{"name": "Ana", "ready": False, "leader": True, "you": True}])

    def test_join_full_busy_version_and_case_insensitive_code(self):
        code, _ = self.make("Ana", "Ben", "Cid")
        self.assertEqual(self.p.join(code, "Dee", VERSION, "c"), {"error": "full"})
        code2, _ = self.make("Eve")
        self.assertIn("member", self.p.join(code2.lower(), "Fay", VERSION, "c"))
        self.assertEqual(self.p.join(code2, "Old", "0.0.1", "c")["error"], "version")
        self.assertEqual(self.p.create("Old", "0.0.1")["error"], "version")
        code3, secrets_ = self.make("Gus")
        self.ready_up(code3, secrets_)
        self.assertEqual(self.p.join(code3, "Hal", VERSION, "c"), {"error": "busy"})

    def test_wrong_codes_are_rate_limited_per_client(self):
        for _ in range(10):
            self.assertEqual(self.p.join("ZZZZZ", "x", VERSION, "9.9.9.9"), {"error": "not_found"})
        self.assertEqual(self.p.join("ZZZZZ", "x", VERSION, "9.9.9.9"), {"error": "rate_limited"})
        code, _ = self.make("Ana")
        self.assertEqual(self.p.join(code, "x", VERSION, "9.9.9.9"), {"error": "rate_limited"})
        self.assertIn("member", self.p.join(code, "x", VERSION, "8.8.8.8"))   # other addresses are fine
        self.clock.advance(61)
        self.core.tick()
        code, _ = self.make("Bo")   # the first party idled away meanwhile
        self.assertIn("member", self.p.join(code, "y", VERSION, "9.9.9.9"))

    def test_only_members_see_a_party(self):
        code, (secret,) = self.make("Ana")
        self.assertEqual(self.view(code, "wrong"), {"error": "not_member"})
        self.assertEqual(self.view("ZZZZZ", secret), {"error": "gone"})

    def test_mode_is_leader_only_and_must_fit_the_party(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.assertEqual(self.p.set_mode(code, ben, "arena", "c"), {"error": "not_leader"})
        self.assertEqual(self.p.set_mode(code, ana, "duel", "c")["error"], "mode")   # duel is for one
        self.assertEqual(self.p.set_mode(code, ana, "arena", "c"), {"mode": "arena"})
        self.assertEqual(self.view(code, ben)["mode"], "arena")

    def test_ready_clears_on_a_change_and_the_leader_needs_the_others(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.assertEqual(self.p.set_ready(code, ana, True, "c"), {"error": "not_ready"})
        self.p.set_ready(code, ben, True, "c")
        self.assertTrue(self.view(code, ana)["members"][1]["ready"])
        self.p.set_mode(code, ana, "arena", "c")
        self.assertFalse(self.view(code, ana)["members"][1]["ready"])
        self.p.set_ready(code, ben, True, "c")
        cid = self.p.join(code, "Cid", VERSION, "c")["member"]
        self.assertFalse(any(m["ready"] for m in self.view(code, cid)["members"]))

    def test_a_joiner_resets_a_mode_that_no_longer_fits(self):
        code, (ana,) = self.make("Ana")
        self.p.set_mode(code, ana, "duel", "c")
        self.p.join(code, "Ben", VERSION, "c")
        self.assertEqual(self.view(code, ana)["mode"], "trio")

    def test_queue_is_atomic_with_one_shared_queue_time(self):
        code, secrets_ = self.make("Ana", "Ben", "Cid")
        self.clock.advance(5)
        self.assertEqual(self.ready_up(code, secrets_), {"state": "queued"})
        tickets = [self.core.tickets[self.view(code, s)["ticket"]] for s in secrets_]
        self.assertEqual({t.created_at for t in tickets}, {self.clock.t})
        self.assertEqual({t.party for t in tickets}, {code})
        v = self.view(code, secrets_[0])
        self.assertEqual((v["state"], v["position"]), ("queued", 1))
        self.assertEqual(v["eta_s"], 20)

    def test_trio_party_is_one_team_and_goes_playing(self):
        code, secrets_ = self.make("Ana", "Ben", "Cid")
        stranger = self.core.enqueue("trio", "Zed", VERSION)["ticket"]
        self.start_match(code, secrets_)
        ready_all(self.core)
        tokens = self.core.launcher.started[0].tokens
        team_of = {v["name"]: v["team"] for v in tokens.values()}
        self.assertEqual(len({team_of[n] for n in ("Ana", "Ben", "Cid")}), 1)
        self.assertNotEqual(team_of["Zed"], team_of["Ana"])
        self.assertEqual(self.core.status(stranger)["state"], "ready")
        self.assertEqual(self.view(code, secrets_[0])["state"], "playing")
        self.assertEqual(self.core.matches[next(iter(self.core.matches))].parties, {code})

    def test_duo_packs_a_stranger_as_third(self):
        code, secrets_ = self.make("Ana", "Ben")
        self.core.enqueue("trio", "Zed", VERSION)
        self.start_match(code, secrets_)
        tokens = self.core.launcher.started[0].tokens
        self.assertEqual(len({v["team"] for v in tokens.values()}), 1)

    def test_leader_passes_to_the_longest_member_and_keeps_the_mode(self):
        code, (ana, ben, cid) = self.make("Ana", "Ben", "Cid")
        self.p.set_mode(code, ana, "arena", "c")
        self.p.leave(code, ana, "c")
        v = self.view(code, ben)
        self.assertEqual([m["name"] for m in v["members"] if m["leader"]], ["Ben"])
        self.assertEqual(v["mode"], "arena")
        self.assertEqual(self.p.set_mode(code, cid, "trio", "c"), {"error": "not_leader"})

    def test_empty_party_is_deleted(self):
        code, (ana,) = self.make("Ana")
        self.p.leave(code, ana, "c")
        self.assertNotIn(code, self.p.by_code)
        self.assertEqual(self.p.view(code, ana, "c"), {"error": "gone"})

    def test_leave_while_queued_keeps_place_and_time_and_the_seat_goes_to_a_bot(self):
        code, (ana, ben, cid) = self.make("Ana", "Ben", "Cid")
        self.ready_up(code, [ana, ben, cid])
        leaver_ticket = self.view(code, cid)["ticket"]
        self.wait(10)
        self.p.leave(code, cid, "c")
        self.assertEqual(self.core.status(leaver_ticket), {"state": "gone"})
        v = self.view(code, ana)
        self.assertEqual((v["state"], v["position"], v["eta_s"]), ("queued", 1, 10))
        self.wait(10.1)
        self.core.tick()
        humans = [t["name"] for t in self.core.launcher.started[0].tokens.values()]
        self.assertEqual(sorted(humans), ["Ana", "Ben"])

    def test_whole_party_leaves_while_queued(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.ready_up(code, [ana, ben])
        tickets = [self.view(code, s)["ticket"] for s in (ana, ben)]
        self.p.leave(code, ben, "c")
        self.p.leave(code, ana, "c")
        self.assertNotIn(code, self.p.by_code)
        self.assertEqual([self.core.status(t)["state"] for t in tickets], ["gone", "gone"])
        self.assertEqual(self.core.queue.waiting["trio"], [])

    def test_leader_cancel_returns_everyone_to_forming(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.ready_up(code, [ana, ben])
        self.assertEqual(self.p.cancel_queue(code, ben, "c"), {"error": "not_leader"})
        self.assertEqual(self.p.cancel_queue(code, ana, "c"), {"state": "forming"})
        v = self.view(code, ben)
        self.assertEqual(v["state"], "forming")
        self.assertNotIn("ticket", v)
        self.assertFalse(any(m["ready"] for m in v["members"]))
        self.assertEqual(self.core.queue.waiting["trio"], [])

    def test_unused_token_expires_and_a_bot_takes_the_seat(self):
        code, secrets_ = self.make("Ana", "Ben")
        self.start_match(code, secrets_)
        ready_all(self.core)
        self.core.launcher.started[0].events.put(("joined", self.core.tickets[self.view(code, secrets_[0])["ticket"]].slot))
        self.core.tick()
        self.clock.advance(61)
        self.core.tick()
        ben_ticket = self.view(code, secrets_[1])["ticket"]
        self.assertEqual(self.core.status(ben_ticket), {"state": "gone"})
        self.assertEqual(self.view(code, secrets_[1])["state"], "playing")   # the party is not bounced

    def test_match_end_returns_to_forming_with_a_grace_period(self):
        code, secrets_ = self.make("Ana", "Ben")
        self.start_match(code, secrets_)
        ready_all(self.core)
        self.clock.advance(600)    # members are in the match, not polling: no idle drop while playing
        self.core.tick()
        self.assertEqual(self.view(code, secrets_[0])["state"], "playing")
        self.core.launcher.started[0].events.put(("exit", 0))
        self.core.tick()
        v = self.view(code, secrets_[0])
        self.assertEqual(v["state"], "forming")
        self.assertNotIn("ticket", v)
        self.assertFalse(any(m["ready"] for m in v["members"]))
        self.clock.advance(100)    # inside the 120 s grace
        self.core.tick()
        self.assertEqual(len(self.p.by_code[code].members), 2)
        self.clock.advance(21)     # grace over and 121 s without a poll
        self.core.tick()
        self.assertNotIn(code, self.p.by_code)

    def test_server_crash_before_ready_requeues_the_party_into_a_new_server(self):
        code, secrets_ = self.make("Ana", "Ben")
        self.start_match(code, secrets_)
        self.core.launcher.started[0].events.put(("exit", 1))
        self.core.tick()   # the tickets keep their queue time, so a second server starts at once
        self.assertEqual(len(self.core.launcher.started), 2)
        self.assertEqual(self.view(code, secrets_[0])["state"], "playing")
        self.core.launcher.started[1].events.put(("exit", 1))
        self.core.tick()   # a second crash drops the tickets: the party is back on its card
        self.assertEqual(self.view(code, secrets_[0])["state"], "forming")

    def test_expired_tickets_before_a_match_return_to_forming(self):
        code, (ana,) = self.make("Ana")
        self.ready_up(code, [ana])
        self.core.cancel(self.view(code, ana)["ticket"])
        self.core.tick()
        self.assertEqual(self.view(code, ana)["state"], "forming")

    def test_idle_member_is_dropped_and_the_rest_unreadied(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.p.set_ready(code, ben, True, "c")
        self.clock.advance(15)
        self.view(code, ana)                  # Ana keeps polling, Ben stops
        self.clock.advance(6)
        self.core.tick()
        v = self.view(code, ana)
        self.assertEqual([m["name"] for m in v["members"]], ["Ana"])
        self.assertEqual(self.view(code, ben), {"error": "not_member"})

    def test_idle_leader_passes_leadership(self):
        code, (ana, ben) = self.make("Ana", "Ben")
        self.clock.advance(15)
        self.view(code, ben)
        self.clock.advance(6)
        self.core.tick()
        self.assertEqual(self.view(code, ben)["members"][0], {"name": "Ben", "ready": False, "leader": True, "you": True})


if __name__ == "__main__":
    unittest.main()
