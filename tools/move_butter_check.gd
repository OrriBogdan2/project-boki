extends RefCounted
## --move-butter-check [--butter-hero=<arch>] [--butter-csv=<file>] [--shots-dir=<dir>]: how smooth movement looks, where
## --move-feel-check measures how fast it answers. One Hero with clips runs the real frame (Match._process; the
## check holds the keys and the aim) through a course carved on flat ground: a run with a 90 degree turn and a stop,
## a chain of five 1.6 m ledges (jump and push in at each face), a run off the top into a glide that bends 45
## degrees, and a landing run on. Visual only: it reads the posed skeleton, the clip channels and the camera.
##
## Prints "BUTTER <key> = <value> <unit> target <op> <target> ok|FAIL (why)" and "MOVE BUTTER CHECK DONE, failures: N";
## --butter-csv (default <dir>/butter_trace.csv) gets the per-frame speed, heading, lean and bank (the velocity graph). With
## --shots-dir every second frame goes to <dir>/frames/NNNNN.jpg (run it under jobq --needs gpu):
##   ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg -c:v libx264 -crf 24 -pix_fmt yuv420p butter.mp4
## Never writes the save.

const DT := 1.0 / 60.0
const LEDGES := 5               # steps in the chain
const STEP_LV := 2              # terraces a step rises (1.6 m)
const STEP_DEEP := 4            # tiles a step runs back
const TOP_DEEP := 6             # tiles of the top step, the run-up to the glide
const LANE := 2                 # tiles either side of the course's line
const RUN_IN := 10              # tiles of flat ground before the first step
const AFTER := 22               # tiles of flat ground past the top for the glide to come down on
const GLIDE_STEPS := 80         # steps under the glider before letting go to land
const JUMP_AT := 1.1            # m from a face the check jumps (a player's timing)

## key -> [op, target, unit, why]
const T := {
	"turn_bank_deg":       [">=", 4.0, "deg", "leans into a 90 degree turn at a run"],
	"start_lean_deg":      [">=", 2.0, "deg", "pulling away tips him past his running lean"],
	"stop_lean_deg":       [">=", 2.0, "deg", "a stop rocks him back past standing"],
	"pose_pop_m":          ["<=", 0.09, "m", "the head never jumps more than this against the feet in a frame"],
	"clip_switches":       ["<=", 30.0, "", "clip changes over the whole course"],
	"foot_slide_s":        ["<=", 0.05, "s", "a full-body clip holding the legs while you run"],
	"ledges_topped":       [">=", 5.0, "", "every ledge of the chain climbed"],
	"chain_t":             ["<=", 5.5, "s", "first face to standing on the top"],
	"chain_stall_s":       ["<=", 1.0, "s", "time the climb spends under 1 m/s across the ground (pressed to a face)"],
	"mantle_vy_kick":      ["<=", 3.0, "m/s", "the most the rise changes speed in a step beyond gravity (pops)"],
	"glide_bank_deg":      [">=", 6.0, "deg", "banks into a turn under the glider"],
	"land_recover_s":      ["<=", 0.12, "s", "touchdown to 90% of run speed, keys held"],
	"cam_jerk":            ["<=", 60.0, "m/s2", "the camera's sharpest change of speed over the course"],
}

