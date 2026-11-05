extends RefCounted
## --build-hold-check: holding to build, your Boki helping, materials spent as the work goes (item 90), and
## the tools and the weapon put away while you chop, mine and build (item 91).
##   1. the rules: a build's quarters add up to its cost; a save from before (cost paid up front) still loads
##   2. holding the key N seconds is N / beat swings, the same as that many taps; a Boki nearby makes it faster;
##      materials leave as the quarters pass; with none the build stops at the step and says what it needs
##   3. every Hunter and the Empty: the weapon, off-hand blade, shield and orb are hidden with a tool out, the
##      tool is in the hands, and the weapon is back after (but not at home, where the Empty carries none)
##   4. chopping and mining at home: hits land on the beat, trees and boulders react, hold keeps going
## Never touches the real save.

const BEAT_SLACK := 0.08          # s: how far from the strike a hit may land
const HAND_REACH := 0.3           # m: the tool's butt is this close to the hands at most
const SETTLE_FRAMES := 90

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BUILDHOLD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_rules()
	_rigs()
	await _building()
	await _gathering()
	print("BUILDHOLD DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ setup
func _new_save(kin_count := 1) -> Dictionary:
	var d := Save.fresh()
	for i in kin_count:
		var k := Save.new_kin(["zapple", "cindle"][i], ["Pip", "Ash"][i])
		k["level"] = 5
		Care.ensure(k)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	return d

func _home(kin_count: int):
	Save.d = _new_save(kin_count)
	HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	var home = await main._hb_home()
	home._close_panel()
	return home

func _house() -> Dictionary:
	for e in HomeLayout.of(Save.d)["deco"]:
		if String(e["id"]) == "house":
			return e
	return {}

func _set_mats(cost: Dictionary) -> void:
	Save.d["mats"] = {}
	for m in ["wood", "stone", "fibre"]:
		Work.add_mat(m, int(cost.get(m, 0)))

func _reset_site(e: Dictionary, cost: Dictionary) -> void:
	e["site"]["got"] = 0
	e["site"]["steps"] = 0
	e["site"]["paid"] = {}
	_set_mats(cost)

# ------------------------------------------------------------------ 1. the rules
func _rules() -> void:
	var all_add_up := true
	for id in FarmSites.rules()["build"]:
		var cost := FarmSites.build_cost(String(id))
		var sum := {}
		for k in FarmSites.STEPS:
			var share := FarmSites.step_share(cost, k)
			for mat in share:
				sum[mat] = int(sum.get(mat, 0)) + int(share[mat])
		for mat in FarmSites.MATS:
			all_add_up = all_add_up and int(sum.get(mat, 0)) == int(cost.get(mat, 0))
	ok(all_add_up, "every building's four quarters add up to its whole cost")
	var house := FarmSites.build_cost("house")
	ok(int(house["wood"]) >= 10 and int(house["stone"]) >= 6,
			"the house is a real build: %s" % FarmSites.cost_text(house))
	var s := {"need": 12, "got": 0}
	var due: Array = []
	for got in [0, 2, 3, 5, 6, 9, 11]:
		s["got"] = got
		due.append(FarmSites.steps_due(s))
	ok(due == [1, 1, 2, 2, 3, 4, 4], "a 12-swing build asks for a quarter at swings 0, 3, 6 and 9 (%s)" % str(due))
	var tiny := {"need": 3, "got": 0}
	ok(FarmSites.steps_due(tiny) == 2 and FarmSites.step_start(3, 3) < 3,
			"a 3-swing build still pays everything before its last swing")
	# a site from before: the whole cost was paid up front
	Save.d = _new_save()
	var old := {"u": 1, "id": "house", "x": 3, "z": 3, "r": 0, "t": 1.0,
			"site": {"need": 8.0, "got": 3.0, "to": 1.0, "up": false, "paid": {"wood": 3.0}}}
	FarmSites.clean(old)
	var loaded_paid: bool = int(old["site"]["steps"]) == FarmSites.STEPS and old["site"]["cost"] == old["site"]["paid"]
	ok(loaded_paid and not FarmSites.stalled(old),
			
			"a site saved before this loads as fully paid and never asks for more")
	Work.add_mat("wood", 0)
	var done := false
	for i in 8:
		done = FarmSites.add_swing(old) or done
	ok(done and not FarmSites.has_site(old) and Work.mat("wood") == 0,
			"and it finishes without spending anything again")
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify({"site": {"need": 12, "got": 4, "to": 1, "up": false,
			"cost": {"wood": 10, "stone": 6}, "paid": {"wood": 3}, "steps": 1}}))
	var e2 := {"id": "house", "t": 1, "site": round_trip["site"]}
	FarmSites.clean(e2)
	ok(int(e2["site"]["steps"]) == 1 and int(e2["site"]["cost"]["wood"]) == 10 and e2["site"]["got"] is int,
			"a new-shape site survives a save and load")

