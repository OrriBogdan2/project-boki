extends RefCounted
## --warden-native-check (docs/art/wardens/MESHY_NATIVE.md): each Hunter switched onto Meshy's own skeleton
## (content/rules/warden_native.json) builds from its <art>_meshy.glb with Meshy's bones as Meshy named them (no
## contract bones, no WardenSync), its clips play for the game states (idle, walk, run, jump, attack, crouch), it
## stands as tall as the contract model, faces the way the Hunter faces, keeps the hit ring, hides the rig's procedural
## weapon, puts the aim node on Meshy's hand, hangs the anchor empties on Meshy's bones and wears the drop poses (the
## landing squash: --land-weight-check). Every other Warden keeps the contract path. The clip slots (data "clips": lmb,
## lmb_hold, rmb, e, r, dash, glide, land, hit, downed, stomp): each is picked by its state or move, a missing one
## plays today's clip, a clips file's clips load onto Meshy's bones, and no switch shows the T-pose.

const HEIGHT_TOL := 0.03  # share: the head stands this close to the contract model's head height
const UPRIGHT := 0.25  # m, Meshy scale: the head stays this far over the hips in every state (a clip in a wrong frame)
const BLADE := 1.38  # Meshy units: a held sword's tip from the hand bone, along its Y (Kael's: warden_props)
const PROBE := 1.0 / 240.0  # s: the step the move clips are swept at
const CONTRACT_BONES := ["hips", "upper_arm.L", "thigh.L"]
const POSED_MIN := 10  # bones turned off Meshy's T-pose rest in a playing clip (the T-pose turns none)
const TURNED := 0.03  # rad: a bone this far off its rest is posed
const CALM_CAST := 99.0  # s since the last cast: Hunter._anim_state always sends "cast" (WardenNative baselines on it)
const SYNTH := "Zz_Clip"  # the test clip a synthetic clips file carries
const STRING_PULL := 0.08  # m, Meshy scale: the string is drawn this far off the bow at a release move's first frame
const STRING_BACK := 0.03  # and this near it a frame later
const RUN_STEP := 0.1  # m per frame the model runs (6 m/s) in the springs case
const TRAIL_MIN := 0.04  # m: a coat tail's tip streams this much farther back in the run than at a stand
const LINK_TOL := 0.02  # share: a spring chain's links keep their rest lengths
## Slot -> [state before, state that starts it, the clip today's game plays for it]. A cast's state names its cast
## slot, which HunterAnim's counters turn into a new cast (cast 5 -> 0).
const SLOT_CASES := {
	"lmb": [{"swing_n": 0}, {"swing_n": 1, "combo": 0}, "attack"],
	"lmb_hold": [{"swing_n": 0}, {"swing_n": 1, "combo": -1}, "attack"],
	"rmb": [{"cast": 5.0, "cast_slot": "secondary"}, {"cast": 0.0, "cast_slot": "secondary", "kmove": "x"}, "attack"],
	"e": [{"cast": 5.0, "cast_slot": "utility"}, {"cast": 0.0, "cast_slot": "utility", "kmove": "x"}, "attack"],
	"r": [{"cast": 5.0, "cast_slot": "ult"}, {"cast": 0.0, "cast_slot": "ult", "kmove": "x"}, "attack"],
	"dash": [{}, {"rolling": true}, "idle"],
	"glide": [{"grounded": false}, {"grounded": false, "gliding": true}, "jump"],
	"land": [{}, {"feel": Vector2(0.8, 0.0)}, "idle"],
	"hit": [{"hit_t": 99.0}, {"hit_t": 0.0, "hit_k": Oomph.HEAVY_FLINCH}, "idle"],  # (a stagger; a chip hit only leans)
	"downed": [{}, {"fall": 0.5}, "idle"],
	"stomp": [{}, {"stomp": 0.4}, "idle"],
}

