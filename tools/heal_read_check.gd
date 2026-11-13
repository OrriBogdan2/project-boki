extends RefCounted
## --heal-read-check: every heal reads one way, through Fx.healed (docs/DASHES_AND_ABILITY_FEEL.md 5.1): a soft
## green-gold glow (Feel's sustain colour) riding on the healed Hunter and a green "+N" (HudStyle.HEAL) of the
## heal kind, never added into a damage number. Runs the real sources on support_check's flat strip: Meeko's
## Hearthlight (a pulse, the flare) and Hearth Call, Albert's Mending Ground (a tick, the burst), Kael's Gilded
## Riposte and a Void weapon's lifesteal; then the number rules. Never touches the save. With --shots-dir=<dir>
## every step is drawn and each source leaves a strip heal_read_<source>.png (needs a GPU: jobq).

const DT := 1.0 / 60.0
const STRIP_AT := [0.0, 0.15, 0.3, 0.45]   # s after the first heal: the strip's frames
const CROP := Vector2i(260, 300)           # px round the healed Hunter, scaled 1.5x
const DAZE_PINK := Color("ff6fae")         # stands in for the Gunslinger's Daze "+N" (a damage number)
const HEAL_JUMP := 0.5                     # hp in one step: a heal landed

var main: Node
var sc                                     # tools/support_check.gd, for its flat-strip match
var bad := 0
var n := 0
var parts := 0                             # sections that ran to their end (a script error stops one short)
var dir := ""

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("HEALREAD %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
	sc = load("res://tools/support_check.gd").new()
	sc.main = main
	await _meeko()
	await _albert()
	await _kael()
	await _lifesteal_and_rules()
	ok(parts == 4, "every section ran to its end", "%d of 4" % parts)
	print("HEALREAD %s, %d checks" % ["PASS" if bad == 0 else "FAIL (%d)" % bad, n])
	main.get_tree().quit(1 if bad > 0 else 0)

func _match(arch: String, dist := 6.0) -> Array:
	var r: Array = sc.setup(arch, dist)
	if dir != "":
		(r[0] as Match).hud.visible = false     # the read itself, without the hover card over the Hunter
		if main.get("fade") != null:
			await main.get("fade").reveal(0.01)
	return r

func _meeko() -> void:
	var r: Array = await _match("tender")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: TenderKit = P.ak
	A.hp = A.max_hp * 0.4
	_clear(m.fx)
	P.inp["sig"] = true
	await _step(m, A)
	P.inp["sig"] = false
	ok(await _until_healed(m, A, 2.0), "Meeko Hearthlight: a pulse heals the teammate")
	_reads(m, A, "Meeko Hearthlight pulse")
	await _strip(m, A, "meeko_hearthlight")
	A.hp = A.max_hp * 0.4
	_clear(m.fx)
	K._e_end()
	_reads(m, A, "Meeko Hearthlight flare")
	await _strip(m, A, "meeko_flare")
	A.hp = A.max_hp * 0.4
	K.cd["x"] = 0.0
	sc.aim_at(P, A.pos)
	await _step(m, A)
	_clear(m.fx)
	HunterKeys.ult_pressed(P)
	ok(await _until_healed(m, A, 2.0) and not K.hearth_call.is_empty(), "Meeko Hearth Call: the tether heals")
	_reads(m, A, "Meeko Hearth Call tick")
	await _strip(m, A, "meeko_hearth_call")
	parts += 1
	await _free(m)

func _albert() -> void:
	var r: Array = await _match("bulwark")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: BulwarkKit = P.ak
	A.teleport(P.pos + Vector3(-1.0, 0, 0.6))
	A.hp = A.max_hp * 0.4
	P.inp["aim"] = P.pos
	_clear(m.fx)
	K.use_e()
	ok(await _until_healed(m, A, 2.0) and not K.mend.is_empty(), "Albert Mending Ground: a tick heals the teammate")
	_reads(m, A, "Albert Mending Ground tick")
	await _strip(m, A, "albert_mend_tick")
	var t := 0.0
	while not K.mend.is_empty() and t < 6.0:
		A.hp = A.max_hp * 0.4
		_clear(m.fx)
		await _step(m, A)
		t += DT
	ok(K.mend.is_empty(), "Albert Mending Ground: the zone ends in its burst")
	_reads(m, A, "Albert Mending Ground burst")
	await _strip(m, A, "albert_mend_burst")
	parts += 1
	await _free(m)

func _kael() -> void:
	var r: Array = await _match("juggernaut", 2.5)
	var m: Match = r[0]
	var P: Hunter = r[1]
	P.hp = P.max_hp * 0.5
	_clear(m.fx)
	HunterKeys.ult_pressed(P)
	ok(await _until_healed(m, P, 2.5), "Kael Gilded Riposte: the cleave heals him")
	_reads(m, P, "Kael Gilded Riposte")
	await _strip(m, P, "kael_riposte")
	parts += 1
	await _free(m)

func _lifesteal_and_rules() -> void:
	var r: Array = await _match("archer")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var fx: Fx = m.fx
	# a Void weapon drains what it deals; a light hit's sliver waits hidden until the heals add up
	P.welem = "void"
	P.hp = P.max_hp * 0.5
	T.inv_t = 0.0
	_clear(fx)
	var drained := _void_hit(P, T, 3.0)
	var sliver := _heal_num(fx, P)
	ok(drained > 0.0 and drained < Fx.NUM_MIN and not sliver.is_empty() and not (sliver["node"] as Label3D).visible,
		"lifesteal: a light hit's sliver waits hidden", "%.2f HP" % drained)
	for i in 3:
		drained += _void_hit(P, T, 3.0)
	var num := _heal_num(fx, P)
	ok(is_same(num, sliver) and absf(float(num["val"]) - drained) < 0.01, "lifesteal: the slivers add up on one number",
		"%.2f of %.2f HP" % [float(num.get("val", 0.0)), drained])
	_reads(m, P, "Void weapon lifesteal")
	for i in 10:
		_void_hit(P, T, 3.0)
		await _step(m, P)
	await _strip(m, P, "void_lifesteal")
	P.welem = ""
	# a heal never joins a damage number on the same spot: not a hit, not a Daze "+N"
	_clear(fx)
	var at := A.pos + Vector3(0, Fx.HEAL_NUM_Y, 0)
	fx.number(at, 20.0, HudStyle.HIT, false)
	fx.number(at, 9.0, DAZE_PINK, true, "+")
	fx.number(at, 12.0, HudStyle.HEAL, false, "+", "", Fx.Num.HEAL)
	var hit := _num_at(fx, at, Fx.Num.HIT, "")
	var daze := _num_at(fx, at, Fx.Num.HIT, "+")
	var heal := _num_at(fx, at, Fx.Num.HEAL, "+")
	ok(fx.nums.size() == 3 and float(hit.get("val", 0)) == 20.0 and float(daze.get("val", 0)) == 9.0
		and float(heal.get("val", 0)) == 12.0, "a heal, a hit and a Daze +N on one spot stay three numbers")
	ok(_rgb((daze["node"] as Label3D).modulate) == _rgb(DAZE_PINK)
		and _rgb((heal["node"] as Label3D).modulate) == _rgb(HudStyle.HEAL), "each keeps its own colour")
	# damage numbers off: the hit hides, the heal still shows
	var was = Settings.get_v("damage_numbers")
	Settings.set_v("damage_numbers", false, false)
	_clear(fx)
	fx.number(T.pos + Vector3(0, 1.5, 0), 20.0, HudStyle.HIT, false)
	fx.healed(A, 10.0)
	ok(_num_at(fx, T.pos + Vector3(0, 1.5, 0), Fx.Num.HIT, "").is_empty() and not _heal_num(fx, A).is_empty(),
		"damage numbers off: hits show no number, heals still do")
	Settings.set_v("damage_numbers", was, false)
	# one glow per body while it is up; it moves with them; a new one after it fades
	_clear(fx)
	fx.healed(A, 5.0)
	fx.healed(A, 5.0)
	ok(_glows(fx, A) == 1 and float(_heal_num(fx, A).get("val", 0)) == 10.0,
		"two quick heals: one glow, one +10")
	A.teleport(A.pos + Vector3(3.0, 0, 0))
	var g: Node3D = _glow(fx, A).get("node")
	ok(g != null and absf(g.global_position.x - A.global_position.x) < 0.05, "the glow rides on the healed Hunter")
	for i in int(ceil((Fx.GLOW_DUR + 0.05) / DT)):
		fx._process(DT)
	fx.healed(A, 5.0)
	ok(_glows(fx, A) == 1 and _glow(fx, A).get("node") != g, "after it fades, the next heal pulses again")
	# nothing on a Hunter you can't see; nothing at full health
	_clear(fx)
	A.unseen = true
	fx.healed(A, 20.0)
	ok(fx.nums.is_empty() and fx.ghosts.is_empty(), "a Hunter you can't see shows no heal")
	A.unseen = false
	A.hp = A.max_hp
	A.heal(20.0)
	ok(fx.nums.is_empty() and fx.ghosts.is_empty(), "a heal at full health shows nothing")
	# a remote Hunter heals on its own game; this screen shows the heal now
	A.remote = true
	A.hp = A.max_hp - 30.0
	A.heal(20.0)
	ok(A.hp == A.max_hp - 30.0 and float(_heal_num(fx, A).get("val", 0)) == 20.0 and _glows(fx, A) == 1,
		"a remote teammate's heal shows on the healer's screen")
	A.remote = false
	parts += 1
	await _free(m)

## One hit from P's Void weapon on T; returns what it drained back into P.
func _void_hit(P: Hunter, T: Hunter, dmg: float) -> float:
	var ex := {}
	Loot.rider(P, ex, dmg)
	var hp0 := P.hp
	T.hurt(dmg, P, ex)
	return P.hp - hp0

## The heal read on `h`: a green "+N" of the heal kind over them and the soft green-gold glow riding on them.
func _reads(m: Match, h: Hunter, what: String) -> void:
	var num := _heal_num(m.fx, h)
	var l: Label3D = num.get("node")
	var green := l != null and l.visible and l.text.begins_with("+") and _rgb(l.modulate) == _rgb(HudStyle.HEAL)
	ok(green, what + ": a green +N heal number", l.text if l != null else "none")
	var glow := _glow(m.fx, h)
	var on_body := not glow.is_empty() and (glow["node"] as Node).get_parent() == h
	ok(on_body and glow["col"] == Feel.cat_color("sustain"), what + ": the green-gold glow on the healed Hunter")
	var motes := false
	for p in m.fx.bursts:
		var off: float = p.global_position.distance_to(h.global_position)
		motes = motes or (p.emitting and p.color == Feel.cat_color("sustain") and off < 0.6 and p.gravity.y > 0.0)
	ok(motes, what + ": green-gold motes rise off them")
	var green_hits := 0
	for e in m.fx.nums:
		var hit: bool = e.has("val") and int(e["kind"]) == Fx.Num.HIT
		if hit and _rgb((e["node"] as Label3D).modulate) == _rgb(HudStyle.HEAL):
			green_hits += 1
	ok(green_hits == 0, what + ": no damage number in the heal colour")

func _heal_num(fx: Fx, h: Hunter) -> Dictionary:
	for e in fx.nums:
		if e.has("val") and int(e["kind"]) == Fx.Num.HEAL and (e["base"] as Vector3).distance_to(h.pos) < 3.0:
			return e
	return {}

func _num_at(fx: Fx, at: Vector3, kind: int, prefix: String) -> Dictionary:
	for e in fx.nums:
		if e.has("val") and int(e["kind"]) == kind and String(e["pre"]) == prefix and e["base"] == at:
			return e
	return {}

func _glow(fx: Fx, h: Hunter) -> Dictionary:
	for g in fx.ghosts:
		if int(g.get("on", 0)) == h.get_instance_id():
			return g
	return {}

func _glows(fx: Fx, h: Hunter) -> int:
	var c := 0
	for g in fx.ghosts:
		if int(g.get("on", 0)) == h.get_instance_id():
			c += 1
	return c

func _rgb(c: Color) -> Color:
	return Color(c, 1.0)

## Drops every number, glow and burst, so the next source's read is its own.
func _clear(fx: Fx) -> void:
	for p in fx.bursts:
		p.emitting = false
	for e in fx.nums:
		(e["node"] as Label3D).visible = false
	fx.nums.clear()
	for g in fx.ghosts:
		if is_instance_valid(g["node"]):
			(g["node"] as Node).queue_free()
	fx.ghosts.clear()

## One match step; Fx ages as it would in a frame. In shots mode the frame is drawn round `focus`.
func _step(m: Match, focus: Hunter) -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.step(DT)
	if dir == "":
		m.fx._process(DT)
		return
	m.cam.snap(focus.pos)
	for x in m.hunters:
		x.render(DT, 1.0)
	await main.get_tree().process_frame

## Steps until one step heals `h` by HEAL_JUMP or more (a heal, not a regen trickle), at most `secs`.
func _until_healed(m: Match, h: Hunter, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		var hp0 := h.hp
		await _step(m, h)
		t += DT
		if h.hp >= hp0 + HEAL_JUMP:
			return true
	return false

## In shots mode: the frames at STRIP_AT from now, cropped round `h`, side by side in heal_read_<file>.png.
## One step is drawn first: a heal called outside a step (the flare) has no frame of its own yet.
func _strip(m: Match, h: Hunter, file: String) -> void:
	if dir == "":
		return
	await _step(m, h)
	var shots: Array[Image] = []
	var t := 0.0
	for at in STRIP_AT:
		while t < float(at) - 0.001:
			await _step(m, h)
			t += DT
		var img := main.get_viewport().get_texture().get_image()
		var c := main.get_viewport().get_camera_3d().unproject_position(h.position + Vector3(0, 1.2, 0))
		var rg := Rect2i(Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2), CROP)
		var crop := img.get_region(rg.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(int(CROP.x * 1.5), int(CROP.y * 1.5), Image.INTERPOLATE_BILINEAR)
		shots.append(crop)
	var w := shots[0].get_width()
	var wide := w * shots.size() + 4 * (shots.size() - 1)
	var out := Image.create(wide, shots[0].get_height(), false, shots[0].get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, shots[i].get_size()), Vector2i(i * (w + 4), 0))
	out.save_png(dir.path_join("heal_read_%s.png" % file))
	print("HEALREAD strip %s" % file)

func _free(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame
