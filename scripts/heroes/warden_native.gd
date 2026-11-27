class_name WardenNative
extends Node
## A Hunter drawn on Meshy's own skeleton and playing Meshy's own clips (docs/art/wardens/MESHY_NATIVE.md). Only the
## Hunters switched on in content/rules/warden_native.json ("meshy_native") take this path; every other one keeps the
## contract model (WardenGlb, WardenSync, WardenClips) untouched. Meshy's bones are never renamed, retargeted or merged
## onto the contract: the clips play on them as Meshy keyed them; of the contract's procedural bone layers the look-at,
## the drop pose and the landing squash are built (on WardenSkeleton.find's stand-ins), and the springs only where data
## "springs" names Meshy's own bones for a chain (Sable's coat tails: WardenSprings.setup_named). The
## contract's anchor empties hang on Meshy's bones as BoneAttachment3D nodes (data "anchors"), and the weapon's aim
## node rides Meshy's hand bone. HunterAnim still runs
## on the hidden rig and hands over its state (WardenClips.STATE) each frame. The surfaces take the game's hero-toon
## pass (WardenGlb._toon: shading, ink, hit flashes) like every other Hunter's, unless data "toon" is false.

const DATA_PATH := "res://content/rules/warden_native.json"
const META := "meshy_native"  # root meta: this Hunter is drawn on Meshy's skeleton
const STILL := 0.25  # m/s: below this he is standing
const FADE := 0.15  # s: one clip into the next
const GLIDE_OUT := 0.2  # s: the glide clip back into the next one (it opens at once)
const DASH_IN := 0.25  # s: the dash clip over the body
const RATE_MIN := 0.6  # the walk, run and sneak clips' slowest rate, of their keyed pace
const RATE_MAX := 1.8  # and their fastest: a quicker stride keeps the feet nearer the ground speed
const LEAD_FADE := 0.05  # s: a basic attack that starts mid-clip (data "lmb_lead") blends in this fast
const ATTACK_AGAIN := 0.6  # share of the attack clip after which a new hit starts it over
const LEGS_RUN := ["walk", "run", "crouch"]  # the states where the legs carry him (they turn to his way)
const LOOPS := ["idle", "walk", "run", "crouch"]
## Clip slots data "clips" may add beside the six states; a missing one plays today's clip (MESHY_NATIVE.md).
## Swing and cast one-shots (the attack clip without them): lmb, lmb_hold (a charged swing), rmb, e, r (the kit's cast
## slots, MOVE_SLOTS). One-shots: hit, land. Held while the state lasts: dash, glide and stomp (these two loop), downed.
const HIT_SLOTS := ["hit", "land"]
const SLOTS := ["lmb", "lmb_hold", "rmb", "e", "r", "dash", "glide", "land", "hit", "downed", "stomp"]
const MOVE_SLOTS := {"secondary": "rmb", "utility": "e", "ult": "r"}  # the state's cast_slot -> its clip slot
const SLOT_CAST := 0.5  # s: a kit move that starts this soon after a cast belongs to that cast's slot
const LAND_MIN := 0.3  # a landing this hard (WardenClips.FEEL, 0..1) plays the land clip
## An animation-only file beside the model: the clips the data names, matched by name.
const CLIPS_FILE := "%s/%s/%s_clips.glb"
const ARMS_CLIP := "%s_arms"  # the crouch with another clip's arms (data "crouch_arms_from"), added beside Meshy's
const BOKI_SLOTS := ["k1", "k2"]  # cast slots that are the riding Boki's ability, not the Hunter's (no attack clip)
const ARM_ROOTS := ["LeftShoulder", "RightShoulder"]  # Meshy's bones whose chains are the arms (data "arm_roots")
## Set by the checks of the contract path (clips, rig, look-at, strides): every Hunter builds its contract model.
static var contract_only := false
static var _data = null  # art name -> its entry (parsed once)
## "art orbit" -> [the orbit node packed (instanced per Hunter), its rest, the head's, its bone's, the contract scene].
## The scene is kept loaded: letting it go freed Tarek's contract .glb on the main thread mid-build (480 ms on rp2g).
static var _orbit_src := {}
static var _contracts := {}  # art -> what its contract .glb gives the native path (contract(): sk_m, anchors)

