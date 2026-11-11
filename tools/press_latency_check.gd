extends RefCounted
## --press-latency-check: frames from a key press to the first frame its result shows, for every hero's
## LMB, RMB, E, R, dash and jump at 60 and 144 Hz. It drives Match._process (the real path: Input actions,
## _gather_input, the fixed 60 Hz steps, the interpolated render) one call per engine frame at the case's
## refresh rate and stamps two frames per press: "sim", the first frame the simulation acted on it (a shot,
## a charge spent, a cast, a dash or jump under way, a draw or wind-up started), and "vis", the first frame
## something shows on screen (a shot or node spawned, the hunter's rendered position moving, the cast or
## kit-move pose, a swing, the bow draw, the muzzle flash). Frame 0 is the frame of the press.
## Beside them, from the press, the first frame of each change the source footage can show: "pose" (a body
## bone as the model's driver drew it, past the idle's own drift), "shot" (a shot spawned) and "move" (the hunter
## displaced).
## Taps are 33 ms (2 frames at 60 Hz, 5 at 144). An RMB with a hold variant (archetype rmb "hold") and a
## sword with a charge (weapon "charge_time") go off on the release by design: those are stamped from the
## release, and the press-to-first-sign frame is printed beside them. A key whose tap shows nothing by design
## (HELD) is held through the watch and stamped from its hold threshold, the same way. At 144 Hz each press is
## tried at every phase of the 60 Hz accumulator (0, 1 and 2 frames into a tick) and the latest kept.
## Budget: 2 frames at 60 Hz, the same 33 ms at 144 Hz (4 frames). Source rows (FOOTAGE): at 60 Hz, the
## first of pose, shot and move must sit within one footage frame of the source's. Run it under --fixed-fps 60:
## a model's clips blend on the engine's frame time, which Engine.time_scale then sets to each case's frame.
## The findings and the tables are in docs/MOVEMENT_FEEL.md ("Press to picture"). It never touches the save.
##
## Prints "PRESS <hz>Hz <hero> <key> sim <n> vis <n> (<what>) [press->sign <n>]  pose <n> shot <n> move <n>
## allow <= N  ok|FAIL" per case, "PRESSREF <hero> <key> first <n> source <n> ... ok|FAIL" per source row and
## "PRESS LATENCY CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var P: Hunter
var T: Hunter                # a foe 4 m ahead, so hooks, marks and shots have something to land on
var main: Node
var flat := Vector3.ZERO     # where this press happens
var spots: Array = []        # flat spots far apart; each press takes the next, away from the last one's leftovers
var spot_i := 0
var noisy := false           # nodes were still spawning on their own before the press: the node signal is off
var unrest := ""             # the hunter was not at rest when the press came (the case is void): what still moved
var km_last := {}            # the kit-move channels one frame ago (a move still playing changes them)
var pose_rest := PackedVector3Array()    # the model's bones the frame before the press, in the hunter's space
var pose_last := PackedVector3Array()    # the same, one frame ago (while settling)
var pose_drift := PackedFloat32Array()   # m: the most each bone moved in one frame of the idle before the press
const HZ := [60, 144]
const BUDGET_S := 2.0 / 60.0           # s: two frames at 60 Hz, the same wall time at every refresh rate
const TAP_S := 0.033                   # s: how long a key is down (a quick click)
const WATCH_S := 0.6                   # s: how long a press is watched for its result
const SETTLE_S := 0.75                 # s: the least rest between cases
const SETTLE_MAX_S := 4.0              # s: the most, waiting for the last case's move, flight or lantern to end
const BASE_S := 0.15                   # s: the end of the settle, watched for nodes spawning on their own
const MOVE_EPS := 0.003                # m: a rendered move this big counts as seen
const POSE_EPS := 0.02                 # m: a bone this far past the idle's own drift is a new pose
const POSE_QUIET := 0.9                # m/s: a bone faster than this is still playing a move, not the idle
const SPOTS := 24                      # spots in the ring: a spot is reused only ~24 presses (30 s+) later
const SPOT_GAP := 14.0                 # m: between spots, out of reach of a late shot's blast or a raised rock
const SPOT_TRIES := 3                  # spots tried for one press before it is void (a leftover outlived the ring)
const KEYS := ["lmb", "rmb", "e", "dash", "jump", "r"]      # R last: the Merge changes the hunter's form
const ACTION := {
	"lmb": "fire", "rmb": "secondary", "e": "signature", "dash": "dash", "jump": "jump", "r": "ultimate",
}
const CALIB_SPOT := Vector3(12.0, 0.0, -32.0)       # move_feel_check's flat spot, when the seed keeps it
## Keys played as a hold whose tap shows nothing by design: Lace's Heavy Shot has no tap variant, and Albert's tap
## lowers an aegis that only goes up at the 0.1 s hold.
const HELD := {"archer": "rmb", "bulwark": "rmb"}
const FPS := 60.0                      # the engine's fixed frame rate the check is run at (--fixed-fps)
const FOOT_STEPS := 12                 # 60 Hz steps in one frame of the 5 fps source footage (0.2 s)
## The source's press to first motion, in footage frames (origin/ext/hero-ref-footage, 5 fps): from the frame
## the input first shows (its HUD slot, cast bar or aim lane) to the first that moves (pose, shot or position).
## The frames behind each number: docs/MOVEMENT_FEEL.md, "Press to picture against the source".
const FOOTAGE := {
	"gunslinger": {"lmb": 0, "rmb": 0, "e": 1, "dash": 0},
	"juggernaut": {"lmb": 0, "rmb": 0, "e": 0, "dash": 0},
	"archer": {"lmb": 0, "rmb": 0, "e": 0, "dash": 0},
	"ashwick": {"lmb": 1, "rmb": 0, "e": 1, "dash": 0},
}
const FAR := Vector3(-500, 50, -500)

