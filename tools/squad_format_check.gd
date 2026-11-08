extends RefCounted
## --squad-format-check: the expedition's one format, Data.SQUADS trios, bots filling
## every spot no player takes. A fresh save's expedition opts start a match with exactly 10 squads of
## 3, one starting spot per squad, spread out, and enough exits, chests and monsters for 30 hunters.
## (Under autoplay your hunter is bot-driven too, so "you" is m.player, not the one non-bot.)
## Prints the per-hunter numbers and the sim cost of a step against the old 20-hunter count. Never
## touches the save.

const SPOT_MIN := 25.0         # m: the closest two squads may start
const SIM_T := 60.0            # s of play the step cost is measured over
const COST_MAX := 1.8          # the 30-hunter step may cost at most this many times the 20-hunter one

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SQUADFMT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var o := Data.squad_opts()
	var fmt_ok := int(o["teams"]) == 10 and int(o["squad"]) == 3 and int(o["total"]) == 30
	ok(fmt_ok, "the expedition is 10 squads of 3 (%s)" % str(o))
	var m := _match(main, o)
	var teams := {}
	for h in m.hunters:
		teams[h.team] = int(teams.get(h.team, 0)) + 1
	var trios := teams.values().all(func(n): return n == Data.SQUAD_SIZE)
	ok(teams.size() == Data.SQUADS and trios, "the match has %d squads, sizes %s" % [teams.size(), str(teams.values())])
	var mates := m.hunters.filter(func(h): return h.team == m.player.team and h != m.player)
	ok(mates.size() == Data.SQUAD_SIZE - 1 and m.hunters.size() == Data.MATCH_PLAYERS,
		"your squad is full (%d bot squadmates) and bots fill the other %d squads" % [mates.size(), Data.SQUADS - 1])
	var leads := m.skydrop.leads.size() if m.skydrop else 0
	ok(leads == Data.SQUADS, "every squad has a drop leader (%d)" % leads)
	# starting spots: one per squad, as far apart as the map allows
	var bases := {}
	for h in m.hunters:
		if not bases.has(h.team): bases[h.team] = h.ai.get("land", h.pos)
	var dmin := 1e9
	var bl: Array = bases.values()
	for i in bl.size():
		for j in range(i + 1, bl.size()):
			dmin = minf(dmin, Vector2(bl[i].x - bl[j].x, bl[i].z - bl[j].z).length())
	var W := m.world
	ok(dmin >= SPOT_MIN, "squads start at least %.0f m apart (closest %.1f m, %d islands, %d spawn spots, map %d tiles)"
		% [SPOT_MIN, dmin, W.islands.size(), W.spawns.size(), W.w])
	var n_exits := m.exits.list.size() if m.exits else 0
	var n_mobs := m.mobs.filter(func(x): return not x.dead).size()
	print("SQUADFMT density: %d exits (%.2f a squad), %d chests (%.2f a hunter), %d monsters (%.2f a hunter)"
		% [n_exits, n_exits / float(Data.SQUADS), m.chests.size(), m.chests.size() / 30.0, n_mobs, n_mobs / 30.0])
	# (chests are laid out by the map, not the headcount: 2+ a squad is what the old 10-squad Duos had)
	var holds := n_exits >= Data.SQUADS / 2 and m.chests.size() >= Data.SQUADS * 2 and n_mobs >= Data.MATCH_PLAYERS
	ok(holds, "the map holds 30: an exit for every 2 squads, 2+ chests a squad, a monster a hunter")
	var cost30 := _step_cost(m)
	m.free()
	var m20 := _match(main, {"teams": 7, "squad": 3, "total": 20})
	var cost20 := _step_cost(m20)
	m20.free()
	print("SQUADFMT perf (headless sim): %.2f ms a step with 30 hunters, %.2f ms with the old 20" % [cost30, cost20])
	var ratio := cost30 / maxf(0.001, cost20)
	ok(ratio <= COST_MAX, "30 hunters cost %.2fx the old 20 in the sim (limit %.1fx)" % [ratio, COST_MAX])
	print("SQUADFMT DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _match(main: Node, o: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	var mo := o.duplicate()
	mo.merge({"tier": 1, "seed": 41, "autoplay": true, "plan_t": 0.5})
	m.start(mo)
	m.set_process(false)
	return m

## Mean ms of one sim step over SIM_T seconds of play from the drop.
func _step_cost(m: Match) -> float:
	var n := int(SIM_T / Match.DT)
	var t0 := Time.get_ticks_usec()
	for i in n:
		m.step(Match.DT)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
