extends RefCounted
## Grimble's ultimate on X, Brass Broadside, for --dredge-combo-check (docs/heroes/dredge.md): the level gate,
## the 1.1s charge behind a growing fan everyone sees (a slow walk, the fan turning with the aim), two waves 0.6s
## apart of six slugs each (shots through Match.spawn_shot), Anti-Heal, every slug landing up close and fewer
## further out, bond once per cast and only on a land, the stun that stops it, the other buttons locked while
## it runs, no back bonus, the merge drop, the cooldown, the reel combo and the burst cap; clarity: the fan in his
## gold at AimKit's low fill, and no look over the bodies in it bigger than the scattergun's muzzle flash.

const BURST := preload("res://tools/ult_burst.gd")
const FACE_AWAY := PI / 2.0         # a target east of Grimble facing this way shows him its back

var ak = null
var ok_fn: Callable
var widest_flash := 0.0             # m: the largest look DredgeBlast put up while its waves went (clarity)
var sweeps := 0                     # crescents drawn across the fan (clarity: none)
var plain_slugs := 0                # slugs still drawn as Match's plain sphere under their volley look (clarity: none)

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

## Clarity, each step of the waves: what HeroVfx is showing round him (its surface looks, by shader mode).
func _scan_looks(k: DredgeKit) -> void:
	for e: Dictionary in HeroVfx.of(k.m).live:
		var mode := int(((e["mat"]) as ShaderMaterial).get_shader_parameter("mode"))
		if mode == HeroVfx.MODES["sweep"]:
			sweeps += 1
		if mode == HeroVfx.MODES["flare"]:
			widest_flash = maxf(widest_flash, (e["s0"] as Vector3).x)
	for s: Dictionary in k.m.shots:
		if s["by"] == k.h and (s["x"] as Dictionary).has("kx") and s["node"] != null:
			plain_slugs += 1

## The gun's muzzle flash in the data (the fist flash of a wave may not be bigger).
func _gun_flash() -> float:
	return float((HeroVfx.data("dredge")["moves"] as Dictionary)["shot"]["fx"][0]["size"])

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(p: Hunter) -> float:
	var c: Dictionary = p.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(p.ak) else 0.0

func run() -> void:
	await _charge_and_waves()
	await _props()
	await _guards()
	await _burst()

func _cast(p: Hunter, at: Vector3) -> DredgeBlast:
	var k: DredgeKit = p.ak
	k.cd["x"] = 0.0
	ak.aim_at(p, at)
	HunterKeys.ult_pressed(p)
	return k.broadside