func run(main_: Node) -> void:
	main = main_
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_tree().root.size = Vector2i(1280, 720)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(FAR)
			h.out = true
			if T == null and h.team != P.team: T = h
	for k in m.kins.duplicate():
		if (k as Kin).owner_h != P:
			m.kins.erase(k)          # the foe's Boki would wake with it and fight; only its hunter is wanted
			if (k as Kin).owner_h: ((k as Kin).owner_h as Hunter).kin = null
			k.queue_free()
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	m.paused = false
	spots = _flat_spots()
	print("PRESS %d flat spots, first %s, target %s" % [spots.size(), str(spots[0]), T.name if T else "none"])
	var heroes := _only()
	if await _fixed_rate():
		for hz in HZ:
			Engine.time_scale = FPS / hz       # every node's frame is the case's (a model's clips blend on it)
			for hero in Arch.ORDER:
				if heroes.is_empty() or hero in heroes:
					for key in KEYS:
						await _case(int(hz), String(hero), String(key))
		Engine.time_scale = 1.0
	print("PRESS LATENCY CHECK DONE, failures: ", bad)
	main.get_tree().quit()

# ---------------------------------------------------------------- one press
func _case(hz: int, hero: String, key: String) -> void:
	var allow := int(floor(BUDGET_S * hz + 1e-6))
	var phases := 3 if hz > 60 else 1
	var worst := {"sim": -1, "vis": -1, "via": "", "sign": -1}
	for ph in phases:
		var r := await _press(hz, hero, key, ph, _held(hero, key))
		if r["vis"] < 0 or r["vis"] > worst["vis"] or worst["via"] == "":
			worst = r
		if r["vis"] < 0: break
	var ok_: bool = worst["sim"] >= 0 and worst["vis"] >= 0 and worst["vis"] <= allow
	if not ok_: bad += 1
	var later := _held(hero, key) or _on_release(hero, key)
	var extra := ("  press->sign %s" % _n(worst["sign"])) if later else ""
	var at: Dictionary = worst.get("at", {"pose": -1, "shot": -1, "move": -1})
	print("PRESS %3dHz %-10s %-4s sim %s vis %s (%s)%s  pose %s shot %s move %s  allow <= %d  %s" % [
		hz, hero, key, _n(worst["sim"]), _n(worst["vis"]), worst["via"], extra, _n(at["pose"]), _n(at["shot"]),
		_n(at["move"]), allow, "ok" if ok_ else "FAIL"])
	if hz == 60 and FOOTAGE.get(hero, {}).has(key):
		_source_row(hero, key, at)

## The source row: our first change the footage could show (pose, shot or move, steps from the press) within one
## footage frame of the source's.
func _source_row(hero: String, key: String, at: Dictionary) -> void:
	var seen: Array = at.values().filter(func(v: int) -> bool: return v >= 0)
	var first: int = seen.min() if not seen.is_empty() else -1
	var frames := int(FOOTAGE[hero][key])
	var src := frames * FOOT_STEPS
	var ok_ := first >= 0 and absi(first - src) <= FOOT_STEPS
	if not ok_: bad += 1
	print("PRESSREF %-10s %-4s first %s steps  source %d footage frame(s) = %d steps  within %d..%d  %s" % [
		hero, key, _n(first), frames, src, maxi(0, src - FOOT_STEPS), src + FOOT_STEPS,
		"ok" if ok_ else "FAIL"])

