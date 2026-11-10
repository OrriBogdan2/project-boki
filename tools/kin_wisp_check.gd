extends RefCounted
## --kin-wisp-check: Boki are wisps (docs/decisions/0022). Prints WISP PASS/FAIL lines.
##   1. the orbit: on you, your Boki is a small wisp circling you at orbit_r, its body hidden
##   2. the summon: a throw bursts the wisp into the full Boki (form_t eases 0 -> 1, the body scales up, the wisp goes)
##   3. knocked out: a dim wisp on you that a throw (C), its ability (E) or a Merge (R) cannot summon until it recovers
##   4. capacity on scan: a full box (box_capacity) asks to swap or leave it; a scan never pushes the box past it
## --kin-wisp-shots --shots-dir=<dir> (xvfb with a renderer): wisp_orbit_a.png, wisp_orbit_b.png, wisp_summon.png.

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("WISP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

const OPTS := {
	"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true,
	"weapon": "rifle", "cls": "medium", "demo_kin": "cindle",
}

func _fresh() -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(OPTS)
	m.set_process(false)
	_tidy()
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(38.0, 0, 18.0))
	_on_you(m.player.kin)
	run_for(0.5)

func _tidy() -> void:
	for mb in m.mobs.duplicate():
		m.mobs.erase(mb)
		mb.queue_free()

func _on_you(k: Kin) -> void:
	k.state = "wisp"
	k.fly = {}
	k.settle = 1.0
	k.cmd = "return"
	k.ride = false
	k.throw_cd = 0.0
	k.form_t = 0.0

## Steps the match and draws the Boki each step (the headless check has no _process).
func run_for(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		_tidy()
		m.step(Match.DT)
		t += Match.DT
		var k: Kin = m.player.kin
		if k: k.render(Match.DT, 1.0)

# ------------------------------------------------------------------ 1. the orbit
func _orbit() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var R := KinWisp.rules()
	var rad := float(R["orbit_r"])
	var no_body := k.model == null or not k.model.visible
	ok(KinWisp.is_wisp(k) and k.form_t <= 0.0 and no_body, "on you it is a wisp: no body")
	var orb: Node3D = k.get_node_or_null(KinWisp.NODE)
	ok(orb != null and orb.visible, "...a glowing wisp is drawn")
	var angles: Array = []
	var near := true
	for i in 8:
		run_for(float(R["period_s"]) / 8.0)
		var d := Vector2(k.pos.x - P.pos.x, k.pos.z - P.pos.z)
		near = near and absf(d.length() - rad) < 0.05 and k.pos.y > P.pos.y + 0.5
		angles.append(d.angle())
	var turned := 0.0
	for i in range(1, angles.size()):
		turned += absf(angle_difference(float(angles[i - 1]), float(angles[i])))
	ok(near, "it circles at orbit_r (%.2fm, data) above the ground" % rad)
	ok(turned > PI, "...and goes round you over period_s (%.0f deg in one period)" % rad_to_deg(turned))
	P.teleport(P.pos + Vector3(3.0, 0, 0))
	run_for(0.2)
	ok(absf(k.flat_dist(P) - rad) < 0.1, "it follows you when you move (%.2fm)" % k.flat_dist(P))
	ok(P.kin_carry_on(), "carry passives still apply while it is a wisp on you (docs/decisions/0002)")

# ------------------------------------------------------------------ 2. the summon
func _summon() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	ok(k.model != null and not k.model.visible, "setup: the body is hidden while a wisp")
	k.throw_to(P.pos + Vector3(4.0, 0, 0))
	ok(k.state != "wisp" and k.form_t <= 0.0, "a throw bursts the wisp (%s)" % k.state)
	run_for(Match.DT * 2.0)
	var early := k.model.scale.length() if k.model else 0.0
	var growing := k.model != null and k.model.visible and k.form_t > 0.0 and k.form_t < 1.0
	ok(growing, "...the body appears and scales up (form_t %.2f)" % k.form_t)
	run_for(1.5)
	var orb: Node3D = k.get_node_or_null(KinWisp.NODE)
	var full := k.form_t >= 1.0 and k.model.visible and k.model.scale.length() > early * 1.5
	full = full and (orb == null or not orb.visible)
	ok(full, "...the full Boki, no wisp (scale %.2f -> %.2f)" % [early, k.model.scale.length()])
	ok(k.state == "active" and k.summoned, "it is out beside you")
	k.recall()
	run_for(1.5)
	var back := k.state == "wisp" and k.form_t <= 0.0 and not k.model.visible
	ok(back, "a recall shrinks it back into a wisp (%s, form_t %.2f)" % [k.state, k.form_t])

# ------------------------------------------------------------------ 3. knocked out
func _downed() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var fight := func(): P.hurt_at = m.time
	k.throw_to(P.pos + Vector3(4.0, 0, 0))
	run_for(1.0, fight)
	k.go_down()
	run_for(1.0, fight)
	var on_you := k.flat_dist(P) < float(KinWisp.rules()["orbit_r"]) + 0.3
	ok(k.state == "downed" and KinWisp.is_wisp(k) and on_you, "knocked out, it falls back to you as a dim wisp")
	KinCommand.tap(P)
	k.throw_to(P.pos + Vector3(4.0, 0, 0))
	run_for(0.3, fight)
	ok(k.state == "downed", "a throw (C) cannot summon it")
	P.use_kin_ability("k1")
	run_for(0.3, fight)
	ok(k.state == "downed" and k.pend_slot == "", "...nor its ability (E)")
	P.ult = 1.0
	ok(not KinMerge.press(P) and not KinMerge.active(P), "...nor a Merge (R)")
	ok(KinDowned.deny_text(k).contains("dim wisp"), "the deny line says why (\"%s\")" % KinDowned.deny_text(k))
	k.down_t = 0.3
	run_for(0.6, fight)
	ok(k.state == "wisp" and k.ready_to_fight(), "once it recovers it is a wisp on you again (%s)" % k.state)
	k.settle = 1.0
	k.throw_cd = 0.0
	k.throw_to(P.pos + Vector3(4.0, 0, 0))
	ok(k.state != "wisp" and k.state != "downed", "...and a throw summons it (%s)" % k.state)

# ------------------------------------------------------------------ 4. capacity on scan
func _capacity() -> void:
	_fresh()
	var P := m.player
	var cap := Capture.box_cap()
	ok(cap == int(Content.rules("capture")["box_capacity"]), "capacity from content/rules/capture.json (%d)" % cap)
	for i in cap:
		P.caught.append(Save.new_kin("puddlet", "Held%d" % i, 30 + i))
	var rec := Save.new_kin("cindle", "", 91)
	rec["level"] = 3
	var at: Vector3 = P.pos + Vector3(2.0, 0, 0)
	var w := m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)
	run_for(0.2)
	ok(w.state == "dazed" and KinWisp.is_wisp(w), "a beaten wild Boki is a wisp on the ground")
	ok(Capture.must_swap(P, w), "a full box: you must swap or leave it (\"%s\")" % Capture.swap_text(P))
	P.inp["interact"] = true
	run_for(float(Capture.rules()["hold_s"]) + 0.15)
	P.inp["interact"] = false
	run_for(float(Capture.rules()["scan_s"]) + 0.3)
	ok(not w.dead and P.caught.size() == cap, "a normal hold: not past capacity (%d/%d)" % [P.caught.size(), cap])
	P.inp["interact"] = true
	run_for(Capture.hold_need(true) + 0.15)
	P.inp["interact"] = false
	run_for(float(Capture.rules()["scan_s"]) + 0.3)
	var swapped := w.dead and P.caught.size() == cap and String(P.caught[cap - 1]["species"]) == "cindle"
	ok(swapped, "holding to swap takes it and frees the oldest (%d/%d)" % [P.caught.size(), cap])

