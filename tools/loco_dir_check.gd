extends RefCounted
## --loco-dir-check [--wardens=a,b] [--json=<file>]: every Hunter's legs in every direction (docs/art/LOCO_DIR.md).
## Per Hunter with clips, through the game's own path (HunterAnim -> WardenClips, fixed steps, no physics), each state
## of STATES moves the model in the 8 directions of DIRS off its facing and reads the shin-tip ankles:
## A foot is its sole: a heel point under the ankle and a toe point ahead of it on the rest pose's ground, riding the
## foot bone (the shin on a rig without one); the lower of the two is the one on the floor, so a heel-to-toe roll over a
## pinned sole reads as planted, not as a slide.
##  - DIR: a planted foot must travel back against the move (the clip plays the way he goes: no forward loop walking
##    backwards, no mirrored side loop). The angle between the planted feet's mean travel and the move, at most DIR_MAX.
##  - SKATE / SLIP: the planted feet carry the ground back at FOOT_K of the speed or more, and slip over it (the body's
##    velocity plus the foot's own, flat) at most SLIP_K of the speed (SLIP_MIN m/s for the slow crouch).
##  - SNAP: starting and stopping (and crouch-walk to crouch idle) at the game's own rates (HunterMove accel to the
##    speed, HunterMove.brake to a stop) no point jumps: a frame's change of velocity of the
##    hips, head, hands or ankles at most SNAP_K x the steady loop's worst, and at least SNAP_MIN.
##  - PLANT: moving off from idle at walk and run (START_STATES), the first foot down lands within PLANT_TOL frames
##    of the frame the ring passes that foot's contact key (WardenStart picks where the rings pick up); each cell's
##    JSON "start" also carries the first-pose gap and the ring's phase (_start).
## Prints a grid (one row per Hunter and state, one cell per direction: "ok" or the first failed test). A ratchet: the
## cells in KNOWN fail today (docs/art/LOCO_DIR.md, docs/DEBT.md) and print KNOWN; any other failed cell prints FAIL
## and exits 1, a known one that passes prints FIXED. --update rewrites KNOWN from this run (after a fix, never to
## hide a new fail). The steps are fixed (no frame's real dt reaches the clips), so two runs read the same.
## A Hunter in FLAT or with no clips is listed, skipped.
## "aim" states: the Hunter always faces his aim (the facing follows the cursor), so a walk is an aim-walk; aim_walk and
## strafe swing the aim AIM_SWING either side of the facing while he holds the move, so the ring crosses its neighbours.

const AUDIT := preload("res://tools/anim_audit.gd")
const DT := 1.0 / 60.0
const WARM_S := 1.2          # s at a state before sampling: the blends and WardenGait's stride have settled
const SAMPLE_S := 2.0        # s sampled: two or more loops of every Hunter's walk
const SETTLE_S := 0.5        # s read after a start or a stop for a snap
## The states: speed is m/s ("walk": loco walk_speed, "run": halfway to full stick, "sprint": full stick, the
## archetype's HunterMove speed; there is no sprint key, full stick is the top), crouch at Hunter's 0.55 of it.
const STATES := ["walk", "run", "sprint", "crouch_walk", "crouch_idle", "strafe", "aim_walk"]
## The directions off the facing, deg (+ his left: the model's yaw turns him left, so his right is the facing - 90).
const DIRS := {"f": 0.0, "fr": -45.0, "r": -90.0, "br": -135.0, "b": 180.0, "bl": 135.0, "l": 90.0, "fl": 45.0}
const CROUCH_K := 0.55       # hunter.gd: the walking speed crouched, of the run speed
const AIM_SWING := 0.5       # rad (~29 deg) the aim swings either side while strafing
const AIM_HZ := 0.5          # 1/s: the swing's rate
const DIR_MAX := 40.0        # deg: the planted feet's travel off the move, at most
const FOOT_K := 0.55         # of the speed: what the planted feet carry back, at least (under it the loop skates)
const SLIP_K := 0.45         # of the speed: the mean slip of a planted foot over the ground, at most
const SLIP_MIN := 0.45       # m/s: the slip bar never goes under this (a slow crouch at 1.3 m/s)
const SNAP_K := 2.5          # x the steady loop's worst change of velocity in one frame
const SNAP_MIN := 0.06       # m per frame per frame (at 60 fps): a change this small is never a snap
const IDLE_SLIP := 0.25      # m/s: crouched still, a foot drifts at most this (mean, over the hold)
const PLANT_BAND := 0.1     # a sole is planted in the lowest 10 % of its height range (the sole sits on the floor)
const FLAT := ["ostra"]      # Motley rides his spring: no steps to read
const KNOWN := "res://tools/loco_dir_known.txt"     # "<hunter> <state> <dir>" a line: the cells failing today
const START_STATES := ["walk", "run"]   # moving off from idle: the first pose and the first plant (START)
const START_S := 1.0         # s after a start searched for the first touchdown
const LIFT_K := 0.5          # of a sole's height range: over this it is swinging (its next time down is a touchdown)
const PLANT_TOL := 2         # frames: the first touchdown lands this close to the ring's contact key
const POINTS := ["hips", "head", "hand.L", "hand.R", "heel.L", "heel.R", "toe.L", "toe.R"]