var bad := 0
var n := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDENNATIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var native: Array = []
	for a in Arch.ids():
		var m := _model(a)
		var is_on := WardenNative.on(a)
		ok(
			is_on == m.has_node("Warden/Native") and is_on == bool(m.get_meta(WardenNative.META, false)),
			"%s: %s" % [a, "on Meshy's skeleton" if is_on else "not on the native path"]
		)
		if is_on:
			native.append(a)
			ok(not m.has_node("Warden/Sync") and not bool(m.get_meta("glb", true)), "%s: no contract sync" % a)
		m.free()
	ok(not native.is_empty(), "native Hunters: %s" % str(native))
	for a in native:
		_bones(a)
		_height(a)
		await _states(main, a)
	print("WARDENNATIVE DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _model(a: String) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(m)
	return m


## Meshy's bones, as Meshy named them: none of the contract's; the model faces -Z like every Hunter.
func _bones(a: String) -> void:
	var m := _model(a)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	# (own: a bone named as the contract names it, not WardenSkeleton.find's Meshy stand-in)
	var contract := CONTRACT_BONES.filter(func(b): return WardenSkeleton.own(sk, b) >= 0)
	ok(
		sk.find_bone("Hips") >= 0 and sk.find_bone("RightHand") >= 0 and contract.is_empty(),
		"%s: Meshy's skeleton (%d bones, no contract bones %s)" % [a, sk.get_bone_count(), str(contract)]
	)
	var head := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Head")).origin
	var front := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("headfront")).origin
	var fwd := m.global_transform.basis.inverse() * (front - head)
	ok(fwd.z < 0.0 and absf(fwd.z) > absf(fwd.x), "%s: faces -Z (head to face %s)" % [a, fwd])
	m.free()


## The head stands where the contract model's does (the same size in game), times the Hunter's data "size".
func _height(a: String) -> void:
	var nm := WardenGlb.art(a)
	var old := (load("res://art/wardens/%s/%s.glb" % [nm, nm]) as PackedScene).instantiate() as Node3D
	var osk := WardenGlb.skeleton(old)
	var want := (
		osk.get_bone_global_rest(osk.find_bone("head")).origin.y * float(WardenNative.entry(nm).get("size", 1.0))
	)
	old.free()
	var m := _model(a)
	var glb := m.get_node("Warden") as Node3D
	var sk := WardenGlb.skeleton(glb)
	var got := glb.scale.y * sk.get_bone_global_rest(sk.find_bone("Head")).origin.y
	ok(absf(got / want - 1.0) < HEIGHT_TOL, "%s: head at %.3f m, contract model's %.3f m" % [a, got, want])
	m.free()


