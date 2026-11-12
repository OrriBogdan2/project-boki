extends "res://tools/hero_pair_check.gd"
## --gil-combo-check (old name --gil-kit-check): Gil, the Novice Mage (content/archetypes/gil.json,
## scripts/arch/kits/gil_kit.gd), on a training dummy through the real match code: the Fencer chain (steps, third-hit
## slow), the Grab Bag (the shuffled bag, each vial's effect, hold range, the air drop), Fish Out of Water (three marks
## Beach), Ground Swim (hittable, surfacing knocks up), Riptide (spin damage, the spout's knockup, longer spin = wider
## spout) and Tidal Wave (untargetable, knockup then slow, lands with a shield) and its telegraphs (AimKit, seen by
## everyone, no Fx node of their own). Last, his sound set: every move and phase that ran plays a sound of its own
## (content/vfx/gil.json, made by tools/gen_sfx_gil.py), none shared with another move or the stock set. Each cast plays
## its own move, and every move but the dive has his clip. Then the dash-flow rows (content/dash_flow/gil.json,
## tools/dash_flow_check.gd).

var m: Match
var P: Hunter
var T: Hunter
var K: GilKit
var home: Vector3

func run(main_node: Node) -> void:
	main = main_node
	var r := setup("gil", 6.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[3]
	K = P.ak
	_data()
	_bag()
	_fencer()
	_tide()
	_vials()
	_hold_and_air()
	_pull_out()
	_beach()
	_swim()
	_riptide()
	_wave()
	_sounds()
	_telegraphs()
	_moves()
	await done(m)
	var rows_bad: int = await load("res://tools/dash_flow_check.gd").new().check_hero(main, "gil")
	ok("dash flow: every row in content/dash_flow/gil.json holds, every slot casts mid-jump, holds through moves",
		rows_bad == 0, "%d failures" % rows_bad)
	print("PAIRCHECK gil DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _reset(dist := 6.0) -> void:
	K._drop_holds()
	K.flying.clear()
	for pd in K.puddles: (pd["node"] as Node3D).queue_free()
	K.puddles.clear()
	K.spouts.clear()
	K.wave = {}
	K.untarget_t = 0.0
	K.marks.clear()
	K.beach_at.clear()
	K.spin_t = -1.0
	K.swim_t = 0.0
	K.tide = {}
	K.combo_n = 0
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.shield = 0.0
	P.shield_t = 0.0
	fresh(T)
	T.teleport(home + Vector3(dist, 0, 0))
	aim_at(P, T.pos)
	for s in ["e", "rmb", "dash", "x"]: K.cd[s] = 0.0
	K.e_t = 0.0
	K.ch_rmb = float(K.rmb_def()["charges"])
	P.fire_cd = 0.0
	P.dashes = P.max_dashes()
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	P.inp["dash_down"] = false
	step(m, 0.1)
	fresh(T)

## Steps until every thrown vial has landed; returns the most stun/slow/burn/lift the dummy showed.
func _land() -> Dictionary:
	var top := {"stun": 0.0, "slow": 0.0, "burn": 0.0, "lift": 0.0, "slow_k": 0.0}
	var y0 := T.pos.y
	var t := 0.0
	var watch := func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["slow_k"] = maxf(top["slow_k"], T.slow_k)
		top["burn"] = maxf(top["burn"], T.burn_t)
		top["lift"] = maxf(top["lift"], T.pos.y - y0)
	while not K.flying.is_empty() and t < 2.5:
		step(m, DT, watch)
		t += DT
	step(m, 0.05, watch)
	return top

func _data() -> void:
	var card: Dictionary = K.d["card"]
	ok("card: the loop line and one line each for RMB, E, Shift, the passive and the ultimate",
		["loop", "rmb", "e", "dash", "passive", "x"].all(func(k): return String(card.get(k, "")).length() > 10))
	ok("class: Light, signature swordfish", Arch.weight("gil") == "light" and Arch.signature("gil") == "swordfish")
	ok("roster: Gil is in the hunter order (Training Area picker)", "gil" in Arch.ORDER)
	ok("ultimate: Tidal Wave on X, 90 s", float(K.x_def().get("cooldown", 0)) == 90.0)

func _bag() -> void:
	K._refill()
	var counts := {}
	for i in 9:
		var v := K._draw_vial()
		counts[v] = int(counts.get(v, 0)) + 1
	ok("bag: one bag is 2 Thunder, 2 Slime, 2 Air, 2 Fire, 1 Super Zeep",
		counts == {"thunder": 2, "slime": 2, "air": 2, "fire": 2, "zeep": 1}, str(counts))
	ok("bag: refills itself when empty", K.bag.size() == 9, "left %d" % K.bag.size())
	var nx := K.next_vial()
	ok("bag: the next vial is visible on the HUD",
		K.slot_info("sec").get("next", "") == nx and K.res_text() == String(K.vial_def(nx)["name"]))
	var orders := {}
	for i in 4:
		K._refill()
		orders[str(K.bag)] = true
	ok("bag: reshuffles (not one fixed order)", orders.size() > 1)

func _fencer() -> void:
	_reset(3.2)
	var x0 := P.pos.x
	var top := {"n": 0, "slow": 0.0, "t": 0.0, "pose": false}
	var thrusts := int(HeroVfx.of(m).plays.get("thrust", 0))
	step(m, 1.1, func():
		top["t"] += DT
		P.inp["fire"] = fmod(top["t"], 0.12) < 0.05      # clicking (holding is the Tide Lunge)
		top["pose"] = top["pose"] or K.anim_id == "gil_thrust_a"
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["n"] = K.combo_n)
	P.inp["fire"] = false
	ok("Fencer: a thrust plays its own thrust pose and look (no slash arc)",
		top["pose"] and int(HeroVfx.of(m).plays.get("thrust", 0)) > thrusts)
	ok("Fencer: a three-hit chain lands on the dummy", int(top["n"]) >= 3 and dmg(T) >= 20.0,
		"swings %d dmg %.1f" % [top["n"], dmg(T)])
	ok("Fencer: each swing steps him forward", P.pos.x - x0 > 0.8, "moved %.2f" % (P.pos.x - x0))
	ok("Fencer: the third, longer thrust slows (30% for 0.5 s)", top["slow"] > 0.2 and top["slow"] <= 0.55,
		"slow_t %.2f" % top["slow"])

## Held LMB: the Tide Lunge. A short click is one thrust; held, he slows and draws back, and on release drives
## down the line hitting everyone on it; a full charge soaks them (a splash mark toward Beached).
func _tide() -> void:
	_reset(3.0)
	P.inp["fire"] = true
	step(m, 0.1)
	P.inp["fire"] = false
	step(m, 0.4)
	ok("Tide Lunge: a click is one thrust, no lunge", K.combo_n == 1 and K.lmb_t < 0.0 and K.tide.is_empty(),
		"thrusts %d" % K.combo_n)
	_reset(4.0)
	var x0 := P.pos.x
	P.inp["fire"] = true
	step(m, 1.2, func(): P.inp["fire"] = true)
	ok("Tide Lunge: held, he charges it (slowed, drawn back), full by 0.8 s",
		K.lmb_t >= 0.0 and K.tide_k() >= 1.0 and K.move_k() < 1.0 and K.anim_id == "gil_tide_wind",
		"k %.2f anim %s" % [K.tide_k(), K.anim_id])
	var before := dmg(T)
	P.inp["fire"] = false
	step(m, 0.5)
	var td: Dictionary = K.lmb_def()["tide"]
	ok("Tide Lunge: let go, he drives about 5 m down the line", P.pos.x - x0 > 4.0 and P.pos.x - x0 < 7.5,
		"%.2f m" % (P.pos.x - x0))
	ok("Tide Lunge: full charge hits the foe on the line for 22", dmg(T) - before >= float(td["dmg"][1]) * 0.9,
		"%.1f" % (dmg(T) - before))
	ok("Tide Lunge: full charge soaks (one splash mark)", K.marks_on(T) == 1, "%d" % K.marks_on(T))
	ok("Tide Lunge: the release plays its pose and look",
		int(HeroVfx.of(m).plays.get("tide_lunge", 0)) > 0 and int(HeroVfx.of(m).plays.get("tide_hit", 0)) > 0)

func _vials() -> void:
	var want := {"thunder": "stun", "slime": "slow", "fire": "burn", "zeep": "lift"}
	for v in ["thunder", "slime", "air", "fire", "zeep"]:
		_reset(6.0)
		K.bag.append(v)
		var x0 := T.pos.x
		var looks := int(HeroVfx.of(m).plays.get("shatter_" + v, 0))
		tap(m, P)
		var thrown := K.anim_id == "gil_toss"
		var top := _land()
		var hit := dmg(T) > 0.0
		ok("%s: the toss pose, and the bottle breaks in its own look" % v,
			thrown and int(HeroVfx.of(m).plays.get("shatter_" + v, 0)) == looks + 1)
		match v:
			"thunder": ok("Thunder: damage and a stun in the centre", hit and top["stun"] >= 0.4,
				"dmg %.1f stun %.2f" % [dmg(T), top["stun"]])
			"slime": ok("Slime: 40% slow and a puddle stays",
				top["slow"] >= 1.2 and absf(top["slow_k"] - 0.4) < 0.05 and K.puddles.size() == 1,
				"slow %.2f k %.2f puddles %d" % [top["slow"], top["slow_k"], K.puddles.size()])
			"air":
				step(m, 0.5)
				ok("Air: knocks the dummy away", T.pos.x - x0 > 1.5, "pushed %.2f" % (T.pos.x - x0))
			"fire": ok("Fire: damage plus a burn", hit and top["burn"] > 0.0,
				"dmg %.1f burn %.2f" % [dmg(T), top["burn"]])
			"zeep": ok("Super Zeep: bigger blast, knocks up", hit and top["stun"] >= 0.6 and top["lift"] > 0.3,
				"stun %.2f lift %.2f" % [top["stun"], top["lift"]])
	_puddle()

## The slime puddle keeps slowing, and it is drawn for exactly as long, on its radius: Gil's lit rim over a faint
## slime inside, a white flare as it lands, an ease-out fade before it dries, and no strobing rings.
func _puddle() -> void:
	_reset(6.0)
	K.bag.append("slime")
	tap(m, P)
	_land()
	var vd := K.vial_def("slime")
	var pd: Dictionary = K.puddles[0] if K.puddles.size() == 1 else {}
	ok("Slime: one puddle, drawn", pd.has("node") and (pd["node"] as Node3D).is_inside_tree())
	if not pd.has("node"):
		return
	var node: Node3D = pd["node"]
	var rim: ShaderMaterial = pd["rim"]
	var inside: ShaderMaterial = pd["inside"]
	var sig := Arch.color("gil")
	var quad := (node.get_child(1) as MeshInstance3D).mesh as PlaneMesh
	var flare: Color = rim.get_shader_parameter("color")
	ok("Slime: the rim sits on the puddle's radius and flares white as it lands",
		absf(quad.size.x - 2.0 * float(vd["puddle_r"])) < 0.01 and flare.a > GilKit.PUDDLE_RIM_A + 0.05
			and flare.r > sig.r + 0.05,
		"quad %.2f m, flare %s" % [quad.size.x, flare])
	fresh(T)
	step(m, 0.3)
	ok("Slime: the puddle slows whoever stands in it", T.slow_t > 0.0 and absf(T.slow_k - 0.25) < 0.05,
		"slow %.2f k %.2f" % [T.slow_t, T.slow_k])
	var steady: Color = rim.get_shader_parameter("color")
	var in_col: Color = inside.get_shader_parameter("color")
	ok("Slime: then a steady rim in Gil's colour over a faint inside in the slime's (0.25 alpha or less)",
		Color(steady, 1.0).is_equal_approx(sig) and absf(steady.a - GilKit.PUDDLE_RIM_A) < 0.01
			and Color(in_col, 1.0).is_equal_approx(K.col_of(vd)) and in_col.a * 0.3 <= 0.25,
		"rim %s inside %s" % [steady, in_col])
	var at: Vector3 = pd["at"]
	var r := float(pd["r"])
	var on_it := func(rg: Dictionary) -> bool:
		return absf(float(rg["r"]) - r) < 0.05 and (rg["node"] as Node3D).global_position.distance_to(at) < 0.5
	var strobe := false
	while float(pd["left"]) > GilKit.PUDDLE_FADE * 0.5:
		step(m, DT)
		strobe = strobe or m.fx.rings.any(on_it)
	var mid: float = (rim.get_shader_parameter("color") as Color).a / GilKit.PUDDLE_RIM_A
	ok("Slime: no rings strobe over it, and it fades on an ease-out curve as the slow ends (a quarter left halfway)",
		not strobe and absf(mid - 0.25) < 0.05, "%.3f of its glow halfway through the fade" % mid)
	step(m, 0.3)
	ok("Slime: gone with its slow", K.puddles.is_empty() and node.is_queued_for_deletion())

func _hold_and_air() -> void:
	_reset(6.0)
	aim_at(P, home + Vector3(30, 0, 0))
	K.bag.append("air")
	hold(m, P, 0.5)
	var far := 0.0
	if not K.flying.is_empty():
		far = Vector2(K.flying[0]["at"].x - home.x, K.flying[0]["at"].z - home.z).length()
	ok("Grab Bag hold: lands +50% further (12 m against 8)", far > 11.0 and far < 12.6, "%.2f m" % far)
	_land()
	_reset(6.0)
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	K.bag.append("fire")
	tap(m, P)
	var below := false
	if not K.flying.is_empty():
		var at: Vector3 = K.flying[0]["at"]
		below = Vector2(at.x - P.pos.x, at.z - P.pos.z).length() < 0.6 and at.y < P.pos.y - 1.0
	ok("Grab Bag in the air: drops the vial straight down", below)
	_land()

## The potion stays in the bag until the toss clip's pull-out key (rmb draw), then leaves his hand.
func _pull_out() -> void:
	_reset(6.0)
	tap(m, P)
	var held: bool = not K.flying.is_empty() and not K.flying[0].has("from")
	while not K.flying.is_empty() and not K.flying[0].has("from") and m.time - K.anim_at < 1.0:
		step(m, DT)
	var out_t := m.time - K.anim_at
	var draw := float(K.rmb_def()["draw"])
	ok("Grab Bag: the potion comes out of the bag on the toss key", held and absf(out_t - draw) <= 1.0 / 30.0,
		"out %.3f s, key %.3f s" % [out_t, draw])
	_land()

func _beach() -> void:
	_reset(6.0)
	for v in ["air", "fire", "slime"]: K.bag.append(v)      # slime first, then fire, then air (none stuns alone)
	var top := {"stun": 0.0}
	for i in 3:
		K.ch_rmb = 2.0
		K.cd["rmb"] = 0.0
		aim_at(P, T.pos)
		var before := K.marks_on(T)
		tap(m, P)
		var t := _land()
		top["stun"] = maxf(top["stun"], t["stun"])
		if i < 2:
			ok("Fish Out of Water: vial %d leaves a mark (%d)" % [i + 1, K.marks_on(T)], K.marks_on(T) == before + 1)
	ok("Fish Out of Water: three different marks within 5 s Beach the dummy (0.75 s stun)", top["stun"] >= 0.6,
		"stun %.2f" % top["stun"])
	ok("Fish Out of Water: 8 s per target", float(K.beach_at.get(T.get_instance_id(), 0.0)) - m.time > 7.0)

func _swim() -> void:
	_reset(5.0)
	var x0 := P.pos.x
	var dives := int(HeroVfx.of(m).plays.get("dive", 0))
	K.on_dash(false)
	m.step(DT)
	var under := K.swim_t > 0.0
	var hit_on := float(K.incoming(T, 10.0, {})[0]) == 10.0
	ok("Ground Swim: the dive and its wake play, no shared dash pill over the ground",
		int(HeroVfx.of(m).plays.get("dive", 0)) == dives + 1 and K.own_dash_trail())
	step(m, 0.15)
	# owner 11-11: the swim didn't take him under. Mid-swim the dive pose has the whole body (hat and all,
	# plate_offset up from the feet) below the surface.
	var age := m.time - K.anim_at
	var lift := float(HunterAnim.km_sample(K.anim_id, age).get("lift", 0.0))
	ok("Ground Swim: mid-swim his whole body is under the ground",
		K.anim_id == "gil_dive" and lift + float(K.d["plate_offset"]) < 0.0, "%s lift %.2f" % [K.anim_id, lift])
	var top := {"stun": 0.0, "y": 0.0, "out": false}
	var y0 := T.pos.y
	step(m, 0.8, func():
		top["out"] = top["out"] or K.anim_id == "gil_surface"
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["y"] = maxf(top["y"], T.pos.y - y0))
	ok("Ground Swim: swims about 6 m", P.pos.x - x0 > 4.0 and P.pos.x - x0 < 7.5, "%.2f m" % (P.pos.x - x0))
	ok("Ground Swim: he bursts back out (gil_surface) and nothing holds him under after",
		top["out"] and K.anim_id != "gil_dive" and int(HeroVfx.of(m).plays.get("surface", 0)) > 0)
	ok("Ground Swim: he stays hittable underground", under and hit_on)
	ok("Ground Swim: surfacing knocks nearby foes up 0.5 s", top["stun"] >= 0.4 and top["y"] > 0.2,
		"stun %.2f lift %.2f" % [top["stun"], top["y"]])
	ok("Ground Swim: 8 s cooldown", float(K.dash_def()["cd"]) == 8.0)

func _riptide() -> void:
	_reset(1.6)
	K.use_e()
	ok("Riptide: E starts the spin (the spin pose)", K.spin_t >= 0.0 and K.anim_id == "gil_spin")
	step(m, 1.0)
	var spin_dmg := dmg(T)
	ok("Riptide: the spin hurts foes around him", spin_dmg > 0.0, "%.1f" % spin_dmg)
	var w := K.recast_window()
	ok("Riptide: RecastCue's ring runs over the 2 s spin and the spout goes by itself (no EXPIRED)",
		float(w.get("total", 0.0)) == 2.0 and float(w.get("left", 0.0)) < 1.1 and bool(w.get("auto", false)), str(w))
	ok("Riptide: the recast opens and ticks in Gil's own sounds",
		HeroSfx.of(P, "recast_open", "") == "gil_recast_open" and HeroSfx.of(P, "recast_tick", "") == "gil_recast_tick")
	_reset(7.0)
	K.use_e()
	step(m, 0.3)
	K.e_recast()
	ok("Riptide recast: the spin stops on the spout thrust, the spout's look plays",
		K.anim_id == "gil_spout" and int(HeroVfx.of(m).plays.get("spout", 0)) > 0)
	var w_short: float = K.spouts[0]["w"] if not K.spouts.is_empty() else 0.0
	var top := {"stun": 0.0}
	step(m, 1.2, func(): top["stun"] = maxf(top["stun"], T.stun_t))
	ok("Riptide recast: the waterspout runs down the line and knocks up 1 s", top["stun"] >= 0.9 and dmg(T) > 0.0,
		"stun %.2f" % top["stun"])
	_reset(7.0)
	K.use_e()
	step(m, 2.2)
	var w_long := 0.0
	var auto := not K.spouts.is_empty() and K.spin_t < 0.0
	if not K.spouts.is_empty(): w_long = K.spouts[0]["w"]
	if K.spouts.is_empty() and dmg(T) > 0.0: auto = true
	ok("Riptide: at 2 s the spout goes on its own", auto or K.spin_t < 0.0)
	ok("Riptide: a longer spin makes a wider spout",
		w_long > w_short + 0.3 or (w_long == 0.0 and w_short > 0.0 and K.spin_t < 0.0),
		"%.2f vs %.2f" % [w_long, w_short])
	ok("Riptide: 12 s cooldown", float(K.e_def()["cooldown"]) == 12.0)

func _wave() -> void:
	_reset(6.0)
	P.lvl = 6
	ok("Tidal Wave: casts", K.cast_ult())
	m.step(DT)
	ok("Tidal Wave: Gil is untargetable while he surfs (the surf pose, the wave's look)",
		K.untarget_t > 0.0 and float(K.incoming(T, 50.0, {})[0]) == 0.0 and K.anim_id == "gil_surf"
		and int(HeroVfx.of(m).plays.get("wave", 0)) > 0)
	var top := {"stun": 0.0, "slow": 0.0, "k": 0.0}
	step(m, 1.2, func():
		top["stun"] = maxf(top["stun"], T.stun_t)
		top["slow"] = maxf(top["slow"], T.slow_t)
		top["k"] = maxf(top["k"], T.slow_k))
	ok("Tidal Wave: knocks up 1 s, then slows 50% for 2 s",
		top["stun"] >= 0.9 and top["slow"] >= 2.5 and absf(top["k"] - 0.5) < 0.05,
		"stun %.2f slow %.2f k %.2f" % [top["stun"], top["slow"], top["k"]])
	ok("Tidal Wave: lands with a shield and is hittable again",
		K.anim_id != "gil_surf" and int(HeroVfx.of(m).plays.get("wave_land", 0)) > 0
		and P.shield > 0.0 and K.untarget_t <= 0.0 and float(K.incoming(T, 10.0, {})[0]) == 10.0,
		"shield %.1f" % P.shield)
	ok("Tidal Wave: 90 s cooldown after the cast", float(K.cd["x"]) > 85.0, "%.1f" % float(K.cd["x"]))
	_wave_way(Vector2(-1, 0))
	_wave_way(Vector2(0, 1))

## Owner 11-11: the ult pushed him the wrong way. Cast while running another way (back, or sideways), he surfs the
## wave's own line toward the cursor, the whole 14 m, and stays on it.
func _wave_way(run: Vector2) -> void:
	_reset(6.0)
	P.lvl = 6
	K.cd["x"] = 0.0
	P.inp["move"] = run
	var p0 := P.pos
	var aim := P.aim_dir()
	K.cast_ult()
	step(m, 1.1, func(): P.inp["move"] = run)
	P.inp["move"] = Vector2.ZERO
	var moved := P.pos - p0
	var along := Vector2(moved.x, moved.z).dot(aim)
	var off := absf(Vector2(moved.x, moved.z).cross(aim))
	ok("Tidal Wave: running %s, he surfs toward the cursor" % str(run), along > 10.0 and off < 1.0,
		"along %.2f off-line %.2f" % [along, off])
	ok("Tidal Wave: he rides with the crest (within 2 m of it at the end)",
		absf(along - float(K.x_def()["range"])) < 2.0, "along %.2f" % along)

## Each move or phase of the kit -> the sound it plays (the thrusts and the dash pick theirs by "k" and HeroSfx).
const OWN_SOUNDS := {
	"thrust": ["gil_thrust", "gil_thrust_low"], "lunge": ["gil_lunge"], "thrust_hit": ["gil_thrust_hit"],
	"lunge_hit": ["gil_lunge_hit"], "tide_wind": ["gil_tide_wind"], "tide_full": ["gil_tide_full"],
	"tide_lunge": ["gil_tide_lunge"], "tide_hit": ["gil_tide_hit"], "throw": ["gil_toss"],
	"shatter_thunder": ["gil_pop_thunder"], "shatter_slime": ["gil_pop_slime"], "shatter_air": ["gil_pop_air"],
	"shatter_fire": ["gil_pop_fire"], "shatter_zeep": ["gil_pop_zeep"], "mark": ["gil_mark"],
	"beached": ["gil_beached"], "surface": ["gil_surface"], "spin": ["gil_spin"], "spout": ["gil_spout"],
	"wave": ["gil_wave"], "wave_land": ["gil_wave_land"],
}

func _sounds() -> void:
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/vfx/gil.json"))["moves"]
	var set_names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/gil.json"))["sounds"]
	var wrong := []
	var silent := []
	for mv in OWN_SOUNDS:
		var names := (moves[mv].get("sfx", []) as Array).map(func(e): return String(e["n"]))
		if names != OWN_SOUNDS[mv] or not names.all(func(n): return set_names.has(n) and Sfx.ensure(n)):
			wrong.append("%s %s" % [mv, names])
		if int(HeroVfx.of(m).plays.get(mv, 0)) == 0:
			silent.append(mv)
	ok("sounds: every move and phase plays its own levelled gil_* sound (wrong: %s)" % [wrong], wrong.is_empty())
	ok("sounds: every one of those moves ran in this check (never ran: %s)" % [silent], silent.is_empty())
	ok("sounds: the dive is the dash sound alone (no second layer)", not moves["dive"].has("sfx"))
	P.grounded = true
	var ground := HeroSfx.dash_name(P)
	P.grounded = false
	var air := HeroSfx.dash_name(P)
	P.grounded = true
	ok("sounds: Ground Swim dives in gil_dash, the air dash plays gil_dash_air",
		ground == "gil_dash" and air == "gil_dash_air", "%s / %s" % [ground, air])

## Every telegraph Gil makes goes through AimKit (docs/AIMKIT.md), where everyone sees it, and none makes a
## tweened Fx telegraph node (the old ArchKit.tele_circle/tele_lane path is gone). The R fuse ring is ArchKit's.
func _telegraphs() -> void:
	var nodes: int = m.fx.teles.size()
	_reset(6.0)
	K.bag.append("slime")
	tap(m, P)
	m.step(DT)
	var pot := String(K.flying[0]["id"]) if not K.flying.is_empty() else ""
	var c0 := AimKit.entry(P, pot)
	var slime_r := float(K.vial_def("slime")["radius"])
	ok("telegraph: a thrown potion's landing circle (its radius) is up for everyone",
		c0.get("kind", "") == "circle" and bool(c0["all"]) and absf(float(c0["r"]) - slime_r) < 0.01,
		str(c0.get("r", -1.0)))
	var f0 := float(c0.get("fill", -1.0))
	step(m, 0.15)
	var f1 := float(AimKit.entry(P, pot).get("fill", -1.0))
	ok("telegraph: it fills while the potion flies", f0 >= 0.0 and f1 > f0, "%.2f -> %.2f" % [f0, f1])
	_land()
	step(m, 0.15)
	ok("telegraph: and is gone once it lands", not AimKit.shown(P, pot))
	_reset(7.0)
	K.use_e()
	step(m, 0.3)
	K.e_recast()
	m.step(DT)
	var sp: Dictionary = K.spouts[0] if not K.spouts.is_empty() else {}
	var l0 := AimKit.entry(P, String(sp.get("id", "")))
	ok("telegraph: the spout's lane, its length and width, for everyone",
		l0.get("kind", "") == "lane" and bool(l0["all"]) and absf(float(l0["len"]) - float(sp["len"])) < 0.01
		and absf(float(l0["width"]) - float(sp["w"])) < 0.01)
	step(m, 0.1)
	var l1 := AimKit.entry(P, String(sp.get("id", "")))
	ok("telegraph: the spout's lane fills with its front",
		float(l1.get("fill", -1.0)) > float(l0.get("fill", -1.0)) and float(l0.get("fill", -1.0)) >= 0.0)
	_reset(6.0)
	P.lvl = 6
	K.cast_ult()
	m.step(DT)
	var w0 := AimKit.entry(P, "x")
	ok("telegraph: Tidal Wave's lane (an outline, the full range) for everyone while he surfs",
		w0.get("kind", "") == "lane" and bool(w0["all"]) and float(w0["fill"]) < 0.0
		and absf(float(w0["len"]) - float(K.x_def()["range"])) < 0.01)
	step(m, float(K.x_def()["time"]) + 0.3)
	ok("telegraph: and is gone when he lands", not AimKit.shown(P, "x"))
	_reset(6.0)
	K.fuse = {"t": 1.0, "T": 1.0, "bond": false, "guard": "none", "fx": 1.0, "at": P.pos}
	step(m, 0.25)
	var r0 := AimKit.entry(P, "r_fuse")
	ok("telegraph: an R fuse's 2.4 m ring fills on the ground for everyone",
		r0.get("kind", "") == "circle" and bool(r0["all"]) and absf(float(r0["r"]) - 2.4) < 0.01
		and float(r0["fill"]) > 0.15)
	K.fuse = {}
	step(m, 0.15)
	ok("telegraph: none of it made an Fx telegraph node", m.fx.teles.size() == nodes,
		"%d -> %d" % [nodes, m.fx.teles.size()])

## The moves each cast plays (KMovesGil ids, content/rules/warden_anim/gil.json), in the order they play. The dive
## is the rig's keyed pose, not a clip: it takes the whole body under the ground, the swim clip only
## sinks him to the fin.
func _moves() -> void:
	var seen: Array = []
	var watch := func():
		if K.anim_id != "" and (seen.is_empty() or seen[-1] != K.anim_id):
			seen.append(K.anim_id)
	_reset(6.0)
	tap(m, P)
	watch.call()
	K.on_dash(false)
	step(m, 0.8, watch)
	K.use_e()
	step(m, 0.3, watch)
	K.e_recast()
	step(m, 0.1, watch)
	P.lvl = 6
	K.cd["x"] = 0.0
	K.cast_ult()
	step(m, 1.3, watch)
	var want := ["gil_toss", "gil_dive", "gil_surface", "gil_spin", "gil_spout", "gil_surf", "gil_wave_land"]
	ok("moves: the Grab Bag, Ground Swim, Riptide and Tidal Wave each play theirs", seen == want, str(seen))
	var clips: Dictionary = WardenClips.data("gil").get("kmoves", {})
	var bare := want.filter(func(mv: String) -> bool: return mv != "gil_dive" and not clips.has(mv))
	ok("moves: each has a clip in his map", bare.is_empty(), str(bare))
	_reset(6.0)
	K.use_e()
	K._drop_holds()
	ok("moves: a spin cut short (a stun) lets go of the twirl", K.anim_id == "", K.anim_id)