var bad := 0
var holder: Node3D
var rows := {}
var known := {}             # "<hunter> <state> <dir>" -> true
var now_failing: Array = []
var contact := {}            # "<rel> <ring>" -> {foot: phase}: a Hunter's contact keys, per direction and ring
var soles := {}              # side -> [bone index, heel, toe (in that bone's frame)]: the sole at rest

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	var json := ""
	var update := false
	var f := FileAccess.open(KNOWN, FileAccess.READ)
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			known[line] = true
	for a in OS.get_cmdline_user_args():
		if a == "--update":
			update = true
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--json="):
			json = a.substr(7)
	print("LOCO_DIR %-10s %-12s %s" % ["hunter", "state", " ".join(DIRS.keys().map(func(k): return "%-5s" % k))])
	for id in ids:
		await _hero(main, String(id))
	if json != "":
		FileAccess.open(json, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	if update:
		FileAccess.open(KNOWN, FileAccess.WRITE).store_string("# --loco-dir-check: cells failing today (--update)\n"
				+ "\n".join(now_failing) + "\n")
	var cells := 0
	for id in rows:
		for st in rows[id]:
			cells += (rows[id][st] as Dictionary).size()
	print("LOCO_DIR_DONE hunters %d cells %d failing %d (known %d) FAIL %d" % [rows.size(), cells, now_failing.size(),
			known.size(), bad])
	main.get_tree().quit(1 if bad > 0 or rows.is_empty() else 0)

func _hero(main: Node, id: String) -> void:
	if not WardenClips.data(WardenGlb.art(id)).has("loco") or id in FLAT:
		print("LOCO_DIR %-10s skipped (no stepping clips)" % id)
		return
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var a := HunterAnim.new(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)     # (only the fixed steps below move the clips: a real frame's dt would shift their phase)
	for k in 3:
		await main.get_tree().process_frame
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var clips: WardenClips = sync.get("clips")
	_soles(sk)
	contact = {}
	var top := float(HunterMove.of(id)["speed"])
	var accel := float(HunterMove.of(id)["accel"])
	var walk := float(clips.d["loco"].get("walk_speed", 2.2))
	var speed := {"walk": walk, "run": (walk + top) / 2.0, "sprint": top, "crouch_walk": top * CROUCH_K,
			"crouch_idle": top * CROUCH_K, "strafe": top, "aim_walk": walk}
	var row := {}
	for st in STATES:
		if st.begins_with("crouch") and not clips.d.has("crouch"):
			continue
		var cells := {}
		var line := []
		for dir in DIRS:
			var c := _cell(m, a, sync, sk, String(st), deg_to_rad(DIRS[dir]), float(speed[st]), accel)
			cells[dir] = c
			line.append("%-5s" % c["verdict"])
			var key := "%s %s %s" % [id, st, dir]
			if c["verdict"] != "ok":
				now_failing.append(key)
				if not known.has(key):
					bad += 1
				print("%s %s: %s" % ["KNOWN" if known.has(key) else "FAIL", key, c["why"]])
			elif known.has(key):
				print("FIXED %s (--update drops it)" % key)
		row[st] = cells
		print("LOCO_DIR %-10s %-12s %s" % [id, st, " ".join(line)])
		if st in START_STATES:
			print("LOCO_START %-10s %-12s %s" % [id, st, _start_line(cells)])
	rows[id] = row
	m.free()

## A start row: per direction "<dir>:<first-pose gap %>/<first plant off its key, frames>/<ring phase>".
func _start_line(cells: Dictionary) -> String:
	var out: Array = []
	for k in cells:
		var c: Dictionary = cells[k]["start"]
		out.append("%s:%d%%/%+d/%.2f" % [k, roundi(100.0 * float(c["gap"])), int(c["err"]), float(c["phase"])])
	return " ".join(out)

## One state and direction: start from a standstill at `accel` m/s^2, hold the move, brake to a stop.
## `rel`: rad off the facing (+ his left).
func _cell(m: Node3D, a: HunterAnim, sync: Node, sk: Skeleton3D, st: String, rel: float, spd: float,
		accel: float) -> Dictionary:
	var ck := 1.0 if st.begins_with("crouch") else 0.0
	var swing := AIM_SWING if st in ["strafe", "aim_walk"] else 0.0
	var t := 0.0
	var cl: WardenClips = sync.get("clips")
	for k in int(0.6 / DT):     # stand (or crouch) still first
		_tick(m, a, sync, Vector3.ZERO, 0.0, ck)
	var idle := _read(m, sk, Vector3.ZERO)
	var fr: Array = []
	var v := 0.0
	for k in int((WARM_S + SAMPLE_S) / DT):
		var face := swing * sin(TAU * AIM_HZ * t)
		v = move_toward(v, spd, accel * DT)
		_tick(m, a, sync, _vel(face + rel, v), face, ck)
		fr.append(_read(m, sk, _vel(face + rel, v)))
		fr[-1]["ring"] = _ring_at(cl)
		t += DT
	var rate: float = cl.tree.get("parameters/%s/scale" % ("crouch_rate" if ck > 0.0 else "loco_rate"))
	var stop: Array = []
	for k in int((SETTLE_S + 1.0) / DT):
		var face := swing * sin(TAU * AIM_HZ * t)
		v = HunterMove.brake(Vector2(v, 0.0), 1.0, DT).x
		_tick(m, a, sync, _vel(face + rel, v), face, ck)
		stop.append(_read(m, sk, _vel(face + rel, v)))
		t += DT
	m.rotation.y = 0.0
	var steady := fr.slice(int(WARM_S / DT))
	var out := _gait(steady, spd)
	out["rate"] = rate
	out["speed"] = spd
	if st in START_STATES:
		out["start"] = _start(fr, steady, idle, cl, sync, sk, rel)
	var calm: float = _jerk(steady)[0]
	var start := _jerk(fr.slice(0, int(SETTLE_S / DT)))
	var halt := _jerk(stop.slice(0, int(SETTLE_S / DT)))
	var snap := maxf(start[0], halt[0])
	out["snap"] = snap
	out["snap_at"] = "start %s" % start[1] if start[0] >= halt[0] else "stop %s" % halt[1]
	out["snap_bar"] = maxf(calm * SNAP_K, SNAP_MIN)
	out["verdict"] = "ok"
	out["why"] = ""
	var slip_bar := maxf(SLIP_K * spd, SLIP_MIN)
	if st == "crouch_idle":
		var drift := _drift(stop.slice(int(SETTLE_S / DT)))
		out["drift"] = drift
		_judge(out, drift > IDLE_SLIP, "SLIP", "crouched still, a foot drifts %.2f m/s (bar %.2f)" % [drift,
				IDLE_SLIP])
		_judge(out, snap > out["snap_bar"], "SNAP", "crouch-walk to crouch idle jumps %.3f (bar %.3f)" % [snap,
				out["snap_bar"]])
		return out
	_judge(out, out["off_deg"] > DIR_MAX, "DIR", "planted feet travel %.0f deg off the move (bar %.0f): the "
			% [out["off_deg"], DIR_MAX] + "clip plays another direction")
	_judge(out, out["carry"] < FOOT_K, "SKATE", "planted feet carry %.0f%% of the speed (bar %.0f%%)" % [
			100.0 * out["carry"], 100.0 * FOOT_K])
	_judge(out, out["slip"] > slip_bar, "SLIP", "planted feet slip %.2f m/s at %.2f m/s (bar %.2f)" % [out["slip"], spd,
			slip_bar])
	_judge(out, snap > out["snap_bar"], "SNAP", "%s jumps %.3f (bar %.3f, steady %.3f)" % [out["snap_at"], snap,
			out["snap_bar"], calm])
	if out.has("start"):
		var sp: Dictionary = out["start"]
		_judge(out, absi(int(sp["err"])) > PLANT_TOL, "PLANT", "moving off, the first foot down lands %s" % (
				"nowhere near a contact key" if int(sp["err"]) == 99 else "%+d frames off its contact key (bar %d)"
				% [int(sp["err"]), PLANT_TOL]))
	return out

func _judge(out: Dictionary, failed: bool, verdict: String, why: String) -> void:
	if failed and out["verdict"] == "ok":
		out["verdict"] = verdict
		out["why"] = why

func _vel(yaw: float, spd: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)) * spd     # (yaw 0 faces -Z, as the models do)

