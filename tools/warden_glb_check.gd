extends RefCounted
## --warden-glb-check (docs/art/wardens/RIG_CONTRACT.md): the .glb loader's bone table covers every rig node
## HunterAnim poses; every Warden without art/wardens/<name>/<name>.glb builds the procedural model (the
## fallback). Each Warden that has a .glb: it loads, its armature is the contract's (bone names, parents,
## each bone on its rig node), every kit move in every table retargets onto it (the bones sit exactly where
## their rig nodes put them, and each keyed channel moves the bones it drives), the anchor empties ride
## their bones, every surface is on the hero toon shader with the atlas, the hit radius and ring are the
## same as the procedural model's, it stays in the triangle and slot budget, the player's setting turns it
## back into the procedural model and on again, and its idle and run stay its own (not another Warden's).

## Every node HunterAnim binds (HunterAnim._init) that a body mesh can hang on.
const ANIM_PARTS := ["Rig", "Rig/Torso", "Rig/Torso/HeadPivot", "Rig/Torso/ArmLPivot", "Rig/Torso/ArmLPivot/Elbow",
	"Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Torso/ArmRPivot", "Rig/Torso/ArmRPivot/Elbow",
	"Rig/Torso/ArmRPivot/Elbow/Hand",
	"Rig/Legs/LegL", "Rig/Legs/LegL/Knee", "Rig/Legs/LegR", "Rig/Legs/LegR/Knee", "Rig/Torso/PauldronL",
	"Rig/Torso/PauldronR", "Rig/Torso/Skirt", "Rig/Torso/Cape", "Rig/Torso/Scarf", "Rig/Torso/Tail", "Rig/Torso/Wings"]
## Each kit-move channel and the bones it moves (relative to their parent bone). The blade channels only
## drive bladed weapons, so they are not asserted on other Wardens.
const CHANNEL_BONES := {
	"p": ["hips"], "y": ["hips"], "r": ["hips"], "fx": ["root"], "fy": ["root"], "fz": ["root"],
	"lift": ["root", "hips"], "sq": ["root", "hips"],
	"legs": ["thigh.L", "shin.L", "thigh.R", "shin.R"],
	"fl": ["upper_arm.L", "forearm.L", "hand.L"], "fr": ["upper_arm.R", "forearm.R", "hand.R"],
	"gp": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
	"wa": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
	"wo": ["upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"],
}
## A channel's weight: it only plays when that is above zero.
const CHANNEL_WEIGHT := {"legs": "lw", "fl": "hw", "fr": "rw"}
const KEYED := 0.04            # a channel value this big counts as keyed (rad, m, or squash)
const MOVED := 0.004           # a bone moved: this many m, or rad of turn, from its pose with no move
const EXACT := 0.0005          # m: a bone sits on its rig node's retargeted pose
const SLOT_MAX := 8
const MOTION_BONES := ["hips", "thigh.L", "shin.L", "thigh.R", "shin.R", "upper_arm.L", "forearm.L", "upper_arm.R",
	"forearm.R", "head"]
const OWN_MOTION := 0.05       # rad: two Wardens' idle or run joint angles differ by more than this on average
const TRIS_MAX := 15000         # the game budget (RIG_CONTRACT "Budget"): tools/blender/decimate_warden.py
## Over the budget until an art pass: Kael's mane (14.5k of hair cards) breaks when decimated, so it is kept whole.
const TRIS_OVER := {"juggernaut": 24000}