var root: Node3D
var player: AnimationPlayer
var d: Dictionary
var art_id := ""  # the Hunter's art (its contract .glb carries the orbit props)
var plays: Dictionary  # game state -> the clip it plays (data "clips"; the crouch can be its arms-swapped copy)
var skel: Skeleton3D
var hand := -1  # Meshy's weapon-hand bone (data "hand"): the rig's Gun follows it
var gun: Node3D
var built := 0  # the rig weapon last hidden (instance id): Hunter.equip rebuilds it
var built_off := 0  # and the rig's Offhand last hidden (instance id)
var cur := ""  # the game state playing ("idle", "walk", ...)
var attack_left := 0.0  # s the clip of a swing, cast, hit or landing still owns the body
var attack_lead := 0.0  # s of the one-shot's clip its start skips: the clip's strike lands as the shot leaves
var attack_move := false  # it was started by a kit move or a swing (not a cast or a shot): the open reach waits
var hit_prev := 99.0  # the state's s since a hit, last frame
var land_prev := 0.0  # the state's landing squash, last frame
## The state counters last frame; cast -1: none read yet (the first state read is the baseline, no new hit)
var last := {"kmove": "", "swing_n": 0, "cast": -1.0, "recoil": 0.0}
var pose_held_t := 0.0  # s held by SimLod.pose_every (WardenGlb.POSE_HELD), stepped at the next posed frame
var followers: Array = []  # [orbit holder, Meshy bone]: the holder keeps the bone's move from its rest
var orbits := WardenOrbits.new()  # the contract model's orbit props (Tenzo's seeing-stones) riding Meshy's bones
## The contract path's bone layers, laid over Meshy's clips on Meshy's bones (WardenSkeleton.find names them): the hit
## flinch, the wall kick's plant and push, the open channel's reach, the drop's ride and skydive poses. Null when a
## bone is missing. The landing squash (WardenClips.lay_feel) goes on last, as on the contract path.
var flinch: WardenFlinch
var wall: WardenWall
var opener: WardenOpen
var head_look: WardenLookAt  # the head (and a share of the neck and chest) turns to the aim ahead of the body
var drop_pose: WardenDropPose
var heart_w := 0.0  # how far the Heartspark carry (WardenCarry.hold_mote) holds the mote (as WardenClips.heart_w)
var torso_bi := -1  # Meshy's bone standing in for the rig's torso (WardenSkeleton.find "hips": Spine02)
var torso_off := Transform3D()  # that bone's frame -> the rig torso's, at rest (shown_torso)
var mouth: Node3D  # the copied weapon_muzzle (on a bone, a part or the sun): where the Gun's Muzzle sits each frame
var gunprop: WardenGunProp  # Grimble's one gun (data "holster"): hip at rest, hand while he aims
var springs := WardenSprings.new()  # loose parts (data "springs": Sable's coat tails) swinging on Meshy's bones
var props: WardenProps  # the contract's parts Meshy's mesh lacks (data "props": Kael's sword, Cinder's heel jets)
var twist := WardenNativeTwist.new()  # the legs turned to the way he goes, the torso held on the aim
var upper: WardenNativeUpper  # a swing or cast over the running legs (the torso and arms only)
var moves: WardenNativeMoves  # the kit moves with a clip of their own (data "kmoves")
var companions: WardenCompanions  # floating companions cut out of Meshy's body (Meeko's sun and cloud), or null
var steps: WardenNativeSteps  # the footsteps, on the foot plants of Meshy's clips (data "plants")
var mood: WardenMood  # the faces on those companions swap and blink (warden_anim/<art>.json "mood"), or null


## The art's entry in warden_native.json ({} when it has none).
static func entry(art_name: String) -> Dictionary:
	if _data == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return (_data as Dictionary).get(art_name, {})


## Whether this archetype's Hunter is switched onto Meshy's own skeleton (and its file is there).
static func on(arch: String) -> bool:
	var e := entry(WardenGlb.art(arch))
	return not contract_only and bool(e.get("meshy_native", false)) and ResourceLoader.exists(file(arch))


## The Meshy-skeleton .glb, beside the contract one: art/wardens/<art>/<art>_meshy.glb.
static func file(arch: String) -> String:
	var nm := WardenGlb.art(arch)
	return "%s/%s/%s_meshy.glb" % [WardenGlb.DIR, nm, nm]


## Dresses the procedural hunter `model` (built rig-only) in its Meshy model; the rig stays as HunterAnim's state.
## lk: the look Models.hunter built from (its colour picks tint the toon pass's painted slots).
static func dress(model: Node3D, arch: String, scene: PackedScene, lk := {}) -> void:
	var e := entry(WardenGlb.art(arch))
	var glb := scene.instantiate() as Node3D
	glb.name = "Warden"
	glb.rotation.y = PI  # (Meshy faces +Z; a Hunter's model faces -Z)
	model.add_child(glb)
	glb.scale = Vector3.ONE * _fit(model, WardenGlb.skeleton(glb)) * float(e.get("size", 1.0))
	var nat := WardenNative.new()
	nat.name = "Native"
	nat.art_id = WardenGlb.art(arch)
	nat.setup(model, glb, e)
	var look := WardenGlb.look(WardenGlb.art(arch))  # (the contract path's glow and far-hide, on the copied props)
	WardenGlb._halos(model, glb, look)
	WardenFx.bloom(model, glb, look)
	WardenGlb._far_hide(glb, look)
	if nat.wall:
		nat.wall.heavy = Arch.weight(arch) == "heavy"  # (as WardenGlb.dress: a heavy Hero crouches deeper)
	glb.add_child(nat)
	if bool(e.get("toon", true)):
		var own := look
		var mats: Array = model.get_meta("mats", [])
		mats.append_array(WardenGlb._toon(glb, lk, MantleLook.warden(arch), own, arch))
		model.set_meta("mats", mats)
	# (after the toon pass: the faces' atlas shader replaces its override)
	nat.mood = WardenMood.make(model, glb, nat.skel, nat.art_id)
	if nat.companions:
		nat.companions.mood = nat.mood
	model.set_meta(META, true)


