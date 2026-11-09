extends RefCounted
## --anim-audit [--wardens=a,b] [--json=<file>]: how every Hunter's motion measures (docs/art/ANIM_QUALITY_AUDIT.md).
## The gate: FAIL lines and exit code 1 (see MAX_SLIDE). No renderer needed. Per Hunter it poses the real model
## (WardenClips through Warden/Sync) and reads the bones:
##  - walk and run, live: the game's own locomotion hand-off at three speeds: foot slide against the ground while the
##    foot is planted (m/s and % of the speed), the clip's own speed, hip bob, arm swing against the legs, how far
##    the arms reach;
##  - the loop seam of walk_f, run_f and the idle, and the pop from the idle into the walk and the walk into the run;
##  - the two attacks of anim_shots.gd: the weapon hand's travel and how long an arm stands out sideways.
## Prints one line per Hunter and writes every number to --json.

const DT := 1.0 / 30.0
const WARM_S := 1.0          # s of locomotion before a sample, so the blends have settled
const SAMPLE_S := 2.4        # s of locomotion sampled
const SPEEDS := [2.2, 3.4, 4.65]     # m/s: walk, a jog, full stick (content/rules/hunter_move.json)
const PLANT_BAND := 0.3      # a foot is planted in the lowest 30 % of its own height range
const T_ELEV := 1.05         # rad (60 deg): an arm raised this far from hanging...
const SIDEWAYS := 1.0        # ...and pointing more sideways than forward is a T-pose
const ATTACKS := preload("res://tools/anim_shots.gd").ATTACKS
## The gate (every Hunter whose clips move the legs): at full stick a planted foot slides at most this share of the
## speed, and the arms swing against their legs at least this much (-1: with, +1: against; reach-weighted).
const MAX_SLIDE := 0.25
const MIN_COUNTER := 0.3
const NO_LEGS := ["ostra", "rimewright"]     # their clips hover and skate, the legs do not move: a backlog item each
## Props that ride a hand (anchor node: its hand bone). Held means the distance must not drift over a clip.
const HELD := {
	"rimewright": {"anchor_blade_root": "hand.R", "weapon_muzzle": "hand.R"},
	"mage": {"anchor_gun_L": "hand.L", "anchor_gun_R": "hand.R"},
	"thief": {"anchor_blade_root": "hand.R", "anchor_blade_root_l": "hand.L"},
	"dolm": {"anchor_fist_R": "hand.R", "anchor_fist_L": "hand.L", "anchor_gauntlet_R": "forearm.R"},
}
const MAX_PROP_DRIFT := 0.03     # of the Hunter's height: a held prop's distance to its hand over a clip
const POINTS := ["hips", "head", "hand.L", "hand.R", "foot.L", "foot.R"]