var bad := 0
var n := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDENGLB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var mapped := WardenGlb.BONES.values()
	var unmapped := ANIM_PARTS.filter(func(p): return not p in mapped)
	ok(unmapped.is_empty(), "every rig node HunterAnim poses has a bone (unmapped %s)" % str(unmapped))
	var vex := WardenGlb.art("gunslinger")
	ok(
		WardenGlb.path("gunslinger") == "res://art/wardens/%s/%s.glb" % [vex, vex]
				and (vex == "vex" or vex.begins_with("vex_") and WardenGlb.variant("vex") == vex),
		"a Warden's file is art/wardens/<name>/<name>.glb, named as its art (Vex: %s; a variant only when picked)"
				% vex
	)
	ok(
		not WardenGlb.has_model("") and not WardenGlb.has_model("no_such_warden"),
		"no archetype, or one with no file, has no .glb"
	)
	var fallback: Array = []
	var loaded: Array = []
	for a in Arch.ids():
		var m := _model(a)
		var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
		if WardenGlb.has_model(a):
			if bool(m.get_meta("glb", false)) and m.has_node("Warden") and not head.visible:
				loaded.append(a)
			else:
				print("WARDENGLB %s has a .glb that did not load" % a)
		elif not bool(m.get_meta("glb", true)) and not m.has_node("Warden") and head.visible:
			fallback.append(a)
		m.free()
	ok(fallback.size() + loaded.size() == Arch.ids().size(),
			"every Warden builds: %d from their .glb %s, %d procedural (the fallback)" % [
				loaded.size(),
				str(loaded),
				fallback.size()
			])
	ok("gunslinger" in loaded, "Vex (gunslinger) is drawn from her .glb")
	for a in loaded:
		_contract(a)
		_kmoves(a)
		await _anchors(main, a)
		_shading(a)
		_hitbox(a)
		_setting(a)
		_own_motion(a, "bulwark" if a != "bulwark" else "gunslinger")
		_weapon(a)
		_shield(a)
		_springs(a)
		_orbits(a)
		_own_look(a)
		await _halo(main, a)
	_stones_look()
	print("WARDENGLB %d checks, %d failed" % [n, bad])
	print("WARDENGLB_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

func _model(a: String) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(m)
	return m

func _skel(m: Node3D) -> Skeleton3D:
	return WardenGlb.skeleton(m.get_node("Warden"))

## The armature is the contract's, built where the rig's nodes rest; the budget.
func _contract(a: String) -> void:
	var m := _model(a)
	var sk := _skel(m)
	var bad_bones: Array = WardenSkeleton.mismatches(sk, WardenGlb.neutral_rest(a), WardenGlb.EXTRA.get(a, {}))
	ok(bad_bones.is_empty(),
			"%s: the .glb's armature is the contract's (+ variant bones %s): names, parents, bones on rig nodes %s"
			% [a, str(WardenGlb.EXTRA.get(a, {}).keys()), str(bad_bones)])
	var tris := 0
	var slots := {}
	var unskinned := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		# (props on an orbit ride their bone unskinned: WardenGlb.Orbits turns them)
		var orbit := String(mi.get_parent().name).begins_with(WardenGlb.Orbits.PREFIX)
		if (mi as MeshInstance3D).skin == null and not orbit:
			unskinned += 1
		for si in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(si) / 3
			var src := mesh.surface_get_material(si)
			slots[String(src.resource_name).get_slice("-", 0) if src else ""] = true
	var unknown := slots.keys().filter(func(s): return not WardenGlb.SLOTS.has(s))
	var cap: int = TRIS_OVER.get(a, TRIS_MAX)
	ok(unskinned == 0 and tris <= cap and slots.size() <= SLOT_MAX and unknown.is_empty(),
			"%s: skinned (%d meshes not), %d triangles (at most %d), slots %s (at most %d, all toon slots)"
			% [a, unskinned, tris, cap, str(slots.keys()), SLOT_MAX])
	m.free()

## Every kit move of every table, played on this Warden: after each key, every bone is exactly where its rig
## node's pose retargets it, and each channel the key drives has moved its bones.
func _kmoves(a: String) -> void:
	var m := _model(a)
	var an := HunterAnim.new(m)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var sk := _skel(m)
	_drive(an, sync, "", 0.0)
	var still := _local_poses(sk)
	var worst := 0.0
	var count := 0
	var dead: Array = []
	for t in [HunterAnim.KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES,
			KMovesCare.MOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES]:
		for mv in t:
			count += 1
			var moved := {}
			var keyed := {}
			var def := HunterAnim.km_def(mv)
			var end_t := float(def["keys"][-1][0])
			for k in def["keys"]:
				# a move that doesn't hold ends on its last key: it is played up to just before it
				_drive(an, sync, mv, float(k[0]) if def.get("hold", false) else minf(float(k[0]), end_t - 0.002))
				for l in sync.links:
					var want := WardenGlb.retarget(WardenGlb.model_xf(m, l[1]), l)
					worst = maxf(worst, sk.get_bone_global_pose(int(l[0])).origin.distance_to(want.origin))
				var now := _local_poses(sk)
				for ch in _keyed(k[1]):
					if an.hold == "palm" and ch in ["gp", "wa", "wo"]:
						continue      # (nothing held: the weapon's channels move no hand)
					keyed[ch] = true
					for b in CHANNEL_BONES[ch]:
						if _moved(still.get(b), now.get(b)):
							moved[ch] = true
			for ch in keyed:
				if not moved.has(ch):
					dead.append("%s:%s" % [mv, ch])
	ok(worst <= EXACT, "%s: across %d kit moves every bone sits on its rig node's retargeted pose (worst %.5f m)"
			% [a, count, worst])
	ok(dead.is_empty(), "%s: every keyed channel of every kit move moves the bones it drives (dead: %s)"
			% [a, str(dead)])
	m.free()

func _drive(an: HunterAnim, sync: WardenGlb.Sync, mv: String, tt: float) -> void:
	for k in 20:
		an.update(1.0 / 60.0, {"fired": 99.0, "face": 0.0, "grounded": true, "kmove": mv, "kmove_t": tt})
	sync.apply()

## The channels a key plays: keyed past KEYED, with their weight on.
func _keyed(key: Dictionary) -> Array:
	var out: Array = []
	for ch in CHANNEL_BONES:
		if not key.has(ch) or float(key.get(CHANNEL_WEIGHT.get(ch, ""), 1.0)) <= 0.0:
			continue
		var v = key[ch]
		var amount := 0.0
		if ch in ["fx", "fy", "fz"]:
			amount = absf(fposmod(float(v) + PI, TAU) - PI)      # (a whole turn ends where it began)
		elif v is Vector3:
			amount = (v as Vector3).length()
		elif v is Array:
			for x in v:
				amount = maxf(amount, absf(float(x)))
		else:
			amount = absf(float(v))
		if amount >= KEYED:
			out.append(ch)
	return out

## Each contract bone's pose relative to its parent bone.
func _local_poses(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for b in WardenGlb.BONES:
		var bi := WardenSkeleton.find(sk, b)
		if bi >= 0:
			out[b] = sk.get_bone_pose(bi)
	return out

func _moved(a, b) -> bool:
	if a == null or b == null:
		return false
	var ta: Transform3D = a
	var tb: Transform3D = b
	var rel := ta.basis.orthonormalized().inverse() * tb.basis.orthonormalized()
	var turn := rel.get_rotation_quaternion().get_angle()
	var grow := (ta.basis.get_scale() - tb.basis.get_scale()).length()
	return ta.origin.distance_to(tb.origin) > MOVED or turn > MOVED or grow > MOVED

## The anchor empties are on their bones and move with them.
func _anchors(main: Node, a: String) -> void:
	var m := _model(a)
	var missing: Array = []
	var off_bone: Array = []
	for nm in WardenGlb.ANCHORS:
		var an := WardenGlb.anchor(m, nm)
		if an == null:
			missing.append(nm)
		elif not an.get_parent() is BoneAttachment3D:
			off_bone.append(nm)
	ok(missing.is_empty() and off_bone.is_empty(),
			"%s: the anchor empties ride bone attachments (missing %s, not on a bone %s)"
			% [a, str(missing), str(off_bone)])
	var top := WardenGlb.anchor(m, "anchor_head_top")
	if top != null:
		var clips: WardenClips = (m.get_node("Warden/Sync") as WardenGlb.Sync).clips
		if clips:        # (a Hero with clips: hand the head to the rig, or this measures the idle clip's sway)
			clips.force = {"proc": true}
			clips.proc_w = 1.0
		await main.get_tree().process_frame
		var before := top.global_position
		(m.get_node("Rig/Torso/HeadPivot") as Node3D).rotation.x += 0.6
		(m.get_node("Warden/Sync") as WardenGlb.Sync).apply()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var d := top.global_position.distance_to(before)
		ok(d > 0.05, "%s: anchor_head_top follows the head as it nods (%.3f m)" % [a, d])
	m.free()

## Every surface on the hero toon shader with the atlas, and in the model's hit-flash list.
func _shading(a: String) -> void:
	var m := _model(a)
	var mats: Array = m.get_meta("mats", [])
	var wrong := 0
	var surfaces := 0
	var textured := 0
	var relief := 0
	var no_relief := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			surfaces += 1
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm and sm.shader == WardenMood.FACE_SHADER:
				continue        # (a face drawn on glass: no atlas, no toon)
			var src := (mi as MeshInstance3D).mesh.surface_get_material(si) as BaseMaterial3D
			var atlas := src != null and src.albedo_texture != null
			if atlas:
				textured += 1
			# a .glb's normal map reaches the toon shader (use_nrm, the one path)
			if sm and sm.shader == Models.HERO and src and src.normal_enabled and src.normal_texture:
				relief += 1
				var tex: Variant = sm.get_shader_parameter("normal_tex")
				if not sm.get_shader_parameter("use_nrm") or tex != src.normal_texture:
					no_relief += 1
			# a textured surface shows its atlas; a flat-painted one (hand-modelled, no atlas) its own colour
			var shows := false
			if sm and sm.shader == WardenGlb.FLAME:
				shows = true      # (fire: no paint of its own)
			elif sm and atlas:
				shows = bool(sm.get_shader_parameter("use_tex")) and sm.get_shader_parameter("albedo_tex") != null
			elif sm and src:
				shows = (sm.get_shader_parameter("albedo") as Color).is_equal_approx(src.albedo_color)
			# (the void slot is the starfield shader, the card slot its own: RIG_CONTRACT "Materials")
			var shader_ok := sm != null and sm.shader in [Models.HERO, WardenGlb.VOID, WardenGlb.CARD, WardenGlb.FLAME]
			if not shader_ok or not shows or not sm in mats:
				wrong += 1
	ok(surfaces > 0 and wrong == 0,
			"%s: all %d surfaces on the hero toon shader (%d with an atlas, rest flat), in the hit flash (%d not)" \
			% [a, surfaces, textured, wrong])
	ok(no_relief == 0, "%s: all %d of its normal maps reach the shader (%d lost)" % [a, relief, no_relief])
	print("WARDENGLB %s normal-mapped surfaces: %d" % [a, relief])
	m.free()

## The hit radius and the ring that shows it are the same with the .glb as without, and the .glb brings no
## collision of its own.
func _hitbox(a: String) -> void:
	var with := _model(a)
	var ring_w := (with.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
	var shapes := with.get_node("Warden").find_children("*", "CollisionObject3D", true, false).size() \
			+ with.get_node("Warden").find_children("*", "CollisionShape3D", true, false).size()
	with.free()
	WardenGlb.set_model(a, false)
	var without := _model(a)
	var ring_p := (without.get_node("TeamRing") as Node3D).global_transform.basis.get_scale().x
	without.free()
	WardenGlb.set_model(a, true)
	ok(absf(ring_w - ring_p) < 0.0001 and shapes == 0,
			"%s: hit ring %.3f with the .glb, %.3f without (hit radius %.2f m), no collision in the .glb"
			% [a, ring_w, ring_p, Arch.hit_r(a, Data.CLASSES[Arch.weight(a)])])

## A .glb that carries its weapon: it is in the hands (under the Gun node, whose Muzzle stays where the shots
## leave), the procedural weapon is hidden, and its magazine (if it has one apart) is the Gun's Mag.
## A model's spring chains (RIG_CONTRACT "Spring chains": braids) swing: moved sideways, each chain's tip trails
## its rigid place, and standing still it settles back on it. (No chains: nothing to check.)
## Tarek's seeing-stones turn their eyes to a point the kit gives them (WardenGlb.ORBIT_LOOK).
func _stones_look() -> void:
	var m := _model("dolm")
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var stone := m.find_child("stone_0", true, false) as Node3D
	var at := stone.global_position + Vector3(4.0, 0.0, 3.0)
	m.set_meta(WardenGlb.ORBIT_LOOK, at)
	for i in 90:
		sync._process(1.0 / 60.0)
		at = m.get_meta(WardenGlb.ORBIT_LOOK)
	var fwd := -stone.global_basis.z.normalized()
	var off := fwd.angle_to((at - stone.global_position).normalized())
	ok(off < 0.3, "dolm: the seeing-stones turn to what they watch (%.2f rad off)" % off)
	m.free()

func _springs(a: String) -> void:
	var m := _model(a)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.springs.chains.is_empty():
		m.free()
		return
	var sk := _skel(m)
	sync.springs.calm = true
	sync.clips = null      # (the chains alone: a clip's idle keeps moving what they hang from)
	sync._process(1.0 / 60.0)
	var lag := 0.0
	for i in 6:
		m.position.x += 0.08
		sync._process(1.0 / 60.0)
		lag = maxf(lag, _spring_off(sk, sync))
	for i in 240:
		sync._process(1.0 / 60.0)
	var rest := _spring_off(sk, sync)
	ok(lag > 0.02 and rest < 0.016, "%s: %d spring chains trail a sideways move (tip %.3f m off) and settle (%.4f m)"
			% [a, sync.springs.chains.size(), lag, rest])
	# wings fold back while she skates (the root's WING_FOLD meta): each wing tip swings behind its root
	var wings: Array = sync.springs.chains.filter(func(ch): return bool(ch["wing"]))
	if not wings.is_empty():
		var open := _wing_tips(sk, wings)
		m.set_meta(WardenGlb.WING_FOLD, 1.0)
		for i in 240:
			sync._process(1.0 / 60.0)
		var shut := _wing_tips(sk, wings)
		var back := 1.0
		for i in open.size():
			back = minf(back, (shut[i] as Vector3).z - (open[i] as Vector3).z)
		ok(back > 0.08, "%s: %d wings fold back while skating (tips at least %.3f m further back)"
				% [a, wings.size(), back])
	m.free()

## Props on an orbit (RIG_CONTRACT "Orbits"): over a second each circles its pivot (moves, at the same distance
## from it), so the turning is the loader's, not baked into the .glb. (No orbit: nothing to check.)
func _orbits(a: String) -> void:
	var m := _model(a)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.orbits.pivots.is_empty():
		m.free()
		return
	sync._process(1.0 / 60.0)
	var before: Array = []
	for pv in sync.orbits.pivots:
		for pr in pv[2]:
			before.append([pr[0], (pr[0] as Node3D).global_position, (pv[0] as Node3D).global_position])
	for i in 60:
		sync._process(1.0 / 60.0)
	var moved := INF
	var drift := 0.0
	for b in before:
		var nd: Node3D = b[0]
		var c: Vector3 = b[2]
		moved = minf(moved, nd.global_position.distance_to(b[1]))
		var r0 := Vector2(b[1].x - c.x, b[1].z - c.z).length()
		drift = maxf(drift, absf(Vector2(nd.global_position.x - c.x, nd.global_position.z - c.z).length() - r0))
	ok(moved > 0.05 and drift < 0.01,
			"%s: %d orbit props circle their bone (each moved at least %.3f m in 1s, radius kept to %.4f m)"
			% [a, before.size(), moved, drift])
	m.free()

## A model's own look (content/rules/warden_look.json) reaches its surfaces: every surface of a slot it names
## carries that slot's values. (No entry: nothing to check.)
func _own_look(a: String) -> void:
	var own := WardenGlb.look(WardenGlb.art(a))
	if own.is_empty():
		return
	var m := _model(a)
	var slots: Dictionary = own.get("slots", {})
	var seen := 0
	var wrong: Array = []
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""
			var tag := String(src.resource_name).get_slice("-", 1) if src else ""
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			# (a "<slot>-<tag>" entry goes on after its slot's)
			var want_all: Dictionary = (slots.get(slot, {}) as Dictionary).merged(slots.get(slot + "-" + tag, {}), true)
			for k in want_all:
				var want: Variant = WardenGlb._param(want_all[k])
				var got: Variant = sm.get_shader_parameter(k)
				seen += 1
				var same: bool = got.is_equal_approx(want) if want is Color else is_equal_approx(float(got),
						float(want))
				if k == "albedo" and want is Color:
					# (a look's albedo composes with the player's pick: the look's colour x a tint within TINT_MAX)
					same = _within_tint(got as Color, want as Color)
				if not same:
					wrong.append("%s.%s" % [slot, k])
	ok(seen > 0 and wrong.is_empty(), "%s: its own look (warden_look.json) is on its surfaces (%d values, wrong %s)"
			% [a, seen, str(wrong)])
	m.free()

func _within_tint(got: Color, want: Color) -> bool:
	var lo := 1.0 - WardenGlb.TINT_MAX - 0.001
	var hi := 1.0 + WardenGlb.TINT_MAX + 0.001
	for i in 3:
		var r: float = got[i] / maxf(want[i], 1e-4)
		if r < lo or r > hi:
			return false
	return true

## The tips of the wing chains (skeleton space: behind is +Z).
func _wing_tips(sk: Skeleton3D, wings: Array) -> Array:
	return wings.map(func(ch): return sk.get_bone_global_pose(int((ch["ids"] as Array)[-1])).origin)

## A model's glow halos (warden_look.json "halos") hang on their anchors outside the .glb (the skin, the bounds
## and the slot checks never see them) and follow the head when it nods, the body when it turns and leans (a
## chest gem, Pip's lantern on her paw) and the weapon when it aims.
func _halo(main: Node, a: String) -> void:
	var hl: Array = WardenGlb.look(WardenGlb.art(a)).get("halos", [])
	if hl.is_empty():
		return
	var m := _model(a)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	sync.apply()
	await main.get_tree().process_frame
	var found := 0
	var inside := 0
	var off := 0.0
	var moved := 0.0
	var rest := {}
	for hs in hl:
		var mi := m.get_node_or_null("Halo_" + String(hs["anchor"])) as Node3D
		if mi:
			rest[mi] = mi.global_position
	(m.get_node("Rig/Torso/HeadPivot") as Node3D).rotation.x = 0.4
	# (and the arms swing, the body turns and the aim pitches: a halo can ride a hand, Motley's void orb, the chest,
	# Sable's pendant, or the weapon, Hem's bow and Cinder's flame chamber)
	for arm in ["Rig/Torso/ArmRPivot", "Rig/Torso/ArmLPivot"]:
		var ap := m.get_node_or_null(arm) as Node3D
		if ap:
			ap.rotation.x += 0.6
	(m.get_node("Rig/Torso") as Node3D).rotation.y += 0.5
	(m.get_node("Rig/Torso/Aim") as Node3D).rotation.x = 0.4
	(m.get_node("Rig/Torso") as Node3D).rotation.x = 0.3      # (and leans: Pip's lantern)
	sync.apply()
	await main.get_tree().process_frame
	for hs in hl:
		var mi := m.get_node_or_null("Halo_" + String(hs["anchor"])) as Node3D
		var an := WardenGlb.anchor(m, String(hs["anchor"]))
		if mi == null or an == null:
			continue
		found += 1
		if m.get_node("Warden").is_ancestor_of(mi):
			inside += 1
		off = maxf(off, mi.global_position.distance_to(an.global_position))
		moved = maxf(moved, mi.global_position.distance_to(rest[mi]))
	ok(found == hl.size() and inside == 0 and off < 0.001 and moved > 0.01,
			"%s: %d glow halos on their anchors (off %.4f m), outside the .glb, follow nod/twist/lean/arms/aim (%.3f m)"
			% [a, found, off, moved])
	m.free()


## The largest distance of a spring chain's tip from where it rides its parent rigidly.
func _spring_off(sk: Skeleton3D, sync: WardenGlb.Sync) -> float:
	var worst := 0.0
	for ch in sync.springs.chains:
		var ids: Array = ch["ids"]
		var tip := int(ids[ids.size() - 1])
		var par := sk.get_bone_parent(int(ids[0]))
		var base := sk.get_bone_global_pose(par) * sk.get_bone_global_rest(par).affine_inverse()
		var at := (base * sk.get_bone_global_rest(tip)).origin
		if ch.get("hang", false):
			# (a hanging chain settles straight down from its root, whichever way its parent points)
			var root := (base * sk.get_bone_global_rest(int(ids[0]))).origin
			var ln := 0.0
			for j in range(1, ids.size()):
				ln += sk.get_bone_global_rest(int(ids[j])).origin.distance_to(
						sk.get_bone_global_rest(int(ids[j - 1])).origin)
			at = root + (sk.global_transform.basis.inverse() * Vector3.DOWN).normalized() * ln
		worst = maxf(worst, at.distance_to(sk.get_bone_global_pose(tip).origin))
	return worst

func _weapon(a: String) -> void:
	var m := _model(a)
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	var weapon := gun.find_child(WardenGlb.WEAPON, true, false) as MeshInstance3D
	if weapon == null:
		m.free()
		return
	var off := gun.get_node_or_null(WardenGlb.WEAPON_OFF) as Node3D     # (a twin hold's second weapon)
	var own := func(mi: Node) -> bool: return mi == weapon or weapon.is_ancestor_of(mi) \
			or (off != null and (mi == off or off.is_ancestor_of(mi)))
	# a hammer is seated on its swing pivot (meta hammer_pivot), its block round the point BjornFx finds the head
	var pivot: Node3D = null
	for c in gun.get_children():
		if c.has_meta("hammer_pivot"):
			pivot = c
	if pivot:
		ok(weapon.get_parent() == pivot and weapon.get_aabb().has_point(Vector3(0, 0, -0.62)),
				"%s's weapon rides the hammer pivot (the kit's swings) with its head round (0, 0, -0.62) (%s)"
				% [a, str(weapon.get_aabb())])
	var shown := gun.find_children("*", "MeshInstance3D", true, false).filter(
			func(mi): return (mi as Node3D).is_visible_in_tree() and not own.call(mi))
	var mag := gun.get_node_or_null("Mag") as MeshInstance3D
	var own_mag := mag != null and mag.has_meta("glb")      # (the loader moved the .glb's weapon_mag here)
	# its own magazine is the Mag; a weapon modelled whole leaves the Mag node empty
	var mag_ok := mag != null and (mag.mesh != null and mag in shown if own_mag else mag.mesh == null)
	var stray := shown.filter(func(mi): return mi != mag)
	var left := str(stray.map(func(mi): return mi.name))
	ok(gun.has_node("Muzzle") and stray.is_empty() and mag_ok,
			"%s holds its own weapon (in the Gun with the Muzzle, procedural parts left %s, its magazine the Mag: %s)"
			% [a, left, str(mag_ok)])
	m.free()

## A .glb shield (Breaker's prow) rides the left hand's Shield node in place of the procedural one.
func _shield(a: String) -> void:
	var m := _model(a)
	var holder := m.get_node_or_null("Rig/Torso/ArmLPivot/Elbow/Hand/Shield") as Node3D
	var sh := holder.get_node_or_null(WardenGlb.SHIELD) as MeshInstance3D if holder else null
	if sh == null:
		m.free()
		return
	var shown := holder.find_children("*", "MeshInstance3D", true, false).filter(
			func(mi): return (mi as Node3D).is_visible_in_tree() and mi != sh)
	ok(shown.is_empty() and sh.transform.is_equal_approx(Transform3D.IDENTITY),
			"%s holds its own shield on the left hand's Shield node (procedural parts left %s)"
			% [a, str(shown.size())])
	m.free()

## The skeleton is shared names and layout only: each Warden keeps its own motion. Over an idle and a run
## cycle, this Warden's bones and another Warden's (its rig driving the same contract skeleton) take
## clearly different joint angles.
func _own_motion(a: String, other: String) -> void:
	var m := _model(a)
	var mine := _skel(m)
	var o := _model(other)
	var theirs := WardenSkeleton.build(WardenGlb.neutral_rest(other))
	o.add_child(theirs)
	var o_sync := WardenGlb.Sync.new()
	o_sync.setup(o, theirs, WardenGlb.neutral_rest(other))
	var pairs := [[HunterAnim.new(m), m.get_node("Warden/Sync"), mine], [HunterAnim.new(o), o_sync, theirs]]
	for gait in ["idle", "run"]:
		var diff := 0.0
		var samples := 0
		for f in 90:
			for pr in pairs:
				var st := {"fired": 99.0, "face": 0.0, "grounded": true}
				if gait == "run":
					st["vel"] = Vector3(0, 0, -4.6)
				(pr[0] as HunterAnim).update(1.0 / 60.0, st)
				(pr[1] as WardenGlb.Sync).apply()
			if f % 6 == 0:
				for b in MOTION_BONES:
					var qa := mine.get_bone_pose_rotation(WardenSkeleton.find(mine, b))
					var qb := theirs.get_bone_pose_rotation(WardenSkeleton.find(theirs, b))
					diff += qa.angle_to(qb)
					samples += 1
		var mean := diff / maxf(1.0, samples)
		ok(mean > OWN_MOTION, "%s keeps its own %s: its joint angles differ from %s's by %.2f rad on average"
				% [a, gait, other, mean])
	o_sync.free()
	m.free()
	o.free()

## Settings > Video > Warden models: off builds the procedural model, on the .glb again.
func _setting(a: String) -> void:
	WardenGlb.set_model(a, false)
	var off := _model(a)
	var proc := not off.has_node("Warden") and (off.get_node("Rig/Torso/HeadPivot/Head") as Node3D).visible \
			and not WardenGlb.uses_model(a)
	off.free()
	WardenGlb.set_model(a, true)
	var on := _model(a)
	var back := on.has_node("Warden") and WardenGlb.uses_model(a)
	on.free()
	ok(proc and back, "%s: the Warden models setting turns it procedural (%s) and back to its 3D model (%s)"
			% [a, str(proc), str(back)])