## The size that puts Meshy's head bone where the rig's head pivot rests: the contract model's head height (data "size"
## then scales it where Meshy's body stands off the height chart, --native-hitbox-check).
static func _fit(model: Node3D, sk: Skeleton3D) -> float:
	var rest: Dictionary = model.get_meta("rig_rest", {})
	var head := sk.find_bone("Head")
	if not rest.has("head") or head < 0:
		return 1.0
	return (rest["head"] as Transform3D).origin.y / sk.get_bone_global_rest(head).origin.y


func setup(model: Node3D, glb: Node3D, data: Dictionary) -> void:
	root = model
	d = data
	process_priority = 10  # (after Match renders the hunters: HunterAnim.update)
	player = glb.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	plays = (d["clips"] as Dictionary).duplicate()
	if d.has("clip_files"):  # (clips-only files: Hero moves keyed on Meshy's skeleton, beside the .glb)
		var lib_name := player.find_animation_library(player.get_animation(String(plays["idle"])))
		WardenClipFile.add(player.get_animation_library(lib_name), glb, WardenGlb.skeleton(glb), d["clip_files"])
	moves = WardenNativeMoves.new(player, d)
	plays.merge(moves.clips())
	skel = WardenGlb.skeleton(glb)
	_borrow_clips()
	for st in SLOTS + moves.clips().keys():  # (a slot whose clip is nowhere plays today's clip)
		if plays.has(st) and not player.has_animation(String(plays[st])):
			push_warning("warden_native %s: slot %s names clip %s, which no file has" % [art_id, st, plays[st]])
			plays.erase(st)
	for st in LOOPS + ["stomp", "glide"]:
		if plays.has(st):
			player.get_animation(String(plays[st])).loop_mode = Animation.LOOP_LINEAR
	# (the clips advance in _process, then the layers go on top: WardenSync's order)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if d.has("bones"):
		skel.set_meta(WardenSkeleton.BONE_MAP, d["bones"])
	springs.setup_named(skel, d.get("springs", []))
	flinch = WardenFlinch.make(model, skel)
	wall = WardenWall.make(model, skel)
	opener = WardenOpen.make_on(model, skel)
	head_look = WardenLookAt.make(model, skel, true)
	drop_pose = WardenDropPose.make(model, skel)
	if d.has("crouch_arms_from"):
		plays["crouch"] = _arms_swapped("crouch", String(d["crouch_arms_from"]))
	hand = skel.find_bone(String(d.get("hand", "RightHand")))
	torso_bi = WardenSkeleton.find(skel, "hips")
	upper = WardenNativeUpper.make(skel, torso_bi)
	twist.skel = skel
	twist.hips = WardenSkeleton.find(skel, "root")
	twist.torso = torso_bi
	var rest: Dictionary = model.get_meta("rig_rest", {})
	if torso_bi >= 0 and rest.has("hips"):
		var at_rest := WardenGlb.model_xf(model, skel) * skel.get_bone_global_rest(torso_bi)
		torso_off = at_rest.affine_inverse() * (rest["hips"] as Transform3D)
	var anchors: Dictionary = d.get("anchors", {})
	for an in anchors:
		var at := BoneAttachment3D.new()
		at.name = String(an)
		at.bone_name = String(anchors[an])
		skel.add_child(at)
	gun = root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	_add_orbits(glb)
	var to_m := _to_contract(glb)
	props = WardenProps.carry(art_id, skel, to_m, d)
	gunprop = WardenGunProp.make(model, skel, to_m, d.get("holster", {}))
	_copy_anchors(glb)
	var c_xf: Transform3D = contract(art_id).get("sk_m", Transform3D.IDENTITY)
	companions = WardenCompanions.detach(glb, skel, WardenClips.data(art_id), to_m.affine_inverse() * c_xf)
	mouth = skel.find_child(WardenGlb.WEAPON_MUZZLE, true, false) as Node3D
	model.set_meta(WardenClips.DEATH_T, 0.0)  # (the extract beat plays, WardenClips.leave_t; no death clip to hold)
	steps = WardenNativeSteps.new(model, player, d.get("plants", {}))
	_play("idle", 1.0)


## The idle pose at once: a model dressed mid-frame (a re-class, a remote copy built off a snapshot) would draw
## Meshy's rest T-pose until its first _process advance.
func _ready() -> void:
	player.advance(0.0)