func _tick(m: Node3D, a: HunterAnim, sync: Node, vel: Vector3, face: float, ck: float) -> void:
	m.rotation.y = face
	a.update(DT, {"vel": vel, "face": face, "grounded": true, "crouch": ck, "fired": 99.0})
	sync.call("_process", DT)

## The points in the world (the model stands at the origin; the ground passes under him at `vel`).
func _read(m: Node3D, sk: Skeleton3D, vel: Vector3) -> Dictionary:
	var out := {"vel": vel}
	var xf := sk.global_transform
	for b in ["hips", "head", "hand.L", "hand.R"]:
		out[b] = xf * sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin
	for side in soles:
		var gs := sk.get_bone_global_pose(soles[side][0])
		var heel: Vector3 = xf * (gs * (soles[side][1] as Vector3))
		var toe: Vector3 = xf * (gs * (soles[side][2] as Vector3))
		out["heel." + side] = heel
		out["toe." + side] = toe
		out["foot." + side] = heel if heel.y <= toe.y else toe
	return out

## The heel and toe of each foot in its bone's frame, from the rest pose: under the ankle (the foot bone's head, or
## the shin's tip) on the ground, and ahead of it by the ankle's height.
func _soles(sk: Skeleton3D) -> void:
	soles = {}
	for side in ["L", "R"]:
		var shin := WardenSkeleton.find(sk, "shin." + side)
		var bi := shin
		for nm in ["foot.", "x_foot."]:
			if WardenSkeleton.find(sk, nm + side) >= 0:
				bi = WardenSkeleton.find(sk, nm + side)
				break
		var rest := sk.get_bone_global_rest(bi)
		var ankle := rest.origin
		if bi == shin:
			var thigh := sk.get_bone_global_rest(WardenSkeleton.find(sk, "thigh." + side)).origin
			ankle = rest.origin + rest.basis.y.normalized() * (rest.origin - thigh).length()
		var ground := minf(ankle.y, 0.0)
		var heel := Vector3(ankle.x, ground, ankle.z)
		var toe := heel + Vector3(0, 0, -maxf(ankle.y - ground, 0.04))     # (the model faces -Z)
		soles[side] = [bi, rest.affine_inverse() * heel, rest.affine_inverse() * toe]