## Under --fixed-fps 60 the engine's frame time is exact; without it a model's clips blend on whatever time the box
## took, and the pose column means nothing.
func _fixed_rate() -> bool:
	await main.get_tree().process_frame
	var dt := main.get_process_delta_time()
	if absf(dt - 1.0 / FPS) < 1e-6:
		return true
	bad += 1
	print("PRESS FAIL run it under --fixed-fps %d: the engine's frame time here is %.4f s" % [int(FPS), dt])
	return false

## --press-latency-check=<hero>,<hero>: only those heroes (while iterating on one kit); bare: all twelve.
static func _only() -> Array:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--press-latency-check="):
			return Array(String(a).get_slice("=", 1).split(","))
	return []

static func _n(v: int) -> String:
	return "%2d" % v if v >= 0 else "--"

## Is this key played as a hold, its tap showing nothing by design (HELD)? Then it is held through the whole watch,
## and its event is the hold threshold (archetype rmb "hold"), where the design acts.
static func _held(hero: String, key: String) -> bool:
	return HELD.get(hero, "") == key

## Does this key's effect go on the release (a hold variant, a charge)?
func _on_release(hero: String, key: String) -> bool:
	if _held(hero, key):
		return false
	if key == "rmb":
		return float((Arch.def(hero)).get("rmb", {}).get("hold", 0.0)) > 0.0
	if key == "lmb":
		return P.wpn.get("melee", false) and P.wpn.has("charge_time")
	return false

## One press at one accumulator phase: {sim, vis, via, sign, at}, frames counted from the event (the press, the
## release for release-shaped keys, the hold threshold for HELD ones), -1 for never within WATCH_S. sign: press to
## the first visible sign; at: press to the first pose, shot and move.
func _press(hz: int, hero: String, key: String, phase: int, hold: bool) -> Dictionary:
	var dt := 1.0 / hz
	for attempt in SPOT_TRIES:
		await _prep(hero, key, dt)
		if unrest == "": break
		print("PRESS %3dHz %-10s %-4s moved on from a spot still %s" % [hz, hero, key, unrest])
	if unrest != "":
		return {"sim": -1, "vis": -1, "via": "not at rest: " + unrest, "sign": -1}
	var tap := maxi(1, int(round(TAP_S * hz)))
	var ev := tap if _on_release(hero, key) else 0
	if hold:
		ev = int(ceil(float(Arch.def(hero)["rmb"]["hold"]) * hz))
	m.acc = phase * dt      # 144 Hz: where in the 60 Hz tick the press lands
	var n0 := m.shots.size()
	var nodes0 := main.get_tree().get_node_count()
	var rest := P.position
	var km0: Dictionary = P.anim.km.duplicate()
	var base := _state()
	var sim := -1
	var vis := -1
	var via := ""
	var first_sign := -1
	var seen_at := {"pose": -1, "shot": -1, "move": -1}     # frames from the press to each kind of change
	var act := String(ACTION[key])
	for f in int(ceil(WATCH_S * hz)) + ev:
		if f == 0: Input.action_press(act)
		if f == tap and not hold: Input.action_release(act)
		m._process(dt)
		var seen := _visible(n0, nodes0, rest, km0)
		if first_sign < 0 and seen != "": first_sign = f
		if f >= ev:
			if sim < 0 and _state() != base: sim = f - ev
			if vis < 0 and seen != "":
				vis = f - ev
				via = seen
		if seen_at["shot"] < 0 and m.shots.size() > n0: seen_at["shot"] = f
		if seen_at["move"] < 0 and P.position.distance_to(rest) > MOVE_EPS: seen_at["move"] = f
		await main.get_tree().process_frame
		# (the model's driver posed this frame's skeleton after Match._process: read it once the frame is done)
		if seen_at["pose"] < 0 and _pose_moved(f + 1): seen_at["pose"] = f
		if sim >= 0 and vis >= 0 and seen_at.values().min() >= 0: break
	if Input.is_action_pressed(act): Input.action_release(act)
	return {"sim": sim, "vis": vis, "via": via, "sign": first_sign, "at": seen_at}