func _process(dt: float) -> void:
	_hide_rig_weapon()
	if int(root.get_meta(WardenGlb.POSE_HELD, -1)) == Engine.get_process_frames():
		pose_held_t += dt  # SimLod.pose_every held the pose (as WardenSync): the next posed frame catches it up
		_place_gun()  # (the body still moves under it)
		return
	dt += pose_held_t
	pose_held_t = 0.0
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	attack_left -= dt
	var one := _one_shot(s)
	var xt := float(s.get("extract_t", -1.0))
	if xt >= 0.0:  # the extract beat (WardenClips.leave_t): Meshy's crouch for the dip, then its jump for the take-off
		_play("crouch" if xt < WardenClips.EXTRACT_DIP else "jump", 1.0)
	elif moves.owns(s, plays):  # a kit move with its own clip (draw, release, Spirit Walk): laid at the move's clock
		upper.stop()
		moves.play(s, plays, dt)
		attack_left = 0.0
		cur = "kmove"
	elif one != "":
		var lead := 0.0 if one in HIT_SLOTS else attack_lead
		attack_left = (_clip_len(one) - lead) / _shot_rate(one)
		if _over_legs(one, s):
			upper.play(player.get_animation(String(plays[one])), _shot_rate(one), lead)
			_loco(s)
		else:
			upper.stop()
			_play(one, _shot_rate(one), true, lead)
	elif attack_left <= 0.0 or upper.on:
		_loco(s)
	var hips := WardenSkeleton.find(skel, "root")
	skel.set_bone_pose_scale(hips, skel.get_bone_rest(hips).basis.get_scale())  # (Meshy keys no scale: no old squash)
	player.advance(dt)
	moves.pose(s, get_parent() as Node3D)
	upper.lay(dt)
	twist.step(dt, s, cur in LEGS_RUN)
	steps.step(cur if xt < 0.0 else "")
	WardenClips.air_tilt(root, skel, hips)  # (the glider's bank, the dive's pitch)
	# (the look-at lies under a clip that turns the head: the attack clip owns it, eased in and out like a body clip)
	head_look.owned = move_toward(head_look.owned, 1.0 if attack_left > 0.0 else 0.0, dt / FADE)
	head_look.step(dt, null)
	_heart(bool(s.get("heart", false)) and attack_left <= 0.0 and not WardenCarry.owns(String(s.get("kmove", ""))), dt)
	if opener:
		opener.busy = attack_left > 0.0 and attack_move  # (as clips.busy: a kit move's clip owns the body)
		opener.step(dt, 1.0)
	if flinch:
		flinch.step(dt)
	if wall:
		wall.step(dt)
	if drop_pose:
		drop_pose.step(dt)
	var land: Vector2 = root.get_meta(WardenClips.FEEL, Vector2.ZERO)  # (HunterAnim's land_k by weight class)
	WardenClips.lay_feel(root, skel, hips, land.x * WardenClips.LAND_SQUASH, 0.0)
	springs.step(dt)
	props.step(dt, String(s.get("kmove", "")))
	if gunprop:
		gunprop.step()
	if companions:
		companions.step(dt)
	if mood:
		mood.step(dt)
	_place_gun()
	for f in followers:
		var b: int = f[1]
		(f[0] as Node3D).position = (skel.get_bone_global_pose(b).origin - skel.get_bone_global_rest(b).origin)
	orbits.look = root.get_meta(WardenGlb.ORBIT_LOOK, Vector3.INF)
	orbits.step(dt)


## The held gun in Meshy's hand, and its muzzle on a skinned weapon's mouth.
func _place_gun() -> void:
	if gun and gun.is_inside_tree() and hand >= 0:
		gun.global_position = hand_position()
		var mz := gun.get_node_or_null(^"Muzzle") as Node3D
		if mz and mouth:  # (as WardenSync puts it on a skinned weapon's mouth: Cinder's palm)
			mz.global_position = _now(mouth)


## The Heartspark carry on Meshy's arms (WardenClips._heart's layer): the off hand (the Hero's clip data "heart_hand")
## holds the mote at the chest while the legs and the other arm play on; it lets go for the attack clip.
func _heart(on: bool, dt: float) -> void:
	heart_w = move_toward(heart_w, 1.0 if on else 0.0, dt / WardenCarry.FADE)
	if heart_w <= 0.0:
		root.remove_meta(WardenCarry.MOTE)
		return
	var cd := WardenClips.data(art_id)
	var fwd := float(d.get("carry_fwd", cd.get("carry_fwd", WardenCarry.REACH_FWD)))
	var side := String(d.get("heart_hand", cd.get("heart_hand", "L")))
	root.set_meta(WardenCarry.MOTE, WardenCarry.hold_mote(skel, root, heart_w, side, fwd))