var bad := 0
var m: Match
var w: World
var P: Hunter
var clips: WardenClips
var sync: WardenGlb.Sync
var skel: Skeleton3D
var head := -1
var shots := ""
var csv_path := ""
var frame := 0
var main: Node
var trace := PackedStringArray(["t,phase,speed,heading_deg,lean_deg,bank_deg,act_w,air_w,clip,y,vy,mantling,grounded,pop_m,cam_acc"])
var t := 0.0
var phase := ""
var res := {}
# per-frame history
var last_head := Vector3.INF
var last_cur := ""
var switches := 0
var pop := 0.0
var slide := 0.0
var cam_p: Array = []           # the last three camera focus points
var cam_jerk := 0.0
var cam_wait := 0              # frames after a teleport the camera is still settling from its snap (not measured)
var lean_now := 0.0             # this frame's forward tip (deg) and side tip (deg, + toward the right)
var bank_now := 0.0

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var who := "gunslinger"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--butter-hero="): who = String(a).substr(14)
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
		if String(a).begins_with("--butter-csv="): csv_path = String(a).substr(13)
	if csv_path == "" and shots != "":
		csv_path = shots.path_join("butter_trace.csv")
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": true,
			"tut_test": true, "arch": who, "cls": Arch.weight(who), "weapon": Arch.signature(who)})
	m.set_process(false)
	w = m.world
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if h != P: h.teleport(Vector3(-500, 50, -500)); h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.unlock_all()
	if m.hud: m.hud.visible = false
	var o := _course()
	if o == Vector3.INF:
		print("BUTTER no flat strip for the course"); bad += 1
		return _done()
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots.path_join("frames"))
		await w.build_meshes()
	sync = P.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	clips = sync.clips if sync else null
	if clips == null:
		print("BUTTER %s has no clips: nothing to measure" % who); bad += 1
		return _done()
	skel = clips.skel
	sync.set_process(false)     # (posed once a step, below: the same clock as the sim)
	head = WardenSkeleton.find(skel, "head")
	print("BUTTER hero %s, course at %s" % [who, str(o)])
	_put(o)
	await _turn(o)
	await _chain(o)
	await _glide(o)
	rec("pose_pop_m", pop)
	rec("clip_switches", switches)
	rec("foot_slide_s", slide)
	rec("cam_jerk", cam_jerk)
	if csv_path != "":
		FileAccess.open(csv_path, FileAccess.WRITE).store_string("\n".join(trace) + "\n")
	_done()

