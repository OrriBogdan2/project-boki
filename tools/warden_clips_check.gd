extends RefCounted
## --warden-clips-check: the hand-keyed clips (ART-1, scripts/heroes/warden_clips.gd, content/rules/warden_clips.json),
## per Hunter that has a block: every clip it names is in the .glb; every kit move of the Hunter is mapped, and each
## clip is as long as the kit's move; the blend tree plays them (a move changes the pose, kit time drives it); the
## locomotion blends (a run moves the feet); the skinned weapon stays on its bone through every move and only one
## weapon is drawn; it hides when the kit takes it out of the hand and its FX anchors stay on it; the budget holds.
## Never touches the save.

const DT := 1.0 / 60.0
const MAX_TRIS := 15000         # S1: weapon and shield included
const GRIP_TOL := 0.03          # m: the weapon's bone stays this close to where the hand holds it
const PREFIX := {"breaker": ["bulwark", "bul_"]}
const SKIP := ["bul_smash_late"]

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("CLIPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for art_name in PREFIX:
		_hunter(String(art_name), String(PREFIX[art_name][0]), String(PREFIX[art_name][1]))
	_companions()
	print("WARDEN_CLIPS_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(art_name: String, id: String, prefix: String) -> void:
	var cfg := WardenClips.data(art_name)
	ok(not cfg.is_empty(), "%s has a clips block" % art_name)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	ok(bool(m.get_meta("glb", false)), "%s wears its .glb" % art_name)
	var w := m.get_node_or_null("Warden")
	var sk := WardenGlb.skeleton(w)
	var sync := w.get_node("Sync") as WardenGlb.Sync
	var clips: WardenClips = sync.clips
	var lib: AnimationLibrary = clips.lib if clips else null
	ok(clips != null, "%s: the clip tree was built" % art_name)
	if clips == null:
		m.free()
		return
	# the names
	var moves: Dictionary = cfg["kmoves"]
	var want: Array = []
	for k in moves:
		want.append(String((moves[k] as Dictionary)["clip"]))
	var lc: Dictionary = cfg["loco"]
	want.append_array([lc["idle"], lc["stance"], cfg["land"]["clip"], cfg["weapon_out"]["clip"]])
	want.append_array((lc["walk"] as Dictionary).values())
	want.append_array((lc["run"] as Dictionary).values())
	want.append_array([cfg["air"]["rise"], cfg["air"]["fall"], cfg["air"]["glide"]])
	var sts: Dictionary = cfg["states"]
	for k in sts:
		if sts[k] is Dictionary:
			want.append_array([sts[k]["front"], sts[k]["back"]])
		elif sts[k] is String:
			want.append(sts[k])
	var missing: Array = want.filter(func(c): return not lib.has_animation(String(c)))
	ok(missing.is_empty(), "%s: all %d clips are in the .glb (missing %s)" % [art_name, want.size(), str(missing)])
	# every kit move mapped, and long enough for the kit's clock
	var short: Array = []
	var unmapped: Array = []
	for table in [HunterAnim.KMOVES, KMovesPinBjorn.MOVES]:
		for k in table:
			if not String(k).begins_with(prefix) or k in SKIP:
				continue
			if not moves.has(k):
				unmapped.append(k)
				continue
			var keys: Array = (table[k] as Dictionary)["keys"]
			var end_t := float((keys[keys.size() - 1] as Array)[0])
			var cl := String((moves[k] as Dictionary)["clip"])
			if not (moves[k] as Dictionary).has("hold_from") and lib.has_animation(cl) \
					and lib.get_animation(cl).length < end_t - 0.04:
				short.append("%s %.2f < %.2f" % [k, lib.get_animation(cl).length, end_t])
	ok(unmapped.is_empty(), "%s: every kit move has a clip (%s)" % [art_name, str(unmapped)])
	ok(short.is_empty(), "%s: each clip lasts its kit move (%s)" % [art_name, str(short)])
	var an := HunterAnim.new(m)
	var hand := WardenSkeleton.find(sk, "hand.R")
	var foot := WardenSkeleton.find(sk, "x_foot.R")
	var st := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	_play(m, an, sync, st, 40)
	var idle_h := sk.get_bone_global_pose(hand).origin
	var idle_f := sk.get_bone_global_pose(foot).origin
	# a run moves the feet
	var run_st := st.duplicate()
	run_st["vel"] = Vector3(0, 0, -4.8)
	var far := 0.0
	for i in 40:
		_play(m, an, sync, run_st, 1)
		far = maxf(far, sk.get_bone_global_pose(foot).origin.distance_to(idle_f))
	ok(far > 0.1, "%s: the run blend moves the feet (%.2f m)" % [art_name, far])
	# every move: changes the pose, the weapon bone stays on the hand
	var wp := WardenSkeleton.find(sk, "x_weapon")
	var rest_off := (sk.get_bone_global_rest(hand).affine_inverse() * sk.get_bone_global_rest(wp)).origin
	var worst := 0.0
	var worst_mv := ""
	var still: Array = []
	_play(m, an, sync, st, 30)
	for k in moves:
		var moved := 0.0
		var tt := 0.0
		var ln := lib.get_animation(String((moves[k] as Dictionary)["clip"])).length
		while tt < ln:
			var s2 := st.duplicate()
			s2["kmove"] = k
			s2["kmove_t"] = tt
			_play(m, an, sync, s2, 1)
			tt += DT
			moved = maxf(moved, sk.get_bone_global_pose(hand).origin.distance_to(idle_h))
			var off := sk.get_bone_global_pose(hand).affine_inverse() * sk.get_bone_global_pose(wp)
			var d := off.origin.distance_to(rest_off)
			if d > worst:
				worst = d
				worst_mv = k
		if moved < 0.03 and not k in ["bul_short", "bul_crush", "bul_armed"]:
			still.append(k)
		_play(m, an, sync, st, 12)
	ok(still.is_empty(), "%s: each move's clip moves the hand (%s)" % [art_name, str(still)])
	ok(worst <= GRIP_TOL, "%s: the weapon stays in the hand in every move (worst %.3f m, %s)"
			% [art_name, worst, worst_mv])
	if art_name == "breaker":
		_whirl(m, an, sync, sk, st)
	# the weapon: one drawn; hidden when out of the hand; anchors on it
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	var drawn := 0
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			drawn += 1
	ok(drawn == 0, "%s: no second weapon on the rig (%d drawn)" % [art_name, drawn])
	# Hunter.equip rebuilds the rig's weapon and prow: they stay hidden
	Models.gun_parts(gun, Arch.signature(id), Models.toon(Color.GRAY), Models.toon(Color.GRAY), Models.toon(Color.GRAY))
	_play(m, an, sync, st, 2)
	var shown := 0
	for nd in [gun, m.get_node(WardenGlb.SHIELD_PATH)]:
		for mi in (nd as Node).find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).visible:
				shown += 1
	ok(shown == 0, "%s: a rebuilt rig weapon stays hidden (%d drawn)" % [art_name, shown])
	m.set_meta(WardenClips.WEAPON_OUT, true)
	_play(m, an, sync, st, 3)
	ok(sk.get_bone_pose_scale(wp).is_zero_approx(), "%s: the weapon hides when it leaves the hand" % art_name)
	m.set_meta(WardenClips.WEAPON_OUT, false)
	_play(m, an, sync, st, 3)
	ok(sk.get_bone_pose_scale(wp).is_equal_approx(Vector3.ONE), "%s: and comes back" % art_name)
	if art_name == "breaker":
		_hammer_scale(w, sk)
	var tip := WardenGlb.anchor(m, "anchor_hammer_head")
	ok(tip != null, "%s: an FX anchor rides the weapon" % art_name)
	var piece := WardenGlb.thrown_piece(m, "hammer")
	ok(piece != null, "%s: the thrown hammer is the model's own mesh" % art_name)
	if piece:
		piece.free()
	_mood(m, sync, sk)
	# the budget
	var tris := 0
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(si) / 3
	ok(tris <= MAX_TRIS, "%s: %d triangles, the budget %d" % [art_name, tris, MAX_TRIS])
	m.free()

## Meeko's sun and moon (pip_v2 companions sheet; the moon wears the cloud's faces, item 24): two atlas faces off her
## moods, all eight expressions reachable, the cast FX points on her shoulder and the sun's light on the sun.
func _companions() -> void:
	var m := Models.hunter(Arch.weight("tender"), Data.TEAM_COLORS[0], Arch.signature("tender"), "",
			PlayerLook.neutral(), "tender")
	holder.add_child(m)
	var md: WardenMood = (m.get_node("Warden/Sync") as WardenGlb.Sync).mood
	ok(md != null and md.atlas.size() == 2 and md.face == null, "tender: the sun's and cloud's faces are on the atlas")
	var seen := {}
	for st in [{}, {"emote": "x"}, {"kmove": "mm_shot_r"}, {"kmove": "mm_tug"}, {"hit_t": 0.1}, {"downed": true}]:
		m.set_meta(WardenClips.STATE, st)
		md.step(0.5)
		for a in md.atlas:
			seen[int((a[0] as ShaderMaterial).get_shader_parameter("to_cell"))] = true
	ok(seen.size() == 8, "tender: her moods reach all eight faces (%d)" % seen.size())
	for a in ["weapon_muzzle", "anchor_lantern_top"]:
		var at := WardenGlb.anchor(m, a)
		var bone := (at.get_parent() as BoneAttachment3D).bone_name if at else ""
		ok(bone == "pauldron.L", "tender: %s stays on her shoulder" % a)
	var lamp := WardenGlb.anchor(m, PipOrbit.LIGHT_ANCHOR)
	ok(lamp != null and lamp.get_parent().name == "Sun", "tender: the sun's light rides the sun")
	m.free()
	_orbit()

## Item 24: the sun and moon off her body mesh, circling her upper body on opposite sides, below her face when in
## front of her, trailing a little when she moves, and flaring and spinning up when she casts.
func _orbit() -> void:
	var m := Models.hunter(Arch.weight("tender"), Data.TEAM_COLORS[0], Arch.signature("tender"), "",
			PlayerLook.neutral(), "tender")
	holder.add_child(m)
	var w := m.get_node("Warden") as Node3D
	var o: PipOrbit = (w.get_node("Sync") as WardenGlb.Sync).pals
	ok(o != null and o.pals.size() == 2, "tender: a sun and a moon")
	if o == null or o.pals.size() < 2:
		m.free()
		return
	var left: Array = []
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var nm := mesh.surface_get_material(si).resource_name if mesh.surface_get_material(si) else ""
			if nm in PipOrbit.SUN + PipOrbit.GONE + [PipOrbit.MOON_FACE] and (mi as MeshInstance3D).skin:
				left.append(nm)
	ok(left.is_empty(), "tender: nothing of the sun or cloud is left on her skinned body %s" % str(left))
	var sun := o.pals[0][0] as Node3D
	var moon := o.pals[1][0] as Node3D
	var d := Tuning.of("meeko")
	for i in 30:
		o.step(DT)
	var c := o.pivot
	var a := sun.global_position - c
	var b := moon.global_position - c
	var across := Vector2(a.x, a.z).normalized().dot(Vector2(b.x, b.z).normalized())
	ok(across < -0.99, "tender: sun and moon on opposite sides")
	var sk := WardenGlb.skeleton(w)
	var sc := sk.global_transform.basis.get_scale().y
	var head_y := (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin).y
	o.phase = PI      # the sun right in front of her (-Z)
	o.step(DT)
	var top := sun.global_position.y + 0.17 * sc
	ok(top < head_y, "tender: in front of her the sun stays under her face (top %.2f, head %.2f)" % [top, head_y])
	var p0 := sun.global_position
	for i in 60:
		o.step(DT)
	var lap := TAU * float(d["orbit_hz"]) * 60.0 * DT
	ok(
			p0.distance_to(sun.global_position) > 0.05 * sc and lap < 0.5,
			"tender: they circle slowly (%.2f rad a second)" % lap)
	m.position += Vector3(1, 0, 0)
	o.step(DT)
	var want := sk.global_transform * (sk.get_bone_global_pose(o.hips).origin + Vector3.UP * float(d["lift_m"]))
	var trail := o.pivot.distance_to(want)
	var most := float(d["lag_max_m"]) * sc + 0.001
	ok(trail > 0.05 * sc and trail <= most, "tender: they trail her move (%.2f m)" % trail)
	for i in 60:
		o.step(DT)
	ok(o.pivot.distance_to(want) < 0.01, "tender: and catch up")
	var rest := float((o.pals[0][1] as ShaderMaterial).get_shader_parameter("alpha"))
	var s0 := o.spin
	m.set_meta(WardenClips.STATE, {"kmove": "mm_shot_r"})
	o.step(DT)
	var lit := float((o.pals[0][1] as ShaderMaterial).get_shader_parameter("alpha"))
	ok(o.kick > 0.9 and lit > rest + 0.4 and o.spin - s0 > TAU * float(d["spin_hz"]) * DT * 5.0,
			"tender: a cast flares them (%.2f -> %.2f) and spins them up" % [rest, lit])
	var warm := Color(String(d["sun_glow"]))
	var cool := Color(String(d["moon_glow"]))
	ok(warm.r > warm.b and cool.b > cool.r, "tender: the sun glows warm, the moon cool")
	m.free()

## Item 137: the hammer on the sheet is 0.79 of his height (breaker_FINAL_sheet, breaker_weapons), neutral size both.
func _hammer_scale(w: Node, sk: Skeleton3D) -> void:
	var box := (w.find_child("hammer", true, false) as MeshInstance3D).get_aabb()
	var top := (w.find_child("anchor_head_top", true, false) as Node3D)
	var h := sk.get_bone_global_rest(WardenSkeleton.find(sk, "head")).origin.y + top.position.y
	var k := box.size[box.get_longest_axis_index()] / maxf(h, 0.01)
	ok(absf(k - 0.79) <= 0.06, "breaker: the hammer is %.2f of his height (sheet 0.79)" % k)

## The porthole's moods and the fish: cosmetic, off the state and the kit's pokes.
func _mood(m: Node3D, sync: WardenGlb.Sync, sk: Skeleton3D) -> void:
	var md: WardenMood = sync.mood
	ok(md != null and md.face != null and not md.lure.is_empty(), "the porthole and the lure are on their materials")
	var seen := {}
	for st in [{}, {"emote": "x"}, {"kmove": "bul_smash"}, {"kmove": "bul_guard"}, {"downed": true}]:
		m.set_meta(WardenClips.STATE, st)
		md.step(0.5)
		seen[md.face.get_shader_parameter("to_mood")] = true
	ok(seen.size() == 5, "five moods from the state (%d)" % seen.size())
	var fish := WardenSkeleton.find(sk, "x_fish")
	m.set_meta(WardenClips.STATE, {})
	md.step(0.01)
	var calm := sk.get_bone_pose_rotation(fish)
	WardenMood.poke(m)
	md.step(0.03)
	ok(not sk.get_bone_pose_rotation(fish).is_equal_approx(calm), "a blocked hit shivers the fish")
	var rest_glow := float((md.lure[0] as ShaderMaterial).get_shader_parameter("glow"))
	m.set_meta(WardenMood.FLARE, true)
	md.step(1.0)
	ok(float((md.lure[0] as ShaderMaterial).get_shader_parameter("glow")) > rest_glow * 2.0, "the ult flares the lure")
	m.set_meta(WardenMood.FLARE, false)
	md.step(1.0)

## Item 59: the kit's angle seeks the hold's loop: the head goes where the phase says, inside the slam's reach.
func _whirl(m: Node3D, an: HunterAnim, sync: WardenGlb.Sync, sk: Skeleton3D, st: Dictionary) -> void:
	var wp := WardenSkeleton.find(sk, "x_weapon")
	var tip := WardenGlb.anchor(m, "anchor_hammer_head")
	var at := tip.get_parent() as BoneAttachment3D
	var off := sk.get_bone_global_rest(WardenSkeleton.find(sk, at.bone_name)) * tip.transform
	var off_w := sk.get_bone_global_rest(wp).affine_inverse() * off
	var worst := 0.0
	var reach := 0.0
	var s2: Dictionary = st.duplicate()
	s2["kmove"] = "bul_smash_wind"
	for i in 8:
		var a := TAU * i / 8.0
		m.set_meta(WardenClips.PHASE, i / 8.0)
		s2["kmove_t"] = 0.4 + i * 0.1
		_play(m, an, sync, s2, 12)
		var head := (sk.get_bone_global_pose(wp) * off_w).origin
		var flat := Vector2(head.x, head.z)
		reach = maxf(reach, flat.length() * m.scale.x)
		worst = maxf(worst, absf(angle_difference(flat.angle(), Vector2(cos(a), -sin(a)).angle())))
	m.remove_meta(WardenClips.PHASE)
	_play(m, an, sync, st, 12)
	ok(worst < 0.6, "breaker: the kit's angle turns the skinned hammer (worst %.2f rad off)" % worst)
	ok(reach <= 2.8, "breaker: the whirl's head stays inside the slam's reach (%.2f m of 2.8)" % reach)

func _play(m: Node3D, an: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, n: int) -> void:
	for i in n:
		an.update(DT, s)
		sync._process(DT)