## Where empty `nd` (on a bone attachment, maybe under a part) is this frame (world), from the pose the clip just set.
func _now(nd: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = nd
	while n is Node3D and not (n is BoneAttachment3D):
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	if not (n is BoneAttachment3D):
		return nd.global_position
	var bi := skel.find_bone((n as BoneAttachment3D).bone_name)
	return (skel.global_transform * skel.get_bone_global_pose(bi) * xf).origin


## Where the rig's torso shows, world (WardenGlb.shown_torso): Meshy's torso bone as its clip and the air tilt posed
## it, so a Boki riding on the Hunter keeps its seat on the body you see.
func shown_torso() -> Transform3D:
	if torso_bi < 0:
		return (root.get_node(^"Rig/Torso") as Node3D).global_transform
	return skel.global_transform * skel.get_bone_global_pose(torso_bi) * torso_off


## Meshy's weapon hand this frame (world), from the pose the clip just set: an attachment would follow a frame late.
func hand_position() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(hand).origin


## The clip for standing, moving, crouching and the air, at a rate that follows the ground speed.
func _loco(s: Dictionary) -> void:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var ground := Vector2(vel.x, vel.z).length()
	var held := _held(s)
	if bool(s.get("dead", false)):
		_play("idle", 0.0)
	elif held != "":
		_play(held, 1.0)
	elif not bool(s.get("grounded", true)):
		_play("jump", float(d.get("jump_rate", 1.0)))
	elif float(s.get("crouch", 0.0)) > 0.5:
		_play("crouch", _rate(ground, "crouch_mps", 0.0))
	elif ground >= float(d.get("run_from", 3.0)):
		_play("run", _rate(ground, "run_mps", RATE_MIN))
	elif ground >= STILL:
		_play("walk", _rate(ground, "walk_mps", RATE_MIN))
	else:
		_play("idle", 1.0)


## The slot clip a state holds the body in while it lasts (the data names one for it; "" none).
func _held(s: Dictionary) -> String:
	if plays.has("downed") and float(s.get("fall", -1.0)) >= 0.0:
		return "downed"
	if plays.has("stomp") and float(s.get("stomp", -1.0)) >= 0.0:
		return "stomp"
	if plays.has("glide") and bool(s.get("gliding", false)):
		return "glide"
	if plays.has("dash") and bool(s.get("rolling", false)):
		return "dash"
	return ""


## The clip a new one-shot starts this frame ("" none): a stagger (a chip hit only leans: WardenFlinch), a swing,
## cast or kit move, or a hard landing, in that order. Every counter is read each frame, so a one-shot that loses to
## another one is not played later.
func _one_shot(s: Dictionary) -> String:
	var swing := _swing(s)
	var hit := _new_hit(float(s.get("hit_t", 99.0)))
	var hurt := hit and float(s.get("hit_k", 1.0)) >= Oomph.HEAVY_FLINCH
	var landed := _landed()
	if hurt and plays.has("hit") and (cur != "hit" or _fresh("hit")):  # (a hit cuts in on any swing)
		return "hit"
	if swing != "":
		return swing
	return "land" if landed and plays.has("land") and _fresh("land") else ""


## Whether a new one-shot plays on the upper body over the loop clips: a swing or cast while he moves or is in the air
## (standing on the ground it owns the whole body; a stagger or a landing always does).
func _over_legs(st: String, s: Dictionary) -> bool:
	if st in HIT_SLOTS:
		return false
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	return not bool(s.get("grounded", true)) or Vector2(vel.x, vel.z).length() >= STILL


func _new_hit(t: float) -> bool:
	var fresh := WardenFlinch.is_new_hit(t, hit_prev)
	hit_prev = t
	return fresh


## A landing hard enough for the land clip starts when HunterAnim's landing squash rises.
func _landed() -> bool:
	var k := (root.get_meta(WardenClips.FEEL, Vector2.ZERO) as Vector2).x
	var fresh := k >= LAND_MIN and k > land_prev
	land_prev = k
	return fresh


## The clip slot of a new swing, cast or kit move this frame ("" none): the state counters moved on since the last
## frame (a swing count that drops back, a fresh state, is no hit). A swing takes lmb (lmb_hold when charged), a cast
## its cast slot's (rmb, e, r); a slot the data leaves out plays "attack".
func _swing(s: Dictionary) -> String:
	var now := {
		"kmove": String(s.get("kmove", "")),
		"swing_n": int(s.get("swing_n", 0)),
		# (a Boki's own ability, k1 or k2, is its move: the Hunter does not swing for it)
		"cast": INF if String(s.get("cast_slot", "")) in BOKI_SLOTS else float(s.get("cast", INF)),
		"recoil": float(s.get("recoil", 0.0)),
	}
	if not s.has("cast"):
		return ""  # (Hunter._anim_state has not filled this model's state yet: no counters to read)
	if float(last["cast"]) < 0.0:
		last = now  # (the first state read is the baseline: counters a freshly dressed model finds are no new hit)
		return ""
	var move: bool = now["kmove"] != "" and now["kmove"] != last["kmove"]
	var melee: bool = now["swing_n"] > last["swing_n"]
	var cast_new: bool = now["cast"] < last["cast"]
	var shot: bool = now["recoil"] > last["recoil"]
	last = now
	if not (move or melee or cast_new or shot):
		return ""
	var slot := "attack"
	if cast_new or (move and not melee and now["cast"] < SLOT_CAST):
		slot = String(MOVE_SLOTS.get(String(s.get("cast_slot", "")), "attack"))
	elif melee or shot:
		slot = "lmb_hold" if melee and int(s.get("combo", 0)) < 0 else "lmb"
	if not plays.has(slot):  # (an uncharged swing's slot stands in for a charged one's)
		slot = "lmb" if slot == "lmb_hold" and plays.has("lmb") else "attack"
	if not _fresh(slot):
		return ""
	attack_move = move or melee
	attack_lead = _lead(slot, "shot" if melee or shot else String(now["kmove"]))
	return slot


## Where in the clip a basic attack starts (s): data "lmb_lead" by what started it ("shot": a swing or a shot, or the
## kit move's name). The kit lets the round go as the swing is pressed, so the clip begins at its wind-up's end and its
## strike frame lands with the round (tools/lmb_anim_sync_check.gd) instead of half a second after it.
func _lead(slot: String, what: String) -> float:
	return float((d.get("lmb_lead", {}) as Dictionary).get(what, 0.0)) if slot == "lmb" or slot == "attack" else 0.0


## Whether a clip may start now: nothing plays over the body, or the clip before it is past ATTACK_AGAIN of its length.
func _fresh(st: String) -> bool:
	return attack_left <= _clip_len(st) * (1.0 - ATTACK_AGAIN) / _shot_rate(st)


## The play rate of a one-shot: data "attack_rate" for the swing and cast clips, 1 for a hit or a landing.
func _shot_rate(st: String) -> float:
	return 1.0 if st in HIT_SLOTS else float(d.get("attack_rate", 1.0))


## The loop's rate for this ground speed against the speed it was keyed at (data, m/s), clamped to the clip's range.
func _rate(ground: float, key: String, lo: float) -> float:
	return clampf(ground / float(d.get(key, 1.5)), lo, RATE_MAX)


func _clip_len(st: String) -> float:
	return player.get_animation(String(plays[st])).length


## Seconds the clip of state `to` blends in over the one of state `from`: the glide opens at once and lets go slower,
## the dash takes the body gradually, everything else FADE.
static func blend_s(from: String, to: String) -> float:
	if from == "glide":
		return GLIDE_OUT
	if to == "glide":
		return 0.0
	return DASH_IN if to == "dash" else FADE


## The game state's clip, crossfaded in when it changes (restart: a new attack plays it from the start).
func _play(st: String, rate: float, restart := false, from := 0.0) -> void:
	if st != cur or restart:
		player.play(String(plays[st]), LEAD_FADE if from > 0.0 else blend_s(cur, st))
		if restart:
			player.seek(from, true)
		cur = st
	player.speed_scale = rate * (twist.dir if st in LEGS_RUN else 1.0)  # (the legs run backwards when he backs off)


## Meshy's model carries its weapons in the mesh (Sable's two pistols, Tenzo's one stone arm): the rig's procedural
## weapon stays hidden, even after a re-equip, and so does HunterAnim's Offhand (the twin weapon's left piece, the
## fist hold's second gauntlet), which would float beside the Meshy body in every frame.
func _hide_rig_weapon() -> void:
	if gun == null:
		return
	var off := gun.get_parent().get_node_or_null("Offhand") as Node3D
	var id := 0
	if gun.get_child_count() > 0:
		id = gun.get_child(gun.get_child_count() - 1).get_instance_id()
	var off_id := off.get_instance_id() if off else 0
	if id == built and off_id == built_off:
		return
	built = id
	built_off = off_id
	if id != 0:
		WardenGlb._skinned_weapon(root)
	if off:
		for mi in off.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).visible = false
			mi.set_meta("glb_hidden", true)


