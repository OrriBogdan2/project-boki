extends RefCounted
## --warden-native-check (docs/art/wardens/MESHY_NATIVE.md): each Hunter switched onto Meshy's own skeleton
## (content/rules/warden_native.json) builds from its <art>_meshy.glb with Meshy's bones as Meshy named them (no
## contract bones, no WardenSync), its clips play for the game states (idle, walk, run, jump, attack, crouch), it
## stands as tall as the contract model, faces the way the Hunter faces, keeps the hit ring, hides the rig's procedural
## weapon, puts the aim node on Meshy's hand and hangs the anchor empties on Meshy's bones. Every other Warden keeps
## the contract path. The clip slots (data "clips": lmb, lmb_hold, rmb, e, r, dash, glide, land, hit, downed, stomp):
## each is picked by its state or move, a missing one plays today's clip, a clips file's clips load onto Meshy's bones,
## and no switch shows the T-pose.

const HEIGHT_TOL := 0.03  # share: the head stands this close to the contract model's head height
const UPRIGHT := 0.25  # m, Meshy scale: the head stays this far over the hips in every state (a clip in a wrong frame)
const CONTRACT_BONES := ["hips", "upper_arm.L", "thigh.L"]
const POSED_MIN := 10  # bones turned off Meshy's T-pose rest in a playing clip (the T-pose turns none)
const TURNED := 0.03  # rad: a bone this far off its rest is posed
const SYNTH := "Zz_Clip"  # the test clip a synthetic clips file carries
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
	"hit": [{"hit_t": 99.0}, {"hit_t": 0.0}, "idle"],
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


## The head stands where the contract model's does (the same size in game).
func _height(a: String) -> void:
	var nm := WardenGlb.art(a)
	var old := (load("res://art/wardens/%s/%s.glb" % [nm, nm]) as PackedScene).instantiate() as Node3D
	var osk := WardenGlb.skeleton(old)
	var want := osk.get_bone_global_rest(osk.find_bone("head")).origin.y
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
	var cases := [
		["idle", {"grounded": true}],
		["walk", {"grounded": true, "vel": Vector3(0.0, 0.0, -1.5)}],
		["run", {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}],
		["jump", {"grounded": false, "vel": Vector3(0.0, 3.0, -4.0)}],
		["crouch", {"grounded": true, "crouch": 1.0}],
		["attack", {"grounded": true, "swing_n": 1}],
	]
	for c in cases:
		m.set_meta(WardenClips.STATE, c[1])
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
	_moves(a, m, nat)
	_crouch_arms(a, nat)
	await _slots(main, a, m, nat)
	_only_meshy(a, m)
	await _orbits(main, a, nat)
	m.free()


