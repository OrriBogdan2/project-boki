extends RefCounted
## --play-probe: an automated player. Every Hunter in a real match, driven only by keyboard and mouse InputEvents
## sent through Input.parse_input_event (the path a player's keys take: InputMap actions, Match._gather_input,
## _unhandled_input for the map and panels). It records what the body, the camera and the model do each frame and
## flags what would feel wrong: walk/run/stop, jump, dash, glide, every ability as tap and hold, inputs during
## other moves and under the map or a panel, focus loss, walls, ledges, stairs, the island edge, other bodies,
## knockback and getting stuck. Damage and balance are out of scope. The harness only resets between scenarios
## (teleport, a fresh kit, dash charges back); inside a scenario everything comes from the input events.
## Args: --play-probe-out=<dir> (default user://play_probe), --play-probe=<hero>,<hero> (default all),
## --play-probe-clips (save a short mp4 per FLAG; needs drawing, so a GPU worker).
## Writes play_probe_report.md and play_probe.json; prints "PROBE PASS|FLAG ..." and "PLAY PROBE DONE, flags: N".
## Runner: tools/play_probe.sh. It never touches the save.

const Judge := preload("res://tools/play_probe_judge.gd")
const SEED := 77  # one map for every hero (the features are found once per match)
const LANE := 26  # tiles of flat ground a run, a dash and a stop need
const SEARCH := 70  # tiles around the spawn searched for the features
const HIGH := 12.0  # m above the ground: the in-air glide starts
const TAP := 2  # frames a tapped key stays down
const CLIP_EVERY := 2  # frames: a clip keeps every 2nd frame (30 fps)
const CLIP_SIZE := Vector2i(960, 540)  # px: the window when clips are on
const KNOCK := Vector2(14.0, 0.0)  # Ent.impulse: a strong shove (an ability's knock, the game's own path)
const KEY_OF := {Vector2i(1, 0): KEY_D, Vector2i(-1, 0): KEY_A, Vector2i(0, 1): KEY_S, Vector2i(0, -1): KEY_W}
## Ability keys: [name, key or -mouse button]. R is the Hunter's ultimate, Q the first glove.
const ABILITIES := [["lmb", -MOUSE_BUTTON_LEFT], ["rmb", -MOUSE_BUTTON_RIGHT], ["e", KEY_E], ["r", KEY_R], ["q", KEY_Q]]

var judge: Judge = Judge.new()
var main: Node
var m: Match
var me: Hunter
var foe: Hunter
var w: World
var hero := ""
var ss: Array = []  # this scenario's samples, one per frame
var held := {}  # key or -button -> true while the probe holds it down
var mouse := Vector2.ZERO  # px: where the probe's cursor is
var feats := {}  # name -> {at: Vector3, dir: Vector2i} (found once on the seed's map)
var park := Vector3.ZERO  # where the other Hunter waits between scenarios, off the lanes
var last_sid := -1
var last_swing := 0
var last_used := 0
var last_anim := -9.0
var last_cast := -9.0
var feet: Array = []  # the model's foot bone indices
var skel: Skeleton3D
var clips: WardenClips
var prev_feet: Array = []
var frames := 0
var clip_on := false
var shots: Array = []  # this scenario's frames for a clip
var clip_paths := {}
var pending: Array = []  # [scenario, measurements] waiting for its judgement
var out_dir := "user://play_probe"


func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()  # (jobq passes them before or after "--")
	clip_on = "--play-probe-clips" in args
	RenderingServer.render_loop_enabled = clip_on  # no drawing unless clips are saved
	main.get_tree().root.size = CLIP_SIZE if clip_on else Vector2i(1280, 720)
	var heroes: Array = []
	for a in args:
		var s := String(a)
		if s.begins_with("--play-probe="):
			heroes = Array(s.get_slice("=", 1).split(","))
		elif s.begins_with("--play-probe-out="):
			out_dir = s.get_slice("=", 1)
	if heroes.is_empty():
		heroes = Arch.ORDER.duplicate()
	for h in heroes:
		await _hero(String(h))
	var cmd := "tools/play_probe.sh <out dir>%s" % (" --clips" if clip_on else "")
	var sha := OS.get_environment("PROBE_SHA")
	judge.write(ProjectSettings.globalize_path(out_dir), cmd, heroes, clip_paths, {"sha": sha, "frames": frames})
	print("PLAY PROBE DONE, flags: %d, report: %s" % [judge.rows.size(), out_dir.path_join("play_probe_report.md")])
	main.get_tree().quit()


# ---------------------------------------------------------------- one hero
func _hero(id: String) -> void:
	hero = id
	m = Match.new()
	main.add_child(m)
	var opts := {
		"teams": 2,
		"squad": 1,
		"tier": 0,
		"length": 1e9,
		"seed": SEED,
		"no_drop": true,
		"god": true,
		"demo_kin": "cindle",
	}  # a Boki at your side, to walk into
	opts.merge({"cls": Arch.weight(id), "arch": id, "weapon": Arch.signature(id)})
	m.start(opts)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	w = m.world
	me = m.player
	last_sid = -1  # (a new match counts its shots from 0 again)
	me.unlock_all()
	foe = null
	for h in m.hunters:
		if h != me:
			h.ctrl = "idle"
			h.inp["move"] = Vector2.ZERO
			if foe == null:
				foe = h
	await _frames(30)
	_find_feats()
	park = w.free_spot_near(_flat() + Vector3(0, 0, 14))
	_bind_model()
	var names := feet.map(func(b: int) -> String: return skel.get_bone_name(b))
	if names.is_empty() and skel:  # (no foot bone by name: the bone list, to teach _bind_model this rig's names)
		for i in mini(skel.get_bone_count(), 60):
			names.append(skel.get_bone_name(i))
	print("PROBE hero %s features %s feet %s clips %s" % [id, str(feats.keys()), str(names), clips != null])
	await _movement()
	await _abilities()
	await _states()
	await _collisions()
	_judge_pending()
	_release_all()
	m.queue_free()
	await _frames(2)


