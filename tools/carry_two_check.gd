extends RefCounted
## --carry-two-check: carry 2 in, 1 extra out (docs/decisions/0090). Prints CARRY2 PASS/FAIL lines.
##   1. the lead and the second both come in; the second waits in the satchel
##   2. both carry passives are on; the same stat from both does not stack (the stronger counts)
##   3. the swap key trades lead and second, then waits out its cooldown (content/rules/kin_ai.json)
##   4. a claimed Boki takes the one carry-out slot: no passive, no summon, no Boki in the world
##   5. a full carry-out slot blocks the next scan and points to a teammate with room
##   6. extracting brings the carry-out Boki home (Game.apply_result)
##   7. stealing from a deathbox: one stolen slot, at most 4 Boki on one hunter
##   8. bots bring two
##   9. the first match with two Boki says what the swap key does, once
## --carry-two-clip --shots-dir=<dir>: the swap and the carry-out HUD as numbered JPGs (frame_0000.jpg ...) for an MP4.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("CARRY2 %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode := "") -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle",
		"cls": "medium", "demo_kin": "cindle"})
	if mode == "clip":
		await _clip(main)
		return
	m.set_process(false)
	_step(0.5)
	var P := m.player
	_two_in(P)
	_lead_hint(P)
	_passives(P)
	_swap(P)
	_carry_out(P)
	_extract(P)
	_steal(P)
	print("CARRY2 %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT)
		t += Match.DT

func _two_in(P: Hunter) -> void:
	ok(P.kin != null and P.kin2 != null and P.kin != P.kin2, "the lead and the second both come in")
	ok(P.kin2 != null and (P.kin2 as Kin).state == "bench", "the second waits in the satchel")

## The first-time hint (Match._tips) names the swap key the first time you carry two, then never again.
func _lead_hint(P: Hunter) -> void:
	Settings.v["tips"] = true
	Save.d["tutorial"].erase("lead_swap")
	m._tip_t = 2.0
	var lane := m.hud.msgs
	var before := lane.rects().size()
	m._tips()
	var want := "%s swaps your lead Boki" % Settings.key_cap("swap_kin")
	ok(Save.d["tutorial"].get("lead_swap", false) and lane.rects().size() > before, "carrying two shows '%s' once" % want)
	var seen_n := lane.rects().size()
	m._tips()
	ok(lane.rects().size() == seen_n, "and not again")
	var kin2 := P.kin2
	P.kin2 = null
	Save.d["tutorial"].erase("lead_swap")
	m._tips()
	ok(not Save.d["tutorial"].has("lead_swap"), "with one Boki there is nothing to swap, so no hint")
	P.kin2 = kin2

## Lead: move_speed 0.06. Second: move_speed 0.10 and dodge_regen 0.2.
func _passives(P: Hunter) -> void:
	var a: Kin = P.kin
	var b: Kin = P.kin2
	a.ks.carry_passives = [{"stat": "move_speed", "amount": 0.06}]
	b.ks.carry_passives = [{"stat": "move_speed", "amount": 0.10}, {"stat": "dodge_regen", "amount": 0.2}]
	a.state = "shoulder"
	a.settle = 1.0
	a.cmd = "return"
	P._refresh_kin_stats()
	ok(P.kin_carry_on() and KinSlots.second_on(P), "lead riding with you and the second in the satchel: both on")
	var dr := P.owner_stat("dodge_regen")
	ok(is_equal_approx(dr, 0.2), "the second's own stat counts (dodge_regen %.2f)" % dr)
	var ms := P.owner_stat("move_speed")
	ok(is_equal_approx(ms, 0.10), "the same stat from both: the stronger counts (move_speed %.2f, not 0.15)" % ms)
	a.cmd = "follow"
	a.state = "active"
	P._refresh_kin_stats()
	ok(not P.kin_carry_on() and is_equal_approx(P.owner_stat("move_speed"), 0.10),
		"lead out fighting: the second's passive stays on")
	b.hp = 0.0
	P._refresh_kin_stats()
	ok(not KinSlots.second_on(P) and is_zero_approx(P.owner_stat("dodge_regen")), "a fainted second gives nothing")
	b.hp = b.max_hp

func _swap(P: Hunter) -> void:
	var a: Kin = P.kin
	var b: Kin = P.kin2
	P.swap_cd = 0.0
	P.inp["kin_swap"] = true
	KinKeys.apply(P)
	var cd := float(Content.rules("kin_ai")["swap_cooldown"])
	ok(P.kin == b and P.kin2 == a and a.state == "bench" and b.state != "bench", "the swap key trades lead and second")
	ok(is_equal_approx(P.swap_cd, cd), "the swap starts its cooldown (%.1fs, content/rules/kin_ai.json)" % cd)
	P.inp["kin_swap"] = true
	KinKeys.apply(P)
	ok(P.kin == b, "a second press inside the cooldown does nothing")
	_step(cd + 0.1)
	P.inp["kin_swap"] = true
	KinKeys.apply(P)
	ok(P.kin == a and P.kin2 == b, "after the cooldown the swap works again")

func _wild(at: Vector3, species := "puddlet") -> Kin:
	var rec := Save.new_kin(species, "", 77)
	return m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)

