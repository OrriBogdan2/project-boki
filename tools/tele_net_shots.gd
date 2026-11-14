extends "res://tools/remote_anim_check.gd"
## --tele-net-shots --shots-dir=<dir>: two games over the desktop relay (the --remote-anim-check harness).
## The guest (headless) casts the SHOTS abilities in a loop on its own; this game, a foe, waits for each
## `all` telegraph to reach the guest's hunter through AimNet (Net event "tele") and screenshots it, tinted
## hostile. Only match traffic carries it (no lobby commands). Run it with a renderer (GPU, jobq).
## Writes <dir>/tele_net_<arch>_<key>.png and MANIFEST.txt; lines TELESHOT ok|FAIL <what>.

## [arch, key, s held, the telegraph id, its shape kind, caption]
const SHOTS := [
	["archer", "e", 0.0, "e", "arc_wall", "Lace's Hail Wall arc, cast on the other game"],
	["dolm", "rmb", 1.2, "rmb", "circle", "Tenzo's held slam circle, cast on the other game"],
	["dolm", "e", 0.0, "e_tell0", "circle", "Tenzo's three E tells, cast on the other game"],
	["bulwark", "e", 0.0, "e", "circle", "Albert's E zone, cast on the other game"],
]
const AIM := Vector3(6.0, 0, 0)  # m from the caster: where the guest aims
const VIEW := Vector3(0, 0, -6.0)  # m from home: where this game's own hunter stands, out of the way
const GAP := 2.5  # s the guest waits after each cast (the telegraph plays out)
const WAIT := 40.0  # s of real time the host waits for one telegraph (a full loop of the guest's casts)

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
	Save.d["tutorial"][KitDrill.SAVE_KEY] = true  # no first-time drill banner over the shots
	var copy := await _host_up()
	if copy == null:
		return _finish()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	m.player.teleport(home + VIEW)
	for s in SHOTS:
		await _shot(copy, s)
	var f := FileAccess.open(shots_dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	if FileAccess.file_exists(dir.path_join("guest.log")):
		DirAccess.copy_absolute(dir.path_join("guest.log"), shots_dir.path_join("guest.log"))
	_finish()


## Waits for the shot's telegraph (its id and shape kind) under the guest's hunter, then saves the frame.
func _shot(copy: Hunter, s: Array) -> void:
	var arch := String(s[0])
	var key := String(s[1])
	var id := String(s[3])
	copy.reclass(Arch.weight(arch), arch)  # the copy's body (the arch does not ride the snapshot)
	var t0 := Time.get_ticks_msec()
	var up := 0  # frames it has been up: a few, so the camera and the copy's body settle on it
	while up < 4 and Time.get_ticks_msec() - t0 < WAIT * 1000.0:
		await _frame(copy)
		up = up + 1 if AimKit.entry(copy, id).get("kind") == s[4] else 0
	ok(up >= 4, "%s %s: the guest's %s %s is up on this game" % [arch, key, s[4], id])
	var file := "tele_net_%s_%s.png" % [arch, key]
	var img := main.get_viewport().get_texture().get_image()
	ok(img != null, "%s %s: a frame to save (needs a renderer)" % [arch, key])
	if img != null:
		img.save_png(shots_dir.path_join(file))
	lines.append("tele_net|%s|%s (seen by a foe on another game)" % [file, s[5]])


## One step and one drawn frame, the camera on the guest's hunter.
func _frame(copy: Hunter) -> void:
	m.cam.snap(copy.pos + Vector3(3.0, 0, 0))
	for h in m.hunters:
		h.render(DT, 1.0)
	await _run(DT)


# ------------------------------------------------------------------ the guest
func _guest() -> void:
	_cast_loop()
	await super._guest()


## Once its match is up, the guest casts every SHOTS ability in turn, GAP s apart, until the host is done.
func _cast_loop() -> void:
	while m == null or m.player == null:
		await main.get_tree().create_timer(0.2).timeout
	while not stop:
		for s in SHOTS:
			await _cast_here(String(s[0]), String(s[1]), float(s[2]))
			await main.get_tree().create_timer(GAP).timeout


## The guest's own hunter casts at home, aiming AIM away; held keys stay down `held` s (its main loop steps).
func _cast_here(arch: String, key: String, held: float) -> void:
	_kit(arch)
	_aim(m.player.pos + AIM)
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
	var up := AimKit.layer(m).entries.keys()
	printerr("%s guest cast %s %s at %s, net %s, up %s, t %.1f" % [tag, arch, key, me.pos, m.net_on, up, m.time])
	for k in ["fire", "sec", "sec_hold", "sig", "ult"]:
		me.inp[k] = false
