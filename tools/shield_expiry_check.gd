extends RefCounted
## --shield-expiry-check: the shield shell (ShieldLook) shows the real shield. A Tenzo punch shield (Molten Guard) is
## hurt for part of its amount: the shell value follows the share left (within 10%); then it runs out: the shell
## pulses once, starting PULSE_S before the end, and nothing of it stays after the shield is gone. Another source
## (Effects "shield") reads the same. With --shots-dir=<dir> (under xvfb with a renderer) it writes a strip of the
## Hunter from the full shield to the gone one. Never touches the save.

const DT := 1.0 / 60.0
const PULSE_SEEN := 0.03       # the shell this far above the share left counts as pulsing
const PULSE_LATE := 0.08       # s: how late into the window the pulse may first show
const FOLLOW_TOL := 0.1       # the shell value may be this far from the share of the shield left

var bad := 0
var _dir := ""
var _base := {}      # the body's materials and their own ink, before any shield

func ok(cond: bool, what: String) -> void:
	print("SHIELDEXPIRY %s %s" % ["ok  " if cond else "FAIL", what])
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
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "arch": "dolm",
		"cls": Arch.weight("dolm"), "weapon": Arch.signature("dolm")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	P.unlock_all()
	var rival: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			rival = o
	rival.teleport(P.pos + Vector3(0, 0, 80.0))      # out of reach: nothing but the check hurts the shield
	P.inp["aim"] = rival.pos + Vector3(0, 0.9, 0)
	P.face = PI
	await _settle(main, m, P, 0.3)
	for mt in P.mats:
		_base[mt] = (mt as Material).next_pass
	await _punch_shield(main, m, P, rival)
	await _effects_shield(main, m, P)
	print("SHIELDEXPIRY done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A punch's shield, damaged to half, then run out.
func _punch_shield(main: Node, m: Match, P: Hunter, rival: Hunter) -> void:
	(P.ak as DolmKit).guard_stack()
	await _settle(main, m, P, 0.2)
	var full := P.shield
	ok(ShieldLook.shown(P) and absf(ShieldLook.shell_of(P) - 1.0) <= FOLLOW_TOL, "punch shield: a fresh shell is full")
	await _shot(main, m, P, "1_full")
	P.hurt(full * 0.5, rival, {})
	await _settle(main, m, P, 0.1)
	var want := P.shield / full
	var shell := ShieldLook.shell_of(P)
	ok(absf(shell - want) <= FOLLOW_TOL, "punch shield: half left, the shell is %.2f (want %.2f)" % [shell, want])
	await _shot(main, m, P, "2_half")
	P.hurt(P.shield * 0.6, rival, {})
	await _settle(main, m, P, 0.1)
	want = P.shield / full
	shell = ShieldLook.shell_of(P)
	ok(absf(shell - want) <= FOLLOW_TOL, "punch shield: %.0f%% left, the shell is %.2f" % [want * 100.0, shell])
	await _shot(main, m, P, "3_thin")
	await _expire(main, m, P, "punch shield")
	_gone(P, "punch shield")

## Runs the shield's time out, watching the shell value each step: it pulses once, from PULSE_S before the end.
func _expire(main: Node, m: Match, P: Hunter, what: String) -> void:
	var peak: float = P.get_meta("shield_peak")
	P.shield_t = 1.0
	var pulses := 0
	var in_pulse := false
	var first_left := -1.0
	var shot := false
	while P.shield_t > 0.0 and P.shield > 0.0:
		await _settle(main, m, P, DT)
		var hot := ShieldLook.shell_of(P) - P.shield / peak > PULSE_SEEN
		if hot and not in_pulse:
			pulses += 1
			first_left = P.shield_t
		in_pulse = hot
		if not shot and P.shield_t > 0.0 and P.shield_t < ShieldLook.PULSE_S * 0.5:
			shot = true
			await _shot(main, m, P, "4_pulse")
	ok(pulses == 1, "%s: the shell pulsed %d time(s) (want 1)" % [what, pulses])
	var early := first_left - ShieldLook.PULSE_S
	ok(early <= DT * 2.0 and early >= -PULSE_LATE, "%s: pulse began %.2f s before the end" % [what, first_left])
	await _settle(main, m, P, 0.2)

func _gone(P: Hunter, what: String) -> void:
	var changed := 0
	for mt in _base:
		if (mt as Material).next_pass != _base[mt]:
			changed += 1
	ok(not ShieldLook.shown(P) and changed == 0, "%s: gone, the body's own ink is back (%d changed)" % [what, changed])

## Another source (the shared Effects shield) reads the same.
func _effects_shield(main: Node, m: Match, P: Hunter) -> void:
	P.shield = 0.0
	P.shield_t = 0.0
	Effects.run([{"type": "shield", "amount": 40.0, "time": 2.0}], P, {})
	await _settle(main, m, P, 0.2)
	ok(ShieldLook.shown(P) and ShieldLook.shell_of(P) > 0.9, "Effects shield: the shell is up and full")
	await _expire(main, m, P, "Effects shield")
	_gone(P, "Effects shield")

func _settle(main: Node, m: Match, P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		if m.verbs: m.verbs.render(1.0)
		m.cam.snap(P.pos)
		await main.get_tree().process_frame
		t += DT

func _shot(main: Node, m: Match, P: Hunter, label: String) -> void:
	if _dir == "":
		return
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(P.position + Vector3(0, 1.0, 0))
	c *= Vector2(img.get_size()) / vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(240, 240), Vector2i(480, 480))
	var rg := box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rg).save_png(_dir.path_join("expiry_%s.png" % label))
