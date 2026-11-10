extends RefCounted
## --cooldown-text-check: the seconds left on a cooling slot of the bottom bar (HudSlot.cd_text) and the
## charge count, read from what the real match HUD drew: a 7.5 s cooldown shows 8, then 0.4 near the end;
## the dash slot shows its seconds and one pip per charge; the Boki's G slot counts its wait down.
## With --shots-dir=<dir> (a GPU run) it also saves the bar as cooldown_text_bar.png. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("COOLDOWNTEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The bar draws on HudPanels, REDRAW_HZ times a second: wait for its next draw.
func _drawn(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
		"demo_kin": "cindle", "arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	P.ctrl = "local"
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(40, 0, 40))
	P.unlock_all()
	var hud = m.hud
	var want := {7.5: "8", 7.01: "8", 1.0: "1", 0.99: "1.0", 0.4: "0.4"}
	for secs in want:
		var got := HudSlot.cd_text(secs)
		ok(got == want[secs], "%.2f s reads '%s' (got '%s')" % [secs, want[secs], got])
	for secs in [7.5, 0.4]:
		P.ak.cd["e"] = secs
		await _drawn(hud)
		var shown := String(hud.slot_text.get("k1", ""))
		ok(shown == want[secs], "E with %.1f s left draws '%s' (drew '%s')" % [secs, want[secs], shown])
	P.ak.cd["e"] = 0.0
	await _dash(P, hud)
	await _throw(P, hud)
	await _shot(P, hud)
	print("COOLDOWN TEXT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The dash slot: a pip per charge, and its recharge seconds while it is empty.
func _dash(P: Hunter, hud) -> void:
	P.dashes = 0.5
	await _drawn(hud)
	var left := 0.5 * P.dash_regen()
	var sh: Dictionary = DashSlot.shown.get(hud.get_instance_id(), {})
	var pips: Array = sh.get("pips", [])
	ok(String(sh.get("text", "")) == HudSlot.cd_text(left) and pips.size() == int(P.max_dashes()),
		"dash empty, %.2f s to the next charge: '%s' and %d pips" % [left, sh.get("text", ""), pips.size()])
	P.dashes = P.max_dashes()
	await _drawn(hud)
	sh = DashSlot.shown.get(hud.get_instance_id(), {})
	pips = sh.get("pips", [])
	ok(String(sh.get("text", "")) == "" and pips.all(func(f): return float(f) >= 1.0),
		"dash full: no seconds, every pip full")

## The Boki's G slot: it counts its wait down in tenths and clears when it is over.
func _throw(P: Hunter, hud) -> void:
	var k: Kin = P.kin
	ok(k != null, "the player has a Boki")
	if k == null:
		return
	k.state = "shoulder"
	k.throw_cd = 0.4
	await _drawn(hud)
	var shown := String(hud.slot_text.get("throw", ""))
	ok(shown == "0.4", "G with 0.4 s left draws '0.4' (drew '%s')" % shown)
	k.throw_cd = 0.0
	await _drawn(hud)
	ok(not hud.slot_text.has("throw"), "G ready: no countdown")


## The bar with several slots cooling at once (E 7.5 s, X 12.3 s, the dash recharging, G 0.4 s), a 720p crop.
func _shot(P: Hunter, hud) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	P.ak.cd["e"] = 7.5
	P.ak.cd["x"] = 12.3
	P.dashes = 0.5
	P.kin.throw_cd = 0.4
	await _drawn(hud)
	for i in 4:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var bar := Rect2i(sz.x / 2 - 330, sz.y - 150, 660, 150).intersection(Rect2i(Vector2i.ZERO, sz))
	img.save_png(dir.path_join("cooldown_text_full.png"))
	var crop := img.get_region(bar)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join("cooldown_text_bar.png"))
	print("COOLDOWNTEXT shots in ", dir, " (", sz, ")")
