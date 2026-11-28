"""The /social store: players and tokens, who may write what, queries, claims, the town presence."""

import unittest

from helpers import Clock

from mm.social import CLAIM_S, HELLOS_PER_HOUR, HUB_TTL_S, SocialStore


class SocialTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.s = SocialStore(":memory:", clock=self.clock)
        self.a = self.s.hello("", "1.1.1.1")
        self.b = self.s.hello("", "1.1.1.1")

    def op(self, who, op, path, **kw):
        return self.s.op(who["me"], dict(op=op, path=path, **kw))

    def test_hello_makes_distinct_players_and_knows_tokens(self):
        self.assertNotEqual(self.a["me"], self.b["me"])
        self.assertEqual(self.s.hello(self.a["token"], "2.2.2.2"), {"me": self.a["me"], "owner": False})
        self.assertEqual(self.s.player(self.b["token"]), self.b["me"])
        self.assertEqual(self.s.hello("forged", "1.1.1.1"), {"error": "not_member"})
        self.assertEqual(self.s.player("forged"), "")

    def test_new_players_per_address_are_capped(self):
        for _ in range(HELLOS_PER_HOUR - 2):
            self.assertIn("token", self.s.hello("", "1.1.1.1"))
        self.assertEqual(self.s.hello("", "1.1.1.1"), {"error": "rate_limited"})
        self.assertIn("token", self.s.hello("", "3.3.3.3"))

    def test_docs_round_trip_and_bad_paths_fail(self):
        self.assertEqual(self.op(self.a, "set", "guilds/g1", data={"name": "Ash"}), {"r": "ok"})
        self.assertEqual(self.op(self.b, "get", "guilds/g1"), {"r": {"name": "Ash"}})
        self.assertEqual(self.op(self.b, "get", "guilds/none"), {"r": None})
        for path in ("guilds", "guilds/a/b", "../x/y", "Guilds/g1", "guilds/g 1"):
            self.assertEqual(self.op(self.a, "set", path, data={})["error"], "bad_request", path)
        self.assertEqual(self.op(self.a, "set", "guilds/g2", data={"x": "y" * 70000})["error"], "bad_request")

    def test_player_keyed_docs_are_theirs_alone(self):
        a, b = self.a["me"], self.b["me"]
        self.assertEqual(self.op(self.a, "set", "profiles/" + a, data={"name": "A"}), {"r": "ok"})
        self.assertEqual(self.op(self.b, "set", "profiles/" + a, data={"name": "B"}), {"error": "not_yours"})
        self.assertEqual(self.op(self.b, "del", "clanroster/g1_" + a), {"error": "not_yours"})
        self.assertEqual(self.op(self.b, "set", "clanroster/g1_" + b, data={"guild": "g1"}), {"r": "ok"})

    def test_added_docs_name_the_caller_and_only_the_people_named_touch_them(self):
        a, b = self.a["me"], self.b["me"]
        self.assertEqual(self.op(self.b, "add", "gifts", data={"to": a, "from": a}), {"error": "not_yours"})
        gid = self.op(self.b, "add", "gifts", data={"to": a, "from": b, "kind": "seed"})["r"]
        rows = self.op(self.a, "query", "gifts", q={"where": [["to", "==", a]]})["r"]
        self.assertEqual([r["id"] for r in rows], [gid])
        third = self.s.hello("", "4.4.4.4")
        self.assertEqual(self.op(third, "del", "gifts/" + gid), {"error": "not_yours"})
        self.assertEqual(self.op(self.a, "del", "gifts/" + gid), {"r": "ok"})

    def test_a_claim_holds_a_listing_for_one_buyer(self):
        lid = self.op(self.a, "add", "market", data={"seller": self.a["me"], "price": 5})["r"]
        third = self.s.hello("", "4.4.4.4")
        self.assertEqual(self.op(self.b, "claim", "market/" + lid)["r"]["price"], 5)
        self.assertIsNone(self.op(third, "claim", "market/" + lid)["r"])
        self.assertEqual(self.op(third, "del", "market/" + lid), {"error": "not_yours"})
        self.assertEqual(self.op(self.b, "del", "market/" + lid), {"r": "ok"})
        self.assertIsNone(self.op(third, "claim", "market/" + lid)["r"])
        lid = self.op(self.a, "add", "market", data={"seller": self.a["me"]})["r"]
        self.op(self.b, "claim", "market/" + lid)
        self.clock.advance(CLAIM_S + 1)
        self.assertIsNotNone(self.op(third, "claim", "market/" + lid)["r"])

    def test_query_filters_orders_and_limits(self):
        for i, g in enumerate(["x", "y", "x", "x"]):
            self.op(self.a, "set", "contrib/c%d" % i, data={"guild": g, "updated": i})
        q = {"where": [["guild", "==", "x"]], "order": "updated", "dir": "desc", "limit": 2}
        self.assertEqual([r["id"] for r in self.op(self.a, "query", "contrib", q=q)["r"]], ["c3", "c2"])
        bad = {"where": [["guild", ">", "x"]]}
        self.assertEqual(self.op(self.a, "query", "contrib", q=bad), {"error": "bad_request"})

    def test_town_presence_lists_others_until_they_go_quiet(self):
        self.s.hub(self.a["me"], "kf-town", {"x": 1})
        self.assertEqual(self.s.hub(self.b["me"], "kf-town", {"x": 2})["r"], [{"id": self.a["me"], "p": {"x": 1}}])
        self.clock.advance(HUB_TTL_S + 1)
        self.assertEqual(self.s.hub(self.b["me"], "kf-town", {"x": 2})["r"], [])
        self.s.hub(self.a["me"], "kf-town", {"x": 1})
        self.s.hub(self.a["me"], "kf-town", None)
        self.assertEqual(self.s.hub(self.b["me"], "kf-town", {"x": 2})["r"], [])


if __name__ == "__main__":
    unittest.main()
