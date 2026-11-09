extends RefCounted
## --boki-anim-audit [--boki=a,b] [--json=<file>] [--bones]: how every rigged Boki's walk and run measure
## (docs/art/kin/RIGGED_BOKI.md, "Gait audit"). FAIL lines and exit code 1 (see MAX_SLIDE). No renderer needed.
## Per Boki it drives the real BokiRig: a Kin root moves at a speed and the rig reads it, picks the clip and the clip
## rate (BokiRig._process), the player is stepped by hand. Per speed it reads the feet:
##  - slide: while a foot is planted, its speed against the ground, as a share of the move speed;
##  - steps per second;
## and per clip the loop seam, and the pop from the idle into the walk and the walk into the run.

const Shots := preload("res://tools/boki_rig_shots.gd")
const DT := 1.0 / 30.0
const WARM_S := 0.8          # s of locomotion before a sample, so the blend and the speed have settled
const SAMPLE_S := 2.4        # s of locomotion sampled
## m/s: a stroll, a home wander (home.gd 2.4), a home fetch (4.4), a match Boki (kin_speed 5 + 0.2 per point).
const SPEEDS := [1.5, 2.4, 4.4, 6.5]
const PLANT_BAND := 0.5      # a foot is planted in the lowest half of its own height range (and moving back)
## The gate: at any of SPEEDS a planted foot slides at most this share of the speed, unless the legs are already
## at BokiRig.MAX_STEP_HZ: then the stride is too short for the speed (the clips cannot be re-keyed here), and the
## row is listed as STRIDE-LIMITED instead of failed.
const MAX_SLIDE := 0.25
const LIMITED_HZ := 0.8      # of BokiRig.MAX_STEP_HZ: the legs count as sped up to the cap from here
## No stepping legs: flyers, serpents and blobs. Listed in the table, not gated.
const EXEMPT := {"thrumbird": "flyer", "kestrike": "flyer", "wisplet": "flyer", "selenfin": "flyer",
	"zephyrak": "serpent", "glomwort": "blob", "gloamshell": "blob (snail)"}
const FOOT_WORDS := ["paw", "foot", "toe", "hoof"]