## The simulation's view of the press: whatever a key can change the frame it lands.
func _state() -> String:
	var ak := P.ak
	var s := "%d %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %s %s %d" % [
		m.shots.size(), P.fire_cd, P.warm_t, P.draw_t, P.spin, P.mel_hold, P.roll_t, P.vel.y, P.cast_at,
		str(P.used), str(P.merge_st.get("phase", "")), P.swing_n]
	if ak:
		s += " %s %.1f %.3f %.3f %s %s %s %d" % [
			str(ak.cd), ak.ch_rmb, ak.e_t, ak.r_t, str(ak.fuse.keys()), str(ak.rmb_down), ak.anim_id,
			int(ak.dash_press_at * 1000.0)]
	return s

## What shows on screen this frame, "" for nothing yet.
func _visible(n0: int, nodes0: int, rest: Vector3, km0: Dictionary) -> String:
	if m.shots.size() > n0: return "shot"
	if P.position.distance_to(rest) > MOVE_EPS: return "move"
	if P.muzzle_t > 0.0: return "muzzle"
	var a: HunterAnim = P.anim
	if a:
		if a.cast_now > 0.0 and a.cast_now < 0.6: return "cast pose"
		if a.km != km0: return "kit move"
		if a.swing_t > 0.0 and a.swing_t < a.swing_dur: return "swing"
	if P.draw_t > 0.0: return "draw"
	if P.spin > 0.0: return "spin-up"
	if P.merge_st.get("phase", "") != "": return "merge"
	if not noisy and main.get_tree().get_node_count() > nodes0: return "node"
	return ""

# ---------------------------------------------------------------- setup
## A fresh hunter of this hero, at rest on the flat spot, the foe ahead and the cursor on it. The rest waits for
## the last case to end (a long kit move, a lantern still in the air, the Merge), then puts the hunter back.
func _prep(hero: String, key: String, dt: float) -> void:
	if KinMerge.active(P): KinMerge.end(P, "check")
	flat = spots[spot_i % spots.size()]
	spot_i += 1
	if P.arch != hero:
		P.reclass(Arch.weight(hero), hero, Arch.signature(hero))     # the hero's own model (set_arch keeps the last)
	_rest(key)
	m.hitstop = 0.0
	m.slowmo = 0.0
	await _settle(dt)       # the last case's move plays out on the kit that started it
	P.set_arch(hero)        # then a fresh kit: nothing that move left behind (a thrown hammer) stays
	_rest(key)
	await _settle(dt)
	_rest(key)
	noisy = false
	var nodes := main.get_tree().get_node_count()
	pose_drift.resize(pose_last.size())
	pose_drift.fill(0.0)
	for i in int(ceil(BASE_S / dt)):
		_aim_at_target()
		m._process(dt)
		if main.get_tree().get_node_count() > nodes:
			noisy = true
		await main.get_tree().process_frame
		var pts := _pose_pts()
		if pts.size() == pose_last.size():
			for b in pts.size():
				pose_drift[b] = maxf(pose_drift[b], pts[b].distance_to(pose_last[b]))
		pose_last = pts
		unrest = _quiet()
		km_last = P.anim.km.duplicate()
	pose_rest = pose_last

## Steps the match until the hunter and its pose are at rest: SETTLE_S at least, SETTLE_MAX_S at most.
func _settle(dt: float) -> void:
	var n := 0
	var least := int(ceil(SETTLE_S / dt))
	while n < int(ceil(SETTLE_MAX_S / dt)):
		_aim_at_target()
		m._process(dt)
		await main.get_tree().process_frame
		n += 1
		var still := _quiet() == "" and not _posing(dt)
		km_last = P.anim.km.duplicate()
		if n >= least and still: break

## Standing on the spot, still, full charges and ammo, the foe back in front.
func _rest(key: String) -> void:
	P.out = false
	P.gone = false
	P.downed = false
	P.teleport(flat)
	P.vel = Vector3.ZERO
	P.grounded = true
	for zero in ["roll_t", "knock_t", "stun_t", "root_t", "coyote", "jump_buf", "reload_t", "fire_cd",
			"warm_t", "spin", "mel_hold", "swing_buf", "dash_buf", "ex_cd", "merge_cd"]:
		P.set(zero, 0.0)
	for off in ["gliding", "dropping", "diving"]:
		P.set(off, false)
	P.pad = {}
	P.grap = {}
	P.draw_t = -1.0
	P.ammo = int(P.wpn["mag"])
	P.dashes = P.max_dashes()
	P.hp = P.max_hp
	P.ult = 1.0 if key == "r" else 0.0
	if P.kin and (P.kin as Kin).state != "shoulder":
		(P.kin as Kin).stow()        # back on the shoulder (a Merge leaves it out, and it shoves)
	if P.ak: P.ak.cd_off = true
	for kk in ["sec", "sig", "ult", "jump", "dash", "fire", "glide", "glide_btn", "dash_down", "crouch"]:
		P.inp[kk] = false
	if T:
		T.out = false
		T.downed = false
		T.hp = T.max_hp
		T.teleport(flat + Vector3(4.0, 0, 0))
		T.vel = Vector3.ZERO

