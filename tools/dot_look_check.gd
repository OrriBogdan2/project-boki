extends RefCounted
## --dot-look-check: damage over time reads on the body (DotLook). A burning Hunter, Boki and monster get
## a low tint in the burn colour that flickers, pulses on each damage tick and goes when the burn ends;
## a hit's white flash wins over it; on Low quality it is a steady tint. Every DoT source (Ignite, poison
## parts, item burns, Blight embers) lands as Ent.burn_t, so one status on the body stands for all.
## With --shots-dir=<dir> (xvfb with a renderer) it writes dot_strip.png: a burning Hunter above a burning
## Boki across one damage tick. Never touches the save.

const DT := 1.0 / 60.0
const STRIP_FRAMES := 6
const STRIP_GAP_S := 0.07       # s between strip frames
const CELL := 300               # px: one strip cell
const TICK_RATE := 4.0          # burn ticks a second (Ent.tick_status)

var bad := 0
var _dir := ""

func ok(cond: bool, what: String) -> void:
	print("DOTLOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): _dir = String(a).substr(12)
	if _dir != "": DirAccess.make_dir_recursive_absolute(_dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "arch": "ashwick",
		"cls": Arch.weight("ashwick"), "weapon": Arch.signature("ashwick")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	var rival: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			rival = o
	rival.teleport(P.pos + Vector3(0, 0, 40.0))
	P.face = PI
	P.max_hp = 100000.0
	P.hp = P.max_hp
	var k := _boki(m, P)
	k.max_hp = 100000.0
	k.hp = k.max_hp
	await _settle(main, m, P, [P, k], 0.3)
	ok(DotLook.amount(P, false) == 0.0 and DotLook.amount(k, false) == 0.0, "nothing burning: no tint")
	_light(P, k)
	await _settle(main, m, P, [P, k], 0.3)
	_tint(P, "Hunter")
	_tint(k, "Boki")
	_ticks(m, P)
	await _hit_wins(main, m, P)
	await _low_quality(main, m, P)
	await _strip(main, m, P, k)
	P.burn_t = 0.0
	k.burn_t = 0.0
	await _settle(main, m, P, [P, k], 0.2)
	ok(_flash(P) == 0.0 and _flash(k) == 0.0, "burn over: the tint is gone from both bodies")
	ok(_color(P) == Color.WHITE, "burn over: the flash colour is back to white")
	print("DOTLOOK done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Ignite-style fire (Ashwick's lance), a poison part and a merge item burn: all three end as one burn status.
func _light(P: Hunter, k: Kin) -> void:
	P.burn_t = 0.0
	k.burn_t = 0.0
	P.hurt(0.01, k, {"src": "flame", "burn": 8.0, "burn_for": 60.0})
	k.hurt(0.01, P, {"src": "abil", "burn": 8.0, "burn_for": 60.0})
	ok(P.burn_t > 50.0 and k.burn_t > 50.0, "fire and poison hits both set the burn status")

func _tint(e: Ent, who: String) -> void:
	var lo := 1.0
	var hi := 0.0
	for i in 40:
		e.m.time += 0.05
		var a := DotLook.amount(e, false)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	ok(lo >= DotLook.BASE - 0.001, "%s: the tint never drops under the base %.2f (min %.2f)" % [who, DotLook.BASE, lo])
	var cap := DotLook.BASE + DotLook.FLICKER + DotLook.PULSE + 0.001
	ok(hi <= cap, "%s: the tint stays subtle (max %.2f)" % [who, hi])
	ok(hi - lo >= 0.02, "%s: it flickers (%.2f to %.2f)" % [who, lo, hi])
	e.show_flash(0.0)
	var shown := _flash(e) > 0.0 and _color(e).is_equal_approx(DotLook.COL)
	ok(shown, "%s: the body shows the burn colour (flash %.2f)" % [who, _flash(e)])

## The pulse stamp follows the damage tick (4 a second) and the tint peaks on it.
func _ticks(m: Match, P: Hunter) -> void:
	var last := P.dot_tick_at
	var n := 0
	for i in int(2.0 / DT):
		m.step(DT)
		if P.dot_tick_at != last:
			last = P.dot_tick_at
			n += 1
			var peak := DotLook.BASE + DotLook.PULSE * 0.9
			ok(DotLook.amount(P, false) >= peak, "tick %d: the body pulses on the damage tick" % n)
	ok(absi(n - int(2.0 * TICK_RATE)) <= 1, "2 s of burn: %d pulses for %d damage ticks" % [n, int(2.0 * TICK_RATE)])
	m.time = P.dot_tick_at + DotLook.PULSE_S
	var calm := DotLook.BASE + DotLook.FLICKER + 0.001
	ok(DotLook.amount(P, false) <= calm, "the pulse has faded %.1f s after the tick" % DotLook.PULSE_S)

func _hit_wins(main: Node, m: Match, P: Hunter) -> void:
	P.flash_t = 0.12
	await _settle(main, m, P, [P], DT)
	ok(_flash(P) >= 0.5 and _color(P) == Color.WHITE, "a hit's white flash wins over the burn tint")
	P.flash_t = 0.0

func _low_quality(main: Node, m: Match, P: Hunter) -> void:
	var was: Variant = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "low"
	var seen := {}
	for i in 30:
		m.time += 0.07
		seen[DotLook.amount(P, Settings.quality() == "low")] = true
	ok(seen.size() == 1 and seen.has(DotLook.BASE), "Low quality: a steady tint, no flicker or pulse")
	await _settle(main, m, P, [P], DT)
	ok(absf(_flash(P) - DotLook.BASE) < 0.001, "Low quality: the body wears the base tint")
	Settings.v["quality"] = was

func _flash(e: Ent) -> float:
	return float((e.mats[0] as ShaderMaterial).get_shader_parameter("flash"))

func _color(e: Ent) -> Color:
	return (e.mats[0] as ShaderMaterial).get_shader_parameter("flash_color")

func _settle(main: Node, m: Match, P: Hunter, bodies: Array, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for b in bodies: (b as Ent).render(DT, 1.0)
		m.cam.snap(P.pos)
		await main.get_tree().process_frame
		t += DT

func _boki(m: Match, P: Hunter) -> Kin:
	var rec := Save.new_kin("puddlet")
	rec["trust"] = 95.0
	var k := m.give_kin(P, rec)
	k.brain.think_t = 1e9
	k.runner.reset()
	k.teleport(P.pos + Vector3(4.5, 0, 0.2))
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true
	return k

## One damage tick, in six frames: the Hunter on the top row, the Boki below.
func _strip(main: Node, m: Match, P: Hunter, k: Kin) -> void:
	if _dir == "":
		return
	var strip := Image.create(CELL * STRIP_FRAMES, CELL * 2, false, Image.FORMAT_RGBA8)
	while P.dot_tick_at != m.time and absf(m.time - P.dot_tick_at) > DT * 0.5:
		await _settle(main, m, P, [P, k], DT)
		if m.time - P.dot_tick_at > 1.0: break
	for f in STRIP_FRAMES:
		await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)      # (the renderer's format varies; blit needs the strip's)
		var row := 0
		for e in [P, k]:
			var vp := main.get_viewport()
			var c := vp.get_camera_3d().unproject_position((e as Ent).position + Vector3(0, 0.9, 0))
			c *= Vector2(img.get_size()) / vp.get_visible_rect().size
			var box := Rect2i(Vector2i(c) - Vector2i(CELL / 2, CELL / 2), Vector2i(CELL, CELL))
			var rg := box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			strip.blit_rect(img, rg, Vector2i(f * CELL, row * CELL) + (rg.position - box.position))
			row += 1
		await _settle(main, m, P, [P, k], STRIP_GAP_S)
	strip.save_png(_dir.path_join("dot_strip.png"))
