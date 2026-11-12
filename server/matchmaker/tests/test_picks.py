"""Hunter picks: the load wait, per-team turns, one of each Hunter per team, bots and run-out turns."""
import json
import os
import unittest

from helpers import MM_DIR, VERSION, Clock, make_core, ready_all

from mm.picks import HUNTERS, LOAD_WAIT_S, TURN_S, PickPhase

GAME_DIR = os.path.dirname(os.path.dirname(MM_DIR))


class PickPhaseTest(unittest.TestCase):
    def trio(self, humans={0, 1, 2, 3}):
        """Four trios; slots 0-2 are team 0, 3-5 team 1. By default team 0 is all human, team 1 one human."""
        return PickPhase(12, 3, humans, seed=7, now=0.0)

    def test_hunters_match_the_game(self):
        on_disk = set()
        for name in os.listdir(os.path.join(GAME_DIR, "content", "archetypes")):
            with open(os.path.join(GAME_DIR, "content", "archetypes", name), encoding="utf-8") as f:
                on_disk.add(json.load(f)["id"])
        self.assertEqual(set(HUNTERS), on_disk)

    def test_picking_waits_for_every_human_to_load(self):
        p = self.trio()
        for slot in (0, 1, 2):
            p.join(slot)
        p.tick(5.0)
        self.assertEqual((p.phase, p.state(5.0)["loaded"], p.state(5.0)["of"]), ("loading", 3, 4))
        self.assertEqual(p.choose(p.order[0][0], "mage", 5.0), "loading")
        p.join(3)
        p.tick(6.0)
        self.assertEqual(p.phase, "picking")

    def test_a_player_who_never_loads_does_not_hold_everyone(self):
        p = self.trio()
        p.tick(LOAD_WAIT_S)
        self.assertEqual(p.phase, "picking")

    def test_turns_unique_per_team_and_the_enemy_may_mirror(self):
        p = self.trio()
        for slot in (0, 1, 2, 3):
            p.join(slot)
        p.tick(0.0)
        first, second, third = p.order[0]
        self.assertEqual(p.choose(second, "mage", 1.0), "turn")
        self.assertEqual(p.choose(first, "mage", 1.0), "")
        self.assertEqual(p.choose(second, "mage", 2.0), "taken")
        self.assertEqual(p.choose(second, "nobody", 2.0), "unknown")
        self.assertEqual(p.choose(second, "archer", 2.0), "")
        self.assertEqual(p.state(2.0)["teams"][1]["picking"], 3)   # team 1's bots ahead of its human picked at once
        mirror = "mage" if "mage" not in p.state(2.0)["teams"][1]["picks"].values() else "archer"
        self.assertEqual(p.choose(3, mirror, 2.0), "")                # a Hunter team 0 already has
        p.tick(100.0)
        self.assertEqual(p.phase, "done")
        team0 = [p.picks[s] for s in (first, second, third)]
        self.assertEqual(len(set(team0)), 3)
        for team in range(4):
            picks = [p.picks[s] for s in p.order[team]]
            self.assertEqual(len(set(picks)), 3, picks)

    def test_bots_pick_at_once_and_a_run_out_turn_gets_a_random_free_hunter(self):
        p = self.trio(humans={0})
        p.join(0)
        p.tick(0.0)
        state = p.state(0.0)
        self.assertEqual(state["teams"][0]["picking"], 0)     # bots before the human already picked
        self.assertEqual(state["teams"][0]["left_s"], TURN_S)
        self.assertEqual(state["teams"][1]["picking"], -1)    # an all-bot team is done at once
        p.tick(TURN_S - 0.1)
        self.assertNotIn(0, p.picks)
        p.tick(TURN_S)
        self.assertEqual(p.phase, "done")
        self.assertEqual(len({p.picks[s] for s in p.order[0]}), 3)


class MatchmakerPickTest(unittest.TestCase):
    def test_a_ticket_picks_on_its_turn_after_joining(self):
        clock = Clock()
        core = make_core(clock, FILL_TIMEOUT_DUEL="1")
        a = core.enqueue("duel", "Ana", VERSION)["ticket"]
        self.assertEqual(core.pick(a, "mage"), {"error": "no_match"})
        clock.advance(2)
        core.tick()
        ready_all(core)
        proc = core.launcher.started[0]
        self.assertEqual(core.pick(a, "mage")["error"], "loading")
        proc.events.put(("joined", 0))
        core.tick()
        self.assertEqual(core.status(a), {"state": "gone"})   # the token is spent; picking still works
        out = core.pick(a, "mage")
        self.assertTrue(out["ok"], out)
        self.assertEqual(out["picks"]["teams"][0]["picks"], {"0": "mage"})
        self.assertEqual(core.pick(a, "")["picks"]["phase"], "done")


if __name__ == "__main__":
    unittest.main()