func _done() -> void:
	print("MOVE BUTTER CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func rec(key: String, v: float) -> void:
	res[key] = v
	var tg: Array = T[key]
	var ok := v >= float(tg[1]) - 1e-6 if tg[0] == ">=" else v <= float(tg[1]) + 1e-6
	print("BUTTER %-18s = %7.3f %-5s target %s %s %s   (%s)" % [key, v, tg[2], tg[0], str(tg[1]), "ok" if ok else "FAIL", tg[3]])
	if not ok: bad += 1

# ---------------------------------------------------------------- the course
## A strip of ground along +x (RUN_IN + the steps + AFTER tiles, LANE either side), levelled flat with anything
## standing on it cleared, the steps carved into it. The start.
func _course() -> Vector3:
	var span := RUN_IN + LEDGES * STEP_DEEP + TOP_DEEP + AFTER
	for z in range(LANE + 4, w.h - LANE - 4, 3):
		for x in range(4, w.w - span - 4, 3):
			if not _ground(x, z, span):
				continue
			var lv := int(w.level[w.idx(x, z)])
			for dz in range(-LANE - 3, LANE + 4):
				for dx in range(-2, span + 2):
					var i := w.idx(x + dx, z + dz)
					w.level[i] = lv
					for d: Dictionary in [w.stairs, w.walls, w.props, w.sheer]:
						d.erase(i)
			for k in LEDGES:
				var x0 := x + RUN_IN + k * STEP_DEEP
				var deep := STEP_DEEP * (LEDGES - k) + TOP_DEEP - STEP_DEEP
				for dz in range(-LANE, LANE + 1):
					for dx in deep:
						w.level[w.idx(x0 + dx, z + dz)] = lv + STEP_LV * (k + 1)
			return Vector3(x + 2.5, lv * World.LEVEL, z + 0.5)
	return Vector3.INF

## Ground all over the strip (no void, water or bridge), so levelling it leaves no hole.
func _ground(x: int, z: int, span: int) -> bool:
	for dz in range(-LANE - 3, LANE + 4):
		for dx in range(-2, span + 2):
			var i := w.idx(x + dx, z + dz)
			if w.kind[i] != World.T_GROUND or w.bridge.has(i):
				return false
	return true

# ---------------------------------------------------------------- the frame
## One real frame: exactly one sim step, the render, the camera; then the measures of what it drew.
func _frame(mv: Vector2, jump := false, glide := false) -> void:
	P.inp["move"] = mv
	P.inp["jump"] = jump
	P.inp["glide"] = glide
	var hv := Vector2(P.vel.x, P.vel.z)
	var ahead := mv if mv.length() > 0.1 else (hv.normalized() if hv.length() > 0.5 else Vector2(1, 0))
	P.inp["aim"] = P.pos + Vector3(ahead.x, 0.0, ahead.y) * 6.0
	m.acc = 0.0
	m._process(DT)
	sync._process(DT)
	t += DT
	_measure()
	if shots != "":
		await main.get_tree().process_frame
		if frame % 2 == 0:
			main.get_viewport().get_texture().get_image().save_jpg(shots.path_join("frames/%05d.jpg" % (frame / 2)), 0.9)
	frame += 1

func _measure() -> void:
	# the head against the feet, in the model's frame (the camera's lean toward it is the model's own basis)
	var hp := (P.model.global_transform.affine_inverse() * (skel.global_transform * skel.get_bone_global_pose(head).origin))
	var pop_now := hp.distance_to(last_head) if last_head != Vector3.INF else 0.0
	pop = maxf(pop, pop_now)
	last_head = hp
	var tall := maxf(0.5, hp.y)
	# (the model faces -Z: forward is -z, right is +x)
	lean_now = rad_to_deg(atan2(-hp.z, tall))
	bank_now = rad_to_deg(atan2(hp.x, tall))
	if clips.cur != last_cur and clips.cur != "":
		switches += 1
	last_cur = clips.cur
	var spd := Vector2(P.vel.x, P.vel.z).length()
	if P.grounded and spd > 1.5 and clips.act_w > 0.5:
		slide += DT
	cam_p.append(m.cam.focus)
	if cam_p.size() > 3: cam_p.pop_front()
	var cam_acc := 0.0
	if cam_p.size() == 3:
		cam_acc = ((cam_p[2] - cam_p[1]) - (cam_p[1] - cam_p[0])).length() / (DT * DT)
	cam_wait -= 1
	if cam_wait < 0:
		cam_jerk = maxf(cam_jerk, cam_acc)
	trace.append("%.3f,%s,%.3f,%.1f,%.2f,%.2f,%.2f,%.2f,%s,%.2f,%.2f,%d,%d,%.3f,%.1f" % [t, phase, spd, rad_to_deg(atan2(P.vel.z, P.vel.x)),
			lean_now, bank_now, clips.act_w, clips.air_w, clips.cur, P.pos.y, P.vel.y, int(P.mantling()), int(P.grounded), pop_now, cam_acc])

## Stands the player at p, the camera on him (and its history cleared, so the jump isn't a jerk).
func _put(p: Vector3) -> void:
	P.teleport(p)
	P.vel = Vector3.ZERO
	m.cam.snap(P.pos)
	cam_p.clear()
	cam_wait = 10
	last_head = Vector3.INF

## Mean of `f` (lean or bank) over n frames of a given input.
func _hold(mv: Vector2, n: int, side := false) -> float:
	var s := 0.0
	for i in n:
		await _frame(mv)
		s += bank_now if side else lean_now
	return s / n

# ---------------------------------------------------------------- the run, the turn, the stop
func _turn(o: Vector3) -> void:
	phase = "turn"
	# along the lane's start: -z then a 90 degree turn to +x (a right turn as the model sees it), then let go
	_put(o + Vector3(0, 0, LANE))
	for i in 20: await _frame(Vector2.ZERO)
	var still := await _hold(Vector2.ZERO, 10)
	var start_peak := -90.0
	for i in 12:
		await _frame(Vector2(0, -1))
		start_peak = maxf(start_peak, lean_now)
	var run_lean := await _hold(Vector2(0, -1), 30)
	var start := start_peak - run_lean
	var run_bank := await _hold(Vector2(0, -1), 1, true)
	var bank := 0.0
	for i in 24:
		await _frame(Vector2(1, 0))
		bank = maxf(bank, bank_now - run_bank)
	var stop := 0.0
	for i in 40:
		await _frame(Vector2.ZERO)
		stop = maxf(stop, still - lean_now)
	rec("start_lean_deg", start)
	rec("turn_bank_deg", bank)
	rec("stop_lean_deg", stop)

# ---------------------------------------------------------------- five ledges
func _chain(o: Vector3) -> void:
	phase = "chain"
	_put(o)
	for i in 20: await _frame(Vector2.ZERO)
	var x_top := o.x - 2.5 + RUN_IN + (LEDGES - 1) * STEP_DEEP
	var top_y := w.ground_at(x_top + 1.5, o.z)
	var t0 := -1.0
	var done := -1.0
	var stall := 0.0
	var kick := 0.0
	var vy0 := P.vel.y
	for i in 600:
		var next := _next_face()
		var jump := P.grounded and next > 0.0 and next - P.pos.x < JUMP_AT
		await _frame(Vector2(1, 0), jump)
		if t0 < 0.0 and P.mantling(): t0 = t
		if t0 >= 0.0 and done < 0.0:
			if Vector2(P.vel.x, P.vel.z).length() < 1.0: stall += DT
			if not P.grounded: kick = maxf(kick, absf(P.vel.y - (vy0 - Hunter.H_GRAV * DT)) if P.mantling() else 0.0)
		vy0 = P.vel.y
		if done < 0.0 and P.grounded and P.pos.y >= top_y - 0.05:
			done = t
			break
	var topped := 0
	for k in LEDGES:
		if P.pos.y >= w.ground_at(o.x - 2.5 + RUN_IN + k * STEP_DEEP + 0.5, o.z) - 0.05: topped += 1
	rec("ledges_topped", topped)
	rec("chain_t", done - t0 if done > 0.0 and t0 >= 0.0 else 99.0)
	rec("chain_stall_s", stall)
	rec("mantle_vy_kick", kick)

## x of the next face ahead along the lane (0 when none is within 3 m).
func _next_face() -> float:
	var g := w.ground_at(P.pos.x, P.pos.z)
	for k in 30:
		var x := P.pos.x + 0.1 * k
		if w.ground_at(x, P.pos.z) > g + World.STEP:
			return x
	return 0.0

# ---------------------------------------------------------------- off the top into a glide, a landing
func _glide(o: Vector3) -> void:
	phase = "glide"
	var g0 := w.ground_at(P.pos.x, P.pos.z)
	var opened := false
	var bank := 0.0
	var bank0 := 0.0
	var turned := 0
	for i in 400:
		var off := w.ground_at(P.pos.x, P.pos.z) < g0 - 1.0
		# over the edge: Space (a press opens the glider), held; bend 45 degrees once it has carried a moment
		var keys := Vector2(1, 0)
		if opened and P.gliding:
			turned += 1
			if turned == 30: bank0 = bank_now
			if turned > 30: keys = Vector2(1, 1).normalized()
			if turned > 30: bank = maxf(bank, bank_now - bank0)
		var press := off and not opened and not P.grounded
		await _frame(keys, press, off and not P.grounded and turned < GLIDE_STEPS)
		if press: opened = true
		if opened and P.grounded:
			break
	rec("glide_bank_deg", bank)
	phase = "land"
	var rec_t := -1.0
	for i in 60:
		await _frame(Vector2(1, 1).normalized())
		if rec_t < 0.0 and Vector2(P.vel.x, P.vel.z).length() >= 0.9 * P.base_speed: rec_t = (i + 1) * DT
	rec("land_recover_s", rec_t if rec_t > 0.0 else 9.0)
	for i in 30: await _frame(Vector2.ZERO)
