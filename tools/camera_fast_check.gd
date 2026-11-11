extends RefCounted
## --camera-fast-check: your screen offset, frame by frame, through the fastest displacements in the game:
## every hero's dash (Sparkle's 40 m/s Wirerun among them), Kael's Warchain self-pull, being reeled in by
## Grimble's Abyssal Hand, Motley's swap, a ~10 m knockback and the sky train pulling out from under you.
## The source camera stays locked on you (docs/MOVEMENT_FEEL.md, "Camera"): no frame may put you more than
## MAX_OFF of the screen's height from where you sit at rest, nor move you more than MAX_JUMP in one frame.
## It drives the real frame path (Match._process: the sim step, the render lead, the camera), never the save.
## --camera-fast-shots --shots-dir=<dir>: the worst case (the Wirerun) as a strip of centre crops, on a GPU.
##
## Prints "CAMFAST <case> off <peak>% jump <peak>% moved <m>  ok|FAIL" per case and
## "CAMERA FAST CHECK DONE, failures: N" at the end.

const DT := 1.0 / 60.0
const MAX_OFF := 0.08          # share of the screen's height you may sit from your resting spot
const MAX_JUMP := 0.03         # share of the screen's height you may move on screen in one frame
const BODY_Y := 1.0            # m above the feet: the point tracked (the body, where the camera's rise aims)
const MIN_MOVE := 2.0          # m a case must carry you, or it didn't happen and proves nothing
const DASH_HOLD := 40          # frames Shift is held (the Wirerun charges for 0.6 s and runs on release)
const KNOCK := 23.0            # m/s of knockback impulse per unit of mass: about 10 m of travel (printed)
const SETTLE := 30             # frames the follow gets to settle on a standing hunter before a case
const SHOT_EVERY := 3          # frames between the strip's crops
const SHOTS := 8               # crops in the strip
const CROP := Vector2i(480, 360)

