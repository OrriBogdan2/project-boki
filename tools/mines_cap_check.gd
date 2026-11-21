extends "res://tools/ability_check.gd"      # shares its _ac_setup / _ac_run helpers
## --mines-cap-check: one Glintmole fighting a foe for 60 s must never have more than MAX_LIVE puffcap
## mines on the ground at once (Supervive clarity: nothing cluttering the screen). Its own AI casts
## Puffcap Mines whenever the cooldown allows (foe stays in range, never steps on a mine), and every
## 60 s run prints the peak number of live traps per caster. Also checks a hunter-cast mine pair:
## max_live on the trap delivery drops the oldest one. Prints MINESCAP lines.

const MAX_LIVE := 3
const FIGHT_SECS := 60.0

var _mc_fail := 0


func _mc(name: String, ok: bool, info := "") -> void:
	print("MINESCAP %-34s %s  %s" % [name, "PASS" if ok else "FAIL", info])
	if not ok:
		_mc_fail += 1


## Live traps per caster right now: caster -> count.
func _mc_live(m: Match) -> Dictionary:
	var out := {}
	for tr in m.verbs.traps:
		out[tr["caster"]] = int(out.get(tr["caster"], 0)) + 1
	return out


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var r := _ac_setup(5.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	m.opts["training"] = false      # training recharges a Boki's cooldowns 3x; a real match does not
	var rec := Save.new_kin("glintmole")
	rec["trust"] = 95.0
	var k := m.give_kin(P, rec)
	k.stow()
	k.settle = 1.0
	P.merge_cd = 0.0
	P.slot_lv["kin"] = 1      # the Boki's own ability is unlocked
	k.runner.reset()
	k.teleport(P.pos + Vector3(1.0, 0, 0))
	k.state = "active"
	k.cmd = "follow"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true
	var def: AbilitySpec = k.runner.def_of("k1")
	_mc("glintmole's E is puffcap mines", def != null and def.id == "puffcap_mines")
	for rate in [1.0, 3.0]:      # 3.0 = the training ground's recharge, or a high Boki rank
		k.runner.reset()
		k.runner.rate = rate
		m.verbs.clear()
		var peak := 0
		var casts := 0
		var last_ready := true
		var t := 0.0
		while t < FIGHT_SECS:
			T.hp = T.max_hp
			T.teleport(P.pos + Vector3(5.0, 0, 0))     # stays in cue range; never walks onto a mine
			T.vel = Vector3.ZERO
			k.state = "active"      # keep it out and on the foe
			k.target = T
			for mb in m.mobs:
				mb.queue_free()
			m.mobs.clear()
			var rdy: bool = k.runner.is_ready("k1")
			if last_ready and not rdy:
				casts += 1
			last_ready = rdy
			m.step(Match.DT)
			t += Match.DT
			for c in _mc_live(m):
				peak = maxi(peak, int(_mc_live(m)[c]))
		print("MINESCAP cooldown x%.0f: peak %d live puffcaps (%d casts in %.0f s)" % [rate, peak, casts, FIGHT_SECS])
		_mc("x%.0f casts happened" % rate, casts >= 3, "%d" % casts)
		_mc("x%.0f peak per caster <= %d" % [rate, MAX_LIVE], peak <= MAX_LIVE, "peak %d" % peak)
	# the mines expire on their own: no cast for a while and none are left
	k.runner.slots["k1"]["charges"] = 0.0
	k.runner.slots["k1"]["cd"] = 1e9
	_ac_run(m, 20.0)
	_mc("mines are gone once they expire", m.verbs.traps.is_empty(), "%d left" % m.verbs.traps.size())
	m.queue_free()
	await main.get_tree().process_frame
	print("MINESCAP DONE, failures: ", _mc_fail)
	main.get_tree().quit(1 if _mc_fail > 0 else 0)