## The planted feet over a steady stretch: how far their mean travel points off the move (deg), what share of the
## speed they carry back along it, and their mean slip over the ground (m/s).
func _gait(fr: Array, spd: float) -> Dictionary:
	var carry := Vector2.ZERO
	var move := Vector2.ZERO
	var slip := 0.0
	var n := 0
	for f in ["foot.L", "foot.R"]:
		var lo := INF
		var hi := -INF
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		for i in range(1, fr.size() - 1):
			if (fr[i][f] as Vector3).y > lo + PLANT_BAND * maxf(hi - lo, 0.02):
				continue
			var pt: String = ("heel" if (fr[i][f] as Vector3) == fr[i]["heel" + f.substr(4)] else "toe") + f.substr(4)
			var fv: Vector3 = ((fr[i + 1][pt] as Vector3) - (fr[i - 1][pt] as Vector3)) / (2.0 * DT)
			var vel: Vector3 = fr[i]["vel"]
			carry += Vector2(-fv.x, -fv.z)
			move += Vector2(vel.x, vel.z)
			slip += Vector2(vel.x + fv.x, vel.z + fv.z).length()
			n += 1
	if n == 0:
		return {"off_deg": 180.0, "carry": 0.0, "slip": spd}
	var off := rad_to_deg(absf(carry.angle_to(move))) if carry.length() > 0.001 else 180.0
	return {"off_deg": off, "carry": carry.dot(move.normalized()) / n / spd, "slip": slip / n}