## Clips the data names for the slots that Meshy's own file lacks come from the animation-only file beside the model
## (CLIPS_FILE), matched by clip name. Its tracks are matched by bone name onto this skeleton; a track of a bone this
## skeleton lacks is dropped. The copies are added to the shared library once, like the crouch arms.
func _borrow_clips() -> void:
	var path := CLIPS_FILE % [WardenGlb.DIR, art_id, art_id]
	if ResourceLoader.exists(path):
		var src := (load(path) as PackedScene).instantiate() as Node3D
		borrow(src)
		src.free()


## Adds the clips the slots name that are missing here from the instanced animation file `src`.
func borrow(src: Node3D) -> void:
	var sp := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var from := String(sp.get_node(sp.root_node).get_path_to(WardenGlb.skeleton(src)))
	var to := String(player.get_node(player.root_node).get_path_to(skel))
	var lib := player.get_animation_library(&"")
	for st in plays:
		var nm := String(plays[st])
		if nm == "" or player.has_animation(nm) or not sp.has_animation(nm):
			continue
		var clip := sp.get_animation(nm).duplicate(true) as Animation
		for ti in range(clip.get_track_count() - 1, -1, -1):
			var p := clip.track_get_path(ti)
			var bone := String(p.get_concatenated_subnames())
			if String(p.get_concatenated_names()) == from and skel.find_bone(bone) >= 0:
				clip.track_set_path(ti, NodePath("%s:%s" % [to, bone]))
			else:
				clip.remove_track(ti)
		lib.add_animation(nm, clip)