## The Hunter's own clips for its kit moves (data "kmoves", Cinder's hands): each plays instead of Meshy's one swing,
## on the kit's clock, with its pose where the move says: the lance's hand held out ahead, the sighting hand up at the
## eye, the push's palm ahead on the bolt's frame, the cloak's arms flung wide on the blast frame, the flight leaning
## in with the take-off clip then the loop, the landing clip; an upper clip lets go once played out.
func _moves(a: String, m: Node3D, nat: WardenNative) -> void:
	if nat.moves == null:
		return
	var s := {"grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var mv := nat.moves
	var swing := String(nat.plays["attack"])
	var before := _at(m, nat, s, "as_aim", 0.0)
	var held := _at(m, nat, s, "as_lance", 0.6)
	var own: bool = nat.player.current_animation != swing and mv.shown == "cn_u_lance_loop" and mv.weight >= 1.0
	ok(own, "%s: the lance holds its own clip over Meshy's idle (no swing; %s)" % [a, mv.shown])
	var reach: Vector3 = held["hand"]
	ok(reach.z < -0.2 and reach.y > 0.8, "%s: the lance's hand is held out ahead (%s)" % [a, reach])
	s["vel"] = Vector3(0.0, 0.0, -4.6)
	var leg := nat.skel.find_bone("LeftUpLeg")
	_at(m, nat, s, "as_lance", 0.6)
	var stride := nat.skel.get_bone_pose_rotation(leg)
	_at(m, nat, s, "as_lance", 0.7)
	var running: bool = nat.player.current_animation == String(nat.plays["run"])
	ok(
		running and not stride.is_equal_approx(nat.skel.get_bone_pose_rotation(leg)),
		"%s: the legs keep running under the lance (%s)" % [a, nat.player.current_animation]
	)
	s.erase("vel")
	var sight := _at(m, nat, s, "as_aim", 0.35)
	var up: float = sight["hand"].y - held["hand"].y
	ok(up > 0.1, "%s: the sighting hand rises to the eye (%.2f m over the lance's)" % [a, up])
	var fire := _at(m, nat, s, "as_shot", 0.0)
	var push := _at(m, nat, s, "as_shot", 0.1)
	var out_at: Vector3 = fire["muzzle"]
	ok(out_at.z < -0.2 and out_at.y > 1.0, "%s: the bolt leaves her palm on its frame (%s)" % [a, out_at])
	var from_z: float = fire["hand"].z
	var to_z: float = push["hand"].z
	ok(to_z < from_z - 0.03, "%s: the palm pushes on (%.2f to %.2f)" % [a, from_z, to_z])
	var blast := _at(m, nat, s, "as_cloak", 0.05)
	var span: float = blast["span"]
	ok(span > before["span"] + 0.4, "%s: both arms wide on the blast frame (%.2f m across)" % [a, span])
	_at(m, nat, s, "as_cloak", 1.0)
	_at(m, nat, s, "as_cloak", 1.0)
	ok(mv.weight <= 0.0, "%s: the cloak clip lets go once played out" % a)
	_at(m, nat, s, "lw_jet", 0.1)
	var clip := nat.player.current_animation
	ok(clip == "cn_f_takeoff", "%s: Flue Flight takes off (%s)" % [a, clip])
	var fly := _at(m, nat, s, "lw_jet", 0.9)
	ok(nat.player.current_animation == "cn_f_fly", "%s: then the flight loop (%s)" % [a, nat.player.current_animation])
	var lean: float = fly["lean"]
	ok(lean > before["lean"] + 0.25, "%s: flying leans into it (head %.2f m ahead of the hips)" % [a, lean])
	_at(m, nat, s, "lw_land", 0.1)
	ok(nat.player.current_animation == "cn_f_land", "%s: the landing clip (%s)" % [a, nat.player.current_animation])
	_at(m, nat, s, "", 0.0)
	clip = nat.player.current_animation
	ok(clip != "cn_f_land", "%s: back to the legs' own clip (%s)" % [a, clip])


## The state with kit move `km` `kt` s in, run on 0.1 s twice: the right hand, the muzzle (model frame: forward is -Z),
## the hands' span and the head's lead over the hips.
func _at(m: Node3D, nat: WardenNative, s: Dictionary, km: String, kt: float) -> Dictionary:
	s["kmove"] = km
	s["kmove_t"] = kt
	nat.call("_process", 0.1)
	nat.call("_process", 0.1)
	var hand := m.to_local(nat.hand_position())
	var left := _bone_in(m, nat, "LeftHand")
	var head := _bone_in(m, nat, "Head")
	var hips := _bone_in(m, nat, "Hips")
	var out := {"hand": hand, "span": hand.distance_to(left), "lean": hips.z - head.z}
	if nat.mouth:
		out["muzzle"] = m.to_local(nat._now(nat.mouth))
	return out


## Meshy's bone `bone` this frame, in the model's frame.
func _bone_in(m: Node3D, nat: WardenNative, bone: String) -> Vector3:
	return m.to_local(nat.skel.global_transform * nat.skel.get_bone_global_pose(nat.skel.find_bone(bone)).origin)


## Every surface wears the game's hero-toon material (not Meshy's PBR), and the hit flashes see them (meta "mats"); a
## flame slot's surface (Cinder's heel jets, WardenProps) wears the toon pass's flame shader instead.
func _toon(a: String, m: Node3D) -> void:
	var surfaces := 0
	var toon := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			surfaces += 1
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			var game := sm != null and (sm.shader == Models.HERO or sm.shader == WardenGlb.FLAME)
			toon += int(game and (m.get_meta("mats", []) as Array).has(sm))
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
		var state := {"grounded": true}
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
	nat.player.get_animation_library(&"").remove_animation(SYNTH)
	nat.plays.erase("dash")
	src.free()