## The largest change of velocity of any point in one frame (m per frame per frame), and "<point> f<frame>".
func _jerk(fr: Array) -> Array:
	var worst := [0.0, ""]
	for i in range(1, fr.size() - 1):
		for b in POINTS:
			var acc: Vector3 = (fr[i + 1][b] as Vector3) - 2.0 * (fr[i][b] as Vector3) + (fr[i - 1][b] as Vector3)
			if acc.length() > worst[0]:
				worst = [acc.length(), "%s f%d" % [b, i]]
	return worst

## Mean flat speed of the feet while he stands (m/s): nothing should move them.
func _drift(fr: Array) -> float:
	var sum := 0.0
	var n := 0
	for f in ["heel.L", "heel.R", "toe.L", "toe.R"]:
		for i in range(1, fr.size()):
			var d: Vector3 = (fr[i][f] as Vector3) - (fr[i - 1][f] as Vector3)
			sum += Vector2(d.x, d.z).length() / DT
			n += 1
	return sum / maxi(n, 1)

## The ring that owns the legs ("walk" or "run") and its phase 0..1, and how much the rings show over the idle.
func _ring_at(cl: WardenClips) -> Dictionary:
	var nm := "run" if cl.run_w >= 0.5 else "walk"
	var at := "parameters/%s/current_" % nm
	return {"nm": nm, "ph": float(cl.tree.get(at + "position")) / maxf(float(cl.tree.get(at + "length")), 0.001),
			"w": cl.move_w}

