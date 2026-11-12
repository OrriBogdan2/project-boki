extends RefCounted
## --wade-check: Boki wade (BokiWade, content/rules/wade.json). A stream three tiles wide is painted across a
## base_mode farm. A Boki crossing it walks at the wade speed in the shallow edge and the deep speed in the middle
## (never stopped), leaves a ripple and shakes off coming out; a Water type that goes in lingers playing the splash
## clip and gains joy; a Fire type dropped mid-stream is on dry ground within 2 s. Never touches the real save.
## --shots-dir=<dir> adds a GPU strip (wade_strip.png): a Zapple wading across, a Puddlet paddling and a Kilnbadger
## stepping out, six frames a second apart.
## (The nav sweep, --garden-nav-check, covers getting stuck with the whole base running.)

const DT := 1.0 / 30.0         # s per step
const OUT_SECS := 2.0          # s: a Fire Boki must be out by then
const CAST := ["zapple", "kilnbadger", "puddlet"]
const SEED := 11
const FRAMES := 6              # frames in the GPU strip

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("WADE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _save() -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in CAST.size():
		var rec := Save.new_kin(CAST[i], "B%d" % i)
		Care.ensure(rec)
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, SEED)
	Save.d = d

## A stream three tiles wide east to west across the landing, and the z of its middle row.
func _stream() -> int:
	var land := HomeLayout.LANDING
	var zc := int(land.z) - 6
	for x in range(int(land.x) - 8, int(land.x) + 9):
		for z in range(zc - 1, zc + 2):
			home.hb.L()["water"][HomeLayout.key(x, z)] = 1
	home.hb.apply(false)
	return zc

func _kin(i: int) -> Dictionary:
	return home.kins[i]

## Puts Boki i at p; every other Boki is busy so only this one moves.
func _only(i: int, p: Vector3) -> void:
	for j in home.kins.size():
		_kin(j)["busy"] = j != i
	var k := _kin(i)
	k["pos"] = p
	k["goal"] = p
	k["vel"] = Vector3.ZERO
	k["t"] = 999.0
	k.erase("wade")
	(k["node"] as Node3D).position = p

func _step(k: Dictionary, goal: Vector3) -> float:
	var before: Vector3 = k["pos"]
	k["goal"] = goal
	k["t"] = 999.0
	home._move_kin(DT)
	return Vector2(k["pos"].x - before.x, k["pos"].z - before.z).length() / DT

func _cross(zc: int) -> void:
	var k := _kin(0)
	var x := HomeLayout.LANDING.x
	_only(0, Vector3(x, 0, zc + 5.0))
	var dry := 0.0
	var shallow := 0.0
	var deep := 0.0
	var wet_steps := 0
	var stalled := false
	var paddled := false
	var far := Vector3(x, 0, zc - 5.0)
	for i in 400:
		var sp := _step(k, far)
		var dep: int = home.water.depth(k["pos"].x, k["pos"].z)
		if dep == 0 and wet_steps == 0:
			dry = maxf(dry, sp)
		elif dep == 1 and deep == 0.0:
			shallow = sp      # the last step in the near edge, once the speed has settled
		elif dep == 2:
			deep = sp
			paddled = paddled or _paddling(k)
		if dep > 0:
			wet_steps += 1
			stalled = stalled or sp < 0.3
		if k["pos"].z <= zc - 4.5:
			break
	var R := BokiWade.rules()
	ok(wet_steps > 10, "crossed the stream (%d steps in the water)" % wet_steps)
	var slow := dry * float(R["wade_speed"]) * 1.25      # a little over the multiplier: the speed eases in
	ok(shallow > 0.0 and shallow < slow, "shallow: %.2f m/s against %.2f dry" % [shallow, dry])
	slow = dry * float(R["deep_speed"]) * 1.15
	ok(deep > 0.0 and deep < slow, "deep: %.2f m/s against %.2f dry" % [deep, dry])
	ok(not stalled and k["pos"].z <= zc - 4.5, "never stuck: out the far side at z %.1f" % k["pos"].z)
	ok(home.wade.kind(k["rec"]) == "wade", "a Zapple wades through")
	ok(paddled, "in the deep middle it paddles, lifted off the bed (BokiRig)")

## The rig takes the water this step put on the node: true while it paddles afloat.
func _paddling(k: Dictionary) -> bool:
	var rig := (k["node"] as Node3D).get_node("Body/Flex/BokiRig") as BokiRig
	rig._process(DT)
	return rig.clip == "paddle" and rig.model.position.y > 0.0

