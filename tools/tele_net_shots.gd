extends "res://tools/remote_anim_check.gd"
## --tele-net-shots --shots-dir=<dir>: two games over the desktop relay (the --remote-anim-check harness).
## The guest (headless) casts a kit's ability; this game, a foe, screenshots the guest's hunter with the
## `all` telegraph that reached it through AimNet (Net event "tele"), tinted hostile. Run it with a renderer
## (GPU, jobq). Writes <dir>/tele_net_<arch>_<key>.png and MANIFEST.txt; lines TELESHOT ok|FAIL <what>.

## [arch, key, s held, the telegraph id, caption]
const SHOTS := [
	["archer", "e", 0.0, "e", "Lace's Hail Wall arc, cast on the other game"],
	["dolm", "rmb", 1.2, "rmb", "Tenzo's held slam circle, cast on the other game"],
	["dolm", "e", 0.0, "e_tell0", "Tenzo's three E tells, cast on the other game"],
	["bulwark", "e", 0.0, "e", "Albert's E zone, cast on the other game"],
]
const AIM := Vector3(6.0, 0, 0)  # m from the caster: where the guest aims
const VIEW := Vector3(0, 0, -6.0)  # m from home: where this game's own hunter stands, out of the way

var shots_dir := ""
var lines: Array = []


func _init() -> void:
	tag = "TELESHOT"
	guest_flag = "--tele-net-shots=guest"
	guest_bin = OS.get_executable_path()  # a GPU worker has no queue wrapper
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots_dir = a.substr(12)


func _host() -> void:
	var copy := await _host_up()
	if copy == null:
		return _finish()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	for s in SHOTS:
		await _shot(copy, String(s[0]), String(s[1]), float(s[2]), String(s[3]), String(s[4]))
	var f := FileAccess.open(shots_dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	_finish()


func _shot(copy: Hunter, arch: String, key: String, held: float, id: String, caption: String) -> void:
	m.player.teleport(home + VIEW)
	copy.reclass(Arch.weight(arch), arch)  # the copy's body, as the guest's kit wears it
	replies.clear()
	Net.lobby_emit("ra", {"c": "cast", "arch": arch, "key": key, "held": held})
	await _reply()
	var t := 0.0
	while not AimKit.shown(copy, id) and t < 4.0:
		await _frame(copy)
		t += DT
	for i in 12:
		await _frame(copy)
	var up := AimKit.shown(copy, id)
	ok(up, "%s %s: the guest's %s telegraph is up on this game" % [arch, key, id])
	var file := "tele_net_%s_%s.png" % [arch, key]
	var img := main.get_viewport().get_texture().get_image()
	ok(img != null, "%s %s: a frame to save (needs a renderer)" % [arch, key])
	if img != null:
		img.save_png(shots_dir.path_join(file))
	lines.append("tele_net|%s|%s (seen by a foe on another game)" % [file, caption])
	await _run(1.0)


## One step and one drawn frame, the camera on the guest's hunter.
func _frame(copy: Hunter) -> void:
	m.cam.snap(copy.pos + Vector3(3.0, 0, 0))
	for h in m.hunters:
		h.render(DT, 1.0)
	await _run(DT)


# ------------------------------------------------------------------ the guest
func _on_msg(topic: String, data, from: String) -> void:
	if topic == "ra" and typeof(data) == TYPE_DICTIONARY and String(data.get("c", "")) == "cast" and m and m.player:
		_cast_here(String(data["arch"]), String(data["key"]), float(data["held"]))
		return
	super._on_msg(topic, data, from)


## The guest's own hunter casts at home, aiming AIM away; held keys stay down `held` s (its main loop steps).
func _cast_here(arch: String, key: String, held: float) -> void:
	_kit(arch)
	_aim(m.player.pos + AIM)
	Net.lobby_emit("dn_r", {"pos": [0, 0, 0]})
	var me := m.player
	var inp: String = {"lmb": "fire", "rmb": "sec", "e": "sig", "r": "ult"}[key]
	me.inp[inp] = true
	if key == "rmb":
		me.inp["sec_hold"] = held > 0.0
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	if inp != "fire":
		me.inp[inp] = false
	await main.get_tree().create_timer(held).timeout
	for k in ["fire", "sec", "sec_hold", "sig", "ult"]:
		me.inp[k] = false
