extends RefCounted
## --strike-reach-check [--reach-trace]: every melee and close strike against its kit's hit reach (content/archetypes)
## at the owner's heights. A keyed move with "strike" in warden_anim ([point, reach, rule]) is stepped frame by frame
## and its striking point read: "tip" (the skinned weapon's weapon_muzzle), a bone, "fist" (the lower hand) or "front"
## (the body's leading point, a ram). The reach is a path into the archetype's data ("lmb/reach"), or "ram" (the hit
## radius plus the ram's touch). Rules: "edge", the point's furthest reach lands within TOL of the hit area's edge (a
## cut, a ring, a strip); "ground", where the point lands lowest it is inside the area ahead (a slam into the ground);
## "start", where it lands furthest forward it is inside the area (a punch that starts a lane); "throw", the hand is
## ahead of the body at the release. --clip-check runs this too; alone, --reach-trace prints every frame. Never touches
## the save.

const DT := 1.0 / 30.0
const TOL := 0.15             # of the reach: how far the tip may land short of or past the hit area's edge
const RAM_TOUCH := 0.45       # m: the Soot Ram hits a foe within hit_r + this of Cinder's centre (ashwick_kit)
## Strikes docs/art/wardens/CLIPS.md found short at the owner's heights: "<id>:<move>" -> why (docs/DEBT.md). Reported,
## not failed; a re-keyed clip that reaches removes its entry.
const OPEN := {
	"juggernaut:jug_slash_r": "tip 2.1 of 3.1 m: the arm folds, the sword is the splash's 0.61; straight out 2.6",
	"juggernaut:jug_slash_l": "tip 2.1 of 3.1 m: the arm folds, the sword is the splash's 0.61; straight out 2.6",
	"juggernaut:jug_riposte": "tip 1.9 of the 3.6 m strip: the elbow sits behind the shoulder; straight out 2.2",
	"bulwark:bul_whirl": "head 2.9 of the 3.5 m ring: arm and hammer straight out reach 3.2",
}

var bad := 0
var trace := false

func ok(cond: bool, what: String) -> void:
	print("REACH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	trace = "--reach-trace" in OS.get_cmdline_user_args()
	var holder := Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ids():
		var dd := WardenClips.data(WardenGlb.art(String(id)))
		if dd.is_empty():
			continue
		var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		m.set_meta("anim_seed", 1)
		holder.add_child(m)
		var sync := m.get_node_or_null("Warden/Sync")
		if sync != null and sync.get("clips") != null:
			sync.set_process(false)
			n += await hero(String(id), m, sync, dd, main.get_tree())
		m.free()
	ok(n > 0, "at least one strike measured (%d)" % n)
	print("STRIKE_REACH_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A Hero's strikes (the model `m` in the tree, its Sync not processing): the rows checked. Returns how many.
func hero(id: String, m: Node3D, sync: Node, dd: Dictionary, tree: SceneTree) -> int:
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var n := 0
	var moves: Dictionary = dd.get("kmoves", {})
	for km in moves:
		var mv: Dictionary = moves[km]
		if not mv.has("strike"):
			continue
		n += 1
		var spec: Array = mv["strike"]
		var reach := _reach(id, String(spec[1]))
		ok(reach > 0.0, "%s %s: kit reach %s = %.2f m" % [id, km, spec[1], reach])
		if reach <= 0.0:
			continue
		var clip := String(mv["clip"])
		var length := clips.lib.get_animation(clip).length
		var end := float(mv.get("hold_from", length))
		var rule := String(spec[2])
		var pick := Vector3.ZERO      # the point at the frame the rule reads
		var pick_t := -1.0
		var t := 0.0
		while t <= end + 0.001:
			clips.force = {"clip": clip, "t": minf(t, length - 0.001)}
			for k in 3:
				sync.call("_process", DT)
			await tree.process_frame
			var p := _point(m, sync, sk, String(spec[0]))
			if trace:
				print("TRACE %s %s t %.3f flat %.2f fwd %.2f y %.2f" % [
						id, km, t, Vector2(p.x, p.z).length(), -p.z, p.y])
			var better := false
			match rule:
				"edge":
					better = Vector2(p.x, p.z).length() > Vector2(pick.x, pick.z).length()
				"ground":
					better = pick_t < 0.0 or p.y < pick.y
				_:
					better = -p.z > -pick.z
			if better or pick_t < 0.0:
				pick = p
				pick_t = t
			t += DT
		clips.force = {}
		_judge(id, String(km), String(spec[0]), rule, pick, pick_t, reach)
	return n

func _judge(id: String, km: String, point: String, rule: String, p: Vector3, t: float, reach: float) -> void:
	var flat := Vector2(p.x, p.z).length()
	var fwd := -p.z
	var good := false
	var what := ""
	match rule:
		"edge":
			good = absf(flat / reach - 1.0) <= TOL
			what = "%s lands on the hit area's edge: %.2f of %.2f m (%+.0f%%) at %.2f s" % [
					point, flat, reach, (flat / reach - 1.0) * 100.0, t]
		"ground":
			good = fwd >= 0.0 and flat <= reach and p.y < 0.6
			what = "%s lands inside the area ahead: %.2f m out (%.2f fwd, %.2f up) of %.2f at %.2f s" % [
					point, flat, fwd, p.y, reach, t]
		"start":
			good = fwd > 0.0 and flat <= reach
			what = "%s starts inside the area: %.2f m fwd of %.2f at %.2f s" % [point, fwd, reach, t]
		"throw":
			good = fwd > 0.0
			what = "%s is ahead of the body at the release: %.2f m fwd at %.2f s" % [point, fwd, t]
	var key := "%s:%s" % [id, km]
	if OPEN.has(key):
		var stale := " (now reaches: drop it from OPEN)" if good else ""
		print("REACH open %s %s %s [%s]%s" % [id, km, what, OPEN[key], stale])
		ok(not good, "%s: OPEN entry still needed" % key)
	else:
		ok(good, "%s %s: %s" % [id, km, what])

static func _reach(id: String, path: String) -> float:
	if path == "ram":
		return Arch.hit_r(id, Data.CLASSES[Arch.weight(id)]) + RAM_TOUCH
	var v: Variant = Arch.def(id)
	for k in path.split("/"):
		v = (v as Dictionary).get(k, {}) if v is Dictionary else (v as Array)[int(k)]
	return float(v) if v is float or v is int else -1.0

static func _bone(m: Node3D, sk: Skeleton3D, b: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin - m.global_position

## The striking point in the Hero's own frame (it stands at the origin facing -z).
static func _point(m: Node3D, sync: Node, sk: Skeleton3D, which: String) -> Vector3:
	match which:
		"tip":
			return (sync.get("blade_tip") as Node3D).global_position - m.global_position
		"fist":
			var r := _bone(m, sk, "hand.R")
			var l := _bone(m, sk, "hand.L")
			return r if r.y <= l.y else l
		"front":
			var g := Vector3.ZERO
			var tip := (sync.get("blade_tip") as Node3D).global_position - m.global_position
			for at in [tip, _bone(m, sk, "head"), _bone(m, sk, "hips"), _bone(m, sk, "hand.R"), _bone(m, sk, "hand.L")]:
				if -(at as Vector3).z > -g.z:
					g = at
			return g
	return _bone(m, sk, which)