func _bind_model() -> void:
	feet.clear()
	skel = null
	clips = null
	var sks: Array = me.model.find_children("*", "Skeleton3D", true, false) if me.model else []
	if not sks.is_empty():
		skel = sks[0]
		for i in skel.get_bone_count():
			var n := skel.get_bone_name(i).to_lower()
			if "foot" in n or "ankle" in n:
				feet.append(i)
	var sync := me.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync if me.model else null
	clips = sync.clips if sync else null


# ---------------------------------------------------------------- input: real events only
func _key(code: int, down: bool) -> void:
	if code < 0:
		var b := InputEventMouseButton.new()
		b.button_index = (-code) as MouseButton
		b.pressed = down
		b.position = mouse
		b.global_position = mouse
		Input.parse_input_event(b)
	else:
		var k := InputEventKey.new()
		k.physical_keycode = code as Key
		k.keycode = code as Key
		k.pressed = down
		Input.parse_input_event(k)
	Input.flush_buffered_events()
	if down:
		held[code] = true
	else:
		held.erase(code)


func _release_all() -> void:
	for c in held.keys():
		_key(int(c), false)


## The cursor on a world point (a mouse motion event, as the OS sends one).
func _aim_at(p: Vector3) -> void:
	var cam := main.get_viewport().get_camera_3d()
	if cam == null:
		return
	mouse = cam.unproject_position(p)
	Input.warp_mouse(mouse)
	var ev := InputEventMouseMotion.new()
	ev.position = mouse
	ev.global_position = mouse
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _tap(code: int) -> void:
	_key(code, true)
	await _frames(TAP)
	_key(code, false)


# ---------------------------------------------------------------- frames and samples
func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame
		frames += 1
		if me != null and is_instance_valid(me):
			_sample()


func _sample() -> void:
	var cam := main.get_viewport().get_camera_3d()
	var vp := main.get_viewport().get_visible_rect()
	var on := true
	if cam:
		var sp := cam.unproject_position(me.position)
		on = vp.has_point(sp) and not cam.is_position_behind(me.position)
	var low := me.pos.y < w.lowest_top() - 30.0
	(
		ss
		. append(
			{
				"p": me.pos,
				"v": me.vel,
				"g": me.grounded,
				"st": me.loco.state_name(),
				"gl": me.gliding,
				"dash": me.roll_t > 0.0 or me.loco.state == Loco.S.DASHING,
				"ch": me.dashes,
				"act": _activity(),
				"map": m.hud != null and m.hud.map_open(),
				"scr": on,
				"lp": clips.loco_pos.length() if clips else -1.0,
				"aw": maxf(clips.act_w, clips.up_w) if clips else 0.0,
				"clip": clips.cur if clips else "",
				"rest": _rest_dev(),
				"foot": _foot_speed(),
				"out": me.out,
				"low": low,
				"low_by": w.lowest_top() - me.pos.y,
				"shk": m.cam.shake_left > 0.0 or m.cam.pull > 0.01,
				"cam": cam.global_position if cam else Vector3.ZERO,
			}
		)
	)
	if clip_on and frames % CLIP_EVERY == 0:
		shots.append(main.get_viewport().get_texture().get_image())


## Events this frame that show the hunter acting: its new shots, a swing, a cast, a kit move, a slot used.
func _activity() -> int:
	var n := 0
	var top := last_sid
	for s in m.shots:
		if s["by"] == me and int(s["sid"]) > last_sid:
			top = maxi(top, int(s["sid"]))
	if top > last_sid:
		n += 1
		last_sid = top
	if me.swing_n != last_swing:
		n += 1
		last_swing = me.swing_n
	var u := 0
	for k in me.used:
		u += int(me.used[k])
	if u != last_used:
		n += 1
		last_used = u
	if me.ak and me.ak.anim_id != "" and me.ak.anim_at != last_anim:
		n += 1
		last_anim = me.ak.anim_at
	if me.cast_at != last_cast:
		n += 1
		last_cast = me.cast_at
	return n


## rad: the skeleton's mean bone turn from its rest pose (about 0 = the T-pose), -1 with no skeleton.
func _rest_dev() -> float:
	if skel == null or not is_instance_valid(skel) or skel.get_bone_count() == 0:
		return -1.0
	var tot := 0.0
	for i in skel.get_bone_count():
		var a := skel.get_bone_pose_rotation(i)
		var b := skel.get_bone_rest(i).basis.get_rotation_quaternion()
		tot += a.angle_to(b)
	return tot / skel.get_bone_count()


## m/s: the slower foot's flat world speed this frame (the planted one), -1 with no foot bones.
func _foot_speed() -> float:
	if feet.is_empty() or not is_instance_valid(skel):
		return -1.0
	var now: Array = []
	for b in feet:
		now.append(skel.global_transform * skel.get_bone_global_pose(int(b)).origin)
	var slow := INF
	if prev_feet.size() == now.size():
		for i in now.size():
			var d: Vector3 = now[i] - prev_feet[i]
			slow = minf(slow, Vector2(d.x, d.z).length() / Judge.DT)
	prev_feet = now
	return slow if slow < INF else -1.0