## Each game state plays its clip; the aim node rides the hand; the rig's weapon is hidden.
func _states(main: Node, a: String) -> void:
	var m := _model(a)
	var nat := m.get_node("Warden/Native") as WardenNative
	# (every state carries "cast" like Hunter._anim_state's: without it WardenNative reads the state
	# as not yet filled and ignores the swing; the idle case is the first read, the baseline
	# the attack's swing_n 1 is counted against)
	# (the walk at 1.5 m/s, or half the speed this Hunter's walk hands over to the run: Meeko's is under 1.5, but not
	# under 1.2 STILL)
	var walk := clampf(
		0.5 * float(WardenNative.entry(WardenGlb.art(a)).get("run_from", 3.0)), 1.2 * WardenNative.STILL, 1.5
	)
	var cases := [
		["idle", {"cast": 99.0, "grounded": true}],
		["walk", {"cast": 99.0, "grounded": true, "vel": Vector3(0.0, 0.0, -walk)}],
		["run", {"cast": 99.0, "grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}],
		["jump", {"cast": 99.0, "grounded": false, "vel": Vector3(0.0, 3.0, -4.0)}],
		["crouch", {"cast": 99.0, "grounded": true, "crouch": 1.0}],
		["attack", {"cast": 99.0, "grounded": true, "swing_n": 1}],
	]
	for c in cases:
		m.set_meta(WardenClips.STATE, {"cast": CALM_CAST}.merged(c[1], true))
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var want := String(nat.plays[c[0]])
		var sk := nat.skel
		var up := (
			sk.get_bone_global_pose(sk.find_bone("Head")).origin.y
			- sk.get_bone_global_pose(sk.find_bone("Hips")).origin.y
		)
		ok(up > UPRIGHT, "%s: %s stands up (head %.2f m over the hips)" % [a, c[0], up])
		ok(nat.player.current_animation == want, "%s: %s plays %s (%s)" % [a, c[0], want, nat.player.current_animation])
	var shown := m.get_node("Rig/Torso/Aim/Gun").find_children("*", "MeshInstance3D", true, false).filter(
		func(mi): return (mi as MeshInstance3D).visible
	)
	ok(shown.is_empty(), "%s: the rig's procedural weapon is hidden" % a)
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	ok(gun.global_position.distance_to(nat.hand_position()) < 0.01, "%s: the aim node rides Meshy's hand" % a)
	var anchors := ["anchor_head_top", "anchor_chest", "anchor_gun_R"].filter(func(an): return WardenGlb.anchor(m, an))
	ok(anchors.size() == 3, "%s: the anchors ride Meshy's bones (%s)" % [a, str(anchors)])
	_toon(a, m)
	_crouch_arms(a, nat)
	await _slots(main, a, m, nat)
	await _upper(main, a, m, nat)
	_twist(a, nat)
	_blends(a)
	await _kmoves(main, a, m, nat)
	_moves(a, nat)
	_only_meshy(a, m)
	await _orbits(main, a, nat)
	_drop_poses(a, m, nat)
	_springs(a, m, nat)
	m.free()


## Data "springs" builds its chains on Meshy's own bones and no other Hunter's: Sable's coat tails stream back in a
## run (the tip farther behind the hips than standing) and keep their links' lengths.
func _springs(a: String, m: Node3D, nat: WardenNative) -> void:
	var want := (WardenNative.entry(WardenGlb.art(a)).get("springs", []) as Array).size()
	ok(nat.springs.chains.size() == want, "%s: %d spring chains (data names %d)" % [a, nat.springs.chains.size(), want])
	if want == 0:
		return
	nat.set_process(false)
	var ids: Array = nat.springs.chains[0]["ids"]
	var tip := int(ids[ids.size() - 2])
	var back: Array = []
	for run_mps in [0.0, RUN_STEP]:
		m.set_meta(WardenClips.STATE, {"cast": CALM_CAST, "grounded": true, "vel": Vector3(0.0, 0.0, -run_mps * 60.0)})
		for k in 90:
			m.position.z -= run_mps
			nat._process(1.0 / 60.0)
		var hips := nat.skel.global_transform * nat.skel.get_bone_global_pose(int(ids[0])).origin
		var tail := nat.skel.global_transform * nat.skel.get_bone_global_pose(tip).origin
		back.append(tail.z - hips.z)
	ok(
		back[1] > back[0] + TRAIL_MIN,
		"%s: the coat tail streams back in a run (%.2f m, standing %.2f m)" % [a, back[1], back[0]]
	)
	var worst := 0.0
	for j in ids.size() - 2:
		var rest := nat.skel.get_bone_global_rest(int(ids[j + 1])).origin.distance_to(
			nat.skel.get_bone_global_rest(int(ids[j])).origin
		)
		var now := nat.skel.get_bone_global_pose(int(ids[j + 1])).origin.distance_to(
			nat.skel.get_bone_global_pose(int(ids[j])).origin
		)
		worst = maxf(worst, absf(now / rest - 1.0))
	ok(worst < LINK_TOL, "%s: the coat tail keeps its link lengths (off by %.1f%%)" % [a, worst * 100.0])


## The drop's shared poses (WardenDropPose) on Meshy's bones, held to the contract Heroes' bars (--clip-check's
## _drop_poses): upright aboard the rocket, belly down and spread in the skydive, banking into a steer, off for the
## glider.
func _drop_poses(a: String, m: Node3D, nat: WardenNative) -> void:
	var clip_check = load("res://tools/clip_check.gd").new()
	clip_check._drop_poses(a, m, nat)
	ok(clip_check.bad == 0, "%s: the drop poses on Meshy's bones (%d misses)" % [a, clip_check.bad])
	nat.set_process(true)


## Every surface wears the game's hero-toon material (not Meshy's PBR), and the hit flashes see them (meta "mats"); a
## flame slot's surface (Cinder's heel jets, WardenProps) wears the toon pass's flame shader instead, a card slot's
## (see-through wings) the card shader, and a mood face (Meeko's sun and cloud) its face shader.
func _toon(a: String, m: Node3D) -> void:
	var surfaces := 0
	var toon := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			surfaces += 1
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			var game := sm != null and sm.shader in [Models.HERO, WardenGlb.FLAME, WardenGlb.CARD]
			var face := sm != null and sm.shader == WardenMood.FACE_SHADER
			toon += int(face or (game and (m.get_meta("mats", []) as Array).has(sm)))
	ok(surfaces > 0 and toon == surfaces, "%s: hero-toon on %d of %d surfaces" % [a, toon, surfaces])


## The crouch's arm bones play the walk's arm keys (Meshy's crouch holds a torch out); its legs keep the crouch.
func _crouch_arms(a: String, nat: WardenNative) -> void:
	var from := String(nat.d.get("crouch_arms_from", ""))
	if from == "":
		return
	var mix := nat.player.get_animation(String(nat.plays["crouch"]))
	var arms := nat.player.get_animation(String(nat.plays[from]))
	var meshy := nat.player.get_animation(String(nat.d["clips"]["crouch"]))
	var arm := NodePath(String(meshy.track_get_path(0)).get_slice(":", 0) + ":RightForeArm")
	var leg := NodePath(String(arm).get_slice(":", 0) + ":RightLeg")
	var rot := Animation.TYPE_ROTATION_3D
	var mi := mix.find_track(arm, rot)
	var ai := arms.find_track(arm, rot)
	var same_arm: bool = mi >= 0 and ai >= 0 and mix.track_get_key_value(mi, 0) == arms.track_get_key_value(ai, 0)
	var li := mix.find_track(leg, rot)
	var ci := meshy.find_track(leg, rot)
	var same_leg: bool = li >= 0 and ci >= 0 and mix.track_get_key_value(li, 0) == meshy.track_get_key_value(ci, 0)
	ok(same_arm and same_leg, "%s: the crouch takes the %s's arms and keeps its own legs" % [a, from])


## Each kit move's own clip (data "kmoves"; its clock is the kit's) is there, and its hit pose sits on the kit's hit
## second (data "hit") within a frame: "peak" speed = the blade tip's fastest second, low = its lowest (first second
## within 2 cm of it), reach = the first second it stands within 2 cm of its farthest from the hips.
func _moves(a: String, nat: WardenNative) -> void:
	for km: String in nat.moves.moves:
		var mv: Dictionary = nat.moves.moves[km]
		var clip := String(mv["clip"])
		ok(nat.player.has_animation(clip), "%s: %s plays its own clip %s" % [a, km, clip])
		if not mv.has("hit"):
			continue
		var length := nat.player.get_animation(clip).length
		var tips: Array = []
		var hips: Array = []
		nat.player.play(clip)
		for k in int(length / PROBE) + 1:
			nat.player.seek(k * PROBE, true)
			var hand := nat.skel.get_bone_global_pose(nat.hand)
			tips.append(hand.origin + hand.basis.y * BLADE)
			hips.append(nat.skel.get_bone_global_pose(nat.skel.find_bone("Hips")).origin)
		var at := _peak(String(mv["peak"]), tips, hips) * PROBE
		ok(
			absf(at - float(mv["hit"])) <= 1.0 / 30.0 + 0.001,
			"%s: %s's hit pose (%s) at %.3f s, the kit's hit %.3f s" % [a, km, mv["peak"], at, mv["hit"]]
		)
	nat.player.stop()


func _peak(kind: String, tips: Array, hips: Array) -> int:
	var score: Array = []
	for k in tips.size():
		match kind:
			"speed":
				score.append(0.0 if k == 0 else (tips[k] as Vector3).distance_to(tips[k - 1]))
			"low":
				score.append(-(tips[k] as Vector3).y)
			_:
				score.append((tips[k] as Vector3).distance_to(hips[k]))
	var best: float = score.max()
	for k in score.size():
		if score[k] >= best - (0.0 if kind == "speed" else 0.02):
			return k
	return 0


## Only Meshy's model draws the body: no mesh of the hidden procedural rig (its weapon, the Offhand's second gauntlet
## or twin piece) shows, where it would float off the Meshy body in every frame. (Glow quads and the hit ring live
## outside the rig and are not counted.)
func _only_meshy(a: String, m: Node3D) -> void:
	var stray: Array = []
	for gi in m.get_node("Rig").find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).is_visible_in_tree():
			stray.append(String(m.get_path_to(gi)))
	ok(stray.is_empty(), "%s: no rig mesh draws beside Meshy's model (showing: %s)" % [a, str(stray)])


## Each data orbit (Tenzo's seeing-stones) rides its Meshy bone with all its props, round the head at the contract
## model's height, and turns over time.
func _orbits(main: Node, a: String, nat: WardenNative) -> void:
	var want: Dictionary = nat.d.get("orbits", {})
	for orb in want:
		var nd := nat.skel.find_child(String(orb), true, false) as Node3D
		var props := nd.get_children().filter(func(c): return c is MeshInstance3D) if nd else []
		var head := nat.skel.global_transform * nat.skel.get_bone_global_pose(nat.skel.find_bone("Head")).origin
		var far := 0.0
		for p in props:
			far = maxf(far, (p as Node3D).global_position.distance_to(head))
		var p0: Vector3 = props[0].global_position if not props.is_empty() else Vector3.ZERO
		for k in 10:
			await main.get_tree().process_frame
		var moved: float = props[0].global_position.distance_to(p0) if not props.is_empty() else 0.0
		ok(
			(
				nd != null
				and props.size() >= 3
				and far < 0.8
				and moved > 0.0005
				and nat.orbits.pivots.size() == want.size()
			),
			(
				"%s: %s rides %s (%d props, %.2f m from the head at most, moved %.3f m)"
				% [a, orb, want[orb], props.size(), far, moved]
			)
		)


## Plays state `s` for two frames (`calm` first, so the counters take it as their baseline) from a clean slate.
func _feed(main: Node, nat: WardenNative, m: Node3D, calm: Dictionary, s: Dictionary) -> void:
	nat.attack_left = 0.0
	nat.last = {"kmove": "", "swing_n": 0, "cast": -1.0, "recoil": 0.0}
	nat.hit_prev = 99.0
	nat.land_prev = 0.0
	for st in [calm, s]:
		var state := {"grounded": true, "cast": CALM_CAST}
		state.merge(st, true)
		m.set_meta(WardenClips.STATE, state)
		m.set_meta(WardenClips.FEEL, state.get("feel", Vector2.ZERO))
		await main.get_tree().process_frame
		await main.get_tree().process_frame


## How many bones the playing pose has turned off Meshy's rest (a T-pose turns none).
func _turned(nat: WardenNative) -> int:
	var sk := nat.skel
	var n_turned := 0
	for b in sk.get_bone_count():
		var rest := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		n_turned += int(sk.get_bone_pose_rotation(b).angle_to(rest) > TURNED)
	return n_turned


## Each slot: with no clip in the data a state plays today's clip; with one it plays that clip, in a pose that is not
## the T-pose on the switch nor once the crossfade is done; a charged swing without lmb_hold takes lmb; a clips
## file's clip is found, laid on Meshy's bones and plays; every slot the data names has its clip.
func _slots(main: Node, a: String, m: Node3D, nat: WardenNative) -> void:
	var named: Array = SLOT_CASES.keys().filter(func(sl): return (nat.d["clips"] as Dictionary).has(sl))
	var all_there: bool = named.all(func(sl): return nat.plays.has(sl))
	ok(all_there, "%s: every clip slot the data names has its clip (%s)" % [a, named])
	var pick := String(nat.d["clips"]["crouch"])  # (Meshy's clip no fallback plays)
	for sl in SLOT_CASES:
		var c: Array = SLOT_CASES[sl]
		if not nat.plays.has(sl):
			await _feed(main, nat, m, c[0], c[1])
			var want := String(nat.plays[c[2]])
			var now := nat.player.current_animation
			ok(now == want, "%s: slot %s empty plays %s" % [a, sl, now])
		nat.plays[sl] = pick
		await _feed(main, nat, m, c[0], c[1])
		var first := _turned(nat)
		nat.player.advance(WardenNative.FADE * 2.0)
		var done := _turned(nat)
		var got := nat.player.current_animation
		ok(
			got == pick and first >= POSED_MIN and done >= POSED_MIN,
			"%s: slot %s plays %s, no T-pose (%d, %d bones posed)" % [a, sl, got, first, done]
		)
		nat.plays.erase(sl)
	nat.plays["lmb"] = pick
	await _feed(main, nat, m, {"swing_n": 0}, {"swing_n": 1, "combo": -1})
	ok(nat.player.current_animation == pick, "%s: a charged swing takes lmb without lmb_hold" % a)
	nat.plays.erase("lmb")
	await _synthetic_clips(main, a, m, nat)


## A swing while he runs plays on the upper body (the run clip stays the playing one, the layer owns the arms); on the
## spot the attack clip owns the whole body.
func _upper(main: Node, a: String, m: Node3D, nat: WardenNative) -> void:
	var run_in := {"vel": Vector3(0.0, 0.0, -4.6)}
	await _feed(main, nat, m, run_in, run_in.merged({"swing_n": 1, "combo": 0}, true))
	var run_clip := String(nat.plays["run"])
	ok(
		nat.player.current_animation == run_clip,
		"%s: a swing on the run keeps the run clip (%s)" % [a, nat.player.current_animation]
	)
	var n_tracks := nat.upper.tracks().size()
	ok(nat.upper.on and nat.upper.w > 0.0 and n_tracks >= 5, "%s: ...and %d upper-body tracks play it" % [a, n_tracks])
	await _feed(main, nat, m, {}, {"swing_n": 1, "combo": 0})
	ok(
		not nat.upper.on and nat.player.current_animation == String(nat.plays["attack"]),
		"%s: a swing standing owns the body" % a
	)


## Strafing right while facing ahead turns the legs a quarter turn to the way he goes and leaves the torso where it
## was (the aim); back-pedalling, the legs face the aim and run backwards; standing, nothing turns.
func _twist(a: String, nat: WardenNative) -> void:
	var sk := nat.skel
	var hips_before := sk.get_bone_global_pose(nat.twist.hips).basis.get_rotation_quaternion()
	var torso_before := sk.get_bone_global_pose(nat.twist.torso).basis.get_rotation_quaternion()
	nat.twist.step(1.0, {"vel": Vector3(4.6, 0.0, 0.0), "face": 0.0}, true)
	var legs: float = sk.get_bone_global_pose(nat.twist.hips).basis.get_rotation_quaternion().angle_to(hips_before)
	var torso: float = sk.get_bone_global_pose(nat.twist.torso).basis.get_rotation_quaternion().angle_to(torso_before)
	ok(
		absf(legs - PI / 2.0) < 0.05 and torso < 0.05,
		"%s: strafing turns the legs %.2f rad, the torso %.2f" % [a, legs, torso]
	)
	nat.twist.step(1.0, {"vel": Vector3.ZERO, "face": 0.0}, true)
	ok(absf(nat.twist.turn) < 0.01, "%s: standing, the legs face the aim again" % a)
	_back(a, nat.twist)


## Backing off (more than 120 deg off the aim) runs the clip in reverse with the legs straight under the torso, from
## either side and at exactly 180 deg; between 110 and 130 deg it keeps the way it was going (no flicker).
func _back(a: String, tw: WardenNativeTwist) -> void:
	var reverse: Array = []
	for deg in [90.0, 125.0, 180.0, 115.0, 105.0, -125.0, -180.0]:
		var v := Vector3(-sin(deg_to_rad(deg)), 0.0, -cos(deg_to_rad(deg))) * 4.6
		tw.step(1.0, {"vel": v, "face": 0.0}, true)
		reverse.append(tw.dir < 0.0)
	ok(
		reverse == [false, false, true, true, false, false, true],
		"%s: reverse past 130 deg, forwards inside 110: %s" % [a, reverse]
	)
	ok(absf(tw.turn) < 0.01, "%s: dead behind the aim, no hip twist (%.3f rad)" % [a, tw.turn])
	tw.step(1.0, {"vel": Vector3.ZERO, "face": 0.0}, true)
	ok(tw.dir > 0.99, "%s: standing, the clip plays forwards again" % a)


## The clip blends: the glide opens at once and lets go over 0.2 s, the dash comes in over 0.25 s, the rest 0.15 s.
func _blends(a: String) -> void:
	var got := [
		WardenNative.blend_s("run", "glide"),
		WardenNative.blend_s("glide", "run"),
		WardenNative.blend_s("run", "dash"),
		WardenNative.blend_s("run", "jump")
	]
	ok(got == [0.0, 0.2, 0.25, 0.15], "%s: blends glide in/out, dash in, other: %s" % [a, got])


## A clips file (made here: a skeleton under another node name, one clip named SYNTH) lends its clip to a slot.
func _synthetic_clips(main: Node, a: String, m: Node3D, nat: WardenNative) -> void:
	var src := Node3D.new()
	var holder_node := Node3D.new()
	holder_node.name = "Elsewhere"
	src.add_child(holder_node)
	var sk := nat.skel.duplicate() as Skeleton3D
	sk.name = "Rig"
	holder_node.add_child(sk)
	var clip := nat.player.get_animation(String(nat.plays["attack"])).duplicate(true) as Animation
	for ti in clip.get_track_count():
		clip.track_set_path(ti, NodePath("Elsewhere/Rig:%s" % clip.track_get_path(ti).get_concatenated_subnames()))
	var lib := AnimationLibrary.new()
	lib.add_animation(SYNTH, clip)
	var sp := AnimationPlayer.new()
	sp.add_animation_library(&"", lib)
	src.add_child(sp)
	nat.plays["dash"] = SYNTH
	nat.borrow(src)
	var got := nat.player.get_animation(SYNTH) if nat.player.has_animation(SYNTH) else null
	var home := nat.player.get_node(nat.player.root_node)
	var on_bones := got != null and got.get_track_count() == clip.get_track_count()
	for ti in got.get_track_count() if got else 0:
		var p := got.track_get_path(ti)
		var bone := nat.skel.find_bone(p.get_concatenated_subnames())
		on_bones = on_bones and home.get_node_or_null(p) == nat.skel and bone >= 0
	var tracks := got.get_track_count() if got else 0
	ok(on_bones, "%s: a clips file's clip is laid on Meshy's bones (%d tracks)" % [a, tracks])
	await _feed(main, nat, m, {}, {"rolling": true})
	var plays_it := nat.player.current_animation == SYNTH and _turned(nat) >= POSED_MIN
	ok(plays_it, "%s: the slot plays the clips file's clip" % a)
	nat.player.stop()  # (a clip removed while it plays errors on every advance)
	nat.player.get_animation_library(&"").remove_animation(SYNTH)
	nat.plays.erase("dash")
	src.free()


## Each kit move the data gives a clip (data "kmoves"): the clip is there, plays on the move and is no T-pose; a hold
## loop stays inside [hold_from, end] while the move lasts and is gone the frame it ends; a release has the string
## drawn on its first frame and back on the bow on the next (the arrow leaves within a frame of the kit's fire time).
func _kmoves(main: Node, a: String, m: Node3D, nat: WardenNative) -> void:
	var kms: Dictionary = nat.d.get("kmoves", {})
	var string_bi := nat.skel.find_bone("StringMid")
	for km in kms:
		var mv: Dictionary = kms[km]
		var clip := String(mv["clip"])
		mv["fade"] = 0.0  # (the blend from the calm pose would be in every reading)
		ok(
			nat.plays.has("km:" + km) and nat.player.has_animation(clip),
			"%s: kit move %s has its clip %s" % [a, km, clip]
		)
		var length := nat.player.get_animation(clip).length
		var hold := float(mv.get("hold_from", -1.0))
		# (0.2 s in, or half a short clip's length: a clip with no hold loop stops on its last frame, holds that pose)
		var early := minf(0.2, 0.5 * length)
		await _feed(main, nat, m, {}, {"kmove": km, "kmove_t": early})
		ok(nat.player.current_animation == clip and _turned(nat) >= POSED_MIN, "%s: %s plays %s" % [a, km, clip])
		if hold >= 0.0:
			var late := hold + 2.5 * (length - hold)
			await _feed(main, nat, m, {}, {"kmove": km, "kmove_t": late})
			var pos := nat.player.current_animation_position
			ok(pos >= hold - 0.05 and pos < length, "%s: %s holds in its loop (%.2f s of %.2f)" % [a, km, pos, length])
			await _feed(main, nat, m, {}, {})
			# (a move on the idle loop itself, Gil's Riptide turn, ends back on that clip: the move lets go of the body)
			var idle_clip := clip == String(nat.plays.get("idle", ""))
			ok(
				nat.cur != "kmove" and (idle_clip or nat.player.current_animation != clip),
				"%s: no %s once the move ends" % [a, km]
			)
		elif string_bi >= 0:
			var pulls := []
			for t in [0.0, 1.0 / 30.0]:
				await _feed(main, nat, m, {}, {"kmove": km, "kmove_t": t})
				var off := nat.skel.get_bone_pose_position(string_bi) - nat.skel.get_bone_rest(string_bi).origin
				pulls.append(off.length())
			ok(pulls[0] > STRING_PULL and pulls[1] < STRING_BACK, "%s: %s lets go within a frame (%s)" % [a, km, pulls])