func run(mn: Node, mode: String = "check") -> void:
	main = mn
	Save.no_write = true
	if mode == "shots":
		await _shots()
		return
	for part in ["orbit", "summon", "downed", "capacity"]:
		call("_" + part)
	print("WISP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ shots (xvfb with a renderer)
func _shots() -> void:
	var dir := "/tmp/wisp_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start(OPTS)
	if main.get("fade"):
		await main.fade.reveal(0.01)
	_tidy()
	var P := m.player
	var k: Kin = P.kin
	for h in m.hunters:
		if h.team != P.team:
			h.ctrl = "idle"
			h.teleport(P.pos + Vector3(38.0, 0, 18.0))
	_on_you(k)
	await _frames(90)
	await _shot(dir, "wisp_orbit_a", P.pos)
	await _frames(40)
	await _shot(dir, "wisp_orbit_b", P.pos)
	k.throw_to(P.pos + Vector3(2.5, 0, 0.5))
	await _frames(5)
	await _shot(dir, "wisp_summon", P.pos + Vector3(1.5, 0, 0))
	print("WISPSHOTS 3 in %s" % dir)
	main.get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		_tidy()
		await main.get_tree().process_frame

## The match view, plus a 2x close-up round `at`, side by side.
func _shot(dir: String, file: String, at: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var cam := main.get_viewport().get_camera_3d()
	var c := cam.unproject_position(at + Vector3(0, 0.8, 0))
	var px := Vector2i(320, 240)
	var corner := Vector2i(int(c.x) - px.x / 2, int(c.y) - px.y / 2)
	var rg := Rect2i(corner, px).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(rg.size.x * 2, rg.size.y * 2, Image.INTERPOLATE_BILINEAR)
	img.save_png(dir.path_join(file + ".png"))
	crop.save_png(dir.path_join(file + "_close.png"))