func _charge_and_waves() -> void:
	var r: Array = ak.setup("dredge", 1.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	var b := k.broadside
	t_v.teleport(home + Vector3(-6.0, 0, -5.0))
	t2.teleport(home + Vector3(-6.0, 0, 5.0))
	p.lvl = 5
	_cast(p, home + Vector3(4, 0, 0))
	ok("ult: no cast below level 6", not b.running() and float(k.cd["x"]) == 0.0 and b.casts == 0, "level %d" % p.lvl)
	p.lvl = 6
	# his walk first, to compare the slowed walk against
	ak.step(m, 0.2, func(): p.inp["move"] = Vector2(0, 1))
	var w0 := p.pos
	ak.step(m, 0.3, func(): p.inp["move"] = Vector2(0, 1))
	var run_v := p.flat_dist(w0) / 0.3
	p.inp["move"] = Vector2.ZERO
	ak.step(m, 0.2)
	p.teleport(home)
	var shots0: int = m.shot_n
	_cast(p, home + Vector3(4, 0, 0))
	ok(
		"ult cast: the charge move plays, its own cooldown starts (21s)",
		b.charging() and k.anim_id == "dr_blast" and absf(float(k.cd["x"]) - 21.0) < 0.2, "cd %.1f" % float(k.cd["x"])
	)
	ak.step(m, 0.3, func(): p.inp["move"] = Vector2(0, 1))
	var fan: Dictionary = AimKit.entry(p, "x_fan")
	var len_a := float(fan.get("len", 0.0))
	var p0 := p.pos
	ak.step(m, 0.6, func(): p.inp["move"] = Vector2(0, 1))
	var len_b := float(AimKit.entry(p, "x_fan").get("len", 0.0))
	var net_off := b.net_gun_tip().distance_to(b.gun_tip())
	ok(
		"ult gun arm: another game's copy holds it out on his own line (synced move + facing)",
		net_off < 0.6,
		"%.2f m apart" % net_off
	)
	ok(
		"ult telegraph: a 105 degree fan everyone sees, growing over the charge",
		bool(fan.get("all", false)) and absf(float(fan.get("deg", 0.0)) - 105.0) < 0.5 and len_b > len_a + 0.5,
		"len %.1f -> %.1f" % [len_a, len_b]
	)
	var fan_col: Color = fan.get("col", Color.BLACK)
	ok(
		"ult clarity: the fan is his gold at AimKit's own fill (the bodies in it stay readable)",
		fan_col.is_equal_approx(AimKit.hero_col(p)) and float(fan.get("alpha", 9.0)) <= 1.0,
		"col %s alpha %.2f" % [fan_col.to_html(false), float(fan.get("alpha", 9.0))]
	)
	var charge_k := p.flat_dist(p0) / 0.6 / maxf(0.01, run_v)
	ok(
		"ult: he walks slowly through the charge (about 30% of his speed)",
		b.waves == 0 and charge_k > 0.2 and charge_k < 0.4, "%.2f of %.1f m/s" % [charge_k, run_v]
	)
	# the cursor swings round to the south: the fan turns with it, and the waves go that way
	ak.aim_at(p, p.pos + Vector3(0, 0, 4.0))
	var walk_scan := func():
		p.inp["move"] = Vector2(0, 1)
		_scan_looks(k)
	ak.step(m, 0.25, walk_scan)
	var p1 := p.pos
	ak.step(m, 0.4, walk_scan)
	var fire_k := p.flat_dist(p1) / 0.4 / maxf(0.01, run_v)
	var fdir: Vector2 = b.blast.get("dir", Vector2.ZERO)
	ok(
		"ult: he walks slower still while the waves go (about 20%), and keeps turning to the cursor",
		b.waves >= 1 and fire_k > 0.1 and fire_k < 0.3 and fdir.distance_to(Vector2(0, 1)) < 0.15,
		"%.2f, fan toward (%.2f, %.2f)" % [fire_k, fdir.x, fdir.y]
	)
	p.inp["move"] = Vector2.ZERO
	ak.aim_at(p, p.pos + Vector3(4, 0, 0))
	ak.step(m, 0.65, _scan_looks.bind(k))
	ok(
		"ult clarity: no sweep over the fan, no plain sphere under a slug, a fist flash no bigger than the gun's",
		b.waves == 2 and sweeps == 0 and plain_slugs == 0 and widest_flash > 0.0
			and widest_flash <= _gun_flash() + 0.01,
		"sweeps %d, plain slugs %d, widest flash %.2f m" % [sweeps, plain_slugs, widest_flash]
	)
	ok(
		"ult: one press, two waves of six slugs through spawn_shot",
		b.waves == 2 and m.shot_n - shots0 >= 12 and not b.running(),
		"waves %d shots %d" % [b.waves, m.shot_n - shots0]
	)
	ok(
		"ult bond: nothing for waves that hit nobody", _owed(p) == 0.0 and b.casts == 1,
		"owed %.2f casts %d" % [_owed(p), b.casts]
	)
	HunterKeys.ult_pressed(p)
	ok("ult: the cooldown denies a new cast", not b.running() and b.casts == 1, "cd %.1f" % float(k.cd["x"]))
	ak.step(m, 0.05)
	ok("ult gun arm: the copy's arm is free once the cast is over", not b.net_gun_tip().is_finite())
	# point blank: every slug of both waves lands, with Anti-Heal; the waves 0.6s apart
	p.teleport(home)
	ak.fresh(t_v)
	t_v.teleport(home + Vector3(1.6, 0, 0))
	t_v.face = FACE_AWAY
	var times: Array = []
	_cast(p, t_v.pos)
	var w := b.waves
	var t := 0.0
	while t < 2.3:
		m.step(ak.DT)
		t += ak.DT
		if b.waves > w:
			w = b.waves
			times.append(t)
	var hits: Array = b.last_wave_hits
	ok(
		"ult beats: wave 1 at the end of the 1.1s charge, wave 2 0.6s later",
		times.size() == 2 and absf(float(times[0]) - 1.1) < 0.05
			and absf(float(times[1]) - float(times[0]) - 0.6) < 0.05,
		str(times)
	)
	ok(
		"ult payoff: point blank, all six slugs of each wave land",
		hits.size() == 2 and int(hits[0]) == 6 and int(hits[1]) == 6, str(hits)
	)
	var per := float(k.x_def()["dmg"]) * k.power("x")
	ok(
		"ult payoff: 4 a slug, no back bonus (12 slugs, target facing away)", absf(ak.dmg(t_v) - per * 12.0) < 0.6,
		"dmg %.1f expected %.1f" % [ak.dmg(t_v), per * 12.0]
	)
	ok("ult payoff: the slugs leave Anti-Heal", t_v.blight_t > 0.0, "%.1fs" % t_v.blight_t)
	ok(
		"ult bond: 12 slugs land, the cast still counts once (a hit: 0.6)",
		absf(_owed(p) - 0.6) < 0.001, "owed %.2f" % _owed(p)
	)
	# further out only the middle slugs reach
	ak.fresh(t_v)
	t_v.teleport(home + Vector3(4.6, 0, 0))
	_cast(p, t_v.pos)
	ak.step(m, 2.2)
	hits = b.last_wave_hits
	ok(
		"ult payoff: at 4.6m fewer slugs land (a shotgun fan, not a wall)",
		hits.size() == 2 and int(hits[0]) > 0 and int(hits[0]) < 6, str(hits)
	)
	_reel_combo(m, p, t_v, home)
	await ak.done(m)

## The Broadside's slugs are Explosive (source): they break a crate and a pot and light a keg in the fan.
func _props() -> void:
	var r: Array = ak.setup("dredge", 1.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	p.lvl = 6
	t.teleport(home + Vector3(-6.0, 0, -5.0))
	t2.teleport(home + Vector3(-6.0, 0, 5.0))
	var spots := {"crate": Vector3(3, 0, -1.2), "pot": Vector3(3, 0, 1.2), "keg": Vector3(4, 0, 0)}
	var props := {}
	for kind_s in spots:
		var at: Vector3 = home + spots[kind_s]
		at.y = m.world.ground_at(at.x, at.z)
		m._add_break(kind_s, at)
		props[kind_s] = m.breaks[-1]
	_cast(p, home + Vector3(4, 0, 0))
	ak.step(m, 2.2)
	ok(
		"ult props: the slugs break a crate and a pot and light a keg (Explosive)",
		props["crate"]["dead"] and props["pot"]["dead"] and (props["keg"].has("fuse_t") or props["keg"]["dead"])
	)
	await ak.done(m)

## Deep Reach, the foe hauled to your feet stunned, then the Broadside: every slug lands.
func _reel_combo(m: Match, p: Hunter, t_v: Hunter, home: Vector3) -> void:
	var k: DredgeKit = p.ak
	ak.fresh(t_v)
	t_v.teleport(home + Vector3(8.0, 0, 0))
	k.cd["rmb"] = 0.0
	k.ch_rmb = 1.0
	ak.aim_at(p, t_v.pos)
	ak.tap(m, p)
	var t := 0.0
	while t < 3.0 and (k.flying or not k.pull.is_empty()):
		m.step(ak.DT)
		t += ak.DT
	_cast(p, t_v.pos)
	ak.step(m, 2.2)
	var hits: Array = k.broadside.last_wave_hits
	var n := int(hits[0]) + int(hits[1]) if hits.size() == 2 else 0
	ok("ult combo: reel the foe in, then the Broadside lands (10+ slugs)", k.arrivals >= 1 and n >= 10, "slugs %d" % n)

## A stun in the charge stops it (back in 8s); RMB, E and the barge are locked while it runs; a merge drops it.
func _guards() -> void:
	var r: Array = ak.setup("dredge", 1.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: DredgeKit = p.ak
	var b := k.broadside
	_cast(p, t.pos)
	ak.step(m, 0.4)
	var g0 := k.grapples
	var ch0 := k.ch_rmb
	ak.tap(m, p)
	p.ak.use_e()
	var x0 := p.pos
	p.dashes = p.max_dashes()
	p.ak.on_dash(false)
	ak.step(m, 0.1)
	ok(
		"ult: RMB and E are locked while it runs; Shift barges at once and it runs on, its pose kept (item 51)",
		k.ch_rmb == ch0 and k.grapples == g0 and k.wind <= 0.0 and p.flat_dist(x0) > 0.5 and b.charging()
				and k.anim_id == "dr_blast",
		"moved %.2f m, charging %s" % [p.pos.distance_to(x0), b.charging()]
	)
	p.stun_t = 0.5
	ak.step(m, 0.05)
	ok(
		"ult: a stun in the charge stops it, back in 8s",
		not b.running() and b.waves == 0 and float(k.cd["x"]) <= 8.0 and b.stopped == 1, "cd %.1f" % float(k.cd["x"])
	)
	p.stun_t = 0.0
	ak.step(m, 0.6)
	var waves0 := b.waves
	_cast(p, t.pos)
	ak.step(m, 0.3)
	p.dashes = p.max_dashes()
	p.do_dash()
	ak.step(m, 2.2)
	ok("ult: barged out of in the charge, both waves still go", not b.running() and b.waves == waves0 + 2,
			"waves +%d" % (b.waves - waves0))
	ak.step(m, 0.6)
	waves0 = b.waves
	_cast(p, t.pos)
	ak.step(m, 0.4)
	ok("merge hold: the Broadside is charging before the merge", b.charging())
	ok("merge hold: a merge is under way", ak.merge_now(p))
	ak.step(m, 1.8)
	ok(
		"merge hold: dredge's Broadside is dropped, no wave mid-merge", not b.running() and b.waves == waves0,
		"waves %d" % (b.waves - waves0)
	)
	KinMerge.end(p, "test")
	await ak.done(m)

func _burst() -> void:
	var res: Dictionary = await BURST.run(ak, "dredge", 1.6, func(m: Match, p: Hunter, t: Hunter):
		t.face = FACE_AWAY
		_cast(p, t.pos)
		ak.step(m, 2.2))
	var info := "ult %.0f, ult + merge %.0f of %d" % [res["ult"], res["total"], int(Data.CLASSES["light"]["hp"])]
	ok(
		"burst: Brass Broadside then the merge never one-shots a full-health light hunter",
		bool(res["merged"]) and bool(res["alive"]), info
	)