## The state's clip with the arms of clip `from` (another state's), time-scaled onto it so they cycle once per loop:
## Meshy's only crouch walks holding a torch out in front, which reads in game as the prop floating off the body.
## The arm bones are found below Meshy's own shoulder bones (data "arm_roots"); a bone the source clip does not key
## keeps the state clip's track. The copy is added beside Meshy's clips (its library is shared by every instance of
## the .glb, so it is built once); returns its name.
func _arms_swapped(st: String, from: String) -> String:
	var base := player.get_animation(String(plays[st]))
	var arms := player.get_animation(String(plays[from]))
	var lib_name := player.find_animation_library(base)
	var lib := player.get_animation_library(lib_name)
	var nm := ARMS_CLIP % String(plays[st])
	var full := nm if String(lib_name) == "" else "%s/%s" % [lib_name, nm]
	if lib.has_animation(nm):
		return full
	var bones := {}
	for r in d.get("arm_roots", ARM_ROOTS):
		_chain(skel.find_bone(String(r)), bones)
	var mix := base.duplicate(true) as Animation
	mix.loop_mode = Animation.LOOP_LINEAR
	var k := base.length / arms.length
	for ti in range(mix.get_track_count() - 1, -1, -1):
		var p := mix.track_get_path(ti)
		var tt := mix.track_get_type(ti)
		var si := arms.find_track(p, tt)
		if si < 0 or not bones.has(String(p.get_concatenated_subnames())):
			continue
		mix.remove_track(ti)
		var ni := mix.add_track(tt)
		mix.track_set_path(ni, p)
		mix.track_set_interpolation_type(ni, arms.track_get_interpolation_type(si))
		for key in arms.track_get_key_count(si):
			mix.track_insert_key(ni, arms.track_get_key_time(si, key) * k, arms.track_get_key_value(si, key))
	lib.add_animation(nm, mix)
	return full


## Bone `b` and every bone below it, by name, into `into`.
func _chain(b: int, into: Dictionary) -> void:
	if b < 0:
		return
	into[skel.get_bone_name(b)] = true
	for c in skel.get_bone_children(b):
		_chain(c, into)


## The contract model's orbits (data "orbits": orbit node -> Meshy bone; Tenzo's three seeing-stones round his head)
## are separate props, not in Meshy's mesh: each is copied from the Hunter's contract .glb onto a holder that follows
## Meshy's bone's place (not its turn, so the ring stays level when the clip bows the head), at the same place against
## the bone as on the contract model and at the same size in metres, and
## WardenOrbits turns it as on the contract path (circling, bobbing, the eyes turning to what the kit watches).
func _add_orbits(glb: Node3D) -> void:
	var want: Dictionary = d.get("orbits", {})
	if want.is_empty():
		return
	for orb in want:
		var src := _orbit(String(orb))
		if src.is_empty():
			continue
		var b := skel.find_bone(String(want[orb]))
		if b < 0:
			continue
		var at := Node3D.new()  # (follows the bone's place, not its turn: the orbit stays upright when he bows)
		at.name = "bone_%s" % orb  # (not "orbit_*": WardenOrbits would turn it)
		skel.add_child(at)
		var nd := src[0] as Node3D
		var sk_m := glb.transform * WardenGlb.model_xf(glb, skel)
		# Meshy's bone vs the contract's: the head for a head orbit, the bone it rides there for any other
		var ride := sk_m * skel.get_bone_global_rest(b)
		var ref: Transform3D = src[2] if String(want[orb]) == "Head" else src[3]
		var shift := ride.origin - ref.origin
		nd.transform = (sk_m.affine_inverse() * Transform3D(Basis.IDENTITY, shift) * (src[1] as Transform3D))
		at.add_child(nd)
		followers.append([at, b])
	orbits.setup(skel)


## The orbit node `orb` of this Hunter's contract model (a copy), its rest in model space, the contract head's and the
## rest of the contract bone it rides ([] if none). The contract .glb is loaded and instanced once per art and orbit
## (_orbit_src keeps the part, packed).
func _orbit(orb: String) -> Array:
	var key := "%s %s" % [art_id, orb]
	if not _orbit_src.has(key):
		_orbit_src[key] = _read_orbit(art_id, orb)
	var src: Array = _orbit_src[key]
	return [] if src.is_empty() else [(src[0] as PackedScene).instantiate() as Node3D, src[1], src[2], src[3]]


static func _read_orbit(art_name: String, orb: String) -> Array:
	var path := "%s/%s/%s.glb" % [WardenGlb.DIR, art_name, art_name]
	if not ResourceLoader.exists(path):
		return []
	var out: Array = []
	var ps := load(path) as PackedScene
	var con := ps.instantiate() as Node3D
	var csk := WardenGlb.skeleton(con)
	var nd := con.find_child(orb, true, false) as Node3D
	var at := nd.get_parent() as BoneAttachment3D if nd else null
	if csk and at and csk.find_bone(at.bone_name) >= 0:
		var sk_m := WardenGlb.model_xf(con, csk)
		var rest := sk_m * csk.get_bone_global_rest(csk.find_bone(at.bone_name)) * nd.transform
		var bone := sk_m * csk.get_bone_global_rest(csk.find_bone(at.bone_name))
		var head := sk_m * csk.get_bone_global_rest(WardenSkeleton.find(csk, "head"))
		var copy := nd.duplicate() as Node3D
		for c in copy.find_children("*", "", true, false):
			c.owner = copy  # (packed with it)
		var packed := PackedScene.new()
		packed.pack(copy)
		copy.free()
		out = [packed, rest, head, bone, ps]  # (ps: kept loaded)
	con.free()
	return out


