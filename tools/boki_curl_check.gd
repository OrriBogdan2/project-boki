extends RefCounted
## --boki-curl-check [--curl-boki=a,b]: a big Boki on the Return order guarding at your side
## (docs/BOKI_AGENCY_AUDIT.md) through a run, a jump, a glide off the jump and the landing, rendered every 60 Hz step.
## It curls up on your back while you glide and goes back to its flank when you land (KinCurl eases both ways).
## Prints one CURL_FRAME line a frame: its root (the Kin node) against your spot on the ground (your x and z, the
## ground's height: it stays on the ground when you jump), and its curl pose weight (body pitch / KinCurl.BALL_PITCH,
## 0 on its feet, 1 curled), then a CURL_SUMMARY line per Boki with the biggest one-frame step of each.
## FAIL: a step over MAX_STEP_M or MAX_STEP_W, or it never curled up or never came back down.
## --curl-snap: the old draw for a before/after, the ease skipped (curl set to its end every frame); no FAIL lines.
## --shots-dir=<dir> [--size=480]: also <dir>/<boki>/f000.png... at 30 fps from a fixed side spot (a renderer).

const MAX_STEP_M := 0.15  # m: the root's biggest one-frame step, against your spot on the ground (not your run)
const MAX_STEP_W := 0.5  # the curl pose weight's biggest one-frame step
const CAM_OFF := Vector3(-2.6, 2.0, -3.6)  # m: the film's camera from you (the same in a before and an after)
const MAX_FRAMES := 400  # steps: a glide that never lands stops the dump here
const DEFAULT := ["pebbit", "goliathite"]  # two big forms: the lightest (1.4) and a heaviest (2.0)

var bad := 0
var m: Match
var snap := false
var shots := ""
var cam: Camera3D
var main_tree: SceneTree