# ---------------------------------------------------------------- scenario frame
## A scenario starts here: keys up, the map shut, a fresh kit, charges back, the body still at `at`.
func _begin(at: Vector3, aim_dir := Vector2(1, 0)) -> void:
	_judge_pending()
	_release_all()
	if m.hud and m.hud.map_open():
		m.hud.close_map()
	if m.hud and m.hud.pack_open():
		_key(KEY_ESCAPE, true)
		_key(KEY_ESCAPE, false)
	me.set_arch(hero)
	me.unlock_all()
	me.lvl = maxi(me.lvl, int(Hunter.ULT_AT[0]))  # R opens at that level
	me.hp = me.max_hp
	me.teleport(at)
	me.vel = Vector3.ZERO
	me.dash.charges = me.max_dashes()
	me.dash.ex_cd = 0.0
	me.glide_fuel = 1.0
	me.glide_cd = 0.0
	if foe:
		foe.teleport(park)
	await _frames(20)
	_aim_at(me.pos + Vector3(aim_dir.x, 0, aim_dir.y) * 6.0)
	await _frames(10)
	_activity()  # what the reset itself changed is not the scenario's
	ss.clear()
	shots.clear()
	prev_feet.clear()


## A scenario's measurements; judged at the next reset, so flags raised after this call still count.
func _end(sc: String, meas: Dictionary) -> void:
	pending = [sc, meas]


func _judge_pending() -> void:
	if pending.is_empty():
		return
	var sc: String = pending[0]
	judge.common(hero, sc, ss, pending[1])
	judge.put(hero, sc, pending[1])
	if clip_on and judge.flagged(hero, sc) and not shots.is_empty():
		_save_clip(sc)
	pending = []


func _save_clip(sc: String) -> void:
	var dir := ProjectSettings.globalize_path(out_dir.path_join("clips"))
	var tmp := dir.path_join("%s_%s" % [hero, sc])
	DirAccess.make_dir_recursive_absolute(tmp)
	var keep := shots.slice(maxi(0, shots.size() - 180))  # the last 6 s at most
	for i in keep.size():
		(keep[i] as Image).save_jpg(tmp.path_join("f%04d.jpg" % i), 0.85)
	var mp4 := tmp + ".mp4"
	var args := [
		"-v",
		"error",
		"-y",
		"-framerate",
		"30",
		"-i",
		tmp.path_join("f%04d.jpg"),
		"-pix_fmt",
		"yuv420p",
		"-c:v",
		"libx264",
		"-crf",
		"26",
		mp4
	]
	if OS.execute("ffmpeg", args) != 0:
		clip_paths["%s_%s" % [hero, sc]] = "clips/%s_%s/ (jpg frames: no ffmpeg here)" % [hero, sc]
		return
	clip_paths["%s_%s" % [hero, sc]] = "clips/%s_%s.mp4" % [hero, sc]
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)


func _flat() -> Vector3:
	return feats["flat"]["at"]


func _dir(name: String) -> Vector2i:
	return feats[name]["dir"]


# ---------------------------------------------------------------- movement
func _movement() -> void:
	await _run_stop("run", [])
	await _run_stop("sneak", [KEY_CTRL])
	# reversing: right then left
	await _begin(_flat())
	_key(KEY_D, true)
	await _frames(60)
	_key(KEY_D, false)
	_key(KEY_A, true)
	var turn := ss.size()
	await _frames(60)
	_key(KEY_A, false)
	await _frames(30)
	var back := -1.0
	for i in range(turn, ss.size()):
		if (ss[i]["v"] as Vector3).x < -1.0:
			back = (i - turn) * Judge.DT
			break
	_end("reverse", {"reverse_s": back})
	# diagonal speed against the straight run
	await _begin(_flat())
	_key(KEY_D, true)
	_key(KEY_S, true)
	await _frames(70)
	_release_all()
	await _frames(20)
	_end("diagonal", {"top_mps": Judge.top_speed(ss, 0, 70)})
	await _jumps()
	await _dashes()
	await _glides()


func _run_stop(sc: String, mods: Array) -> void:
	await _begin(_flat())
	for k in mods:
		_key(int(k), true)
	_key(KEY_D, true)
	await _frames(90)
	var rel := ss.size()
	_key(KEY_D, false)
	for k in mods:
		_key(int(k), false)
	await _frames(60)
	var meas := {
		"top_mps": Judge.top_speed(ss, 0, rel),
		"accel_90_s": Judge.rise_s(ss, 0, rel, 0.9),
		"stop_s": Judge.stop_s(ss, rel),
		"slide_m": Judge.flat_dist(ss, rel, ss.size() - 1),
	}
	# overshoot: the body coming back the other way after the stop
	var back := 0.0
	for i in range(rel, ss.size()):
		back = minf(back, (ss[i]["v"] as Vector3).x)
	meas["back_mps"] = back
	if float(meas["stop_s"]) < 0.0:
		judge.flag(hero, sc, "stuck_move", "still at %.2f m/s 1 s after D came up" % Judge.hspeed(ss[-1]))
	elif float(meas["slide_m"]) > 1.2:
		judge.flag(hero, sc, "slide_stop", "slides %.2f m after the key came up" % float(meas["slide_m"]))
	if float(meas["top_mps"]) < 1.0:
		judge.flag(hero, sc, "stuck_geo", "top speed %.2f m/s on flat ground" % float(meas["top_mps"]))
	_end(sc, meas)