var bad := 0
var holder: Node3D
var rows := {}

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
		await _hero(main, String(id))
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	print("ANIM_AUDIT_DONE ", rows.size(), " FAIL ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(main: Node, id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	for k in 5:
		await main.get_tree().process_frame
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var lc: Dictionary = clips.d["loco"]
	var row := {}
	var rest := _pose_at(sync, clips, sk, String(lc["idle"]), 0.0)
	row["same_side"] = {"hand_foot": signf((rest["hand.L"] as Vector3).x) == signf((rest["foot.L"] as Vector3).x),
			"arm_leg_x": [(rest["hand.L"] as Vector3).x, (rest["foot.L"] as Vector3).x]}
	row["height"] = _height(sync, clips, sk, String(lc["idle"]))
	var hgt: float = row["height"]
	var walk := String(lc["walk"]["f"])
	var run := String(lc["run"]["f"])
	row["cfg"] = {"walk_speed": lc.get("walk_speed"), "run_speed": lc.get("run_speed"),
			"walk_len": clips.lib.get_animation(walk).length, "run_len": clips.lib.get_animation(run).length}
	var live := {}
	for s in SPEEDS:
		live[str(s)] = _gait(m, sync, clips, sk, s)
	row["live"] = live
	row["seam"] = {}
	for nm in [walk, run, String(lc["idle"])]:
		row["seam"][nm] = _seam(sync, clips, sk, nm, hgt)
	row["pop"] = {"idle_walk": _first_pose_gap(sync, clips, sk, String(lc["idle"]), walk, hgt),
			"walk_run": _first_pose_gap(sync, clips, sk, walk, run, hgt),
			"contact_walk_run": _contact_gap(sync, clips, sk, walk, run)}
	var weapon := ""
	row["attacks"] = {}
	for nm in ATTACKS[id]:
		row["attacks"][nm] = _attack(sync, clips, sk, String(nm), hgt)
		if weapon == "":
			weapon = row["attacks"][nm]["weapon_hand"]
	row["weapon_hand"] = weapon
	row["props"] = await _held(m, sync, clips, sk, id, hgt, String(lc["idle"]))
	rows[id] = row
	var top: Dictionary = live[str(SPEEDS[2])]
	print("AUDIT %-10s H %.2f run: slide %.2f m/s (%d%%) clip %.2f m/s arms %.2f bob %.1f cm peaks %d" % [id, hgt,
			top["slide"], round(100.0 * top["slide"] / SPEEDS[2]), top["clip_speed"], top["counter"], top["bob_cm"],
			top["peaks"]])
	if not id in NO_LEGS:
		_gate(id, top)
	m.free()

## How far each held prop's anchor wanders from its hand bone over the idle and the attacks (body heights).
func _held(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, id: String, hgt: float, idle: String) -> Dictionary:
	var out := {}
	for an in HELD.get(id, {}):
		var node := WardenGlb.anchor(m, an)
		var bone := WardenSkeleton.find(sk, String(HELD[id][an]))
		var lo := INF
		var hi := -INF
		for clip in [idle] + ATTACKS[id]:
			var length := clips.lib.get_animation(clip).length
			for i in 12:
				clips.force = {"clip": clip, "t": minf(length * i / 11.0, length - 0.001)}
				sync.call("_process", DT)
				await m.get_tree().process_frame      # (a bone attachment follows its bone a frame later)
				var d := node.global_position.distance_to(sk.global_transform * sk.get_bone_global_pose(bone).origin)
				lo = minf(lo, d)
				hi = maxf(hi, d)
		clips.force = {}
		out[an] = {"dist": lo / hgt, "drift": (hi - lo) / hgt}
		print("PROP %-10s %s on %s: %.2f H, drift %.3f H" % [id, an, HELD[id][an], lo / hgt, (hi - lo) / hgt])
		if (hi - lo) / hgt > MAX_PROP_DRIFT:
			print("FAIL %s: %s drifts %.3f H off %s" % [id, an, (hi - lo) / hgt, HELD[id][an]])
			bad += 1
	return out

func _gate(id: String, top: Dictionary) -> void:
	var share: float = top["slide"] / SPEEDS[2]
	if share > MAX_SLIDE:
		print("FAIL %s: feet slide %d%% of the run speed (limit %d%%)" % [id, round(100.0 * share),
				round(100.0 * MAX_SLIDE)])
		bad += 1
	if top["counter"] < MIN_COUNTER:
		print("FAIL %s: arms swing with their leg (%.2f, wanted at least %.2f)" % [id, top["counter"], MIN_COUNTER])
		bad += 1

## Where the bones are, model frame, metres: the points of POINTS, plus the arms' direction.
func _read(sk: Skeleton3D) -> Dictionary:
	var out := {}
	var xf := sk.global_transform
	for b in ["hips", "head", "hand.L", "hand.R", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"]:
		out[b] = xf * sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin
	for side in ["L", "R"]:
		var shin := WardenSkeleton.find(sk, "shin." + side)
		var thigh := WardenSkeleton.find(sk, "thigh." + side)
		var gs := sk.get_bone_global_pose(shin)
		var leg := (sk.get_bone_global_rest(shin).origin - sk.get_bone_global_rest(thigh).origin).length()
		out["foot." + side] = xf * (gs.origin + gs.basis.y.normalized() * leg)
	return out

func _height(sync: Node, clips: WardenClips, sk: Skeleton3D, idle: String) -> float:
	var p := _pose_at(sync, clips, sk, idle, 0.0)
	return maxf((p["head"] as Vector3).y - minf((p["foot.L"] as Vector3).y, (p["foot.R"] as Vector3).y), 0.5)

func _pose_at(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, t: float) -> Dictionary:
	clips.force = {"clip": clip, "t": 0.0}
	for k in 6:
		sync.call("_process", DT)
	clips.force = {"clip": clip, "t": t}
	sync.call("_process", DT)
	var p := _read(sk)
	clips.force = {}
	return p

func _clip_frames(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, n: int) -> Array:
	var length := clips.lib.get_animation(clip).length
	var out: Array = []
	clips.force = {"clip": clip, "t": 0.0}
	for k in 6:
		sync.call("_process", DT)
	for i in n:
		clips.force = {"clip": clip, "t": minf(length * i / (n - 1), length - 0.001)}
		sync.call("_process", DT)
		out.append(_read(sk))
	clips.force = {}
	return out

## A gait at speed s, as the game plays it: the state carries the velocity, facing -Z.
func _gait(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, s: float) -> Dictionary:
	m.set_meta(WardenClips.STATE, {"vel": Vector3(0, 0, -s), "face": 0.0, "grounded": true})
	clips.loco_pos = Vector2.ZERO
	for k in int(WARM_S / DT):
		sync.call("_process", DT)
	var fr: Array = []
	for k in int(SAMPLE_S / DT):
		sync.call("_process", DT)
		fr.append(_read(sk))
	m.set_meta(WardenClips.STATE, {})
	var out := _slide(fr, s)
	out.merge(_swing(fr))
	return out

## Foot slide: while a foot is planted its speed against the ground is the speed minus how fast the clip pulls it back.
func _slide(fr: Array, s: float) -> Dictionary:
	var slide := 0.0
	var peak := 0.0
	var back := 0.0
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
			var v: float = ((fr[i + 1][f] as Vector3).z - (fr[i - 1][f] as Vector3).z) / (2.0 * DT)     # +Z: backward
			slide += absf(s - v)
			peak = maxf(peak, absf(s - v))
			back += v
			n += 1
	return {"slide": slide / maxi(n, 1), "slide_max": peak, "clip_speed": back / maxi(n, 1), "planted": n}

## Hip bob, arm swing against the legs (1: each arm swings against its own-side leg, 0: none) and how far they swing.
func _swing(fr: Array) -> Dictionary:
	var hy: Array = []
	var arm := {"L": [], "R": []}
	var leg := {"L": [], "R": []}
	for p in fr:
		hy.append((p["hips"] as Vector3).y)
		for side in ["L", "R"]:
			arm[side].append(-((p["hand." + side] as Vector3).z - (p["hips"] as Vector3).z))
			leg[side].append(-((p["foot." + side] as Vector3).z - (p["hips"] as Vector3).z))
	var lo: float = hy.min()
	var hi: float = hy.max()
	var peaks := 0
	for i in range(1, hy.size() - 1):
		if hy[i] > hy[i - 1] and hy[i] >= hy[i + 1] and hy[i] > lo + 0.5 * (hi - lo):
			peaks += 1
	var span: float = fr.size() * DT
	var reach_l: float = (arm["L"] as Array).max() - (arm["L"] as Array).min()
	var reach_r: float = (arm["R"] as Array).max() - (arm["R"] as Array).min()
	var against_l := -_corr(arm["L"], leg["L"])
	var against_r := -_corr(arm["R"], leg["R"])
	return {"bob_cm": 100.0 * (hi - lo), "peaks": peaks, "peak_hz": peaks / span, "reach_L": reach_l,
			"reach_R": reach_r,
			"against_L": against_l, "against_R": against_r,
			"counter": (reach_l * against_l + reach_r * against_r) / maxf(reach_l + reach_r, 0.01),
			"steps_hz": _steps(leg["L"], span)}

func _steps(leg: Array, span: float) -> float:
	var c := 0
	for i in range(1, leg.size()):
		if leg[i - 1] < 0.0 and leg[i] >= 0.0:
			c += 1
	return 2.0 * c / span

func _corr(a: Array, b: Array) -> float:
	var ma := 0.0
	var mb := 0.0
	for i in a.size():
		ma += a[i]
		mb += b[i]
	ma /= a.size()
	mb /= a.size()
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in a.size():
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	return sab / sqrt(maxf(saa * sbb, 1e-9))

func _dist(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for k in POINTS:
		worst = maxf(worst, ((a[k] as Vector3) - (b[k] as Vector3)).length())
	return worst

## The last frame of a loop against its first, as a fraction of the Hunter's height.
func _seam(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, hgt: float) -> float:
	var length := clips.lib.get_animation(clip).length
	return _dist(_pose_at(sync, clips, sk, clip, 0.0), _pose_at(sync, clips, sk, clip, length - 0.001)) / hgt

func _first_pose_gap(sync: Node, clips: WardenClips, sk: Skeleton3D, a: String, b: String, hgt: float) -> float:
	return _dist(_pose_at(sync, clips, sk, a, 0.0), _pose_at(sync, clips, sk, b, 0.0)) / hgt

## 0..0.5 of a cycle: how far apart the two loops put the left foot's touchdown (a blend between them crosses the legs).
func _contact_gap(sync: Node, clips: WardenClips, sk: Skeleton3D, a: String, b: String) -> float:
	return absf(_touch(sync, clips, sk, a) - _touch(sync, clips, sk, b))

func _touch(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String) -> float:
	var fr := _clip_frames(sync, clips, sk, clip, 24)
	var best := 0
	for i in fr.size():
		if (fr[i]["foot.L"] as Vector3).z < (fr[best]["foot.L"] as Vector3).z:
			best = i
	return float(best) / (fr.size() - 1)

func _attack(sync: Node, clips: WardenClips, sk: Skeleton3D, clip: String, hgt: float) -> Dictionary:
	var fr := _clip_frames(sync, clips, sk, clip, 24)
	var path := {"L": 0.0, "R": 0.0}
	var out_frames := 0
	var jump := 0.0
	for i in fr.size():
		for side in ["L", "R"]:
			if i > 0:
				var step := ((fr[i]["hand." + side] as Vector3) - (fr[i - 1]["hand." + side] as Vector3)).length()
				path[side] += step
				jump = maxf(jump, step)
		if _t_posed(fr[i], "L") or _t_posed(fr[i], "R"):
			out_frames += 1
	var weapon := "R" if path["R"] >= path["L"] else "L"
	var length := clips.lib.get_animation(clip).length
	return {"length": length, "weapon_hand": weapon, "weapon_travel": path[weapon] / hgt,
			"free_travel": path["L" if weapon == "R" else "R"] / hgt, "t_pose": float(out_frames) / fr.size(),
			"jump": jump / hgt}

func _t_posed(p: Dictionary, side: String) -> bool:
	var d: Vector3 = (p["forearm." + side] as Vector3) - (p["upper_arm." + side] as Vector3)
	return d.angle_to(Vector3.DOWN) > T_ELEV and absf(d.x) > SIDEWAYS * absf(d.z)