func ok(cond: bool, what: String) -> void:
	print("BOKICURL %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Settings.v["boki_wisps"] = false  # (walking-Boki rules: the wisp is the default now, see --wisp-check)
	main_tree = main.get_tree()
	var ids: Array = DEFAULT
	var px := 480
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--curl-boki="):
			ids = Array(a.substr(12).split(",", false))
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
		if a.begins_with("--size="):
			px = int(a.substr(7))
		snap = snap or a == "--curl-snap"
	if shots != "":
		if main.get("fade") != null:
			main.fade.reveal(0.01)
		main.get_window().size = Vector2i(px, px)
		main.get_viewport().size = Vector2i(px, px)
	for id in ids:
		await _dump(main, String(id))
	print("BOKICURL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## A training match with a flat strip across the map (21 tiles wide), `id` stowed on Return and guarding at your side.
func _fresh(main: Node, id: String) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"training": true,
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"no_drop": true,
			"demo_kin": id,
			"weapon": "rifle",
			"cls": "medium"
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var p: Hunter = m.player
	var w_v: World = m.world
	var hi: int = w_v.idx(int(floor(p.pos.x)), int(floor(p.pos.z)))
	var lv: int = int(w_v.level[hi]) if w_v.kind[hi] != World.T_VOID else 0
	var z0 := int(w_v.h / 2.0)
	for z in range(maxi(1, z0 - 10), mini(w_v.h - 1, z0 + 11)):
		for x in range(1, w_v.w - 1):
			var i: int = w_v.idx(x, z)
			w_v.kind[i] = World.T_GROUND
			w_v.level[i] = lv
			w_v.island[i] = w_v.island[hi]
			w_v.stairs.erase(i)
			w_v.walls.erase(i)
			w_v.props.erase(i)
			w_v.bush.erase(i)
			w_v.block_top.erase(i)
	for other in m.hunters:
		if other != p:
			other.ctrl = "idle"
			other.teleport(p.pos + Vector3(0, 0, 60))
	p.teleport(Vector3(4.5, lv * World.LEVEL, z0 + 0.5))
	p.vel = Vector3.ZERO
	p.kin.teleport(p.pos + Vector3(1.0, 0, 0.7))
	KinCommand.order(p, "return")
	for i in 110:
		m.step(Match.DT)
	if shots != "":
		m.hud.visible = false
		cam = Camera3D.new()
		m.add_child(cam)
		cam.make_current()
		cam.fov = 40.0
		DirAccess.make_dir_recursive_absolute(shots.path_join(id))


## Run 0.5 s, jump, open the glider at the top of the jump, glide down, land and run on 1.2 s; one frame a step.
func _dump(main: Node, id: String) -> void:
	_fresh(main, id)
	var p: Hunter = m.player
	var k: Kin = p.kin
	ok(k.big() and k.beside, "%s: big (mass %.1f), guarding at your side before the jump" % [id, k.ks.mass])
	var body: Node3D = k.model.get_node("Body")
	# the Hero clips' sync stepped with the sim, not by the wall clock while a frame is grabbed (as --glide-shots)
	var sync := p.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.set_process(false)
	var last := Vector3.INF
	var last_w := 0.0
	var top := {"m": 0.0, "mf": 0, "w": 0.0, "wf": 0, "on": -1, "off": -1}
	var t := 0.0
	var landed_t := -1.0
	var f := 0
	while (landed_t < 0.0 or t - landed_t < 1.2) and f < MAX_FRAMES:
		p.inp["move"] = Vector2(1, 0)
		var gl := t > 0.75 and landed_t < 0.0
		p.inp["glide"] = gl
		p.inp["glide_btn"] = gl
		if f == 30:
			p.do_jump()
		m.step(Match.DT)
		p.render(Match.DT, 1.0)
		if sync:
			sync._process(Match.DT)
		if snap:
			k.curl = 1.0 if k.state == "shoulder" and not k.beside else 0.0
		k.render(Match.DT, 1.0)
		if t > 0.75 and p.grounded and landed_t < 0.0:
			landed_t = t
		var at := p.model.global_position
		var rel := k.global_position - Vector3(at.x, m.world.ground_at(at.x, at.z), at.z)
		var w := clampf(body.rotation.x / KinCurl.BALL_PITCH, 0.0, 1.0)
		var dm := 0.0 if last == Vector3.INF else rel.distance_to(last)
		var dw := absf(w - last_w)
		if dm > top["m"]:
			top["m"] = dm
			top["mf"] = f
		if dw > top["w"]:
			top["w"] = dw
			top["wf"] = f
		if not k.beside and top["on"] < 0:
			top["on"] = f
		if k.beside and top["on"] >= 0 and top["off"] < 0:
			top["off"] = f
		var ph := "jump"
		if f < 30:
			ph = "run"
		elif p.gliding:
			ph = "glide"
		elif landed_t >= 0.0:
			ph = "land"
		var up := p.pos.y - m.world.ground_at(p.pos.x, p.pos.z)
		print(
			(
				"CURL_FRAME %s f%03d %-5s up=%.2f beside=%d rel=(%5.2f %5.2f %5.2f) step=%.3f w=%.2f dw=%.2f scale=%.2f"
				% [id, f, ph, up, int(k.beside), rel.x, rel.y, rel.z, dm, w, dw, k.model.scale.x]
			)
		)
		last = rel
		last_w = w
		if shots != "" and f % 2 == 0:
			await _grab(p, shots.path_join(id).path_join("f%03d.png" % int(f / 2.0)))
		f += 1
		t = f * Match.DT
	print(
		(
			"CURL_SUMMARY %s frames=%d curl_on=f%03d curl_off=f%03d max_step=%.3fm@f%03d max_dw=%.2f@f%03d"
			% [id, f, top["on"], top["off"], top["m"], top["mf"], top["w"], top["wf"]]
		)
	)
	if snap:
		return
	ok(top["on"] >= 0 and top["off"] > top["on"], "%s: it curls onto your back in the glide, off on landing" % id)
	ok(
		top["m"] <= MAX_STEP_M,
		"%s: no one-frame jump in its root over %.2f m (biggest %.3f m)" % [id, MAX_STEP_M, top["m"]]
	)
	ok(
		top["w"] <= MAX_STEP_W,
		"%s: no one-frame jump in its curl over %.1f (biggest %.2f)" % [id, MAX_STEP_W, top["w"]]
	)


## A frame from a fixed spot beside your run, over the grass, on you (your Boki within 1.7 m).
func _grab(p: Hunter, path: String) -> void:
	var at := p.model.global_position + Vector3(0, 0.9, 0)
	cam.global_position = at + CAM_OFF
	cam.look_at(at)
	await RenderingServer.frame_post_draw
	main_tree.root.get_texture().get_image().save_png(path)