func _jumps() -> void:
	await _begin(_flat())
	await _tap(KEY_SPACE)
	await _frames(90)
	var air := Judge.air_s(ss, 0)
	_end("jump", {"peak_m": Judge.peak_y(ss, 0), "air_s": air, "drift_m": Judge.flat_dist(ss, 0, ss.size() - 1)})
	if air < 0.0:
		judge.flag(hero, "jump", "stuck_geo", "Space tap: never left the ground or never landed")
	# a running jump: does the run carry
	await _begin(_flat())
	_key(KEY_D, true)
	await _frames(50)
	var take := ss.size()
	var v0 := Judge.hspeed(ss[-1])
	await _tap(KEY_SPACE)
	await _frames(70)
	_key(KEY_D, false)
	await _frames(20)
	var air_v := Judge.top_speed(ss, take + 4, take + 20)
	var land := take + 4 + Judge.first(ss, take + 4, "g")
	var land_v := INF
	for i in range(land, mini(land + 15, ss.size())):
		land_v = minf(land_v, Judge.hspeed(ss[i]))
	_end(
		"jump_run",
		{
			"run_mps": v0,
			"air_mps": air_v,
			"land_min_mps": land_v,
			"peak_m": Judge.peak_y(ss, take),
			"air_s": Judge.air_s(ss, take)
		}
	)
	# Space held from the jump: never a glide (DECISIONS), and how much higher than a tap
	await _begin(_flat())
	_key(KEY_SPACE, true)
	await _frames(80)
	_key(KEY_SPACE, false)
	await _frames(40)
	var gl := Judge.first(ss, 0, "gl")
	_end("jump_hold", {"peak_m": Judge.peak_y(ss, 0), "glide_at_f": gl})


func _dashes() -> void:
	# ground dash while running
	await _begin(_flat())
	_key(KEY_D, true)
	await _frames(30)
	var at := ss.size()
	await _tap(KEY_SHIFT)
	await _frames(40)
	_key(KEY_D, false)
	await _frames(40)
	var n := Judge.dash_starts(ss, at, ss.size())
	var dash_len := 0
	for i in range(at, ss.size()):
		dash_len += int(ss[i]["dash"])
	var meas := {
		"dashes": n,
		"dash_s": dash_len * Judge.DT,
		"dist_m": Judge.flat_dist(ss, at, at + dash_len + 2),
		"top_mps": Judge.top_speed(ss, at, at + dash_len + 2)
	}
	meas["acts"] = Judge.acts(ss, at, ss.size())
	if n == 0 and int(meas["acts"]) == 0:
		judge.flag(hero, "dash", "dash_none", "Shift tap while running: no dash state, no kit move")
	_end("dash", meas)
	# charges: four taps 0.25 s apart
	await _begin(_flat())
	_key(KEY_D, true)
	for i in 4:
		await _tap(KEY_SHIFT)
		await _frames(13)
	_key(KEY_D, false)
	await _frames(40)
	_end("dash_charges", {"cap": me.max_dashes(), "dashes": Judge.dash_starts(ss, 0, ss.size())})
	# standing dash (no keys): toward the cursor or facing
	await _begin(_flat())
	await _tap(KEY_SHIFT)
	await _frames(50)
	_end("dash_still", {"dashes": Judge.dash_starts(ss, 0, ss.size()), "dist_m": Judge.flat_dist(ss, 0, ss.size() - 1)})
	# air dash
	await _begin(_flat())
	_key(KEY_D, true)
	await _tap(KEY_SPACE)
	await _frames(14)
	var air_at := ss.size()
	await _tap(KEY_SHIFT)
	await _frames(70)
	_key(KEY_D, false)
	await _frames(30)
	var an := Judge.dash_starts(ss, air_at, ss.size())
	_end("dash_air", {"dashes": an, "dist_m": Judge.flat_dist(ss, air_at, air_at + 30), "landed": ss[-1]["g"]})
	if an == 0 and Judge.acts(ss, air_at, ss.size()) == 0:
		judge.flag(hero, "dash_air", "dash_none", "Shift tap in the air: no dash state, no kit move")