# ------------------------------------------------------------------ 3. the rigs
func _rigs() -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var cases: Array = []
	for id in Arch.ids():
		cases.append([String(id), Arch.weight(String(id)), Arch.signature(String(id)), PlayerLook.neutral()])
	cases.append(["the Empty", "medium", "smg", Unmasked.default_look()])
	for c in cases:
		var arch: String = c[0] if c[0] != "the Empty" else ""
		var model := Models.hunter(c[1], Data.TEAM_COLORS[0], c[2], "", c[3], arch)
		model.set_meta("anim_seed", 1)
		holder.add_child(model)
		for tool in HunterTool.TOOLS:
			_rig_cycle(String(c[0]), model, String(tool))
		model.free()
	holder.free()

func _weapon_nodes(a: HunterAnim) -> Array:
	var out: Array = []
	for n in [a.gun, a.offhand, a.hand_l.get_node_or_null("Shield") if a.hand_l else null, a.focus]:
		if n != null:
			out.append(n)
	return out

func _frames(a: HunterAnim, state: Dictionary, n: int, tool_t_from := 0.0) -> void:
	for i in n:
		var s := state.duplicate()
		s["tool_t"] = tool_t_from + float(i) / 60.0
		a.update(1.0 / 60.0, s)

func _rig_cycle(who: String, model: Node3D, tool: String) -> void:
	var a := HunterAnim.new(model)
	_frames(a, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}, 30)
	var armed := _weapon_nodes(a).any(func(n): return (n as Node3D).visible)
	var act := HunterTool.act_of(tool)
	# working: weapon put away, tool in the hands, at several points of the swing
	var state := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "tool": tool, "act": act, "holster": true}
	_frames(a, state, SETTLE_FRAMES)
	var node := model.get_node_or_null("Rig/Torso/Tool") as Node3D
	var hidden := _weapon_nodes(a).all(func(n): return not (n as Node3D).visible)
	var near := 9.0
	for i in 12:
		_frames(a, state, 5, float(i) * 0.07)
		if node:
			var left := a.arm_l.transform * (a.el_l.transform * a.hand_l.position)
			var right := a.arm_r.transform * (a.el_r.transform * a.hand_r.position)
			near = minf(near, minf(node.position.distance_to(left), node.position.distance_to(right)))
	ok(armed, "%s: carries a weapon before it takes up the %s" % [who, tool])
	ok(hidden and node != null and node.visible and near < HAND_REACH,
			"%s with the %s: weapon nodes hidden, tool in the hands (%.2f m from a hand)" % [who, tool, near])
	# done: the tool goes. At home the weapon stays away; in a match it comes back
	_frames(a, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "holster": true}, SETTLE_FRAMES)
	var tool_gone := node == null or not node.visible
	var still_away := _weapon_nodes(a).all(func(n): return not (n as Node3D).visible)
	_frames(a, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}, SETTLE_FRAMES)
	var shield := a.hand_l.get_node_or_null("Shield") if a.hand_l else null
	var back: bool = (a.gun == null or a.gun.visible) and (shield == null or shield.visible)
	ok(tool_gone and still_away and back,
			"%s after the %s: tool away, weapon away at home, back in a match" % [who, tool])