## The body's pose as drawn: the Warden contract's bones less its cloth (WardenGlb.BONES), from the skinned
## skeleton of a Hero model, else the procedural rig's parts, in the hunter's own space. Springs, props and the face
## (a braid, a coin, a spinning barrel) move on their own and are left out. Read after the frame's process, when the
## model's driver has posed it.
func _pose_pts() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var inv := P.global_transform.affine_inverse()
	var sk := _body_skeleton()
	for bone: String in WardenGlb.BONES:
		if bone in WardenGlb.OPTIONAL:
			continue
		if sk:
			var bi := WardenSkeleton.find(sk, bone)
			if bi >= 0:
				pts.append(inv * (sk.global_transform * sk.get_bone_global_pose(bi).origin))
		else:
			var part := P.model.get_node_or_null(String(WardenGlb.BONES[bone])) as Node3D
			if part:
				pts.append(inv * part.global_position)
	return pts

## The Hero model's body skeleton (the one with hips), or null for the procedural rig.
func _body_skeleton() -> Skeleton3D:
	for sk: Skeleton3D in P.model.find_children("*", "Skeleton3D", true, false):
		if WardenSkeleton.find(sk, "hips") >= 0:
			return sk
	return null

## Is a bone still moving faster than the idle does (a move playing out)? Steps pose_last on to this frame.
func _posing(dt: float) -> bool:
	var pts := _pose_pts()
	var fast := pts.size() != pose_last.size()
	for b in pts.size():
		if not fast and pts[b].distance_to(pose_last[b]) > POSE_QUIET * dt:
			fast = true
	pose_last = pts
	return fast

## Has a bone left the rest pose by more than the idle alone moved it in this many frames?
func _pose_moved(frames: int) -> bool:
	var pts := _pose_pts()
	if pts.size() != pose_rest.size() or pose_drift.size() != pts.size():
		return true      # (the model was rebuilt)
	for b in pts.size():
		if pts[b].distance_to(pose_rest[b]) > POSE_EPS + pose_drift[b] * frames:
			return true
	return false

## "" when the hunter is at rest, else what still moves.
func _quiet() -> String:
	if not P.grounded: return "airborne"
	if P.vel.length() > 0.01: return "moving"
	if P.roll_t > 0.0: return "dash"
	if P.ak and P.ak.in_dash(): return "kit dash"
	if P.anim and P.anim.km != km_last: return "kit move"
	if KinMerge.active(P): return "merged"
	if P.position.distance_to(P.pos) > 0.01: return "render catching up"
	return ""

## The cursor on the foe's feet: snapped to the foe or not, the aim is its spot on the ground (a plant like
## Sable's E needs ground within reach). A mouse motion event is what the viewport reads, in window pixels:
## the canvas point through the root's final transform (a real window's stretch and scale; headless, identity).
## The pointer itself is warped there too, so a real display's own pointer never contradicts the event.
func _aim_at_target() -> void:
	if T == null or m.cam == null: return
	var at: Vector2 = main.get_tree().root.get_final_transform() * m.cam.unproject_position(T.pos)
	Input.warp_mouse(at)
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## Flat open spots 6 m clear all round (move_feel_check's rule), SPOT_GAP apart, up to SPOTS of them.
func _flat_spots() -> Array:
	var w: World = m.world
	var found: Array = []
	for k in 20001:
		var g: Vector3 = w.random_ground()
		if k == 0:
			g = Vector3(CALIB_SPOT.x, w.ground_at(CALIB_SPOT.x, CALIB_SPOT.z), CALIB_SPOT.z)
		if g.y > 2.0 and k < 15000:
			continue
		if found.any(func(f: Vector3) -> bool: return f.distance_to(g) < SPOT_GAP):
			continue
		if _clear_around(g):
			found.append(g)
			if found.size() >= SPOTS: break
	return found if not found.is_empty() else [m.world.spawns[0]]

func _clear_around(g: Vector3) -> bool:
	var w: World = m.world
	if w.is_void(g.x, g.z) or w.is_block(g.x, g.z):
		return false
	for i in 16:
		var a := TAU * i / 16.0
		for d in [2.0, 4.0, 6.0]:
			var x: float = g.x + cos(a) * d
			var z: float = g.z + sin(a) * d
			if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
				return false
	return true