## Meshy's skeleton -> the model as the contract model is sized (the data "size" taken off): what the contract gives in
## metres (parts, anchors, companions) then grows or shrinks with the body.
func _to_contract(glb: Node3D) -> Transform3D:
	var to_m := glb.transform * WardenGlb.model_xf(glb, skel)
	var size := float(d.get("size", 1.0))
	return Transform3D(to_m.basis / size, to_m.origin / size)


## The contract model's anchor empties (anchor_*, weapon_muzzle*: the points the kits and VFX read, Cinder's palms,
## tail tip and heel jets, Kael's blade tip) that data "anchors" does not place. Each rides the Meshy bone that plays
## the part of its contract bone, or of the nearest ancestor bone Meshy has a stand-in for (WardenSkeleton.find).
## On its own bone's stand-in it keeps that bone's frame at the same distance in metres (the bone frames, not the
## model, carry it over: Meshy's rest is a T-pose, the contract's arms hang); on a parent's (a tail spring, a
## pauldron: the torso, whose rest the two models share) or on the nearest bone (a loose one) it keeps where it sits
## on the contract model.
func _copy_anchors(glb: Node3D) -> void:
	var to_m := _to_contract(glb)
	var inv := to_m.affine_inverse()
	var k := 1.0 / maxf(to_m.basis.get_scale().y, 0.0001)  # metres -> Meshy's skeleton units
	var have: Dictionary = d.get("anchors", {})
	for a: Array in contract(art_id).get("anchors", []):
		if have.has(a[0]) or skel.find_child(String(a[0]), true, false) != null:
			continue
		var nb := -1
		var local := Transform3D.IDENTITY
		for link: Array in a[1]:  # [contract bone, the anchor in its frame], the anchor's own bone first
			nb = WardenSkeleton.find(skel, String(link[0]))
			if nb >= 0:
				local = link[1]
				local.origin *= k
				break
		if nb < 0:
			nb = _nearest(inv * (a[2] as Transform3D).origin)
		if nb >= 0 and WardenSkeleton.find(skel, String(a[1][0][0])) != nb:  # (on a parent: where it sits on the model)
			local = skel.get_bone_global_rest(nb).affine_inverse() * inv * (a[2] as Transform3D)
		var at := BoneAttachment3D.new()
		at.name = "bone_%s" % a[0]
		at.bone_name = skel.get_bone_name(nb)
		skel.add_child(at)
		var e := Node3D.new()
		e.name = String(a[0])
		e.transform = local
		at.add_child(e)


## The bone whose rest head is nearest `p` (skeleton space).
func _nearest(p: Vector3) -> int:
	var best := 0
	for b in skel.get_bone_count():
		if skel.get_bone_global_rest(b).origin.distance_to(p) < skel.get_bone_global_rest(best).origin.distance_to(p):
			best = b
	return best


## What the native path reads off the art's contract .glb ({sk_m, anchors}, see measure_contract; {} when it has
## none): baked (WardenRest.contracts), else measured once a session.
static func contract(art_name: String) -> Dictionary:
	if not _contracts.has(art_name):
		var baked := WardenRest.contracts()
		_contracts[art_name] = baked[art_name] if baked.has(art_name) else measure_contract(art_name)
	return _contracts[art_name]


## The arts on the native path's data (warden_native.json; WardenRest bakes their anchors).
static func arts() -> Array:
	entry("")
	return (_data as Dictionary).keys().filter(func(k): return typeof(_data[k]) == TYPE_DICTIONARY)


## Reads the art's contract .glb (loads and instances it; {} when there is none): "sk_m" its skeleton -> its model,
## "anchors" its anchor empties: [name, [[contract bone, the anchor in that bone's rest frame (metres)] from its own
## bone up to the root], its model-space rest].
static func measure_contract(art_name: String) -> Dictionary:
	var out: Array = []
	var path := "%s/%s/%s.glb" % [WardenGlb.DIR, art_name, art_name]
	if not ResourceLoader.exists(path):
		return {}
	var con := (load(path) as PackedScene).instantiate() as Node3D
	var csk := WardenGlb.skeleton(con)
	var sk_m := WardenGlb.model_xf(con, csk) if csk else Transform3D.IDENTITY
	for nd in con.find_children("*", "Node3D", true, false) if csk else []:
		var nm := String(nd.name)
		if nd is MeshInstance3D or not (nm.begins_with("anchor_") or nm.begins_with("weapon_muzzle")):
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = nd
		while n is Node3D and not (n is BoneAttachment3D):
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var cb := csk.find_bone((n as BoneAttachment3D).bone_name) if n is BoneAttachment3D else -1
		if cb < 0:
			continue
		var on_sk := csk.get_bone_global_rest(cb) * xf  # (the anchor in the contract skeleton's space)
		var chain: Array = []
		var b := cb
		while b >= 0:
			chain.append([csk.get_bone_name(b), csk.get_bone_global_rest(b).affine_inverse() * on_sk])
			b = csk.get_bone_parent(b)
		out.append([nm, chain, sk_m * on_sk])
	con.free()
	return {"sk_m": sk_m, "anchors": out}