func _glides() -> void:
	# from high up: a fresh Space press opens it, holding keeps it, letting go folds it
	await _begin(_flat() + Vector3(0, HIGH, 0))
	_key(KEY_D, true)
	await _frames(12)
	var press := ss.size()
	_key(KEY_SPACE, true)
	await _frames(60)
	var rel := ss.size()
	_key(KEY_SPACE, false)
	await _frames(30)
	_key(KEY_D, false)
	await _frames(120)
	var open_f := Judge.first(ss, press, "gl")
	var fold_f := -1
	for i in range(rel, ss.size()):
		if not ss[i]["gl"]:
			fold_f = i - rel
			break
	var sink := 0.0
	if open_f >= 0 and rel - (press + open_f) > 20:
		var a: Vector3 = ss[press + open_f + 10]["p"]
		var b: Vector3 = ss[rel - 1]["p"]
		sink = (a.y - b.y) / ((rel - 1 - press - open_f - 10) * Judge.DT)
	var meas := {
		"open_f": open_f,
		"fold_f": fold_f,
		"sink_mps": sink,
		"glide_mps": Judge.top_speed(ss, press + 20, rel),
		"end_gliding": ss[-1]["gl"],
		"end_grounded": ss[-1]["g"]
	}
	if open_f < 0:
		judge.flag(hero, "glide", "glide_none", "Space pressed and held in the air 1 s: glider never opened")
	elif fold_f < 0 or fold_f > 6:
		judge.flag(hero, "glide", "glide_stuck", "glider still open %d frames after Space came up" % maxi(fold_f, 150))
	_end("glide", meas)
	# held all the way down: it must close on landing and the hunter walks off
	await _begin(_flat() + Vector3(0, HIGH * 0.5, 0))
	await _frames(8)
	_key(KEY_SPACE, true)
	await _frames(200)
	var land := Judge.first(ss, 0, "g")
	_key(KEY_D, true)
	var walk := ss.size()
	await _frames(40)
	_release_all()
	await _frames(20)
	var after_gl := false
	for i in range(maxi(0, land + 5), walk):
		after_gl = after_gl or ss[i]["gl"]
	meas = {"landed_f": land, "gliding_after_land": after_gl, "walk_m": Judge.flat_dist(ss, walk, walk + 40)}
	if after_gl:
		judge.flag(hero, "glide_land", "glide_stuck", "glider still open on the ground with Space held")
	if float(meas["walk_m"]) < 1.0:
		judge.flag(
			hero,
			"glide_land",
			"no_control",
			"after a held glide landing D moved only %.2f m in 0.66 s" % meas["walk_m"]
		)
	_end("glide_land", meas)


# ---------------------------------------------------------------- abilities: tap, hold, release
func _abilities() -> void:
	for ab in ABILITIES:
		await _ability(String(ab[0]), int(ab[1]), false)
		await _ability(String(ab[0]), int(ab[1]), true)


func _ability(name: String, code: int, hold: bool) -> void:
	var sc: String = "%s_%s" % [name, "hold" if hold else "tap"]
	await _begin(_flat())
	_key(code, true)
	await _frames(90 if hold else TAP)
	var rel := ss.size()
	_key(code, false)
	await _frames(100)
	var after := ss.size()
	_key(KEY_A, true)  # control back: walk away
	await _frames(40)
	_key(KEY_A, false)
	await _frames(10)
	var late := 0
	for i in range(rel + int(Judge.LATE_S / Judge.DT), after):
		late += int(ss[i]["act"])
	var meas := {
		"acts_down": Judge.acts(ss, 0, rel),
		"acts_after": Judge.acts(ss, rel, after),
		"late_acts": late,
		"last_act_s": Judge.last_act_s(ss, rel),
		"walk_m": Judge.flat_dist(ss, after, after + 40)
	}
	var total := int(meas["acts_down"]) + int(meas["acts_after"])
	if late >= Judge.LATE_EVENTS and name != "r":  # (an ultimate may run on for seconds by design)
		var kind := "stuck_fire" if hold else "tap_repeat"
		judge.flag(
			hero,
			sc,
			kind,
			(
				"%d activity events from %.1f s after the release (last at +%.2f s)"
				% [late, Judge.LATE_S, float(meas["last_act_s"])]
			)
		)
	var empty_glove := name == "q" and (me.gear[0] as Dictionary).is_empty()
	meas["empty_glove"] = empty_glove
	if not hold and total == 0 and not empty_glove:
		judge.flag(hero, sc, "tap_none", "a %d-frame tap: no shot, swing, cast, kit move or slot use in 1.7 s" % TAP)
	if float(meas["walk_m"]) < 0.8:
		judge.flag(
			hero, sc, "no_control", "1.7 s after the release, A moved only %.2f m in 0.66 s" % float(meas["walk_m"])
		)
	_end(sc, meas)


# ---------------------------------------------------------------- inputs during other states and under UI
func _states() -> void:
	# LMB during a dash
	await _begin(_flat())
	_key(KEY_D, true)
	await _frames(20)
	await _tap(KEY_SHIFT)
	await _frames(2)
	await _tap(-MOUSE_BUTTON_LEFT)
	await _frames(50)
	_key(KEY_D, false)
	await _frames(20)
	var n := Judge.acts(ss, 22, ss.size())
	_end("fire_in_dash", {"acts": n})
	if n == 0:
		judge.flag(hero, "fire_in_dash", "eaten_input", "LMB tapped 2 frames into a dash: no attack within 1 s")
	# LMB at the top of a jump
	await _begin(_flat())
	await _tap(KEY_SPACE)
	await _frames(16)
	var at := ss.size()
	await _tap(-MOUSE_BUTTON_LEFT)
	await _frames(70)
	n = Judge.acts(ss, at, ss.size())
	_end("fire_in_jump", {"acts": n, "air_s": Judge.air_s(ss, 0), "landed": ss[-1]["g"]})
	if n == 0:
		judge.flag(hero, "fire_in_jump", "eaten_input", "LMB tapped at the top of a jump: no attack within 1 s")
	# LMB and Shift while gliding
	await _begin(_flat() + Vector3(0, HIGH, 0))
	await _frames(6)
	_key(KEY_SPACE, true)
	await _frames(30)
	at = ss.size()
	await _tap(-MOUSE_BUTTON_LEFT)
	await _frames(20)
	var still_gl: bool = ss[-1]["gl"]
	var fire_n := Judge.acts(ss, at, ss.size())
	var dash_at := ss.size()
	await _tap(KEY_SHIFT)
	await _frames(40)
	_key(KEY_SPACE, false)
	await _frames(120)
	_end(
		"glide_fire_dash",
		{
			"acts": fire_n,
			"glide_kept": still_gl,
			"dashes": Judge.dash_starts(ss, dash_at, ss.size()),
			"end_gliding": ss[-1]["gl"]
		}
	)
	if ss[-1]["gl"]:
		judge.flag(
			hero, "glide_fire_dash", "glide_stuck", "fire then dash under the glider: still gliding 2 s after release"
		)
	await _map_mid_hold("map_lmb", -MOUSE_BUTTON_LEFT, KEY_M)
	await _map_mid_hold("map_rmb", -MOUSE_BUTTON_RIGHT, KEY_M)
	await _map_mid_hold("pack_lmb", -MOUSE_BUTTON_LEFT, KEY_I)
	await _map_move()
	await _focus_loss()


