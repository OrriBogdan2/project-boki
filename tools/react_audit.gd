extends "res://tools/anim_audit.gd"
## --react-audit [--wardens=a,b] [--json=<file>]: how every Hunter takes a hit (docs/art/REACT_AUDIT.md). No renderer.
## Per Hunter it poses the real model through Warden/Sync and reads the bones:
##  - the hit flinch, front and back, as the game hands it off (hit_t in the state, the upper-body blend): how far the
##    body has moved 0.1 s after the hit, the peak, when it peaks and when it has settled back to a quarter of it;
##  - the stun loop's seam and how much it moves; the knockback: the fall loop's seam and the landing's squash;
##  - through all of them: the weapon bone stays on its hand, no arm stands out in a T-pose.
## The gate: FAIL lines and exit code 1, except the pairs in OPEN (known, filed, not fixed yet).

const READ_T := 0.1          # s: a hit must read by then (DECISIONS: getting hit reads instantly)
const MIN_READ := 0.03       # share of the Hunter's height a point has moved at READ_T
const MIN_SQUASH := 0.02     # share of height the hips drop in the first READ_T of the landing
const MAX_SEAM := 0.02       # share of height between a loop's last and first frame
const MAX_GRIP := 0.03       # m the weapon bone may leave its hand
const SETTLED := 0.25        # the flinch is over when it is back under this share of its peak
## The settle time a body of each weight should show (s): light snaps back, heavy carries the hit, medium between.
const WEIGHT := {"light": [0.14, 0.30], "medium": [0.18, 0.38], "heavy": [0.24, 0.45]}
## The bone that holds the weapon, where it is not skinned straight into the hand mesh.
const WEAPON := {"bulwark": "x_weapon", "archer": "bow", "dredge": "hook", "mage": "rod.0", "gunslinger": "gatling"}
const ELBOW_STRAIGHT := 0.35     # rad: the forearm runs on with the upper arm
const OPEN := {}             # "id:test": why it still fails (docs/art/REACT_AUDIT.md)

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = Arch.ORDER.duplicate()
	var json := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--json="): json = a.substr(7)
	for id in ids:
		await _react(main, String(id))
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	print("REACT_AUDIT_DONE ", rows.size(), " FAIL ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _react(main: Node, id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	for k in 5:
		await main.get_tree().process_frame
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var st: Dictionary = clips.d["states"]
	var hd: Dictionary = st["hit"]
	var row := {"weight": Arch.weight(id), "dur": hd["dur"]}
	var hgt := _height(sync, clips, sk, String(clips.d["loco"]["idle"]))
	row["height"] = hgt
	grip = {"bone": WEAPON.get(id, ""), "worst": 0.0}
	var idle_hips: float = (_pose_at(sync, clips, sk, String(clips.d["loco"]["idle"]), 0.0)["hips"] as Vector3).y
	row["hit_f"] = _hit(m, sync, sk, Vector2(0, 1), float(hd["dur"]), hgt)
	row["hit_b"] = _hit(m, sync, sk, Vector2(0, -1), float(hd["dur"]), hgt)
	row["stun"] = _loop(sync, clips, sk, String(st["stun"]), hgt)
	row["fall"] = _loop(sync, clips, sk, String(clips.d["air"]["fall"]), hgt)
	row["land"] = _land(sync, clips, sk, String(clips.d["land"]["clip"]), hgt, idle_hips)
	row["grip_m"] = grip["worst"]
	var t_pose := ""
	for k in ["hit_f", "hit_b", "stun", "fall", "land"]:
		if row[k]["t_pose"] > 0.0:
			t_pose += "%s %d%% " % [k, round(100.0 * row[k]["t_pose"])]
	row["t_pose"] = t_pose.strip_edges()
	rows[id] = row
	var f: Dictionary = row["hit_f"]
	var b: Dictionary = row["hit_b"]
	print("REACT %-10s %-6s hit_f read %.3f peak %.3f at %.2fs settles %.2fs away %.3f" % [
			id, row["weight"], f["read"], f["peak"], f["peak_t"], f["settle_t"], f["away"]],
			" | hit_b read %.3f settles %.2fs away %.3f" % [b["read"], b["settle_t"], b["away"]],
			" | stun seam %.3f move %.3f | fall seam %.3f | land squash %.3f | grip %.3f m | T-pose %s" % [
			row["stun"]["seam"], row["stun"]["move"], row["fall"]["seam"], row["land"]["squash"], row["grip_m"],
			row["t_pose"] if row["t_pose"] != "" else "none"])
	_gate(id, row)
	m.free()

var grip := {}
var t_frames := 0
var frames := 0

func _gate(id: String, row: Dictionary) -> void:
	var band: Array = WEIGHT[row["weight"]]
	for side in ["hit_f", "hit_b"]:
		var h: Dictionary = row[side]
		_want(id, side + " reads", h["read"] >= MIN_READ,
				"moved %.3f of his height at %.1f s (min %.3f)" % [h["read"], READ_T, MIN_READ])
		_want(id, side + " weight", h["settle_t"] >= band[0] and h["settle_t"] <= band[1],
				"a %s body settles in %.2f s (wanted %.2f to %.2f)" % [row["weight"], h["settle_t"], band[0], band[1]])
	for loop in ["stun", "fall"]:
		var seam: float = row[loop]["seam"]
		_want(id, loop + " seam", seam <= MAX_SEAM, "%.3f of his height (max %.3f)" % [seam, MAX_SEAM])
	var squash: float = row["land"]["squash"]
	_want(id, "land squash", squash >= MIN_SQUASH,
			"hips drop %.3f of his height by %.1f s (min %.3f)" % [squash, READ_T, MIN_SQUASH])
	_want(id, "grip", row["grip_m"] <= MAX_GRIP,
			"the weapon bone leaves the hand by %.3f m (max %.3f)" % [row["grip_m"], MAX_GRIP])
	_want(id, "T-pose", row["t_pose"] == "", "both arms stand out straight and sideways (%s)" % row["t_pose"])

func _want(id: String, test: String, good: bool, what: String) -> void:
	var key := "%s:%s" % [id, test]
	if OPEN.has(key):
		var stale := " (now passes: drop it from OPEN)" if good else ""
		print("REACT open %s %s: %s [%s]%s" % [id, test, what, OPEN[key], stale])
		if good:
			bad += 1
	elif not good:
		print("FAIL %s %s: %s" % [id, test, what])
		bad += 1

## One frame of the live hand-off: the pose, plus the grip and T-pose tallies.
func _frame(sync: Node, sk: Skeleton3D, dt: float) -> Dictionary:
	sync.call("_process", dt)
	var p := _read(sk)
	frames += 1
	if _t_posed(p, "L") and _t_posed(p, "R") and _straight(p, "L") and _straight(p, "R"):
		t_frames += 1
	if grip["bone"] != "":
		var wp := WardenSkeleton.find(sk, grip["bone"])
		if wp >= 0:
			var par := sk.get_bone_parent(wp)
			var rest := (sk.get_bone_global_rest(par).affine_inverse() * sk.get_bone_global_rest(wp)).origin
			var now := (sk.get_bone_global_pose(par).affine_inverse() * sk.get_bone_global_pose(wp)).origin
			grip["worst"] = maxf(grip["worst"], rest.distance_to(now))
	return p

func _straight(p: Dictionary, side: String) -> bool:
	var up: Vector3 = (p["forearm." + side] as Vector3) - (p["upper_arm." + side] as Vector3)
	var fore: Vector3 = (p["hand." + side] as Vector3) - (p["forearm." + side] as Vector3)
	return up.angle_to(fore) < ELBOW_STRAIGHT

## The share of the frames tallied since `_begin` that stood in a T-pose.
func _begin() -> void:
	t_frames = 0
	frames = 0

func _t_share() -> float:
	return float(t_frames) / maxi(frames, 1)

## A hit while he stands, as the game plays it: hit_t runs 0 to dur. hit_dir is hunter.gd's, from the attacker to him:
## at face 0 he looks down -Z, so (0, 1) is a hit from the front and (0, -1) one from behind.
func _hit(m: Node3D, sync: Node, sk: Skeleton3D, hit_dir: Vector2, dur: float, hgt: float) -> Dictionary:
	_begin()
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	for k in int(WARM_S / DT):
		sync.call("_process", DT)
	var pre := _read(sk)
	var disp: Array = []
	var away := 0.0
	var t := 0.0
	while t < dur:
		s["hit_t"] = t
		s["hit_dir"] = hit_dir
		m.set_meta(WardenClips.STATE, s)
		var p := _frame(sync, sk, DT)
		disp.append(_dist(p, pre) / hgt)
		# (+: the head goes with the blow, away from the attacker)
		away = maxf(away, ((p["head"] as Vector3).z - (pre["head"] as Vector3).z) * signf(hit_dir.y) / hgt)
		t += DT
	m.set_meta(WardenClips.STATE, {})
	var peak := 0.0
	var peak_i := 0
	for i in disp.size():
		if disp[i] > peak:
			peak = disp[i]
			peak_i = i
	var settle := dur
	for i in range(peak_i, disp.size()):
		if disp[i] < SETTLED * peak:
			settle = i * DT
			break
	return {"read": disp[mini(int(READ_T / DT), disp.size() - 1)], "peak": peak, "peak_t": peak_i * DT,
			"settle_t": settle, "away": away, "t_pose": _t_share()}

## A keyed loop: its seam (last frame against the first) and how far it moves at all.
func _loop(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, hgt: float) -> Dictionary:
	_begin()
	var fr := _frames(sync, clips, sk, clip, 24)
	var move := 0.0
	for p in fr:
		move = maxf(move, _dist(p, fr[0]))
	return {"seam": _dist(fr[0], fr[-1]) / hgt, "move": move / hgt, "length": clips.lib.get_animation(clip).length,
			"t_pose": _t_share()}

## The landing, keyed: how far below his standing height the hips dip in the first READ_T (the squash that sells it).
func _land(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, hgt: float, idle_hips: float) -> Dictionary:
	_begin()
	var fr := _frames(sync, clips, sk, clip, 24)
	var length := clips.lib.get_animation(clip).length
	var drop := 0.0
	for i in fr.size():
		if length * i / 23.0 <= READ_T + 0.001:
			drop = maxf(drop, idle_hips - (fr[i]["hips"] as Vector3).y)
	return {"squash": drop / hgt, "length": length, "t_pose": _t_share()}

## `_clip_frames` through `_frame`, so the grip and T-pose tallies see every sample.
func _frames(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, n: int) -> Array:
	var length := clips.lib.get_animation(clip).length
	var out: Array = []
	clips.force = {"clip": clip, "t": 0.0}
	for k in 6:
		sync.call("_process", DT)
	for i in n:
		clips.force = {"clip": clip, "t": minf(length * i / (n - 1), length - 0.001)}
		out.append(_frame(sync, sk, DT))
	clips.force = {}
	return out