## Moving off from idle (START): "gap", the ring's first pose against the idle's, worst point over the height;
## "phase", the ring's phase at the start; "keys", the phases a sole touches down at in the steady loop (per foot,
## kept per direction and ring in `contact`, so a run start's walk-ring frames read the walk cell's keys);
## "plant_f", the frame of the first plant: a foot that lifted coming down, or one down since the start that the ring
## carries through its own key; "key_f", the frame the ring passes that foot's key nearest it ("err" the two
## apart, frames: early is the idle pulling a swinging foot down, late a foot held off the floor).
func _start(fr: Array, steady: Array, idle: Dictionary, cl: WardenClips, sync: Node, sk: Skeleton3D,
		rel: float) -> Dictionary:
	var band := {}
	var lift := {}
	var keys := {}
	for f in ["foot.L", "foot.R"]:
		var lo := INF
		var hi := -INF
		for p in steady:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		band[f] = lo + PLANT_BAND * maxf(hi - lo, 0.02)
		lift[f] = lo + LIFT_K * maxf(hi - lo, 0.02)
		var sum := Vector2.ZERO
		for i in range(1, steady.size()):
			if (steady[i][f] as Vector3).y <= band[f] and (steady[i - 1][f] as Vector3).y > band[f]:
				sum += Vector2.from_angle(TAU * float(steady[i]["ring"]["ph"]))
		keys[f] = fposmod(sum.angle() / TAU, 1.0) if sum.length() > 0.001 else -1.0
	contact["%.2f %s" % [rel, steady[0]["ring"]["nm"]]] = keys
	var r0: Dictionary = fr[0]["ring"]
	var out := {"phase": r0["ph"], "ring": r0["nm"], "keys": [keys["foot.L"], keys["foot.R"]], "plant_f": -1,
			"key_f": -1, "err": 99}
	var n := mini(int(START_S / DT), fr.size())
	for f in band:
		var cross: Array = []     # the frames the ring passes this foot's contact key
		for i in range(1, n):
			var a: Dictionary = fr[i - 1]["ring"]
			var b: Dictionary = fr[i]["ring"]
			var key: float = contact.get("%.2f %s" % [rel, b["nm"]], {}).get(f, -1.0)
			if a["nm"] == b["nm"] and key >= 0.0 \
					and fposmod(key - float(a["ph"]), 1.0) < fposmod(float(b["ph"]) - float(a["ph"]), 1.0):
				cross.append(i)
		var held := true      # down since the start: planted on its key if the ring passes it before the foot lifts
		var up := false
		for i in range(1, n):
			var down: bool = (fr[i][f] as Vector3).y <= band[f]
			if held and not cross.is_empty() and i == cross[0] + PLANT_TOL:
				_plant(out, f, cross[0], cross[0])
				break
			held = held and down
			up = up or (fr[i][f] as Vector3).y > lift[f]
			if up and down:
				var near := -1
				for c in cross:
					near = c if near < 0 or absi(c - i) < absi(near - i) else near
				_plant(out, f, i, near)
				break
	out["gap"] = _first_gap(idle, cl, sync, sk, String(r0["nm"]), rel, float(r0["ph"]))
	return out

## The first plant of a start so far (the earliest frame wins): the frame a foot came down, the frame of its key.
func _plant(out: Dictionary, f: String, at: int, key: int) -> void:
	if out["plant_f"] >= 0 and at >= int(out["plant_f"]):
		return
	out["plant_f"] = at
	out["key_f"] = key
	out["foot"] = f
	out["err"] = at - key if key >= 0 else 99

## The worst point's distance between the idle and the ring's loop for this direction at `ph`, over his height
## (-1: no loop keyed for the direction).
func _first_gap(idle: Dictionary, cl: WardenClips, sync: Node, sk: Skeleton3D, ring: String, rel: float,
		ph: float) -> float:
	var dir := ""
	for k in DIRS:
		if absf(angle_difference(deg_to_rad(DIRS[k]), rel)) < 0.01:
			dir = k
	var loops: Dictionary = cl.d["loco"][ring]
	if not loops.has(dir):
		return -1.0
	var length := cl.lib.get_animation(String(loops[dir])).length
	cl.force = {"clip": String(loops[dir]), "t": 0.0}
	for k in 6:
		sync.call("_process", DT)
	cl.force = {"clip": String(loops[dir]), "t": ph * length}
	sync.call("_process", DT)
	var p := _read(cl.root, sk, Vector3.ZERO)
	cl.force = {}
	var worst := 0.0
	for b in POINTS:
		worst = maxf(worst, ((p[b] as Vector3) - (idle[b] as Vector3)).length())
	return worst / maxf((idle["head"] as Vector3).y, 0.5)