# ------------------------------------------------------------------ 2. building
func _sim(home, secs: float, hold: bool) -> void:
	for i in int(secs / 0.05):
		for k in home.kins:
			for n in Care.NEEDS:
				k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 70.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		home.hw.tick(0.05)
		home.hob.tick(0.05)
		if i % 200 == 0:
			await main.get_tree().process_frame

func _hammer(home, e: Dictionary, secs: float) -> void:
	home.hw.scan_t = 0.0
	home.hw.scan()
	var it: Dictionary = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	home.hob.use(it)
	home.tw.test_hold = true
	await _sim(home, secs, true)
	home.tw.test_hold = false

func _tap(home) -> void:
	var it: Dictionary = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	home.hob.use(it)
	for i in 40:
		home.hob.tick(0.05)
		if not home.tw.active():
			break

func _building() -> void:
	var home = await _home(1)
	ok(home.guide.place_house(), "the house goes down as a site")
	var e := _house()
	var cost := FarmSites.build_cost("house")
	ok(FarmSites.is_site(e) and int(e["site"]["steps"]) == 0 and (e["site"]["paid"] as Dictionary).is_empty(),
			"marking it out spends nothing")
	var hc := HomeLayout.deco_center(e)
	home.ppos = hc + Vector3(2.0, 0, 2.2)
	for k in home.kins:
		k["pos"] = hc + Vector3(30.0, 0, 30.0)
		(k["node"] as Node3D).position = k["pos"]
		k["t"] = 999.0
		k["goal"] = k["pos"]
	var beat := HunterTool.period("hammer")
	var lead := beat * HunterTool.IMPACT - beat * 0.4         # the first hit lands this long after the press
	# holding N beats vs tapping N times
	var beats := 4
	var hold_s := lead + beat * float(beats - 1) + 0.1
	_set_mats(cost)
	await _hammer_alone(home, e, hold_s)
	var held_got := int(e["site"]["got"])
	_reset_site(e, cost)
	for i in beats:
		_tap(home)
	ok(held_got == beats and int(e["site"]["got"]) == beats,
			"holding %.1f s did %d swings, as did %d taps (one beat is %.1f s)" % [hold_s, held_got, beats, beat])
	# the materials leave a quarter at a time
	_reset_site(e, cost)
	var follows := true
	var seen: Array = []
	home.hob.use(home.hob.find(Vector2(home.ppos.x, home.ppos.z)))
	home.tw.test_hold = true
	for i in int(20.0 / 0.05):
		home.hob.tick(0.05)
		if not FarmSites.has_site(e):
			break
		var paid_quarters := int(e["site"]["steps"])
		var spent_wood := int(cost["wood"]) - Work.mat("wood")
		var want_wood := 0
		for k in paid_quarters:
			want_wood += int(FarmSites.step_share(cost, k).get("wood", 0))
		follows = follows and spent_wood == want_wood
		if seen.is_empty() or seen[-1] != spent_wood:
			seen.append(spent_wood)
	home.tw.test_hold = false
	ok(follows and seen.size() >= FarmSites.STEPS,
			"wood left in four steps as the quarters began (spent so far: %s)" % str(seen))
	ok(not FarmSites.has_site(e) and Work.mat("wood") == 0 and Work.mat("stone") == 0,
			"and the finished house used exactly its %s" % FarmSites.cost_text(cost))
	home.queue_free()
	await main.get_tree().process_frame
	await _stalling()
	await _crew()

func _hammer_alone(home, e: Dictionary, secs: float) -> void:
	home.hob.use(home.hob.find(Vector2(home.ppos.x, home.ppos.z)))
	home.tw.test_hold = true
	for i in int(secs / 0.05):
		home.hob.tick(0.05)
	home.tw.test_hold = false
	for i in 40:
		home.hob.tick(0.05)