## Hold an attack, open the map (or the pack) with its key, let the attack go under it, shut it, watch.
func _map_mid_hold(sc: String, code: int, ui_key: int) -> void:
	await _begin(_flat())
	_key(code, true)
	await _frames(30)
	await _tap(ui_key)
	await _frames(30)
	var ui_up: bool = ss[-1]["map"] or (m.hud != null and m.hud.pack_open())
	_key(code, false)
	await _frames(30)
	if ui_key == KEY_I:
		await _tap(KEY_ESCAPE)
	else:
		await _tap(ui_key)
	var shut := ss.size()
	await _frames(120)
	var late := Judge.acts(ss, shut + 30, ss.size())
	_end(sc, {"ui_opened": ui_up, "acts_after_close": Judge.acts(ss, shut, ss.size()), "late_acts": late})
	if late >= Judge.LATE_EVENTS:
		judge.flag(
			hero,
			sc,
			"stuck_fire",
			"button let go under the %s; %d attacks after it closed" % ["map" if ui_key == KEY_M else "pack", late]
		)


## Walk, open the map, let the key go under the map, close it: the hunter must stop. While the map is up and D is
## held the body moves or stands, but the model must match.
func _map_move() -> void:
	await _begin(_flat())
	_key(KEY_D, true)
	await _frames(30)
	await _tap(KEY_M)
	var up := ss.size()
	await _frames(40)
	var mv_up := Judge.top_speed(ss, up + 10, ss.size())
	_key(KEY_D, false)
	await _frames(20)
	await _tap(KEY_M)
	await _frames(60)
	var meas := {"map_opened": ss[up]["map"], "mps_map_up": mv_up, "mps_after_close": Judge.hspeed(ss[-1])}
	if float(meas["mps_after_close"]) > Judge.STILL:
		judge.flag(
			hero,
			"map_move",
			"stuck_move",
			"D let go under the map; still %.2f m/s 1 s after it closed" % meas["mps_after_close"]
		)
	_end("map_move", meas)


## Hold D and LMB, the window loses focus (the engine lets every key go, then refocuses): all of it must stop.
func _focus_loss() -> void:
	await _begin(_flat())
	_key(KEY_D, true)
	_key(-MOUSE_BUTTON_LEFT, true)
	await _frames(30)
	main.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_release_all()
	await _frames(20)
	main.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var back := ss.size()
	await _frames(80)
	var meas := {"mps_after": Judge.hspeed(ss[-1]), "late_acts": Judge.acts(ss, back + 30, ss.size())}
	if float(meas["mps_after"]) > Judge.STILL:
		judge.flag(hero, "focus_loss", "stuck_move", "keys let go on focus loss; still %.2f m/s" % meas["mps_after"])
	if int(meas["late_acts"]) >= Judge.LATE_EVENTS:
		judge.flag(hero, "focus_loss", "stuck_fire", "%d attacks after focus came back" % meas["late_acts"])
	_end("focus_loss", meas)


# ---------------------------------------------------------------- collisions and the map's shapes
func _collisions() -> void:
	if feats.has("wall"):
		await _push("wall", KEY_SHIFT)
		await _push("wall", -1)
	for f in ["step_up", "step_down", "stairs"]:
		if feats.has(f):
			await _cross(f)
	if feats.has("edge"):
		await _edge()
	await _bodies()
	await _knock()
	await _wander()


## Run into the wall (dash into it with `extra` = Shift), hold 1.2 s, then walk away.
func _push(name: String, extra: int) -> void:
	var sc := "wall_dash" if extra > 0 else "wall_walk"
	var d := _dir(name)
	var key: int = KEY_OF[d]
	await _begin(feats[name]["at"], Vector2(d))
	_key(key, true)
	if extra > 0:
		await _frames(10)
		await _tap(extra)
	await _frames(80)
	var a := ss.size() - 40
	var inside := 0
	for s in ss:
		inside += int(
			(
				w.is_block((s["p"] as Vector3).x, (s["p"] as Vector3).z)
				and not w.is_stand_block((s["p"] as Vector3).x, (s["p"] as Vector3).z)
			)
		)
	var jit := Judge.jitter(ss, a, ss.size(), Vector2(d))
	_key(key, false)
	var back_key: int = KEY_OF[-d]
	_key(back_key, true)
	var away := ss.size()
	await _frames(40)
	_key(back_key, false)
	await _frames(10)
	var meas := {
		"inside_f": inside,
		"jitter_m": jit,
		"away_m": Judge.flat_dist(ss, away, away + 40),
		"launch_mps": _max_vy(0, away)
	}
	if inside > 0:
		judge.flag(hero, sc, "through_wall", "%d frames with the body inside a wall tile" % inside)
	if jit > Judge.JITTER_M:
		judge.flag(hero, sc, "wall_jitter", "pushed back %.2f m in one frame while holding into the wall" % jit)
	if float(meas["away_m"]) < 1.0:
		judge.flag(hero, sc, "stuck_geo", "walking away from the wall moved %.2f m in 0.66 s" % float(meas["away_m"]))
	if float(meas["launch_mps"]) > 5.0:
		judge.flag(hero, sc, "launch", "thrown up at %.1f m/s at the wall" % float(meas["launch_mps"]))
	_end(sc, meas)


func _max_vy(a: int, b: int) -> float:
	var top := 0.0
	for i in range(maxi(0, a), mini(b, ss.size())):
		top = maxf(top, (ss[i]["v"] as Vector3).y)
	return top


## Walk across a terrace step (up or down) or a flight of stairs: how far it gets, how much speed it loses.
func _cross(name: String) -> void:
	var d := _dir(name)
	var key: int = KEY_OF[d]
	await _begin(feats[name]["at"], Vector2(d))
	_key(key, true)
	await _frames(110)
	_key(key, false)
	await _frames(20)
	var p0: Vector3 = ss[0]["p"]
	var p1: Vector3 = ss[-1]["p"]
	var low := INF
	for i in range(40, 110):
		low = minf(low, Judge.hspeed(ss[i]))
	var meas := {
		"dist_m": Judge.flat_dist(ss, 0, ss.size() - 1),
		"rise_m": p1.y - p0.y,
		"min_mps": low,
		"top_mps": Judge.top_speed(ss, 0, 110),
		"launch_mps": _max_vy(0, ss.size())
	}
	if float(meas["dist_m"]) < 3.0:
		judge.flag(
			hero,
			name,
			"stuck_geo" if name != "step_up" else "ledge_stop",
			"held %s 1.8 s at the %s: moved %.2f m" % [OS.get_keycode_string(key), name, float(meas["dist_m"])]
		)
	elif name == "stairs" and low < 0.4 * float(meas["top_mps"]):
		judge.flag(
			hero, name, "stuck_geo", "speed drops to %.1f of %.1f m/s on the stairs" % [low, float(meas["top_mps"])]
		)
	if float(meas["launch_mps"]) > 6.0 and name != "step_up":
		judge.flag(hero, name, "launch", "thrown up at %.1f m/s" % float(meas["launch_mps"]))
	_end(name, meas)


## Walk off the island's edge and keep the key down: what brings the hunter back, and is it ever lost below.
func _edge() -> void:
	var d := _dir("edge")
	var key: int = KEY_OF[d]
	await _begin(feats["edge"]["at"], Vector2(d))
	_key(key, true)
	await _frames(110)
	_key(key, false)
	await _frames(300)
	var low_y := INF
	for s in ss:
		low_y = minf(low_y, (s["p"] as Vector3).y)
	var meas := {
		"walked_m": Judge.flat_dist(ss, 0, 110),
		"min_y": low_y,
		"end_grounded": ss[-1]["g"],
		"end_gliding": ss[-1]["gl"],
		"died": ss[-1]["out"],
		"end_y": (ss[-1]["p"] as Vector3).y
	}
	if not ss[-1]["g"] and not ss[-1]["out"] and not ss[-1]["gl"]:
		judge.flag(
			hero,
			"edge",
			"out_of_map",
			"6 s after walking off the edge: not on ground, not gliding, y %.1f" % meas["end_y"]
		)
	_end("edge", meas)


## Walk into the other Hunter and into your own Boki.
func _bodies() -> void:
	for who in ["hunter", "boki"]:
		var body: Ent = foe if who == "hunter" else me.kin
		if body == null:
			continue
		await _begin(_flat())
		body.teleport(me.pos + Vector3(3, 0, 0))
		if body is Hunter:
			(body as Hunter).ctrl = "idle"
		_key(KEY_D, true)
		await _frames(90)
		_key(KEY_D, false)
		await _frames(20)
		var through := false
		var bx: float = body.pos.x
		var crossed: bool = (ss[-1]["p"] as Vector3).x > bx + 0.3
		var near := INF
		for s in ss:
			near = minf(near, Vector2((s["p"] as Vector3).x - body.pos.x, (s["p"] as Vector3).z - body.pos.z).length())
		through = crossed and near < 0.3 and body.hittable()
		var sc: String = "walk_into_" + who
		var meas := {
			"solid": body.hittable(),
			"crossed": crossed,
			"nearest_m": near,
			"launch_mps": _max_vy(0, ss.size()),
			"dist_m": Judge.flat_dist(ss, 0, ss.size() - 1)
		}
		if through:
			judge.flag(hero, sc, "through_body", "walked through it (closest %.2f m)" % near)
		if float(meas["launch_mps"]) > 5.0:
			judge.flag(hero, sc, "launch", "thrown up at %.1f m/s" % float(meas["launch_mps"]))
		_end(sc, meas)