func _carry_out(P: Hunter) -> void:
	P._refresh_kin_stats()
	var before := KinSlots.carry_stats(P)
	var own := m.kins.filter(func(k): return k.owner_h == P and not k.dead).size()
	var k := _wild(P.pos + Vector3(2.0, 0, 0))
	ok(Capture.block_reason(P, k) == "", "an empty carry-out slot: the scan can start")
	m._catch(P, k)
	ok(P.caught.size() == 1 and Capture.stolen_count(P) == 0,
		"the claimed Boki takes the carry-out slot (%s)" % CaptureHud.box_text(P))
	P._refresh_kin_stats()
	ok(KinSlots.carry_stats(P) == before, "the carry-out Boki gives no passive")
	ok(m.kins.filter(func(x): return x.owner_h == P and not x.dead).size() == own and k.dead,
		"the carry-out Boki is no Boki in the world: nothing to send out or summon")
	var k2 := _wild(P.pos + Vector3(-2.0, 0, 0))
	var mate: Hunter = Capture.mate_with_room(m, P)
	ok(mate != null and not Capture.room(P), "the carry-out slot is full; a teammate has room")
	ok(mate != null and Capture.block_reason(P, k2).contains(mate.pname),
		"the full note points to a teammate with room (%s)" % Capture.block_reason(P, k2))

func _extract(P: Hunter) -> void:
	var old: Dictionary = Save.d
	var d := Save.fresh()
	var mine := Save.new_kin("cindle", "Ember")
	d["roster"].append(mine)
	d["active"] = mine["uid"]
	Save.d = d
	var r := {"arch": String(P.arch), "extracted": true, "why": "extracted", "knocks": 0, "kills": 0, "gems": 0,
		"seeds": {}, "stats": {}, "lvl": 1, "caught": P.caught.duplicate(true), "kin_runs": [], "tonics": 0}
	Game.apply_result(r)
	var sp := String(P.caught[0]["species"])
	var home: Array = (Save.d["roster"] as Array).filter(func(x): return String(x["species"]) == sp)
	ok(home.size() == 1, "extracting brings the carry-out Boki home (a %s in the roster)" % sp)
	Save.d = old

func _steal(P: Hunter) -> void:
	var T: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			T = h
			break
	ok(T != null and T.kin != null and T.kin2 != null, "bots bring two Boki")
	if T == null:
		return
	T.caught = []
	var a := Save.new_kin("puddlet", "Drip")
	a["lost_from"] = "you"
	var c := Save.new_kin("puddlet", "Drop")
	c["lost_from"] = "you"
	var wild := Save.new_kin("cindle", "")
	var b := {"owner": P, "team": P.team, "pos": T.pos, "gems": 0, "seeds": {}, "caught": [a, c, wild], "belt": [],
		"soul_until": 0.0, "prog": {}, "node": null, "empty": false, "gear": [], "pack": [], "keys": 0, "chest_keys": 0}
	Life.take_item(m, T, b, {"key": "caught", "i": 0})
	ok(T.caught.size() == 1 and Capture.stolen_count(T) == 1, "a rival steals one of your Boki from the deathbox")
	Life.take_item(m, T, b, {"key": "caught", "i": 0})
	ok(T.caught.size() == 1 and (b["caught"] as Array).size() == 2, "one stolen slot: the next stays in the box")
	Life.take_item(m, T, b, {"key": "caught", "i": 1})
	ok(T.caught.size() == 2 and Capture.wisps(T) == 4, "a claimed Boki fills the carry-out slot: 4 Boki, the cap")
	T.caught.remove_at(1)
	T.kin2 = null
	ok(Capture.room(T) and not Capture.room(T, c), "with room left, the stolen slot still holds only one")

## The match runs live; a swap at 1.5 s, a claim at 3 s, a swap back at 5.5 s, one JPG a frame until 8 s.
func _clip(main: Node) -> void:
	var dir := "/tmp/carry_two_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var tree := main.get_tree()
	if main.get("fade") != null:
		main.fade.reveal(0.01)          # the boot splash would cover the frames
	var P := m.player
	var t0 := m.time
	var done := {}
	var n := 0
	while m.time - t0 < 8.0:
		var t := m.time - t0
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		if t > 1.5 and not done.has("swap"):
			done["swap"] = true
			P.inp["kin_swap"] = true
		if t > 3.0 and not done.has("claim"):
			done["claim"] = true
			m._catch(P, _wild(P.pos + Vector3(2.0, 0, 0)))
		if t > 5.5 and not done.has("back"):
			done["back"] = true
			P.inp["kin_swap"] = true
		await tree.process_frame
		tree.root.get_texture().get_image().save_jpg("%s/frame_%04d.jpg" % [dir, n], 0.9)
		n += 1
	print("CARRY2 clip %d frames in %s" % [n, dir])
	tree.quit(0)
