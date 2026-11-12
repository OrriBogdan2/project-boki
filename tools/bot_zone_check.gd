extends RefCounted
## --bot-zone-check [--bz-seeds=1,2,3] [--bz-squad=3]: bots and the closing zone (scripts/match/bot_zone.gd).
## Plays whole all-bot expeditions (10 trios by default, the player on autoplay too) through the last
## close and counts, per close, the bots that stood outside the edge long enough for a zone tick, the
## bots downed outside and the bots knocked out outside (the fall at the last close included).
## Passes when the bots average under one zone death per seed. Never touches the save.

const SEEDS := [3, 9, 21, 47, 58]
const TEAMS := {3: 10, 1: 20}     # squad size -> teams (an expedition's 30 slots)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOTZONE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds := SEEDS.duplicate()
	var squad := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bz-seeds="):
			seeds = Array(a.substr(11).split(",")).map(func(x): return int(x))
		if a.begins_with("--bz-squad="):
			squad = int(a.substr(11))
	var deaths := 0
	for s in seeds:
		deaths += _expedition(main, s, squad)
	var per := float(deaths) / maxf(1.0, seeds.size())
	ok(per < 1.0, "%d zone deaths in %d seeds (%.2f a seed, under 1)" % [deaths, seeds.size(), per])
	print("BOTZONE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## One expedition; returns its zone deaths. Prints one row per close.
func _expedition(main: Node, seed_v: int, squad: int) -> int:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": TEAMS.get(squad, 10), "squad": squad, "tier": 0, "seed": seed_v, "autoplay": true})
	m.set_process(false)
	var z: ShrinkZone = m.zone
	ok(z != null, "seed %d: the expedition has a closing zone" % seed_v)
	if z == null:
		m.free()
		return 0
	var n := z.last()
	var tick_s := float(ShrinkZone.rules()["tick_s"])
	var out_s := {}        # Hunter -> s outside the edge in this close (where the zone hurts)
	var hurt := []         # per close: bots that took a zone tick
	var downs := []        # ... downed outside
	var dead := []         # ... knocked out outside
	for j in n + 1:
		hurt.append({})
		downs.append(0)
		dead.append(0)
	var was := {}          # Hunter -> [out, downed, outside] last step
	for h in m.hunters:
		was[h] = [h.out, h.downed, false]
	var t_wall := Time.get_ticks_msec()
	while not m.over and m.time < z.t1[n] + 5.0:
		var k0 := z.k
		m.step(Match.DT)
		if z.k != k0:
			out_s.clear()
		for h in m.hunters:
			var outside := z.k > 0 and z.outside(h.pos)
			var w: Array = was[h]
			var hit: bool = outside and not (h.out or h.extracted or h.downed or h.riding or h.dropping)
			out_s[h] = float(out_s.get(h, 0.0)) + Match.DT if hit else 0.0
			if out_s[h] >= tick_s:
				hurt[z.k][h] = true
			if h.downed and not w[1] and (outside or w[2]):
				downs[z.k] += 1
			if h.out and not w[0] and not h.extracted and (outside or w[2] or (z.fallen and z.k == n)):
				dead[z.k] += 1
			was[h] = [h.out, h.downed, outside]
	var total := 0
	for j in range(1, n + 1):
		total += dead[j]
		var row := [seed_v, j, z.t0[j], z.t1[j], hurt[j].size(), downs[j], dead[j]]
		var f := "BOTZONE row seed %d close %d (%.0f-%.0f s): %d bots took zone damage, %d downed, %d out outside"
		print(f % row)
	var alive := m.hunters.filter(func(x): return not x.out).size()
	var secs := (Time.get_ticks_msec() - t_wall) / 1000.0
	var sum := [seed_v, total, alive, m.hunters.size(), m.time, secs]
	print("BOTZONE seed %d: %d zone deaths, %d of %d hunters left at %.0f s (%.0f s wall)" % sum)
	m.free()
	return total
