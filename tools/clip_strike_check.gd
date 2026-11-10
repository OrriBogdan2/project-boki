extends RefCounted
## A Hero's clip strikes against his kit (briefs/DECISIONS.md 2026-11-07, parity first): each listed move's clip
## is swept offline at 60 Hz through the Hero's WardenClips library, and its strike (the fastest hand frame, either
## hand) is set, on the kit's move clock (the clip time minus the move's "lead"), against the moment the kit
## releases the move. Runs inside --dancer-combo-check (Sable) and --ostra-combo-check (Motley); the tables it keeps
## true are "Animation timing" in docs/heroes/thief.md and docs/heroes/ostra.md.

const DT := 1.0 / 60.0
const TOL := 0.05          # s: a strike this close to the release reads as one beat (a quarter of a 5 fps frame)
const HANDS := ["hand.L", "hand.R"]

## events: kit move -> s on its move clock at which the kit releases it; winds: move -> clip s its wind-up lasts
## (a whirl faster than the throw, not searched). a: any check with ok(name, cond, info).
func run(a, main: Node, id: String, events: Dictionary, winds := {}) -> void:
	var mdl := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	main.add_child(mdl)
	var sync := mdl.get_node("Warden/Sync")
	sync.set_process(false)
	var cl: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(mdl.get_node("Warden"))
	cl.tree.active = false
	var glb := cl.tree.get_parent()
	var ap := AnimationPlayer.new()
	glb.add_child(ap)
	ap.root_node = ap.get_path_to(glb)
	ap.add_animation_library("", cl.lib)
	var bones: Array = HANDS.map(func(b): return sk.find_bone(b))
	var moves: Dictionary = cl.d["kmoves"]
	for km in events:
		var mv: Dictionary = moves[km]
		var wind := float(winds.get(km, 0.0))
		var strike := _strike(ap, sk, bones, String(mv["clip"]), wind) - float(mv.get("lead", 0.0))
		var gap := strike - float(events[km])
		a.ok("%s clip timing: %s strikes at %.2f s, the kit releases it at %.2f s" % [id, km, strike, events[km]],
				absf(gap) <= TOL, "%+.2f s" % gap)
	mdl.free()

## The clip time (s) at the end of its fastest hand frame after the wind-up.
func _strike(ap: AnimationPlayer, sk: Skeleton3D, bones: Array, clip: String, wind: float) -> float:
	var length := ap.get_animation(clip).length
	ap.play(clip)
	var prev: Array = []
	var best := 0.0
	var at := 0.0
	var t := 0.0
	while t <= length:
		ap.seek(t, true)
		sk.force_update_all_bone_transforms()
		var pts: Array = bones.map(func(b): return sk.get_bone_global_pose(b).origin)
		for i in prev.size():
			var v := (pts[i] as Vector3).distance_to(prev[i]) / DT
			if v > best and t > wind:
				best = v
				at = t
		prev = pts
		t += DT
	return at