var main: Node
var m: Match
var P: Hunter
var cam: CamRig
var mf: RefCounted             # move_feel_check: its flat-spot finder and hunter reset, reused
var flat := Vector3.ZERO
var rest := Vector2.ZERO       # your pixel at rest, the offset's zero
var view_h := 720.0
var bad := 0

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "map": "skyreach", "no_drop": true,
			"god": true, "tut_test": true})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	cam = m.cam
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	cam.lead = 0.0             # no cursor lean: the offset measured is the follow's alone
	mf = load("res://tools/move_feel_check.gd").new()
	mf.m = m
	mf.w = m.world
	mf.P = P
	flat = mf._flat_spot(8.0)
	view_h = cam.get_viewport().get_visible_rect().size.y
	print("CAMFAST flat spot %s, screen %s" % [str(flat), str(cam.get_viewport().get_visible_rect().size)])
	m.acc = 0.0
	m.paused = false
	if mode == "shots":
		await _shots()
	else:
		m.set_process(false)
		for c in _cases():
			_case(c)
		print("CAMERA FAST CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## Each case: a key, frames measured, frames Shift is held, the hero (reclassed first), `place` (run before
## the rest frames: where you start) and `go` (run after them: what moves you).
func _cases() -> Array:
	var out: Array = []
	for a in Arch.ids():
		out.append({"key": "dash_" + a, "frames": 150, "hold": DASH_HOLD, "arch": a})
	out.append({"key": "warchain_pull", "frames": 150, "arch": "juggernaut", "go": _chain})
	out.append({"key": "abyssal_hand_reel", "frames": 180, "go": _reel})
	out.append({"key": "knockback", "frames": 150, "go": _knock})
	out.append({"key": "train_depart", "frames": 360, "place": _train})
	return out

func _case(c: Dictionary) -> void:
	var a := String(c.get("arch", ""))
	if a != "":
		P.reclass(Arch.weight(a), a)
	mf._reset(flat + Vector3(-6.0, 0, 0))
	P.inp["aim"] = P.pos + Vector3(12.0, 0, 0)
	if c.has("place"):
		(c["place"] as Callable).call()
	cam.snap(P.pos)
	for i in SETTLE: m._process(DT)
	rest = _screen()
	var from := P.pos
	if c.has("go"):
		(c["go"] as Callable).call()
	var hold := int(c.get("hold", 0))
	var peak := 0.0
	var jump := 0.0
	var far := 0.0
	var last := rest
	for i in int(c["frames"]):
		if hold > 0:
			P.inp["move"] = Vector2(1, 0)
			P.inp["dash"] = i < hold
		m._process(DT)
		var s := _screen()
		peak = maxf(peak, (s - rest).length() / view_h)
		jump = maxf(jump, (s - last).length() / view_h)
		last = s
		far = maxf(far, Vector2(P.pos.x - from.x, P.pos.z - from.z).length())
	var okk := peak <= MAX_OFF and jump <= MAX_JUMP and far >= MIN_MOVE
	print("CAMFAST %-20s off %5.1f%%  jump %5.1f%%  moved %5.1f m  %s" % [c["key"], peak * 100.0, jump * 100.0, far,
			"ok" if okk else "FAIL"])
	if not okk: bad += 1
	if c.has("go"): _clear_guest()

## Your body's pixel, from the rendered position the model stands at.
func _screen() -> Vector2:
	return cam.unproject_position(P.position + Vector3(0, BODY_Y, 0))

func _chain() -> void:
	var k := P.ak as JuggernautKit
	k.warchain._hook(null, P.pos + Vector3(12.0, 0.6, 0))
	k.warchain.pull()

## A Grimble 14 m away reels you in: the same Displace tow his Abyssal Hand starts on a catch.
func _reel() -> void:
	var g: Hunter = m.make_hunter("G", 1, "heavy", "Grimble", "idle", {}, flat + Vector3(8.0, 0, 0), {"arch": "dredge"})
	var rdf: Dictionary = (g.ak as DredgeKit).rmb_def()
	m.displace.tow(P, g, {"mode": "haul", "spd": float(rdf["pull_speed"]), "gap": float(rdf["gap"]),
			"dur": float(rdf["pull_max"]), "swing": DredgeKit.SWING, "stun": 0.2})

func _clear_guest() -> void:
	for h in m.hunters:
		if h.name == "G" and not h.out:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true

func _knock() -> void:
	m.displace.knock(P, Vector2(KNOCK * P.mass(), 0.0))

## Aboard a car at a stop, a second before the train pulls out.
func _train() -> void:
	var st: SkyTrain = m.skytrain
	if st == null:
		print("CAMFAST (no sky train on this map)")
		return
	var t := 0.0
	while t < st.period and not (st._schedule(t).y < 0.001 and st._schedule(t + 0.1).y > 0.001):
		t += 0.05
	m.time = fposmod(t - 1.0, st.period)
	st.tick(0.0)
	var o: Vector3 = (st.cur[1] as Transform3D).origin
	P.teleport(Vector3(o.x, st.deck_y(o + Vector3(0, 1.0, 0), 3.0), o.z))
	P.grounded = true

## The Wirerun on a real screen: crops round the screen's centre every SHOT_EVERY frames from the release.
func _shots() -> void:
	var dir := "user://camera_fast_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.reclass("light", "mage")
	mf._reset(flat + Vector3(-6.0, 0, 0))
	P.inp["aim"] = P.pos + Vector3(12.0, 0, 0)
	cam.snap(P.pos)
	var strip := Image.create(CROP.x * SHOTS, CROP.y, false, Image.FORMAT_RGB8)
	var n := 0
	for i in DASH_HOLD + SHOT_EVERY * SHOTS:
		P.inp["move"] = Vector2(1, 0)
		P.inp["dash"] = i < DASH_HOLD
		await main.get_tree().process_frame
		if i < DASH_HOLD or (i - DASH_HOLD) % SHOT_EVERY != 0:
			continue
		var img := main.get_viewport().get_texture().get_image()
		var at := Vector2i(img.get_size() / 2) - CROP / 2
		strip.blit_rect(img.get_region(Rect2i(at, CROP)), Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * n, 0))
		for y in CROP.y:
			strip.set_pixel(CROP.x * n + CROP.x / 2, y, Color.WHITE)     # the screen's centre line
		n += 1
	strip.save_png(dir.path_join("camera_fast_wirerun.png"))
	print("CAMFAST SHOTS DONE")