var bad := 0
var old_rate := false      # --old-rate: the clip rate BokiRig had before GAIT (the before column)
var holder: Node3D
var rows := {}

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = _species()
	var json := ""
	var bones := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boki="): ids = Array(a.substr(7).split(",", false))
		if a.begins_with("--json="): json = a.substr(7)
		if a == "--bones": bones = true
		if a == "--old-rate": old_rate = true
	for id in ids:
		await _boki(main, String(id), bones)
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	print("BOKI_ANIM_AUDIT_DONE ", rows.size(), " FAIL ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species() -> Array:
	var out: Array = []
	for id in BokiRig.FRAME:
		out.append(id)
	out.sort()
	return out

func _boki(main: Node, id: String, bones: bool) -> void:
	var k := Shots.rigged_kin(id)
	holder.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var sk := rig.skeleton()
	if bones:
		var names := []
		for i in sk.get_bone_count():
			names.append("%s:%.2f" % [sk.get_bone_name(i), sk.get_bone_global_rest(i).origin.y])
		print("BONES ", id, " ", ",".join(names))
	rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var feet := _feet(sk)
	var row := {"feet": feet.size(), "exempt": EXEMPT.get(id, "")}
	var live := {}
	for s in SPEEDS:
		live[str(s)] = _gait(k, rig, sk, feet, s)
	row["live"] = live
	row["clip"] = {}
	for nm in ["walk", "run"]:
		row["clip"][nm] = _clip_gait(k, rig, sk, feet, nm)
	row["seam"] = {}
	for nm in ["idle", "walk", "run"]:
		row["seam"][nm] = _seam(rig, sk, nm)
	row["pop"] = {"idle_walk": _pop(rig, sk, "idle", "walk"), "walk_run": _pop(rig, sk, "walk", "run")}
	rows[id] = row
	var cw: Dictionary = row["clip"]["walk"]
	var cr: Dictionary = row["clip"]["run"]
	print("BOKIGAIT \"%s\": [%.2f, %.1f, %.2f, %.1f]," % [id, cw["foot_mps"], cw["steps_hz"],
			cr["foot_mps"], cr["steps_hz"]])
	var worst := 0.0
	for s in SPEEDS:
		worst = maxf(worst, float(live[str(s)]["slide"]) / s)
	var slides: Array = []
	var cadence: Array = []
	for sp in SPEEDS:
		slides.append("%d%%" % round(100.0 * live[str(sp)]["slide"] / sp))
		cadence.append("%.1f" % live[str(sp)]["steps_hz"])
	var tag := " EXEMPT " + String(EXEMPT[id]) if id in EXEMPT else ""
	print("BOKIAUDIT %-10s feet %d slide worst %d%% (%s) steps/s %s seam %.2f/%.2f pop %.2f/%.2f%s" % [id,
			feet.size(), round(100.0 * worst), ", ".join(slides), ", ".join(cadence), row["seam"]["walk"],
			row["seam"]["run"], row["pop"]["idle_walk"], row["pop"]["walk_run"], tag])
	if not id in EXEMPT:
		_gate(id, live)
	k.queue_free()

## The foot bones: the end bones named like a foot, or else the lowest bones of the legs.
func _feet(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).to_lower()
		for w in FOOT_WORDS:
			if nm.contains(w):
				out.append(i)
				break
	return out

func _gate(id: String, live: Dictionary) -> void:
	for sp in SPEEDS:
		var g: Dictionary = live[str(sp)]
		var share: float = g["slide"] / sp
		if share <= MAX_SLIDE:
			continue
		if g["steps_hz"] >= LIMITED_HZ * BokiRig.MAX_STEP_HZ:
			g["limited"] = true
			continue
		print("FAIL %s: planted feet slide %d%% of %.1f m/s at %.1f steps/s (limit %d%%)" % [id,
				round(100.0 * share), sp, g["steps_hz"], round(100.0 * MAX_SLIDE)])
		bad += 1

## The feet in the Kin's frame, metres (the model is scaled into the Kin).
func _read(k: Node3D, sk: Skeleton3D, feet: Array) -> Array:
	var out: Array = []
	var xf := k.global_transform.affine_inverse() * sk.global_transform
	for b in feet:
		out.append(xf * sk.get_bone_global_pose(b).origin)
	return out

## The clip rate BokiRig had before GAIT: speed over 1.5 (walk) or 2.9 m/s (run), at most 1.6x.
static func old_rate_scale(rig: BokiRig) -> void:
	if rig.clip == "run":
		rig.player.speed_scale = clampf(rig._speed / 2.9, 0.7, 1.6)
	elif rig.clip == "walk":
		rig.player.speed_scale = clampf(rig._speed / 1.5, 0.6, 1.6)

func _step(k: Node3D, rig: BokiRig, v: float) -> void:
	k.position.z -= v * DT
	rig._process(DT)
	if old_rate:
		old_rate_scale(rig)
	rig.player.advance(DT)

## A gait at speed v, as the game plays it: the root moves, the rig reads its own speed.
func _gait(k: Node3D, rig: BokiRig, sk: Skeleton3D, feet: Array, v: float) -> Dictionary:
	k.position = Vector3.ZERO
	rig._pos_prev = k.global_position
	rig._speed = 0.0
	rig.set_clip("idle", 0.0)
	for i in int(WARM_S / DT):
		_step(k, rig, v)
	var fr: Array = []
	var clip_at := rig.clip
	var rate := rig.player.speed_scale
	for i in int(SAMPLE_S / DT):
		_step(k, rig, v)
		fr.append(_read(k, sk, feet))
	var out := _slide(fr, v, feet.size())
	out["clip"] = clip_at
	out["rate"] = rate
	return out

## A clip alone at rate 1: how fast its planted feet go back (m/s) and its length.
func _clip_gait(k: Node3D, rig: BokiRig, sk: Skeleton3D, feet: Array, clip: String) -> Dictionary:
	rig.set_clip(clip, 0.0)
	rig.player.speed_scale = 1.0
	var fr: Array = []
	for i in int(SAMPLE_S / DT):
		rig.player.advance(DT)
		fr.append(_read(k, sk, feet))
	var out := _slide(fr, 0.0, feet.size())
	return {"foot_mps": out["slide"], "steps_hz": out["steps_hz"], "length": rig.player.get_animation(clip).length}

## Foot slide: a foot is planted while it is low and moving backward; its speed against the ground is the speed
## minus how fast the clip pulls it back. Steps: twice the cycles of the feet (a foot's z crossing its mean going back).
func _slide(fr: Array, v: float, n_feet: int) -> Dictionary:
	var slide := 0.0
	var n := 0
	var cycles := 0
	for f in n_feet:
		var lo := INF
		var hi := -INF
		var mean := 0.0
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
			mean += (p[f] as Vector3).z / fr.size()
		for i in range(1, fr.size() - 1):
			if (fr[i - 1][f] as Vector3).z < mean and (fr[i][f] as Vector3).z >= mean:
				cycles += 1
			var back: float = ((fr[i + 1][f] as Vector3).z - (fr[i - 1][f] as Vector3).z) / (2.0 * DT)  # +Z: back
			if back > 0.0 and (fr[i][f] as Vector3).y <= lo + PLANT_BAND * maxf(hi - lo, 0.02):
				slide += absf(v - back)
				n += 1
	return {"slide": slide / maxi(n, 1), "planted": n, "steps_hz": 2.0 * cycles / n_feet / SAMPLE_S}

func _pose(rig: BokiRig, sk: Skeleton3D, clip: String, t: float) -> Array:
	rig.set_clip(clip, 0.0)
	rig.player.seek(t, true)
	rig.player.advance(0.0)
	var out: Array = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(i).origin)
	return out

func _dist(a: Array, b: Array, hgt: float) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, ((a[i] as Vector3) - (b[i] as Vector3)).length())
	return worst / hgt

func _height(rig: BokiRig, sk: Skeleton3D) -> float:
	var hi := 0.0
	for p in _pose(rig, sk, "idle", 0.0):
		hi = maxf(hi, (p as Vector3).y)
	return maxf(hi, 0.2)

func _seam(rig: BokiRig, sk: Skeleton3D, clip: String) -> float:
	var length := rig.player.get_animation(clip).length
	return _dist(_pose(rig, sk, clip, 0.0), _pose(rig, sk, clip, length - 0.001), _height(rig, sk))

func _pop(rig: BokiRig, sk: Skeleton3D, a: String, b: String) -> float:
	return _dist(_pose(rig, sk, a, 0.0), _pose(rig, sk, b, 0.0), _height(rig, sk))