## With too little, the build stops at the step and says what it needs; bring it and it goes on.
func _stalling() -> void:
	var home = await _home(1)
	home.guide.place_house()
	var e := _house()
	var cost := FarmSites.build_cost("house")
	var two := {}
	for k in 2:
		var share := FarmSites.step_share(cost, k)
		for mat in share:
			two[mat] = int(two.get(mat, 0)) + int(share[mat])
	_set_mats(two)
	var hc := HomeLayout.deco_center(e)
	home.ppos = hc + Vector3(2.0, 0, 2.2)
	home.kins.clear()
	await _hammer_alone(home, e, 14.0)
	var stop_at := FarmSites.step_start(int(e["site"]["need"]), 2)
	ok(int(e["site"]["got"]) == stop_at and FarmSites.stalled(e) and not home.tw.active(),
			"with two quarters' worth the build stops at swing %d of %d" % [stop_at, int(e["site"]["need"])])
	var need := FarmSites.need_text(e)
	var short := FarmSites.missing(e)
	ok(need.begins_with("Needs ") and need.contains("more wood") and short.has("wood") and int(short["wood"]) > 0,
			"the site says so: '%s'" % need)
	var it: Dictionary = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(home._label_for(it) == need, "and so does the prompt: '%s'" % home._label_for(it))
	FarmModels.tick_bars(home.hw)
	var tag := home.hb.nodes[int(e["u"])].get_node_or_null("Need") as Label3D
	ok(tag != null and tag.visible and tag.text == need, "and it hangs over the site as a label")
	home.hw.scan_t = 0.0
	home.hw.scan()
	var jobs: int = home.hw.jobs.filter(func(j): return String(j["kind"]) == "build").size()
	ok(jobs == 0, "a Boki would not start on a site that is waiting")
	var before := int(e["site"]["got"])
	home.hob.use(it)
	ok(not home.tw.active() and int(e["site"]["got"]) == before,
			"pressing at it does nothing but tell you what is missing")
	_set_mats(cost)
	await _hammer_alone(home, e, 14.0)
	ok(not FarmSites.has_site(e), "bring the rest and hammering carries on to the end")
	home.queue_free()
	await main.get_tree().process_frame

## One Boki nearby comes and helps: more swings in the same time.
func _crew() -> void:
	var secs := 7.0
	var beat := HunterTool.period("hammer")
	var alone_swings := 0
	var helped_swings := 0
	var came := false
	for with_boki in [false, true]:
		var home = await _home(1)
		home.guide.place_house()
		var e := _house()
		var cost := FarmSites.build_cost("house")
		cost["labour"] = 40
		e["site"]["need"] = 40
		_set_mats({"wood": 99, "stone": 99})
		e["site"]["cost"] = {"wood": 10, "stone": 6}
		var hc := HomeLayout.deco_center(e)
		home.ppos = hc + Vector3(2.0, 0, 2.2)
		for k in home.kins:
			k["pos"] = hc + (Vector3(3.0, 0, 3.0) if with_boki else Vector3(60.0, 0, 60.0))
			(k["node"] as Node3D).position = k["pos"]
			k["goal"] = k["pos"]
			k["t"] = 999.0
		await _hammer(home, e, secs)
		if with_boki:
			helped_swings = int(e["site"]["got"])
			came = home.kins.any(func(k): return k.has("job") and String(k["job"].get("kind", "")) == "build")
		else:
			alone_swings = int(e["site"]["got"])
		home.queue_free()
		await main.get_tree().process_frame
	ok(came, "a Boki nearby dropped what it was doing and came to build")
	ok(helped_swings > alone_swings and alone_swings >= int((secs - 0.5) / beat) - 1,
			"%.0f s of holding: %d swings alone, %d with one Boki helping" % [secs, alone_swings, helped_swings])