func _fire(zc: int) -> void:
	var k := _kin(1)
	_only(1, Vector3(HomeLayout.LANDING.x, 0, zc + 0.5))
	var deep: bool = home.water.depth(k["pos"].x, k["pos"].z) == 2
	ok(deep and home.wade.kind(k["rec"]) == "fire", "a Kilnbadger (Fire) in the deep middle")
	var t := 0.0
	home.wade.step(k, k["pos"], k["node"], 0.0)
	while t < OUT_SECS + 1.0 and home.water.depth(k["pos"].x, k["pos"].z) > 0:
		_step(k, k["goal"])
		t += DT
	ok(t <= OUT_SECS, "it is on dry ground after %.2f s (the bar is %.0f s)" % [t, OUT_SECS])
	_step(k, k["goal"])
	ok(float(k["wade"]["shake_t"]) > 0.0, "and it shakes the water off")

func _paddle(zc: int) -> void:
	var k := _kin(2)
	BokiWade.rules()["linger_chance"] = 1.0
	_only(2, Vector3(HomeLayout.LANDING.x, 0, zc + 3.0))
	Care.change(k["rec"], "joy", -40.0)
	var joy0 := Care.need(k["rec"], "joy")
	var far := Vector3(HomeLayout.LANDING.x, 0, zc - 5.0)
	var lingered := 0.0
	var played := false
	for i in 300:
		_step(k, k["goal"] if k.get("wade", {}).get("in", false) else far)      # once in, the Boki steers itself
		if float(k.get("wade", {}).get("stay", 0.0)) > 0.0:
			lingered += DT
			played = played or (k["node"] as Node3D).get_meta("kact", "") == "splash"
	ok(home.wade.kind(k["rec"]) == "swim", "a Puddlet swims")
	ok(lingered > 3.0 and played, "it lingered %.1f s in the water playing the splash clip" % lingered)
	ok(Care.need(k["rec"], "joy") > joy0 + 2.0, "and its joy rose %.1f -> %.1f" % [joy0, Care.need(k["rec"], "joy")])

## Six frames of the three Boki at the stream, one image across. Needs a rendering display (jobq --needs gpu).
func _strip(dir: String, zc: int) -> void:
	var x := HomeLayout.LANDING.x
	_only(0, Vector3(x - 2.5, 0, zc + 3.0))
	_only(1, Vector3(x + 0.5, 0, zc + 0.5))
	_only(2, Vector3(x + 2.5, 0, zc + 3.0))
	for k in home.kins:
		k["busy"] = false
	home.ppos = Vector3(x, 0, zc + 3.0)
	home.player.position = home.ppos
	home.set_process(true)
	home.cam.zoom_to = 0.55      # close in on the stream
	home.cam.zoom = 0.55
	if main.fade:
		await main.fade.reveal(0.05)      # the boot splash stays up when a check builds the farm by hand
	var frames: Array = []
	var gap := 50
	for i in gap * FRAMES:
		home.kins[0]["goal"] = Vector3(x - 2.5, 0, zc - 5.0)
		home.kins[2]["goal"] = Vector3(x + 2.5, 0, zc - 5.0) if i < gap else home.kins[2]["goal"]
		for k in home.kins:
			k["t"] = 999.0
		await main.get_tree().process_frame
		if i % gap == gap - 1:
			frames.append(main.get_viewport().get_texture().get_image())
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var strip := Image.create(w * FRAMES, h, false, frames[0].get_format())
	for i in FRAMES:
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(w * i, 0))
	strip.resize(w * FRAMES / 2, h / 2)
	strip.save_png(dir + "/wade_strip.png")
	home.set_process(false)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(SEED)
	_save()
	home = await main._hb_home()
	for i in 20:
		await main.get_tree().process_frame      # a rendering display needs a few frames to finish building the farm
	home.set_process(false)
	home.life = null
	var zc := _stream()
	var x := HomeLayout.LANDING.x
	ok(home.water.depth(x, zc) == 2 and home.water.depth(x, zc + 1.0) == 1, "a stream: deep middle, shallow edges")
	_cross(zc)
	_fire(zc)
	_paddle(zc)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir=") and DisplayServer.get_name() != "headless":
			await _strip(a.substr(12), zc)
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("WADE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
