extends RefCounted
## --anim-strafe-check [--wardens=a,b]: every Hunter on hand-keyed clips runs forward, sideways and back while its
## LMB clip plays on the upper body, facing -Z (the cursor). Per direction it reads the planted foot as the
## ext/anim-quality-audit --anim-audit slide metric does (lowest 30 % of the foot's own height range), but in 2D: a
## planted foot must travel against the move at the move's speed. Prints the slide (% of the speed) and how
## far the planted foot's travel points off the move (deg: 0 the legs follow, 90 a forward run carried sideways).
## Gate (every Hunter with legs): the planted foot travels within MAX_OFF of the move in every direction, and a diagonal
## slides at most MAX_EXTRA of the speed over the worse of its two run clips. A run clip's own slide (stride and rate)
## is --anim-audit's.

const DT := 1.0 / 30.0
const WARM_S := 1.0          # s of locomotion before a sample, so the blends have settled
const SAMPLE_S := 2.4        # s sampled
const SPEED := 4.65          # m/s: full stick (content/rules/hunter_move.json)
const PLANT_BAND := 0.3      # a foot is planted in the lowest 30 % of its own height range
const MAX_EXTRA := 0.2       # of the speed: a diagonal over its run clips (two clips blended: 25-80 points over)
const MAX_OFF := 15.0        # deg: the most a planted foot's travel may point off the move
const NO_LEGS := ["ostra", "rimewright"]     # hover and skate clips (the --anim-audit exemption)
## (model frame, facing -Z: the move, and its name; the run clips first, as the diagonals read them)
const DIRS := {"f": Vector3(0, 0, -1), "r": Vector3(1, 0, 0), "l": Vector3(-1, 0, 0), "b": Vector3(0, 0, 1),
	"fl": Vector3(-0.7071, 0, -0.7071), "fr": Vector3(0.7071, 0, -0.7071),
	"bl": Vector3(-0.7071, 0, 0.7071), "br": Vector3(0.7071, 0, 0.7071)}
const SIDES := {"fl": ["f", "l"], "fr": ["f", "r"], "bl": ["b", "l"], "br": ["b", "r"]}     # a diagonal's run clips
## The kmove each Hunter's LMB plays (content/rules/warden_anim), held mid-clip while it moves
const LMB := {"archer": "arc_loose", "ashwick": "as_shot", "bulwark": "bul_throw", "dolm": "breah_throw",
	"dredge": "dr_shot", "gunslinger": "gunslinger_lmb", "juggernaut": "jug_slash_r", "mage": "mage_lmb_l",
	"ostra": "ostra_orb", "rimewright": "tm_dart_r", "tender": "mm_shot_r", "thief": "thf_lmb_r"}

var bad := 0
var holder: Node3D

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = LMB.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
	for id in ids:
		await _hero(main, String(id))
	print("ANIM_STRAFE_DONE ", ids.size(), " FAIL ", bad)
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
	var km := String(LMB[id])
	var mv: Dictionary = clips.d.get("kmoves", {}).get(km, {})
	var length := clips.lib.get_animation(String(mv["clip"])).length if mv.has("clip") else 0.0
	var up_v: Variant = mv.get("upper", false)
	var upper: bool = not (up_v is bool and not up_v)     # ("moving" and true keep the legs on the loco)
	var line := "STRAFE %-10s %-14s" % [id, km if upper else "(full: legs only)"]
	var share := {}
	for nm in DIRS:
		var r := _run(m, sync, clips, sk, DIRS[nm] * SPEED, km, length, upper)
		share[nm] = r["slide"] / SPEED
		line += " %s %3d%% %3ddeg" % [nm, round(100.0 * share[nm]), round(r["off"])]
		var cap := INF
		if SIDES.has(nm):
			cap = maxf(share[SIDES[nm][0]], share[SIDES[nm][1]]) + MAX_EXTRA
		if not id in NO_LEGS and (share[nm] > cap or r["off"] > MAX_OFF):
			print("FAIL %s %s: feet slide %d%% (its run clips' cap %d%%), travel %d deg off the move" % [id, nm,
					round(100.0 * share[nm]), round(100.0 * minf(cap, 9.99)), round(r["off"])])
			bad += 1
	print(line)
	m.free()

## A run at vel (model frame) with the LMB held mid-clip, as the game feeds it.
func _run(m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, vel: Vector3, km: String, length: float,
		mv_upper: bool) -> Dictionary:
	clips.loco_pos = Vector2.ZERO
	var fr: Array = []
	for k in int((WARM_S + SAMPLE_S) / DT):
		var s := {"vel": vel, "face": 0.0, "grounded": true}
		if length > 0.0 and mv_upper:
			s["kmove"] = km
			s["kmove_t"] = length * 0.5
		m.set_meta(WardenClips.STATE, s)
		sync.call("_process", DT)
		if k >= int(WARM_S / DT):
			fr.append(_feet(sk))
	m.set_meta(WardenClips.STATE, {})
	return _slide(fr, vel)

## The two feet (the shin's end), model frame, metres.
func _feet(sk: Skeleton3D) -> Dictionary:
	var out := {}
	var xf := sk.global_transform
	for side in ["L", "R"]:
		var shin := WardenSkeleton.find(sk, "shin." + side)
		var thigh := WardenSkeleton.find(sk, "thigh." + side)
		var gs := sk.get_bone_global_pose(shin)
		var leg := (sk.get_bone_global_rest(shin).origin - sk.get_bone_global_rest(thigh).origin).length()
		out[side] = xf * (gs.origin + gs.basis.y.normalized() * leg)
	return out

## Planted foot: its ground speed is the move plus its travel in the model frame; off: its travel against the move.
func _slide(fr: Array, vel: Vector3) -> Dictionary:
	var want := Vector2(-vel.x, -vel.z)
	var slide := 0.0
	var travel := Vector2.ZERO
	var n := 0
	for f in ["L", "R"]:
		var lo := INF
		var hi := -INF
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		for i in range(1, fr.size() - 1):
			if (fr[i][f] as Vector3).y > lo + PLANT_BAND * maxf(hi - lo, 0.02):
				continue
			var d: Vector3 = ((fr[i + 1][f] as Vector3) - (fr[i - 1][f] as Vector3)) / (2.0 * DT)
			var v := Vector2(d.x, d.z)
			slide += (v - want).length()
			travel += v
			n += 1
	var off := rad_to_deg(absf(travel.angle_to(want))) if travel.length() > 0.05 else 180.0
	return {"slide": slide / maxi(n, 1), "off": off}