## A strong shove through the game's own knock (Displace.knock, what an ability calls): the slide, and control back.
func _knock() -> void:
	await _begin(_flat())
	m.displace.knock(me, KNOCK, 2.0)
	await _frames(70)
	var stop := ss.size()
	_key(KEY_A, true)
	await _frames(40)
	_key(KEY_A, false)
	await _frames(10)
	var meas := {
		"slide_m": Judge.flat_dist(ss, 0, stop),
		"air_s": Judge.air_s(ss, 0),
		"landed": ss[stop - 1]["g"],
		"walk_m": Judge.flat_dist(ss, stop, stop + 40)
	}
	if float(meas["walk_m"]) < 1.0:
		judge.flag(hero, "knock", "no_control", "1.2 s after the shove, A moved %.2f m in 0.66 s" % meas["walk_m"])
	_end("knock", meas)
	if feats.has("wall"):
		var d := _dir("wall")
		await _begin(feats["wall"]["at"], Vector2(d))
		m.displace.knock(me, Vector2(d) * KNOCK.length(), 1.0)
		await _frames(80)
		var inside := 0
		for s in ss:
			inside += int(
				(
					w.is_block((s["p"] as Vector3).x, (s["p"] as Vector3).z)
					and not w.is_stand_block((s["p"] as Vector3).x, (s["p"] as Vector3).z)
				)
			)
		_end("knock_wall", {"inside_f": inside, "end_mps": Judge.hspeed(ss[-1])})
		if inside > 0:
			judge.flag(hero, "knock_wall", "through_wall", "shoved into a wall: %d frames inside it" % inside)


## Short walks from seeded spots in each direction: held keys that go nowhere with no wall ahead = stuck.
func _wander() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var stuck := 0
	var where := []
	for i in 8:
		var at := w.random_ground()
		at.y = w.ground_at(at.x, at.z)
		var d: Vector2i = KEY_OF.keys()[rng.randi_range(0, 3)]
		await _begin(at, Vector2(d))
		var key: int = KEY_OF[d]
		_key(key, true)
		await _frames(50)
		_key(key, false)
		await _frames(5)
		var slow := 0
		for j in range(15, 50):
			var p: Vector3 = ss[j]["p"]
			var ahead := Vector2(p.x, p.z) + Vector2(d) * 0.9
			var wall := (
				w.is_block(ahead.x, ahead.y)
				or w.is_void(ahead.x, ahead.y)
				or w.ground_at(ahead.x, ahead.y) > p.y + World.STEP
			)
			if Judge.hspeed(ss[j]) < 0.3 and not wall and ss[j]["g"]:
				slow += 1
		if slow >= 20:
			stuck += 1
			where.append("(%.0f, %.0f) %s" % [at.x, at.z, OS.get_keycode_string(key)])
	var meas := {"walks": 8, "stuck": stuck}
	if stuck > 0:
		judge.flag(hero, "wander", "stuck_geo", "stuck with open ground ahead at " + ", ".join(where))
	_end("wander", meas)


# ---------------------------------------------------------------- the seed's map features
## Spots on the seed's map, found once: a long flat lane, a wall, a step up and down, stairs and the island edge,
## each with a straight flat run-up and the direction to walk.
func _find_feats() -> void:
	if not feats.is_empty():
		return
	var c := Vector2i(int(me.pos.x), int(me.pos.z))
	for r in SEARCH:
		for dz in range(-r, r + 1):
			for dx in [-r, r] if absi(dz) != r else range(-r, r + 1):
				var t := c + Vector2i(dx, dz)
				for d in KEY_OF:
					_try_feat(t, d)
		if feats.size() >= 6:
			break


func _try_feat(t: Vector2i, d: Vector2i) -> void:
	var run_up := 7
	if not feats.has("flat") and _lane(t, d, LANE):
		feats["flat"] = {"at": _spot(t), "dir": d}
		return
	if not _lane(t - d * run_up, d, run_up):
		return
	var lv := _lv(t - d)
	var nx := t
	var i := w.idx(nx.x, nx.y) if w.inb(nx.x, nx.y) else -1
	if i < 0:
		return
	var at := _spot(t - d * run_up)
	if not feats.has("wall") and w.kind[i] == World.T_BLOCK and not w.block_top.has(i):
		feats["wall"] = {"at": at, "dir": d}
	elif not feats.has("edge") and w.kind[i] == World.T_VOID and _all_void(t, d, 3):
		feats["edge"] = {"at": at, "dir": d}
	elif not feats.has("stairs") and w.stairs.has(i) and w.stairs[i] == d:
		feats["stairs"] = {"at": at, "dir": d}
	elif w.kind[i] != World.T_GROUND or w.stairs.has(i) or not _lane(t, d, 4):
		return
	elif not feats.has("step_up") and _lv(t) == lv + 1:
		feats["step_up"] = {"at": at, "dir": d}
	elif not feats.has("step_down") and _lv(t) <= lv - 1:
		feats["step_down"] = {"at": at, "dir": d}


func _lv(t: Vector2i) -> int:
	return int(w.level[w.idx(t.x, t.y)]) if w.inb(t.x, t.y) else -99


## n tiles from t along d, three wide: plain ground (no block, stairs, void), one level, no bush.
func _lane(t: Vector2i, d: Vector2i, n: int) -> bool:
	var side := Vector2i(d.y, d.x)
	var lv := _lv(t)
	for k in n:
		for s: int in [-1, 0, 1]:
			var q := t + d * k + side * s
			if not w.inb(q.x, q.y):
				return false
			var i := w.idx(q.x, q.y)
			if (
				w.kind[i] != World.T_GROUND
				or w.stairs.has(i)
				or int(w.level[i]) != lv
				or w.in_bush(q.x + 0.5, q.y + 0.5)
			):
				return false
	return true


func _all_void(t: Vector2i, d: Vector2i, n: int) -> bool:
	for k in n:
		var q := t + d * k
		if w.inb(q.x, q.y) and w.kind[w.idx(q.x, q.y)] != World.T_VOID:
			return false
	return true


func _spot(t: Vector2i) -> Vector3:
	return Vector3(t.x + 0.5, w.ground_at(t.x + 0.5, t.y + 0.5), t.y + 0.5)