# ------------------------------------------------------------------ 4. chopping and mining
func _gathering() -> void:
	var home = await _home(1)
	var hg: HomeGather = home.hg
	var hb: HomeBuild = home.hb
	HomeGather.give_tool("axe")
	HomeGather.give_tool("pickaxe")
	for what in ["tree", "rock"]:
		var tile := -1
		var stand := Vector3.INF
		for i in hb.wild_t:
			if hb.wild_t[i] != what:
				continue
			var b := hg.beside(i, HomeLayout.LANDING)
			if b == Vector3.INF:
				continue
			var it := hg.find(Vector2(b.x, b.z))
			if int(it.get("i", -1)) == i:
				tile = i
				stand = b
				break
		ok(tile >= 0, "there is a %s to work" % what)
		if tile < 0:
			continue
		home.ppos = stand
		home.player.position = stand
		var tool := HomeGather.tool_for(what)
		var mat := String(HomeGather.TOOLS[tool]["mat"])
		var have0 := Work.mat(mat)
		home.tw.test_hold = true
		hg.use(hg.find(Vector2(stand.x, stand.z)))
		ok(home.tw.tool == tool and hg.busy(), "holding use with the %s out starts working the %s" % [tool, what])
		await _wiring(home, tool)
		var period := HunterTool.period(tool)
		var on_beat := true
		var cracks_ok := true
		for i in int(8.0 / 0.05):
			var before := int(hg.damage.get(tile, 0))
			var t_before: float = home.tw.swing_t
			home.tw.tick(0.0, true)
			hg.tick(0.05)
			var after := int(hg.damage.get(tile, 0))
			if after > before:
				on_beat = on_beat and absf(t_before + 0.05 - period * HunterTool.IMPACT) <= BEAT_SLACK + 0.05
				if what == "rock" and after < HomeGather.HITS:
					var holder: Node3D = hg.cracks.get(tile)
					cracks_ok = cracks_ok and is_instance_valid(holder) and holder.get_child_count() == after
			if not hg.busy():
				break
		home.tw.test_hold = false
		ok(not hb.wild_t.has(tile) and Work.mat(mat) >= have0 + int(HomeGather.TOOLS[tool]["n"]),
				"%d hits felled the %s: %d %s" % [HomeGather.HITS, what, Work.mat(mat) - have0, mat])
		ok(on_beat,
				"every hit landed as the head met the target (%.0f%% into the swing)" % (HunterTool.IMPACT * 100.0))
		ok(cracks_ok,
				"the %s showed each hit" % ("boulder cracked" if what == "rock" else "tree shed leaves and chips"))
	# let go: the swing finishes and the tool goes
	var spot := Vector3.INF
	var t2 := -1
	for i in hb.wild_t:
		if hb.wild_t[i] == "tree":
			spot = hg.beside(i, HomeLayout.LANDING)
			if spot != Vector3.INF and int(hg.find(Vector2(spot.x, spot.z)).get("i", -1)) == i:
				t2 = i
				break
	home.ppos = spot
	hg.use(hg.find(Vector2(spot.x, spot.z)))
	for i in 5:
		hg.tick(0.05)
	for i in 80:
		hg.tick(0.05)
	ok(not home.tw.active() and not hg.busy() and int(hg.damage.get(t2, 0)) == 1 and hb.wild_t.has(t2),
			"a tap is one swing: the tree keeps its hit and the tool goes away")
	home.queue_free()
	await main.get_tree().process_frame

## The real Home frame loop: the pose state reaches the rig (weapon away, tool out).
func _wiring(home, tool: String) -> void:
	for i in 40:
		await main.get_tree().process_frame
	var a: HunterAnim = home.p_anim
	var node := home.player.get_node_or_null("Rig/Torso/Tool") as Node3D
	var away := _weapon_nodes(a).all(func(n): return not (n as Node3D).visible)
	ok(a.tool_kind == tool and node != null and node.visible and away,
			"at home the %s is in the hands and the weapon nodes are hidden" % tool)
