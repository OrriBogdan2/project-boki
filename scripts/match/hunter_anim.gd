class_name HunterAnim
extends RefCounted
## Procedural animation for a hunter model (Models.hunter). Everything is posed from a few numbers
## each frame, so it works the same in a match, at home, in town and on the title screen.
##
## Layers, blended with eased weights so nothing pops:
##   stance     each class stands its own way: lights springy on the balls of their feet, mediums
##              balanced, heavies wide and planted; knees and elbows always a little bent, weight
##              resting on one leg (contrapposto) and shifting now and then, breathing
##   idle       glances, and fidgets after a while standing still (look around, roll the shoulders,
##              stretch, check or spin the weapon, peek at the kin on your shoulder; a few per race)
##   move       run cycles with arm swing, hips and shoulders turning against each other, a steady
##              head, strafing and backpedalling legs, a lean into starts and turns that overshoots
##              when you stop, feet shuffling round when you turn on the spot
##   air        takeoff kick, tuck at the apex, reaching down to land; a long fall gets a light a
##              flip (front, back or side by direction) and a landing roll, a medium a corkscrew
##              spin, a heavy a cannonball and a ground slam; landings squash by how far you fell
##   moves      class dodges (light phase lunge, medium combat roll, heavy shoulder charge), the
##              glide (with the cloth streaming), skydiving, mantles and ledge pulls, crouching
##   combat     the hands sit on the weapon's grips (elbows solved each frame), weapon aim poses and
##              relaxed carries, recoil per gun, reloads, melee swing arcs per combo step, casting,
##              flinches toward the hit, stun wobble, downed crawl, revive kneel, stomps, the base
##              channel, tonics, and the emote wheel (wave, thumbs up, laugh, point, flag, bow)
##   cloth      skirt, cape, scarf and tail on springs that follow through
##
## update() takes a state dictionary; every key is optional:
##   vel (Vector3) face (yaw) grounded gliding diving rolling dash_dir (Vector2, world) dash_kind
##   ("phase" "roll" "charge" "lunge" "skate"; from the class when left out) crouch (0..1) downed ledge
##   mantle (0..1, -1 when not) reload (0..1, -1) drink (0..1, -1) stomp (0..1, -1) recoil (0..1)
##   flash (0..1) fired (seconds since the last shot) wid (weapon id) swing_n (counts swings)
##   combo (combo step of that swing, -1 for a charged attack) charge (0..1 holding a charge)
##   cast (seconds since an ability went off) cast_slot hit_t (seconds since a hit) hit_dir
##   (Vector2, world, from the attacker) stun reviving base (0..1, -1) emote (id) emote_t (seconds)
##   air_h (height above the ground, enables the long-jump tricks) squash (0..1) stretch
##   kin_on_shoulder
## Out: stepped (a foot came down this frame) slammed (a heavy landing hit the ground) flipping.

const THIGH := 0.2
const SHIN := 0.245
const LEG := THIGH + SHIN
const UPPER := 0.21
const FORE := 0.235
const REACH := UPPER + FORE
const WEAPON_SLACK := 0.02     # m: the trigger hand may sit this far off its grip before the weapon is pulled to it
const BODY_C := Vector3(0, 0.62, 0)      # whole-body turns (flips, rolls) go about the hips
const G_UP := Hunter.H_GRAV                # for guessing how long a jump stays up
const FLIP_MIN := 0.8                     # total airtime that earns a trick
const AIM_Y := 0.5                        # Aim sits this high on the torso
const GROUND_CLEAR := 0.05                # no part of a weapon ever goes nearer the ground than this (m)

## How each class stands and moves.
const STANCE := {
	"light": {"knee": 0.3, "width": 0.07, "lean": 0.12, "bounce": 1.0, "breath": 2.7, "arm": 1.25, "elbow": 0.55},
	"medium": {"knee": 0.17, "width": 0.09, "lean": 0.05, "bounce": 0.0, "breath": 2.2, "arm": 1.0, "elbow": 0.75},
	"heavy": {"knee": 0.24, "width": 0.17, "lean": 0.03, "bounce": 0.0, "breath": 1.7, "arm": 0.8, "elbow": 1.0},
}
## How far the shoulder pieces turn with the arm (the rest is left behind, so a raised arm slides
## under the plate instead of through it).
const PAD_FOLLOW := 0.55

## Where each kind of weapon sits under Aim while aimed (pos), the relaxed carry (low: pitch, yaw),
## and where the hands go on it (gr: the trigger hand, gl: the support hand; Vector3.INF = free).
## Recoil: kick (pitch), push (back), jitter (the gun wobbles in the hand).
const EMPTY_HAND := Vector3(0.09, -0.45, 0.03)     # m from the shoulder: an empty right hand, hanging loose
const HOLDS := {
	"rifle": {"pos": Vector3(0.12, -0.15, -0.3), "low": Vector2(-0.5, 0.38), "gr": Vector3(0, -0.07, 0.04), "gl": Vector3(0, -0.06, -0.2), "kick": 0.12, "push": 0.05, "jitter": 0.2},
	"burst_rifle": {"pos": Vector3(0.12, -0.14, -0.3), "low": Vector2(-0.48, 0.36), "gr": Vector3(0, -0.08, 0.0), "gl": Vector3(0, -0.06, -0.16), "kick": 0.14, "push": 0.05, "jitter": 0.15},
	"smg": {"pos": Vector3(0.12, -0.13, -0.32), "low": Vector2(-0.45, 0.32), "gr": Vector3(0, -0.09, -0.02), "gl": Vector3(0, -0.07, -0.16), "kick": 0.07, "push": 0.03, "jitter": 0.5},
	"sniper": {"pos": Vector3(0.12, -0.12, -0.26), "low": Vector2(-0.55, 0.42), "gr": Vector3(0, -0.06, 0.04), "gl": Vector3(0, -0.05, -0.22), "kick": 0.42, "push": 0.12, "jitter": 0.0},
	"shotgun": {"pos": Vector3(0.12, -0.15, -0.3), "low": Vector2(-0.5, 0.38), "gr": Vector3(0, -0.07, 0.04), "gl": Vector3(0, -0.08, -0.22), "kick": 0.3, "push": 0.1, "jitter": 0.0},
	"minigun": {"pos": Vector3(0.17, -0.28, -0.3), "low": Vector2(-0.22, 0.14), "gr": Vector3(0, -0.15, 0.04), "gl": Vector3(-0.05, 0.11, -0.1), "kick": 0.03, "push": 0.02, "jitter": 1.0},
	"finger": {"pos": Vector3(0.14, -0.02, -0.46), "low": Vector2(-0.35, 0.2), "gr": Vector3(0, 0, 0.0), "gl": Vector3.INF, "kick": 0.3, "push": 0.08, "jitter": 0.0},   # Sparkle: no gun, the arm out, a finger pointed
	"_gun": {"pos": Vector3(0.12, -0.15, -0.3), "low": Vector2(-0.5, 0.36), "gr": Vector3(0, -0.08, 0.02), "gl": Vector3(0, -0.06, -0.18), "kick": 0.15, "push": 0.05, "jitter": 0.2},
	"sword": {"gr": Vector3(0, 0, 0.06), "gl": Vector3.INF},
	"great": {"gr": Vector3(0, 0, 0.02), "gl": Vector3(0, 0, 0.15)},
	"twin": {"gr": Vector3(0.06, 0, -0.02), "gl": Vector3(-0.1, -0.06, -0.08)},
	# nothing held: both hands are free and the kit's moves cast from them (Pip)
	"palm": {
		"pos": Vector3(0.14, -0.25, -0.1), "low": Vector2.ZERO, "gr": Vector3.ZERO, "gl": Vector3.INF,
		"kick": 0.0, "push": 0.0, "jitter": 0.0},
	# a gauntlet on each fist (Tarek): carried like a gun, but it rides the hand wherever a move sends it
	"fist": {
		"pos": Vector3(0.14, -0.2, -0.26), "low": Vector2(-0.35, 0.2), "gr": Vector3(0, -0.02, 0.0), "gl": Vector3.INF,
		"kick": 0.1, "push": 0.05, "jitter": 0.0, "fist": true
	},
}

## Melee swings per combo step: the blade's yaw (left +), pitch (up +) and roll around the swing
## centre, from -> to, the torso's twist from -> to, and which hand swings it.
const SWINGS := {
	"sword": [
		{"a": Vector3(-1.7, 0.15, 1.45), "b": Vector3(1.45, -0.25, 1.45), "tw": Vector2(-0.55, 0.6), "hand": "r"},
		{"a": Vector3(1.35, -0.35, -1.6), "b": Vector3(-1.75, 0.3, -1.6), "tw": Vector2(0.55, -0.6), "hand": "r"},
		{"a": Vector3(0.15, 2.3, 0.0), "b": Vector3(-0.05, -1.05, 0.0), "tw": Vector2(-0.2, 0.15), "hand": "r", "drop": 0.12},
	],
	"great": [
		{"a": Vector3(-1.6, 1.0, 1.2), "b": Vector3(1.3, -0.65, 1.2), "tw": Vector2(-0.6, 0.55), "hand": "b"},
		{"a": Vector3(1.25, -0.75, -1.5), "b": Vector3(-1.6, 0.65, -1.5), "tw": Vector2(0.55, -0.6), "hand": "b"},
		{"a": Vector3(0.0, 2.5, 0.0), "b": Vector3(0.0, -1.2, 0.0), "tw": Vector2(-0.1, 0.1), "hand": "b", "drop": 0.2},
	],
	# Sable's Arc Bolts (by weapon id, over the twin hold's slashes): each blade whipped from cocked out
	# wide and high to straight at the aim, the right, then the left; both at once in a V (the empowered
	# bolt). The torso's turn comes from her kit moves (thf_lmb_r / _l, thf_primed), so no twist here; the
	# ends lean 0.45 against the torso's 0.5 turn into the throw, so the blade points at the aim.
	"arc_bolts": [
		{"a": Vector3(-1.1, 0.45, 0.5), "b": Vector3(0.45, 0.0, 0.0), "tw": Vector2.ZERO, "hand": "r"},
		{"a": Vector3(1.1, 0.45, -0.5), "b": Vector3(-0.45, 0.0, 0.0), "tw": Vector2.ZERO, "hand": "l"},
		{"a": Vector3(-0.9, 0.5, 0.4), "b": Vector3(-0.14, 0.02, 0.0), "tw": Vector2.ZERO, "hand": "x"},
	],
	"twin": [
		{"a": Vector3(-1.4, 0.05, 1.5), "b": Vector3(1.2, -0.25, 1.5), "tw": Vector2(-0.45, 0.5), "hand": "r"},
		{"a": Vector3(1.4, 0.05, -1.5), "b": Vector3(-1.2, -0.25, -1.5), "tw": Vector2(0.45, -0.5), "hand": "l"},
		{"a": Vector3(-1.0, 0.7, 0.9), "b": Vector3(0.9, -0.55, 0.9), "tw": Vector2(-0.1, 0.1), "hand": "x", "drop": 0.1},
	],
}

var model: Node3D
var rig: Node3D
var torso: Node3D
var legs: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var head: Node3D
var aim: Node3D
var gun: Node3D
var mag: Node3D
var spin: Node3D               # a 3D Warden's spinning barrels (WardenGlb.WEAPON_SPIN), turned while firing
var spin_v := 0.0              # their turn rate (rad/s)
const SPIN_MAX := 30.0         # rad/s while firing
const SPIN_EASE := 4.0         # how fast they spin up and wind down (1/s)
var mag_base := Vector3.ZERO
var sentinel := 0             # a part of the weapon in hand (instance id): once it's gone the weapon was swapped
var offhand: Node3D           # twin blades: the reversed dagger, carried by the left hand
var arm_l: Node3D             # shoulder pivots, elbows, hands
var arm_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var sh_l := Vector3.ZERO      # shoulder rest positions on the torso
var sh_r := Vector3.ZERO
var skirt: Node3D
var cape: Node3D
var scarf: Node3D
var tail: Node3D
var wings: Node3D
var pad_l: Node3D              # shoulder pieces (Models.hunter: PauldronL / PauldronR)
var pad_r: Node3D
var focus: Node3D              # the mage's floating orb
var focus_base := Vector3.ZERO
var arch := ""
var flask: Node3D
var flag: Node3D
var gun_scl := 1.0
var gun_pts := PackedVector3Array()      # the weapon's bounds (mesh box corners) in its own space
var off_pts := PackedVector3Array()      # the same for the twin blades' offhand dagger
var floor_y := 0.0                       # the ground under the feet, in the model's space (this frame)
var floor_ok := true                     # false while airborne with no idea where the ground is
var clear_min := INF                     # the lowest a weapon point got above the ground (checks read it)
var clear_raw := INF                     # the same before the safeguard stepped in
var cls := "medium"
var race := "human"
var wid := ""
var hold := "rifle"
var hd: Dictionary = {}        # HOLDS entry
var st: Dictionary = {}        # STANCE entry, with the Warden's gait over it
var ws: WardenStance           # the Warden's signature stance and idle cycle
var snap := false              # rest_pose: jump straight to the targets

var ph := 0.0                  # walk phase, advances with distance travelled
var t := 0.0
var rng := 0                   # a per-character random stream (deterministic, so crowds don't sync)
var seed_ph := 0.0
var stepped := false
var slammed := false
var flipping := false

# eased weights
var run_k := 0.0
var air_k := 0.0
var glide_k := 0.0
var dive_k := 0.0
var crouch_k := 0.0
var down_k := 0.0
var ledge_k := 0.0
var stomp_k := 0.0
var revive_k := 0.0
var act_k := 0.0            # holding interact: the pose for what's being worked (see _act_legs)
var act_kind := ""
var act_t := 0.0
var tool_kind := ""            # the tool in hand or fading out (HunterTool)
var tool_k := 0.0
var tool_ph := 0.0             # where the tool is in its swing, 0..1
var stow_k := 0.0              # the weapon put away for a tool, or holstered at home
var base_k := 0.0
var stun_k := 0.0
var aim_k := 0.0               # 1 aiming (just fired), 0 relaxed carry
var carry_k := 0.0             # running with the weapon in one hand
var gun_vis := 1.0
var emote_k := 0.0
var drink_k := 0.0
var idle_t := 0.0              # how long you've stood still
var back := 1.0

# springs and smoothed signals
var lean_f := 0.0
var lean_fv := 0.0
var lean_s := 0.0
var bank := 0.0
var mf_prev := 0.0
var acc_f := 0.0
var vdir_prev := 0.0
var legs_yaw := 0.0
var face_prev := 0.0
var face_rate := 0.0
var arm_k := 1.0               # the arms' length against the standard (archetype body "arms", Models.hunter)
var lag := 0.0                 # how far the feet are behind the body turning on the spot
var shuffle_t := -1.0
var shuffle_side := 1.0
var weight := 1.0              # contrapposto: which leg holds the weight (-1 left, 1 right)
var weight_to := 1.0
var weight_t := 5.0
var glance_t := 2.0
var glance_to := 0.0
var head_look := 0.0
var fidget := ""
var fidget_t := 0.0
var fidget_dur := 0.0
var fidget_wait := 6.0

# air
var was_grounded := true
var air_t := 0.0
var vy_prev := 0.0
var takeoff_t := 9.0
var trick := ""                # flip_f flip_b flip_l flip_r spin ball
var trick_t := 0.0
var trick_dur := 0.0
var trick_ax := Vector3.RIGHT
var trick_done := false
var land_k := 0.0
var land_rate := 4.0
var roll_t := -1.0             # landing roll / combat roll clock
var roll_dur := 0.35
var roll_ax := Vector3.RIGHT
var slam_k := 0.0

# dodges
var was_rolling := false
var dash_t := 9.0
var dash_kind := ""
const SKATE_LEAN_MAX := 0.4    # radians: the most Claire's skate leans forward, all leans together
var dash_loc := Vector2(0, -1) # dash direction in the model's own frame (x right, y back)
var dash_k := 0.0

# combat
var fired_prev := 99.0
var kick := 0.0
var kick_v := 0.0
var shake_t := 0.0
var pump_t := 9.0
var swing_prev := 0
var swing_t := 9.0
var swing_dur := 0.36
var swing_step := 0
var hit_prev := 99.0
var flinch := Vector2.ZERO
var flinch_v := Vector2.ZERO
var cast_prev := 99.0
var cast_slot := ""
var cast_now := 99.0           # seconds since the last cast (for the arms)
var emote_id := ""
var emote_prev := 99.0
var down_t := 0.0
var down_side := 1.0
var crawl_ph := 0.0

# cloth springs: angle and velocity per axis
var sk_x := 0.0
var sk_xv := 0.0
var sk_z := 0.0
var sk_zv := 0.0
var cp_x := 0.0
var cp_xv := 0.0
var cp_z := 0.0
var cp_zv := 0.0
var sc_x := 0.0
var sc_xv := 0.0
var sc_y := 0.0
var sc_yv := 0.0
var tl_y := 0.0
var tl_yv := 0.0
var tl_x := 0.0
var tl_xv := 0.0
var torso_yaw_prev := 0.0
var hip_y := 0.42              # the torso's rest height on the legs (longer legs set it higher: Models.hunter)

func _init(m: Node3D) -> void:
	model = m
	hip_y = float(m.get_meta("hip_y", hip_y))
	rig = m.get_node("Rig")
	torso = rig.get_node("Torso")
	legs = rig.get_node("Legs")
	leg_l = legs.get_node("LegL")
	leg_r = legs.get_node("LegR")
	knee_l = leg_l.get_node_or_null("Knee")
	knee_r = leg_r.get_node_or_null("Knee")
	head = torso.get_node_or_null("HeadPivot")
	aim = torso.get_node_or_null("Aim")
	arm_k = float(m.get_meta("arm_k", 1.0))
	arm_l = torso.get_node_or_null("ArmLPivot")
	arm_r = torso.get_node_or_null("ArmRPivot")
	if arm_l:
		el_l = arm_l.get_node("Elbow"); hand_l = el_l.get_node("Hand"); sh_l = arm_l.position
	if arm_r:
		el_r = arm_r.get_node("Elbow"); hand_r = el_r.get_node("Hand"); sh_r = arm_r.position
	skirt = torso.get_node_or_null("Skirt")
	cape = torso.get_node_or_null("Cape")
	scarf = torso.get_node_or_null("Scarf")
	tail = torso.get_node_or_null("Tail")
	wings = torso.get_node_or_null("Wings")
	pad_l = torso.get_node_or_null("PauldronL")
	pad_r = torso.get_node_or_null("PauldronR")
	focus = torso.get_node_or_null("Focus")
	if focus: focus_base = focus.position
	cls = String(m.get_meta("cls", "medium"))
	race = String(m.get_meta("race", "human"))
	arch = String(m.get_meta("arch", ""))
	st = (STANCE.get(cls, STANCE["medium"]) as Dictionary).duplicate()
	var stance := String(m.get_meta("stance", arch))      # the Empty's own stance by sex (Unmasked)
	st.merge(WardenStance.gait(stance), true)
	ws = WardenStance.new(stance)
	rng = int(m.get_meta("anim_seed", m.get_instance_id())) & 0x7fffffff
	seed_ph = _rand() * TAU
	weight = 1.0 if _rand() < 0.5 else -1.0
	weight_to = weight
	weight_t = 3.0 + _rand() * 6.0
	glance_t = 1.0 + _rand() * 3.0
	fidget_wait = 3.5 + _rand() * 5.0
	face_prev = m.rotation.y
	if aim:
		gun = aim.get_node_or_null("Gun")
	_setup_weapon(String(m.get_meta("wid", "")))

## The arms on the weapon in a relaxed carry, for a model nothing animates (galleries, portraits).
static func rest_pose(m: Node3D) -> void:
	if not m.has_node("Rig/Torso/ArmLPivot"):
		return
	var a := HunterAnim.new(m)
	a.snap = true
	a.update(1.0 / 60.0, {"fired": 99.0})

## A small deterministic random stream per character.
func _rand() -> float:
	rng = (rng * 1103515245 + 12345) & 0x7fffffff
	return float(rng % 10000) / 10000.0

func _ease(cur: float, want: float, rate: float, dt: float) -> float:
	if snap:
		return want
	return lerpf(cur, want, 1.0 - exp(-rate * dt))

## Works out how the current weapon is held (and gives the twin blades' second dagger to the left hand).
func _setup_weapon(w: String) -> void:
	wid = w
	match w:
		"longsword": hold = "sword"
		"greatsword": hold = "great"
		"twin_blades", "arc_bolts": hold = "twin"
		"coilcaster": hold = "finger"
		"tower_shield": hold = "sword"
		"lantern_crook": hold = "palm"
		"rubble_fists": hold = "fist"
		_: hold = w if HOLDS.has(w) else "_gun"
	hd = HOLDS[hold]
	mag = null
	sentinel = 0
	if offhand and is_instance_valid(offhand):
		offhand.queue_free()
	offhand = null
	if gun == null:
		return
	gun_scl = gun.scale.x
	var held := gun.get_node_or_null(WardenGlb.WEAPON)
	if held and held.has_meta(WardenGlb.GRIP_L) and not held.is_queued_for_deletion():
		hd = hd.duplicate()
		hd["gl"] = held.get_meta(WardenGlb.GRIP_L)
	spin = gun.find_child(WardenGlb.WEAPON_SPIN, true, false) as Node3D
	for ch in gun.get_children():
		if ch.name == "Mag":
			mag = ch; mag_base = mag.position
		elif sentinel == 0 and ch.name != "Muzzle" and not ch.is_queued_for_deletion():
			sentinel = ch.get_instance_id()
	if hold == "fist" and aim:
		offhand = gun.duplicate()      # the second gauntlet, on the left fist
		offhand.name = "Offhand"
		aim.add_child(offhand)
	if hold == "twin" and aim:
		offhand = Node3D.new(); offhand.name = "Offhand"
		aim.add_child(offhand)
		for ch in gun.get_children():
			if ch is MeshInstance3D and (ch as Node3D).position.x < -0.04 and not ch.is_queued_for_deletion():
				var mi := ch as Node3D
				var xf := mi.transform
				gun.remove_child(mi)
				offhand.add_child(mi)
				mi.transform = Transform3D(Basis.IDENTITY, Vector3(0.1, 0.06, 0.08)) * xf     # the hilt at the offhand's origin
		offhand.scale = Vector3.ONE * gun_scl
	gun_pts = _mesh_pts(gun)
	off_pts = _mesh_pts(offhand) if offhand else PackedVector3Array()

## The corners of every mesh's box under n, in n's own space (what has to stay above the ground).
static func _mesh_pts(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	_collect_pts(n, Transform3D.IDENTITY, out)
	return out

static func _collect_pts(n: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	for ch in n.get_children():
		if not (ch is Node3D) or ch.is_queued_for_deletion():
			continue
		var cx := xf * (ch as Node3D).transform
		# (a procedural weapon a Warden's .glb replaced doesn't count: WardenGlb hid it for good)
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh and not ch.has_meta("glb_hidden"):
			var bb := (ch as MeshInstance3D).mesh.get_aabb()
			for i in 8:
				out.append(cx * bb.get_endpoint(i))
		_collect_pts(ch, cx, out)

## n's transform in the model's own space (the model's feet are at y 0 there).
func _to_model(n: Node) -> Transform3D:
	var x := Transform3D.IDENTITY
	while n != null and n != model:
		x = (n as Node3D).transform * x
		n = n.get_parent()
	return x

## Keeps every point of a held weapon above the ground: a blade that would dip into it is tipped up
## about the grip (the hand stays where it is), and only if the grip itself is down there does the
## whole thing lift. Works in the model's space, so flips, squashes, leans and crouches all count.
func _keep_above_ground(node: Node3D, pts: PackedVector3Array) -> void:
	if node == null or pts.is_empty() or not node.visible or not floor_ok:
		return
	var par := _to_model(node.get_parent())
	var g := par * node.transform
	var fy := floor_y + GROUND_CLEAR / maxf(0.01, absf(model.scale.y))
	var moved := false
	for it in 5:
		var low := INF
		var lp := Vector3.ZERO
		for p in pts:
			var q := g * p
			if q.y < low:
				low = q.y; lp = q
		if it == 0:
			clear_raw = minf(clear_raw, (low - floor_y) * absf(model.scale.y))
		if low >= fy - 0.002:
			clear_min = minf(clear_min, (low - floor_y) * absf(model.scale.y))
			break
		moved = true
		var o := g.origin
		if o.y < fy + 0.03:
			# the grip's down at the ground: lift the weapon
			g.origin.y += fy - low + 0.004
			continue
		var v := lp - o
		var ax := v.cross(Vector3.UP)
		if ax.length_squared() < 1e-8:
			ax = g.basis.x
		ax = ax.normalized()
		if v.rotated(ax, 0.3).y < v.y:
			ax = -ax
		var want := fy + 0.004 - o.y
		var lo := 0.0
		var hi := PI * 0.5
		for k in 12:
			var mid := (lo + hi) * 0.5
			if v.rotated(ax, mid).y >= want: hi = mid
			else: lo = mid
		g = Transform3D(Basis(ax, hi) * g.basis, o)
	if moved:
		# tipping it couldn't do it alone (both ends down, say, mid-roll): lift what's left
		var lo2 := INF
		for p in pts:
			lo2 = minf(lo2, (g * p).y)
		if lo2 < fy:
			g.origin.y += fy - lo2 + 0.002
		node.transform = par.affine_inverse() * g
		var fl := INF
		for p in pts:
			fl = minf(fl, (g * p).y)
		clear_min = minf(clear_min, (fl - floor_y) * absf(model.scale.y))

func _check_weapon(s: Dictionary) -> void:
	var w := String(s.get("wid", wid))
	if w != wid:
		_setup_weapon(w)
	elif sentinel != 0:
		var o := instance_from_id(sentinel)
		if o == null or (o as Node).is_queued_for_deletion():
			_setup_weapon(w)

## A damped spring, stepped in small slices so a slow frame can't blow it up. Returns [x, v].
static func _spring(x: float, v: float, want: float, k: float, damp: float, dt: float) -> Vector2:
	var left := minf(dt, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 90.0)
		left -= h
		v += ((want - x) * k - v * damp) * h
		x += v * h
	return Vector2(x, v)

## How long a jump still has before it lands, from the vertical speed and the height above the ground.
static func _time_left(vy: float, h: float) -> float:
	var up := maxf(vy, 0.0)
	var peak := h + up * up / (2.0 * G_UP)
	return up / G_UP + peak / 7.5 + 0.08

## Ease-in-out for spins: slow start, fast middle, a soft finish.
static func _spin_e(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return p - sin(p * TAU) / TAU

func update(dt: float, s: Dictionary) -> void:
	model.set_meta(WardenClips.STATE, s)     # (a Hero's hand-keyed clips read the same state)
	if dt <= 0.0:
		return
	t += dt
	stepped = false
	slammed = false
	_check_weapon(s)
	_update_km(String(s.get("kmove", "")), float(s.get("kmove_t", 99.0)), dt)
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var face: float = s.get("face", model.rotation.y)
	var grounded: bool = s.get("grounded", true)
	var gliding: bool = s.get("gliding", false)
	var diving: bool = s.get("diving", false)
	var rolling: bool = s.get("rolling", false)
	var downed: bool = s.get("downed", false)
	var stun: bool = s.get("stun", false)
	var fired: float = s.get("fired", 99.0)
	var hv := Vector2(vel.x, vel.z)
	var spd := hv.length()
	# where the ground is, for keeping the weapon out of it (unknown in the air without air_h)
	floor_ok = grounded or s.has("air_h") or downed
	floor_y = 0.0 if grounded or not s.has("air_h") else -float(s["air_h"]) / maxf(0.01, absf(model.scale.y))
	var fwd := Vector2(-sin(face), -cos(face))
	var right := Vector2(cos(face), -sin(face))
	var mf := hv.dot(fwd)
	var ms := hv.dot(right)
	var kd := 1.0 if snap else 1.0 - exp(-10.0 * dt)
	# ---------------------------------------------------------------- weights
	var moving := grounded and spd > 0.4 and not downed
	run_k = _ease(run_k, clampf(spd / 5.5, 0.0, 1.35) if moving else 0.0, 9.0, dt)
	var r1 := minf(run_k, 1.0)
	air_k = _ease(air_k, 0.0 if grounded or gliding or diving else 1.0, 14.0, dt)
	glide_k = _ease(glide_k, 1.0 if gliding and not diving else 0.0, 7.0, dt)
	dive_k = _ease(dive_k, 1.0 if diving else 0.0, 6.0, dt)
	crouch_k = _ease(crouch_k, float(s.get("crouch", 0.0)), 12.0, dt)
	down_k = _ease(down_k, 1.0 if downed else 0.0, 6.0 if downed else 4.0, dt)
	var ledge: bool = s.get("ledge", false)
	var mant := float(s.get("mantle", -1.0))
	ledge_k = _ease(ledge_k, 1.0 if ledge or mant >= 0.0 else 0.0, 14.0, dt)
	var st_ph := float(s.get("stomp", -1.0))
	stomp_k = _ease(stomp_k, 1.0 if st_ph >= 0.0 else 0.0, 16.0, dt)
	revive_k = _ease(revive_k, 1.0 if s.get("reviving", false) and grounded and spd < 1.5 else 0.0, 8.0, dt)
	HunterTool.tick(self, dt, s)
	_act_tick(dt, s, grounded, spd)
	var base_p := float(s.get("base", -1.0))
	base_k = _ease(base_k, 1.0 if base_p >= 0.0 else 0.0, 6.0, dt)
	stun_k = _ease(stun_k, 1.0 if stun and not downed else 0.0, 8.0, dt)
	var still := (1.0 - r1) * (1.0 - air_k) * (1.0 - glide_k) * (1.0 - down_k)
	if s.get("statue", false):
		still = 0.0       # a statue (Rimelock): no sway, breath, glance or fidget
	if moving or not grounded or fired < 1.0 or rolling or downed:
		idle_t = 0.0
	else:
		idle_t += dt
	ws.tick(dt, self, s)
	# ---------------------------------------------------------------- signals
	var vy := vel.y
	acc_f = lerpf(acc_f, (mf - mf_prev) / dt, 1.0 - exp(-12.0 * dt))
	mf_prev = mf
	var lv := Vector2(clampf(mf / 32.0, -0.12, 0.2) + clampf(acc_f * 0.01, -0.2, 0.2) * (1.0 if grounded else 0.3), clampf(ms / 24.0, -0.16, 0.16))
	if snap:
		lean_f = lv.x; lean_s = lv.y
	else:
		var sp := _spring(lean_f, lean_fv, lv.x, 160.0, 11.0, dt)     # underdamped: an overshoot when you stop
		lean_f = sp.x; lean_fv = sp.y
		lean_s = _ease(lean_s, lv.y, 8.0, dt)
	# banking into turns: how fast the direction of travel swings round
	var vdir := atan2(hv.x, hv.y)
	var turn := wrapf(vdir - vdir_prev, -PI, PI) / dt if spd > 1.5 else 0.0
	vdir_prev = vdir
	bank = _ease(bank, clampf(turn * spd * 0.012, -0.3, 0.3) * r1, 6.0, dt)
	face_rate = lerpf(face_rate, wrapf(face - face_prev, -PI, PI) / dt, 1.0 - exp(-14.0 * dt))
	var dface := wrapf(face - face_prev, -PI, PI)
	face_prev = face
	# ---------------------------------------------------------------- landing, air time, tricks
	var just_landed := grounded and not was_grounded
	if just_landed:
		var fall_v := -vy_prev
		var hard := clampf(fall_v / 14.0 + air_t * 0.35, 0.0, 1.2)
		land_k = clampf(maxf(land_k, hard), 0.0, 1.0) if fall_v > 2.5 or air_t > 0.45 else land_k
		land_rate = lerpf(5.0, 2.2, clampf(hard, 0.0, 1.0)) * (0.8 if cls == "heavy" else (1.25 if cls == "light" else 1.0))
		if trick == "ball" or (cls == "heavy" and (fall_v > 8.5 or air_t > 0.85)):
			slam_k = 1.0
			slammed = true
			land_k = 1.0
		elif trick.begins_with("flip") and spd > 2.5 and cls == "light":
			# out of a flip with speed: tuck and roll on through
			roll_t = 0.0; roll_dur = 0.42
			var dl := Vector2(ms, -mf).normalized()
			roll_ax = Vector3.UP.cross(Vector3(dl.x, 0, dl.y)).normalized()
			land_k = 0.35
		trick = ""
		flipping = false
	if grounded:
		air_t = 0.0
		trick_done = false
	else:
		air_t += dt
		if was_grounded and vy > 2.0:
			takeoff_t = 0.0
	takeoff_t += dt
	was_grounded = grounded
	vy_prev = vy
	land_k = maxf(0.0, land_k - dt * land_rate)
	slam_k = maxf(0.0, slam_k - dt * 1.8)
	# a long enough jump (we know the height left from air_h) gets the class's trick
	if not grounded and trick == "" and not trick_done and not gliding and not diving and not rolling and not downed and air_t > 0.06 and s.has("air_h"):
		var left := _time_left(vy, float(s["air_h"]))
		if air_t + left >= FLIP_MIN and left > 0.42:
			trick_done = true
			trick_t = 0.0
			trick_dur = clampf(left - 0.08, 0.45, 0.78)
			match cls:
				"light":
					if absf(ms) > absf(mf) * 1.2 and absf(ms) > 1.5:
						trick = "flip_r" if ms > 0.0 else "flip_l"
						trick_ax = Vector3.FORWARD if ms > 0.0 else Vector3.BACK     # top tips toward the strafe
					elif mf < -1.5:
						trick = "flip_b"; trick_ax = Vector3.RIGHT
					else:
						trick = "flip_f"; trick_ax = Vector3.LEFT
				"heavy":
					trick = "ball"; trick_dur = left
				_:
					trick = "spin"; trick_dur = clampf(left - 0.1, 0.45, 0.7)
	if trick != "":
		trick_t += dt
		if (gliding or rolling or downed) or (trick != "ball" and trick_t > trick_dur + 0.05):
			trick = "" if trick != "ball" or gliding or downed else trick
	flipping = trick.begins_with("flip")
	# ---------------------------------------------------------------- dodges
	if rolling and not was_rolling:
		dash_t = 0.0
		dash_kind = String(s.get("dash_kind", {"light": "phase", "medium": "roll", "heavy": "charge"}.get(cls, "roll")))
		var dd: Vector2 = s.get("dash_dir", fwd)
		if dd.length() < 0.1: dd = fwd
		dd = dd.normalized()
		dash_loc = Vector2(dd.dot(right), -dd.dot(fwd))
		if dash_kind == "roll":
			roll_t = 0.0
			roll_dur = 0.36
			roll_ax = Vector3.UP.cross(Vector3(dash_loc.x, 0, dash_loc.y)).normalized()
	was_rolling = rolling
	dash_t += dt
	dash_k = _ease(dash_k, 1.0 if rolling and dash_kind != "roll" else 0.0, 22.0 if rolling else 9.0, dt)
	# a 3D model's wings fold back while she skates and flare on a kit move's "wg" (WardenGlb.Springs,
	# the root's WING_FOLD meta)
	var flare := float(km.get("wg", 0.0))
	if dash_kind == "skate" or flare > 0.0 or model.has_meta(WardenGlb.WING_FOLD):
		model.set_meta(WardenGlb.WING_FOLD, dash_k if dash_kind == "skate" else -flare)
	var roll_k := 0.0
	var roll_ang := 0.0
	if roll_t >= 0.0:
		roll_t += dt
		var rp := roll_t / roll_dur
		if rp >= 1.0:
			roll_t = -1.0
		else:
			roll_ang = TAU * _spin_e(rp)
			roll_k = sin(clampf(rp, 0.0, 1.0) * PI)
			roll_k = minf(1.0, roll_k * 2.0)
	# ---------------------------------------------------------------- the walk phase and footsteps
	var ph0 := ph
	if moving:
		ph += dt * spd * float(STRIDE.get(arch, 2.15 if cls != "heavy" else 1.95)) * float(st.get("cadence", 1.0))
		if int(floor(ph / PI)) != int(floor(ph0 / PI)) and KMovesStone.gait(arch) > 0.5:
			stepped = true
	# strafing and backpedalling: the legs turn toward where you're going; backwards they swing the other way
	var want_yaw := 0.0
	if spd > 0.6 and (grounded or rolling):
		var rel := atan2(ms, mf)
		if absf(rel) > PI * 0.62:
			back = _ease(back, -1.0, 12.0, dt)
			rel = rel - PI * signf(rel)
		else:
			back = _ease(back, 1.0, 12.0, dt)
		want_yaw = -clampf(rel, -1.15, 1.15)
	# turning on the spot: the feet stay put until the body has turned far enough, then shuffle round
	if still > 0.5 and grounded and not downed:
		lag = clampf(lag - dface, -1.4, 1.4)
		if shuffle_t < 0.0 and absf(lag) > 0.6:
			shuffle_t = 0.0
			shuffle_side = signf(lag)
	else:
		lag = _ease(lag, 0.0, 10.0, dt)
	var shuffle_lift := 0.0
	if shuffle_t >= 0.0:
		shuffle_t += dt
		var sp2 := shuffle_t / 0.3
		lag = lerpf(lag, 0.0, minf(1.0, dt * 14.0))
		shuffle_lift = sin(clampf(sp2, 0.0, 1.0) * PI)
		if sp2 >= 1.0:
			shuffle_t = -1.0
			if absf(lag) > 0.3:
				shuffle_t = 0.0     # still behind: another step
				shuffle_side = -shuffle_side
	legs_yaw = lerp_angle(legs_yaw, want_yaw, kd)
	# ---------------------------------------------------------------- contrapposto and fidgets
	weight_t -= dt
	if weight_t <= 0.0:
		weight_t = 4.0 + _rand() * 7.0
		weight_to = -weight_to if _rand() < 0.75 else weight_to
	weight_to = ws.weight_side(weight_to)
	weight = _ease(weight, weight_to, 1.6, dt)
	var wk := weight * still * (1.0 - crouch_k) * (1.0 - revive_k) * (1.0 - stomp_k)
	_tick_fidget(dt, still, s)
	# ================================================================ LEGS
	var knee0: float = st["knee"]
	var width: float = st["width"]
	var phl := ph
	var phr := ph + PI
	var stride := float(st.get("stride", 0.62)) + 0.28 * minf(run_k, 1.3)
	var r_leg := r1 * KMovesStone.gait(arch)      # how much the legs walk (a hoverer's barely do)
	var hl := sin(phl) * stride * r_leg * back
	var hr := sin(phr) * stride * r_leg * back
	# the knee folds most while the leg swings through, a little at foot strike
	var sw_l := maxf(0.0, cos(phl - 0.35 * back))
	var sw_r := maxf(0.0, cos(phr - 0.35 * back))
	var kl := -(knee0 * 0.6 + (0.25 + 1.05 * minf(run_k, 1.3)) * pow(sw_l, 1.3) + 0.18 * maxf(0.0, -sin(phl)) ) * r_leg
	var kr := -(knee0 * 0.6 + (0.25 + 1.05 * minf(run_k, 1.3)) * pow(sw_r, 1.3) + 0.18 * maxf(0.0, -sin(phr)) ) * r_leg
	# standing: knees soft, the free leg bent and turned out, the weight leg straighter
	var idle_w := 1.0 - r1
	var free_l := clampf(wk, 0.0, 1.0)       # the left leg is the free one when the weight is on the right
	var free_r := clampf(-wk, 0.0, 1.0)
	var bounce := float(st["bounce"]) * sin(t * 4.6 + seed_ph) * still
	hl += idle_w * (knee0 * 0.5 + free_l * 0.2 + bounce * 0.03)
	hr += idle_w * (knee0 * 0.5 + free_r * 0.2 + bounce * 0.03)
	kl -= idle_w * (knee0 + free_l * 0.3 + bounce * 0.06)
	kr -= idle_w * (knee0 + free_r * 0.3 + bounce * 0.06)
	var wl := -width * (1.0 - 0.4 * r1) - free_l * 0.04
	var wr := width * (1.0 - 0.4 * r1) + free_r * 0.04
	# shuffling round on the spot
	if shuffle_lift > 0.0:
		if shuffle_side > 0.0:
			hl += shuffle_lift * 0.35; kl -= shuffle_lift * 0.7
		else:
			hr += shuffle_lift * 0.35; kr -= shuffle_lift * 0.7
	# crouch, landing, slam: knees bend, hips drop
	var bend := maxf(crouch_k * 0.75, land_k * 0.85) + slam_k * 0.5
	hl += bend * 0.62; hr += bend * 0.5
	kl -= bend * 1.2; kr -= bend * 1.05
	if slam_k > 0.0:
		# a heavy landing: one knee nearly to the ground
		hr -= slam_k * 0.5; kr -= slam_k * 0.7
	# in the air: a kick off the ground, a tuck up top, reaching down to land
	var rising := clampf(vy / 8.0, -1.0, 1.0)
	var kick_off := clampf(1.0 - takeoff_t / 0.14, 0.0, 1.0)
	var apex := 1.0 - absf(rising)
	var air_hl := lerpf(0.25, 0.95, maxf(rising, 0.0)) + apex * 0.2
	var air_kl := lerpf(-0.35, -1.45, maxf(rising, 0.0)) - apex * 0.3
	var air_hr := lerpf(-0.1, 0.35, maxf(rising, 0.0)) + apex * 0.15
	var air_kr := lerpf(-0.2, -0.8, maxf(rising, 0.0)) - apex * 0.2
	air_hl = lerpf(air_hl, -0.25, kick_off); air_kl = lerpf(air_kl, -0.1, kick_off)
	air_hr = lerpf(air_hr, -0.45, kick_off); air_kr = lerpf(air_kr, -0.2, kick_off)
	var ak := air_k * (1.0 - glide_k) * (1.0 - dive_k)
	hl = lerpf(hl, air_hl, ak); kl = lerpf(kl, air_kl, ak)
	hr = lerpf(hr, air_hr, ak); kr = lerpf(kr, air_kr, ak)
	# tricks tuck up tight
	var tuck := 0.0
	var trick_p := clampf(trick_t / maxf(trick_dur, 0.01), 0.0, 1.0)
	if trick != "":
		tuck = minf(1.0, sin(trick_p * PI) * 1.8) if trick != "ball" else minf(1.0, trick_t * 6.0)
		if trick == "spin": tuck *= 0.55
	hl = lerpf(hl, 1.7, tuck); kl = lerpf(kl, -2.2, tuck)
	hr = lerpf(hr, 1.55 if trick != "spin" else 0.4, tuck); kr = lerpf(kr, -2.1 if trick != "spin" else -0.9, tuck)
	wl = lerpf(wl, -0.12, tuck); wr = lerpf(wr, 0.12, tuck)
	# rolls: tucked up
	hl = lerpf(hl, 1.6, roll_k); kl = lerpf(kl, -2.1, roll_k)
	hr = lerpf(hr, 1.4, roll_k); kr = lerpf(kr, -2.0, roll_k)
	# gliding: legs dangle and paddle a little
	hl = lerpf(hl, 0.35 + sin(t * 3.2 + seed_ph) * 0.12, glide_k); kl = lerpf(kl, -0.5 + sin(t * 3.2 + 1.0 + seed_ph) * 0.15, glide_k)
	hr = lerpf(hr, 0.6 - sin(t * 3.2 + seed_ph) * 0.12, glide_k); kr = lerpf(kr, -0.7 - sin(t * 3.2 + 1.0 + seed_ph) * 0.15, glide_k)
	# skydiving: legs bent back and spread
	hl = lerpf(hl, -0.15, dive_k); kl = lerpf(kl, -1.1, dive_k); wl = lerpf(wl, -0.3, dive_k)
	hr = lerpf(hr, -0.15, dive_k); kr = lerpf(kr, -1.1, dive_k); wr = lerpf(wr, 0.3, dive_k)
	# dodges
	if dash_k > 0.01:
		var dhl := 0.0; var dkl := 0.0; var dhr := 0.0; var dkr := 0.0
		match dash_kind:
			"phase", "rush":     # a long low lunge: lead leg forward, trailing leg stretched back
				dhl = 1.0; dkl = -1.1; dhr = -0.75; dkr = -0.35
			"charge":            # driving forward hard
				var cp := t * 16.0
				dhl = sin(cp) * 0.8 + 0.3; dkl = -0.4 - maxf(0.0, cos(cp)) * 1.2
				dhr = -sin(cp) * 0.8 + 0.3; dkr = -0.4 - maxf(0.0, -cos(cp)) * 1.2
			"lunge":
				dhl = 1.05; dkl = -0.8; dhr = -0.6; dkr = -0.25
		hl = lerpf(hl, dhl, dash_k); kl = lerpf(kl, dkl, dash_k)
		hr = lerpf(hr, dhr, dash_k); kr = lerpf(kr, dkr, dash_k)
	# a kit move's legs
	if not km.is_empty() and km.has("legs") and float(km["lw"]) > 0.0:
		var kl4: Array = km["legs"]
		var lw := clampf(float(km["lw"]), 0.0, 1.0) * stance_leg_k(km_stance, run_k)
		hl = lerpf(hl, kl4[0], lw); kl = lerpf(kl, kl4[1], lw)
		hr = lerpf(hr, kl4[2], lw); kr = lerpf(kr, kl4[3], lw)
	# pulling up a ledge or vaulting: one knee comes up onto it
	var mk := clampf(mant, 0.0, 1.0)
	var ledge_up := 1.0 if mant < 0.0 else clampf(mk * 1.6, 0.0, 1.0)
	hl = lerpf(hl, lerpf(0.4, 1.3, ledge_up), ledge_k); kl = lerpf(kl, lerpf(-0.5, -1.7, ledge_up), ledge_k)
	hr = lerpf(hr, lerpf(0.1, 0.5, ledge_up), ledge_k); kr = lerpf(kr, lerpf(-0.3, -0.9, ledge_up), ledge_k)
	# stomping a wisp: the right foot lifts high, then slams down, over and over
	if stomp_k > 0.01:
		var up := sin(clampf(st_ph, 0.0, 1.0) / 0.7 * PI) if st_ph < 0.7 else 0.0
		hr = lerpf(hr, 1.35 * up - 0.05, stomp_k); kr = lerpf(kr, -1.6 * up - 0.1, stomp_k)
		hl = lerpf(hl, 0.2, stomp_k); kl = lerpf(kl, -0.4, stomp_k)
	# reviving: down on one knee beside them
	if revive_k > 0.01:
		hl = lerpf(hl, 1.35, revive_k); kl = lerpf(kl, -1.45, revive_k)
		hr = lerpf(hr, -0.15, revive_k); kr = lerpf(kr, -1.9, revive_k)
	# holding interact: kneel, squat, brace or stand to it (see _act_legs)
	if act_k > 0.01:
		var al := _act_legs()
		hl = lerpf(hl, al.x, act_k); kl = lerpf(kl, al.y, act_k)
		hr = lerpf(hr, al.z, act_k); kr = lerpf(kr, al.w, act_k)
	# downed: lying face down; crawling kicks the legs, otherwise they lie limp
	if down_k > 0.01:
		var crawl := clampf(spd / 2.0, 0.0, 1.0)
		crawl_ph += dt * (2.0 + spd * 2.5) * (1.0 if crawl > 0.1 else 0.15)
		var c1 := sin(crawl_ph)
		hl = lerpf(hl, 0.1 + c1 * 0.35 * crawl, down_k); kl = lerpf(kl, -0.35 - maxf(0.0, c1) * 0.9 * crawl, down_k)
		hr = lerpf(hr, -0.05 - c1 * 0.35 * crawl, down_k); kr = lerpf(kr, -0.15 - maxf(0.0, -c1) * 0.9 * crawl, down_k)
	# stunned: wobbly knees
	if stun_k > 0.01:
		var wob := sin(t * 7.0 + seed_ph)
		hl += stun_k * (0.25 + wob * 0.1); kl -= stun_k * (0.5 + wob * 0.15)
		hr += stun_k * (0.2 - wob * 0.1); kr -= stun_k * (0.45 - wob * 0.15)
	# melee steps and casts shift the weight forward onto the lead leg
	var sw_k := _swing_k()
	if sw_k > 0.0:
		hl += sw_k * 0.32 * idle_w; kl -= sw_k * 0.3 * idle_w
		hr -= sw_k * 0.22 * idle_w; kr -= sw_k * 0.12 * idle_w
	# the Warden's stance: the knees, the free leg, the feet apart
	hl += ws.hip_l.x
	kl += ws.hip_l.y
	hr += ws.hip_r.x
	kr += ws.hip_r.y
	wl -= ws.spread
	wr += ws.spread
	# ================================================================ BODY
	var breath := sin(t * float(st["breath"]) + seed_ph)
	var pitch := -float(st["lean"]) * (1.0 - down_k) - lean_f - r1 * 0.06 - crouch_k * 0.3 - land_k * 0.32 - slam_k * 0.35
	pitch += rising * 0.1 * ak - glide_k * 0.18 - ledge_k * lerpf(0.4, 0.15, ledge_up) - stomp_k * 0.12 - revive_k * 0.35
	pitch -= tuck * (0.7 if trick != "spin" else 0.3) + roll_k * 0.6
	pitch -= act_k * _act_pitch()
	var yaw := -sin(ph) * 0.16 * r1 * back          # the shoulders swing against the hips
	var roll := -lean_s * (1.0 + glide_k * 0.6) - bank * 0.8 + wk * 0.05
	var dz := 0.0
	if arch == "thief":
		pitch -= r1 * 0.35           # runs low and pitched far forward, chest over the lead foot
	elif arch == "juggernaut":
		pitch -= r1 * 0.25           # hunched, chest well forward over the knees
		roll += sin(ph) * 0.06 * r1  # the shoulders roll over each heavy step
	elif arch == "archer":
		pitch += r1 * 0.04           # runs tall, eyes up
	elif arch == "mage":
		pitch += r1 * 0.05 + still * sin(t * 0.9 + seed_ph) * 0.02    # glides upright; a slow sway standing
	elif arch == "bulwark":
		yaw *= 0.5                   # the shoulders stay square, a moving wall...
		pitch -= r1 * 0.32 * (1.0 - dash_k)      # ...pitched far forward at a run (a dash leans by itself),
		yaw += r1 * 0.3 * (1.0 - dash_k)         # the shield shoulder leading
	# dodge poses
	if dash_k > 0.01:
		match dash_kind:
			"phase", "rush":
				pitch = lerpf(pitch, -0.6, dash_k); roll = lerpf(roll, -dash_loc.x * 0.35, dash_k)
			"charge":
				pitch = lerpf(pitch, -0.45, dash_k); yaw = lerpf(yaw, -0.7, dash_k)
			"lunge":
				pitch = lerpf(pitch, -0.35, dash_k); yaw = lerpf(yaw, 0.35, dash_k)
	# skydive: chest down (the rig tips), back arched, head up
	pitch = lerpf(pitch, 0.3, dive_k)
	# stomp: arms out for balance; downed: lift the chest a little to look ahead
	pitch = lerpf(pitch, 0.25, down_k)
	# stun: the upper body sways in circles
	if stun_k > 0.01:
		pitch += stun_k * (sin(t * 3.1) * 0.12 - 0.12)
		roll += stun_k * cos(t * 3.1) * 0.14
	# a hit: the body jerks away from it
	var hit_t := float(s.get("hit_t", 99.0))
	if hit_t < hit_prev - 0.02 or (hit_t < 0.05 and hit_prev > 0.2):
		var hd2: Vector2 = s.get("hit_dir", -fwd)
		if hd2.length() < 0.01: hd2 = -fwd
		hd2 = hd2.normalized()
		var lx := hd2.dot(right); var lz := -hd2.dot(fwd)
		flinch_v += Vector2(lz, -lx) * 9.0 * float(s.get("hit_k", 1.0))       # pitched back when hit from the front, tipped sideways from the side (harder hits, bigger jerk: Oomph)
	hit_prev = hit_t
	var fx := _spring(flinch.x, flinch_v.x, 0.0, 260.0, 16.0, dt)
	var fy := _spring(flinch.y, flinch_v.y, 0.0, 260.0, 16.0, dt)
	flinch = Vector2(fx.x, fy.x); flinch_v = Vector2(fx.y, fy.y)
	pitch += flinch.x * 0.16
	roll += flinch.y * 0.16
	# melee: the body turns through the swing
	_swing_pose()
	yaw += sw_tw
	pitch -= sw_k * 0.15
	# a kit move's body
	if not km.is_empty():
		pitch += float(km["p"]); yaw += float(km["y"]); roll += float(km["r"])
	# casting: a lean into it
	var cast_t := float(s.get("cast", 99.0))
	if cast_t < cast_prev - 0.02 or (cast_t < 0.05 and cast_prev > 0.3):
		cast_slot = String(s.get("cast_slot", ""))
		# some casts are swings of the weapon: the juggernaut's Earthshatter is the overhead slam, the
		# thief's mark-out a spin with both blades out
		if (arch == "juggernaut" and cast_slot == "utility" and hold == "great") or (arch == "thief" and cast_slot == "ult" and hold == "twin"):
			swing_t = 0.0; swing_step = -1; swing_dur = 0.55
	cast_prev = cast_t
	var cast_k := 0.0
	cast_now = cast_t
	if cast_t < 0.6 and km.is_empty():      # (a kit move is the cast's whole pose)
		cast_k = smoothstep(0.0, 0.07, cast_t) * (1.0 - smoothstep(0.32, 0.6, cast_t))
		pitch -= cast_k * 0.18
		yaw += cast_k * 0.25
		# the archetypes' signature casts
		match arch:
			"thief":
				if cast_slot == "utility":
					# the knife throw: wind up turned away, then whip round into the throw
					yaw += cast_k * lerpf(0.6, -0.35, smoothstep(0.06, 0.18, cast_t))
					pitch -= cast_k * 0.15
				elif cast_slot == "ult":
					# the mark-out: drop low, arms spread with both blades out
					pitch -= cast_k * 0.35
			"archer":
				if cast_slot == "utility" or cast_slot == "ult":
					# side-on to the shot, drawing: the shoulders open, the chest up
					yaw += cast_k * 0.55
					pitch += cast_k * (0.25 if cast_slot == "ult" else 0.05)
			"mage":
				# the cast leans back as the power goes out; the ultimate lifts the whole body
				pitch += cast_k * (0.3 if cast_slot == "ult" else 0.12)
			"gunslinger":
				if cast_slot == "ult":
					yaw -= cast_k * 0.3         # squared up for the deadeye
				else:
					yaw += cast_k * 0.35; pitch -= cast_k * 0.1
			"bulwark":
				# braced behind it: low, chest forward, the weight on the front foot
				pitch -= cast_k * 0.22
			"juggernaut":
				if cast_slot == "ult":
					# the roar: chest up and back, the shoulders thrown wide
					pitch += cast_k * 0.55
				elif cast_slot == "utility":
					pitch -= cast_k * 0.2
	# emotes
	var em := String(s.get("emote", ""))
	var em_t := float(s.get("emote_t", 99.0))
	if em != "" and (em != emote_id or em_t < emote_prev - 0.05):
		emote_id = em
	emote_prev = em_t
	var em_on := em != "" and em_t < 2.4 and down_k < 0.5
	emote_k = _ease(emote_k, 1.0 if em_on else 0.0, 9.0, dt)
	var emp := _emote_body(em_t)
	pitch += emp.x * emote_k
	yaw += emp.y * emote_k
	roll += emp.z * emote_k
	# fidgets that move the whole upper body
	var fid := _fidget_body()
	pitch += fid.x; yaw += fid.y; roll += fid.z
	pitch += ws.body.x
	yaw += ws.body.y
	roll += ws.body.z
	# skating: the skate move owns the lean, capped so she stays up on her blades (about 23 degrees)
	if dash_k > 0.01 and dash_kind == "skate":
		pitch = maxf(pitch, -SKATE_LEAN_MAX)
	# base channel: upright and still, a slow breath
	pitch = lerpf(pitch, 0.05, base_k * 0.8)
	# ---- rig: whole-body turns (tricks, rolls, the skydive, lying downed) and squash
	var rb := Basis.IDENTITY
	var rpivot := BODY_C
	if trick != "":
		match trick:
			"spin":
				rb = Basis(Vector3.UP, TAU * _spin_e(trick_p)) * Basis(Vector3.RIGHT, -0.25 * sin(trick_p * PI))
			"ball":
				rb = Basis(Vector3.RIGHT, -0.5 * minf(1.0, trick_t * 3.0))
			_:
				rb = Basis(trick_ax, TAU * _spin_e(trick_p))
	if roll_t >= 0.0:
		rb = Basis(roll_ax, roll_ang) * rb
		rpivot = Vector3(0, 0.4, 0)
	if dive_k > 0.01:
		rb = Basis(Vector3.RIGHT, -1.15 * dive_k) * rb
	if down_k > 0.01:
		# going down: a stagger and a fall forward (or back, if the hit came from behind)
		rb = Basis(Vector3.RIGHT, -1.38 * down_k) * Basis(Vector3.FORWARD, 0.12 * down_k * sin(crawl_ph * 0.5)) * rb
		rpivot = rpivot.lerp(Vector3.ZERO, down_k)
	# twin blades' charged attack: a full spin
	if swing_t < swing_dur and swing_step == -1 and hold == "twin":
		rb = Basis(Vector3.UP, -TAU * _spin_e(swing_t / swing_dur)) * rb
	if not km.is_empty():
		if absf(float(km["fx"])) > 0.001: rb = Basis(Vector3.RIGHT, float(km["fx"])) * rb
		if absf(float(km["fz"])) > 0.001: rb = Basis(Vector3.BACK, float(km["fz"])) * rb
		if absf(float(km["fy"])) > 0.001: rb = Basis(Vector3.UP, float(km["fy"])) * rb
	var sq := float(s.get("squash", 0.0)) + land_k * 0.12 + slam_k * 0.1 + (float(km["sq"]) * 0.35 if not km.is_empty() else 0.0)
	var stretch := float(s.get("stretch", 0.0))
	var scl := Vector3(1.0 + sq * 0.35 - stretch * 0.3, 1.0 - sq * 0.4 + stretch * 0.15, 1.0 + sq * 0.35 + stretch * 0.5)
	# feet on the ground: drop the hips by however much the standing leg is bent (the legs' own length:
	# a Warden's and the leg-length slider's)
	var dl2 := (THIGH * cos(hl) + SHIN * cos(hl + kl)) * cos(wl)
	var dr2 := (THIGH * cos(hr) + SHIN * cos(hr + kr)) * cos(wr)
	var leg_ref := LEG
	if arch == "unmasked":      # the Empty's soles, not a point foot, meet the ground
		dl2 = FootPlant.reach(hl, kl, wl)
		dr2 = FootPlant.reach(hr, kr, wr)
		leg_ref = FootPlant.HIP
	var drop := (leg_ref - maxf(dl2, dr2)) * legs.scale.y * (1.0 - air_k) * (1.0 - glide_k) * (1.0 - down_k) * (1.0 - dive_k) * (1.0 if roll_t < 0.0 else 0.0)
	var off := Vector3(wk * 0.028 * still, -drop + bounce * 0.008, 0.0) + ws.hip
	if arch == "juggernaut":
		off.y -= absf(cos(ph)) * 0.035 * r1        # each footfall lands with weight
	elif arch == "thief":
		off.y += absf(sin(ph)) * 0.025 * r1 + maxf(0.0, bounce) * 0.006   # springy, up on the toes
	elif arch == "bulwark":
		off.y -= absf(cos(ph)) * 0.025 * r1        # heavy, even steps
	elif arch == "tender":
		off.y += absf(sin(ph)) * 0.07 * r1         # a small scurry: one quick lift per step
	elif arch == "mage":
		off.y += still * (0.012 + sin(t * 1.4 + seed_ph) * 0.008)       # light on its feet, half floating
	elif arch == "dolm":
		off.y -= absf(cos(ph)) * 0.03 * r1         # wide, grounded stomps
	off.y += KMovesStone.hover(arch, t)
	off.y += down_k * 0.15 + base_k * (0.04 + sin(t * 2.0) * 0.015) * smoothstep(0.0, 0.3, base_p)
	off.y -= revive_k * 0.02
	if not km.is_empty():
		off.y += float(km["lift"])
	if roll_t >= 0.0:
		off.y -= 0.12 * roll_k
	if dash_k > 0.01 and dash_kind != "charge":
		off.y -= 0.1 * dash_k
	rb = Basis(Vector3.BACK, sin(ph) * 0.03 * r1 * (1.0 - down_k)) * rb
	rig.basis = rb * Basis.from_scale(scl)
	rig.position = rpivot - rb * rpivot + off
	legs.rotation.y = (legs_yaw + lag) * (1.0 - glide_k) * (1.0 - down_k) * (1.0 - dive_k) + sin(ph) * 0.12 * r1 * back
	leg_l.rotation = Vector3(hl, 0, wl)
	leg_r.rotation = Vector3(hr, 0, wr)
	if knee_l: knee_l.rotation.x = kl
	if knee_r: knee_r.rotation.x = kr
	# torso: bobs with the stride, breathes
	var tb := breath * still * (1.0 - emote_k * 0.5) * ws.breath_k
	torso.position.y = hip_y + tb * 0.006 + glide_k * 0.02
	torso.scale = Vector3(1.0 - tb * 0.006, 1.0 + tb * 0.012, 1.0 - tb * 0.006)
	torso.rotation = Vector3(pitch + dz, yaw, roll)
	# ================================================================ WEAPON AND ARMS
	_upper(dt, s, vel, r1, still, pitch, yaw, cast_k, em_t, fired, breath)
	HunterTool.place(self)
	# ================================================================ HEAD
	if head:
		glance_t -= dt
		if glance_t <= 0.0:
			glance_t = 1.6 + _rand() * 2.8
			glance_to = (_rand() - 0.5) * 0.9 if _rand() < 0.6 else 0.0
		head_look = _ease(head_look, glance_to * still * (1.0 - emote_k) * (1.0 - base_k), 3.0, dt)
		var fh := _fidget_head()
		var eh := _emote_head(em_t) * emote_k
		var lock := 0.85 * (1.0 - down_k)
		head.rotation.y = head_look + fh.y + eh.y - yaw * lock - legs_yaw * 0.0
		head.rotation.x = -pitch * 0.55 * (1.0 - tuck) + sin(ph * 2.0 + 0.6) * 0.03 * r1 + down_k * 0.25 - drink_k * 0.35 + fh.x + eh.x - tuck * 0.4 + flinch.x * 0.1
		head.rotation.z = -roll * 0.5 + sin(t * 0.9 + seed_ph) * 0.03 * still + fh.z + eh.z + stun_k * sin(t * 3.1 + 1.2) * 0.2
		head.rotation += ws.head
	# ================================================================ SHOULDER PIECES
	if pad_l and arm_l:
		pad_l.quaternion = Quaternion.IDENTITY.slerp(arm_l.basis.get_rotation_quaternion(), PAD_FOLLOW)
	if pad_r and arm_r:
		pad_r.quaternion = Quaternion.IDENTITY.slerp(arm_r.basis.get_rotation_quaternion(), PAD_FOLLOW)
	if focus:
		# the mage's orb hovers by the casting hand, bobbing and turning
		focus.position = focus_base + Vector3(0, sin(t * 2.2 + seed_ph) * 0.03, 0)
		focus.rotation.y = t * 1.3
	# ================================================================ CLOTH
	_cloth(dt, vel, spd, mf, ms, yaw, r1)


# ==================================================================== kit moves (kits2)
## Keyed full-body moves the archetype kits play for their abilities (state keys "kmove", the move's
## id, and "kmove_t", seconds since it started). Each is anticipation -> a key pose on the hit ->
## follow-through and recovery, keyed to the kit's own hit timing. Channels (all optional, eased
## between keys): p y r (torso pitch, yaw, roll, added), lift (the body up, m), fx fz fy (whole-body
## turns about the hips: forward flip, side flip, spin), sq (squash; negative stretches), legs
## [hl kl hr kr] with lw (their weight), fl / fr (a free hand's place from its shoulder) with hw / rw,
## blade (the greatsword's yaw, pitch, roll, like SWINGS) with bw, rad (the blade's reach), gp (a
## gun's extra pitch), wa / wo (a held weapon's extra pitch, yaw, roll and offset), wg (a 3D model's wings
## flared, 0..1: WardenGlb.Springs).
## A move with "hold": true stays on its last key until another replaces it; with
## "loop": t as well it cycles from t to the last key instead (a recoil wobble, hand over hand). A move with
## "stance": true keys its legs as a planted stance, used only standing (stance_leg_k); with "swing": n the
## weapon swing it starts plays step n of the weapon's SWINGS (one blade or the other, or both).
const KMOVES := {
}
## Stride rate (walk phase per metre) of heroes whose step differs from their class: quick, short steps
## (their hero sheets measure ~2.3-2.5 strides a second at a run).
const STRIDE := {"archer": 2.9, "bulwark": 2.9}
## wf: how far a kit move takes the held weapon with the body (0: it stays on the aim, 1: it turns with the torso)
const KM_CH := ["p", "y", "r", "lift", "fx", "fz", "fy", "sq", "lw", "hw", "rw", "bw", "rad", "gp", "wf", "wg"]
var km := {}                   # the kit move's channels this frame (empty: none)
var km_id := ""
var km_prev_t := 99.0
var km_from := {}              # the pose the last kit move left the body in, eased out over KM_BLEND
var km_blend := KM_BLEND
var km_stance := false         # the move's legs are a standing stance: running, the legs keep running
var km_swing := -1             # the weapon swing the move throws (its "swing" key), -1: the weapon's combo step
const KM_BLEND := 0.08         # s: one kit move eases into the next (or back to none), so no pose pops

## The kit move's channels this frame; a new move (or the same one restarted) blends in from the last pose.
func _update_km(id: String, tt: float, dt: float) -> void:
	if id != km_id or tt < km_prev_t - 0.001:
		km_from = km
		km_blend = 0.0
	if id != km_id:
		km_stance = bool(km_def(id).get("stance", false))
		km_swing = int(km_def(id).get("swing", -1))
	km_id = id
	km_prev_t = tt
	var now := km_sample(id, tt) if id != "" else {}
	km_blend += dt
	km = now if km_blend >= KM_BLEND or km_from.is_empty() else km_mix(km_from, now, km_blend / KM_BLEND)

## How much of a kit move's legs to use: all of them, or for a move keyed "stance": true (a throw or a shot
## from a planted stance) none at a run, so the legs keep running while the arms and torso play the move.
static func stance_leg_k(stance: bool, run: float) -> float:
	return 1.0 - clampf(run, 0.0, 1.0) if stance else 1.0

## Two kit-move poses mixed (u = 0: `a`, 1: `b`); a side without a channel counts as the rest pose, and the
## whole-body turns take the short way round.
static func km_mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	if a.is_empty() and b.is_empty():
		return {}
	u = u * u * (3.0 - 2.0 * u)
	var out := {}
	for c in KM_CH:
		var va := float(a.get(c, 0.0))
		var vb := float(b.get(c, 0.0))
		out[c] = lerp_angle(va, vb, u) if c in ["fx", "fy", "fz"] else lerpf(va, vb, u)
	var la: Array = a.get("legs", b.get("legs", []))
	var lb: Array = b.get("legs", la)
	if not la.is_empty():
		out["legs"] = [lerpf(la[0], lb[0], u), lerpf(la[1], lb[1], u), lerpf(la[2], lb[2], u), lerpf(la[3], lb[3], u)]
	for c in ["fl", "fr", "blade", "wa", "wo"]:
		if a.has(c) or b.has(c):
			var va2: Vector3 = a.get(c, b.get(c))
			var vb2: Vector3 = b.get(c, a.get(c))
			out[c] = va2.lerp(vb2, u)
	return out

## A kit move's keys, from whichever pair's table has it (scripts/match/kmoves_*.gd); empty if none.
static func km_def(id: String) -> Dictionary:
	for t in [KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES, KMovesCare.MOVES,
			KMovesPinBjorn.MOVES, KMovesDJ.MOVES]:
		if (t as Dictionary).has(id):
			return t[id]
	return {}

## Samples the kit move at time `tt`: each channel eased between the keys around it.
static func km_sample(id: String, tt: float) -> Dictionary:
	var mv := km_def(id)
	if mv.is_empty():
		return {}
	var keys: Array = mv["keys"]
	var last: Array = keys[-1]
	if tt >= float(last[0]):
		if not mv.get("hold", false):
			return {}
		tt = _km_held_t(mv, tt, float(last[0]))
	var i := 0
	while i < keys.size() - 2 and tt >= float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]; var b: Array = keys[mini(i + 1, keys.size() - 1)]
	var span := maxf(0.001, float(b[0]) - float(a[0]))
	var u := clampf((tt - float(a[0])) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var pa: Dictionary = a[1]; var pb: Dictionary = b[1]
	var out := {}
	for c in KM_CH:
		var va := float(pa.get(c, 0.0)); var vb := float(pb.get(c, 0.0))
		# a weight that isn't keyed on one side falls off with the other side's pose
		out[c] = lerpf(va, vb, u)
	for c in ["legs"]:
		var la: Array = pa.get(c, []); var lb: Array = pb.get(c, [])
		if la.is_empty() and lb.is_empty(): continue
		if la.is_empty(): la = lb
		if lb.is_empty(): lb = la
		out[c] = [lerpf(la[0], lb[0], u), lerpf(la[1], lb[1], u), lerpf(la[2], lb[2], u), lerpf(la[3], lb[3], u)]
	for c in ["fl", "fr", "blade", "wa", "wo"]:
		var has_a := pa.has(c); var has_b := pb.has(c)
		if not has_a and not has_b: continue
		var va2: Vector3 = pa.get(c, pb.get(c)); var vb2: Vector3 = pb.get(c, pa.get(c))
		out[c] = va2.lerp(vb2, u)
	return out

## Where a held move samples past its last key: the last key, or with "loop" (the time it loops back to)
## round and round from there, for a held move that keeps moving (a recoil wobble, hand over hand).
static func _km_held_t(mv: Dictionary, tt: float, end_t: float) -> float:
	var loop_from := float(mv.get("loop", -1.0))
	if loop_from < 0.0 or loop_from >= end_t:
		return end_t
	return loop_from + fmod(tt - loop_from, end_t - loop_from)

# ==================================================================== melee helpers
## How far into the current swing's strike we are, 0..1 then back to 0 (for leaning into it).
func _swing_k() -> float:
	if swing_t >= swing_dur:
		return 0.0
	var p := swing_t / swing_dur
	return smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.45, 1.0, p))

## The blade's place and the body's twist for the current swing, into sw_*: w (weight), a (yaw,
## pitch, roll), tw (torso twist), hand ("r" "l" "b" both on one hilt, "x" both blades), drop, rad
## (a reach for thrusts, -1 when not), b2 (the off blade's own pose, INF when mirrored).
var sw_w := 0.0
var sw_a := Vector3.ZERO
var sw_tw := 0.0
var sw_hand := "r"
var sw_drop := 0.0
var sw_rad := -1.0
var sw_b2 := Vector3.INF
## How far along its arc a swing is (0 to 1) at `p`, the share of its time gone: a fast start that settles.
static func swing_ease(p: float) -> float:
	var u := clampf((p - 0.03) / 0.3, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)

func _swing_pose() -> void:
	sw_w = 0.0; sw_tw = 0.0; sw_drop = 0.0; sw_rad = -1.0; sw_b2 = Vector3.INF; sw_hand = "r"
	if swing_t >= swing_dur or not SWINGS.has(hold):
		return
	var p := swing_t / swing_dur
	sw_w = smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.6, 1.0, p))
	var e := swing_ease(p)
	if swing_step < 0:
		# charged: a thrust (sword), an overhead slam (greatsword), a spin with both blades out
		match hold:
			"sword":
				sw_a = Vector3(0.05, 0.0, 0.0); sw_rad = lerpf(0.18, 0.55, e); sw_tw = lerpf(-0.4, 0.45, e) * sw_w
			"great":
				sw_a = Vector3(0.0, lerpf(2.6, -1.25, e), 0.0); sw_hand = "b"; sw_drop = 0.3 * e * sw_w
			_:
				sw_a = Vector3(-1.4, 0.0, 1.5); sw_b2 = Vector3(1.4, 0.0, -1.5); sw_hand = "x"
		return
	var sws: Array = SWINGS.get(wid, SWINGS[hold])
	var d: Dictionary = sws[swing_step % sws.size()]
	sw_a = (d["a"] as Vector3).lerp(d["b"], e)
	var tw: Vector2 = d["tw"]
	sw_tw = lerpf(tw.x, tw.y, e) * sw_w
	sw_hand = d["hand"]
	sw_drop = float(d.get("drop", 0.0)) * e * sw_w

# ==================================================================== upper body
func _upper(dt: float, s: Dictionary, vel: Vector3, r1: float, still: float, pitch: float, yaw: float, cast_k: float, em_t: float, fired: float, breath: float) -> void:
	if aim == null:
		return
	var melee := hold in ["sword", "great", "twin"]
	var grounded: bool = s.get("grounded", true)
	# a new shot: kick the recoil spring
	if fired < fired_prev - 0.005 and fired < 0.1 and not melee:
		kick_v += float(hd.get("kick", 0.15)) * 22.0
		shake_t = 0.12
		if hold == "shotgun": pump_t = 0.0
	fired_prev = fired
	if spin:
		spin_v = lerpf(spin_v, SPIN_MAX if fired < 0.3 else 0.0, minf(1.0, SPIN_EASE * dt))
		spin.rotate_object_local(Vector3.FORWARD, spin_v * dt)
	var ks := _spring(kick, kick_v, 0.0, 420.0, 20.0, dt)
	kick = ks.x; kick_v = ks.y
	shake_t = maxf(0.0, shake_t - dt)
	pump_t += dt
	# a new swing
	var sn := int(s.get("swing_n", swing_prev))
	if sn != swing_prev:
		swing_prev = sn
		swing_t = 0.0
		swing_step = km_swing if km_swing >= 0 else int(s.get("combo", 0))
		var base_d: float = {"twin": 0.3, "sword": 0.36, "great": 0.5}.get(hold, 0.36)
		swing_dur = base_d * (1.25 if swing_step == 2 else 1.0) * (1.35 if swing_step < 0 else 1.0)
	swing_t += dt
	# aiming or relaxed: guns come up when you fire, and drop to a carry a little after
	var want_aim := 1.0 if fired < 1.1 or float(s.get("charge", 0.0)) > 0.0 or crouch_k > 0.5 else 0.0
	aim_k = _ease(aim_k, want_aim, 14.0 if want_aim > aim_k else 3.0, dt)
	var want_carry := 1.0 if r1 > 0.55 and aim_k < 0.3 and grounded and hold != "minigun" else 0.0
	carry_k = _ease(carry_k, want_carry, 6.0, dt)
	var stow := maxf(maxf(glide_k, dive_k), maxf(emote_k * (0.0 if emote_id == "" else 1.0), down_k))
	stow = maxf(stow, stow_k)
	stow = maxf(stow, ledge_k * 0.0)
	gun_vis = _ease(gun_vis, 0.0 if stow > 0.5 else 1.0, 14.0, dt)
	var side_r := Vector3(1, 0, 0)
	# ---------------------------------------------------------------- the weapon's place
	var ap := 0.0     # Aim pitch, yaw, roll
	var ay := 0.0
	var ar := 0.0
	var gpos := Vector3.ZERO
	var gbas := Basis.IDENTITY
	var opos := Vector3.ZERO   # twin blades' offhand
	var lp := 0.0              # guns: Aim only keeps them level while the body leans and twists
	var ly := 0.0
	var obas := Basis.IDENTITY
	var free_l := 0.0          # 1 = the left hand lets go of the weapon
	var free_r := 0.0
	var reload := float(s.get("reload", -1.0))
	var arm_l_t := Vector3.ZERO   # extra offsets for the hands
	if not melee:
		# the gun turns about its own grip (low ready: muzzle down and across), and sits in front of
		# the belly relaxed, up at the chest aimed
		var low: Vector2 = hd["low"]
		var relax := 1.0 - aim_k
		gpos = (hd["pos"] as Vector3) + Vector3(0.0, -0.05, 0.04) * relax
		ap = low.x * relax
		ay = low.y * relax
		# a breath and a sway in the carry
		ap += breath * 0.02 * still + sin(ph * 2.0) * 0.03 * r1
		# running with it: one hand, muzzle down and forward, swinging with the arm
		ap = lerpf(ap, -0.85 + sin(ph) * 0.12, carry_k)
		ay = lerpf(ay, 0.1, carry_k)
		var carry_at := Vector3(0.22, -0.3, -0.1 - sin(ph) * 0.06)
		if hold == "finger":
			carry_at = Vector3(0.36, -0.1, -0.12)     # Sparkle runs upright with her arms held out wide
		gpos = gpos.lerp(carry_at, carry_k)
		free_l = carry_k
		# recoil: the muzzle kicks up and the gun pushes back
		ap += kick
		if not km.is_empty(): ap += float(km["gp"])
		gpos.z += kick / maxf(0.01, float(hd.get("kick", 0.15))) * float(hd.get("push", 0.05)) * 0.6
		if shake_t > 0.0 or (hold == "minigun" and fired < 0.15):
			var sh := float(hd.get("jitter", 0.2)) * 0.012
			gpos += Vector3(sin(t * 91.0) * sh, cos(t * 77.0) * sh, 0.0)
		# keep the gun on target while the body leans and twists
		var lock := lerpf(0.5, 0.95, aim_k) * (1.0 - carry_k) * (1.0 - float(km.get("wf", 0.0)))
		lp = -pitch * lock
		ly = -yaw * lock
		# reloads
		if reload >= 0.0:
			var r := clampf(reload, 0.0, 1.0)
			var rk := smoothstep(0.0, 0.12, r) * (1.0 - smoothstep(0.85, 1.0, r))
			match hold:
				"shotgun":
					# shells, one at a time: the gun tips over and the hand feeds them in
					ap += rk * -0.25; ar -= rk * 0.7; ay += rk * 0.25
					var cyc := fmod(r * 3.0, 1.0)
					arm_l_t = Vector3(0.18 * (1.0 - absf(cyc * 2.0 - 1.0)), -0.2 * (1.0 - absf(cyc * 2.0 - 1.0)), 0.1) * rk
				"minigun":
					# heave the drum: the gun drops, rises, and slams back
					ap += rk * (-0.35 + sin(r * PI * 2.0) * 0.15)
					gpos.y -= rk * 0.06 * sin(r * PI)
				"sniper":
					ap += rk * 0.35; ar -= rk * 0.25
					var bolt := smoothstep(0.55, 0.65, r) * (1.0 - smoothstep(0.75, 0.85, r))
					arm_l_t = Vector3(0.05, 0.08, 0.16) * bolt
				_:
					# tip the gun over and drop the magazine, reach down for a new one, slap it in
					ap += -rk * 0.5; ar -= rk * 0.6; ay += rk * 0.3
					var slap := smoothstep(0.62, 0.68, r) * (1.0 - smoothstep(0.68, 0.8, r))
					ap += slap * 0.25
			_reload_mag(r)
			var reach := smoothstep(0.12, 0.3, reload) * (1.0 - smoothstep(0.42, 0.62, reload))
			if hold in ["rifle", "smg", "burst_rifle", "_gun"]:
				free_l = maxf(free_l, reach)
		elif mag and is_instance_valid(mag) and not mag.visible:
			mag.visible = true
			mag.position = mag_base
		# the shotgun's pump after each shot
		if hold == "shotgun" and pump_t < 0.35:
			var pk := sin(clampf(pump_t / 0.35, 0.0, 1.0) * PI)
			arm_l_t += Vector3(0, 0, 0.12) * pk
	else:
		# melee: guard poses, and swings around the shoulder (each blade on a radius from its shoulder)
		var c := Vector3(0.17, -0.06, 0.0)
		var rad := 0.4
		var guard := Vector3.ZERO        # yaw, pitch, roll at rest
		var o_guard := Vector3.ZERO
		var chg := minf(1.0, float(s.get("charge", 0.0)) * 3.0)
		match hold:
			"sword":
				guard = Vector3(lerpf(-0.4, -0.25, carry_k), lerpf(-0.4, -0.45, carry_k), 0.0).lerp(Vector3(-0.3, -0.35, 0.0), aim_k)
				guard = guard.lerp(Vector3(-0.6, 0.1, 0.0), chg)
				rad = lerpf(rad, 0.22, chg)
				free_l = 1.0
			"great":
				c = Vector3(0.05, -0.04, 0.0)
				rad = 0.36
				guard = Vector3(-0.2, 0.25, 0.0).lerp(Vector3(-0.1, 2.7, 0.0), chg)
			"twin":
				guard = Vector3(-0.5, -0.8, 0.0).lerp(Vector3(-0.4, -0.2, 0.0), aim_k).lerp(Vector3(-1.2, -0.3, 0.0), chg)
				o_guard = Vector3(0.5, -0.8, 0.0).lerp(Vector3(0.45, -0.3, 0.0), aim_k).lerp(Vector3(1.2, -0.3, 0.0), chg)
		var a := guard
		var oa := o_guard
		if sw_w > 0.0:
			if sw_hand in ["r", "b", "x"]:
				a = guard.lerp(sw_a, sw_w)
			if sw_hand == "l":
				oa = o_guard.lerp(sw_a, sw_w)
			elif sw_hand == "x":
				oa = o_guard.lerp(Vector3(-sw_a.x, sw_a.y, -sw_a.z) if sw_b2 == Vector3.INF else sw_b2, sw_w)
			if sw_rad > 0.0:
				rad = lerpf(rad, sw_rad, sw_w)
		if not km.is_empty() and km.has("blade") and float(km["bw"]) > 0.0:
			var bw := clampf(float(km["bw"]), 0.0, 1.0)
			a = a.lerp(km["blade"], bw)
			if float(km["rad"]) > 0.0: rad = lerpf(rad, float(km["rad"]), bw)
			if hold == "twin": oa = oa.lerp(Vector3(-(km["blade"] as Vector3).x, (km["blade"] as Vector3).y, -(km["blade"] as Vector3).z), bw)
		var rot := Basis.from_euler(Vector3(a.y, a.x, 0.0))
		gbas = rot * Basis(Vector3.BACK, a.z)
		gpos = c + rot * Vector3(0, 0, -rad) - Vector3(0, sw_drop * 0.3, 0)
		if hold == "great":
			# at rest the greatsword lies back over the right shoulder, the hands in front of the chest
			var rest := 1.0 - maxf(aim_k * 0.8, maxf(maxf(sw_w, chg), float(km.get("bw", 0.0))))
			if rest > 0.0:
				var rb2 := Basis.from_euler(Vector3(2.35, -0.25, 0.0)) * Basis(Vector3.BACK, 0.3)
				gbas = gbas.slerp(rb2, rest)
				if arch == "juggernaut":
					# the juggernaut carries it in one fist, propped on the shoulder, the other gauntlet
					# hanging free: the shape of a brute, not a fencer
					gpos = gpos.lerp(Vector3(0.2, 0.02, -0.12), rest)
					free_l = maxf(free_l, rest)
				else:
					gpos = gpos.lerp(Vector3(0.1, -0.14, -0.24), rest)
		if hold == "twin":
			var oc := Vector3(-0.17, -0.06, 0.0)
			var orot := Basis.from_euler(Vector3(oa.y, oa.x, 0.0))
			obas = orot * Basis(Vector3.BACK, oa.z)
			opos = oc + orot * Vector3(0, 0, -0.36)
		# fidget: a twirl of the blade in the hand
		if fidget == "weapon" and hold in ["sword", "twin"]:
			gbas = gbas * Basis(Vector3.RIGHT, -TAU * 2.0 * _spin_e(_fidget_p()))
		# keep the blades level with the aim, partly
		ap -= pitch * 0.5
		ay -= yaw * 0.6 * (1.0 - sw_w)
	# casting: the left hand goes out
	if cast_k > 0.0:
		free_l = maxf(free_l, cast_k)
	# drinking a tonic: the left hand brings a flask up
	var drink := float(s.get("drink", -1.0))
	drink_k = 0.0
	if drink >= 0.0:
		drink_k = smoothstep(0.0, 0.2, drink) * (1.0 - smoothstep(0.85, 1.0, drink))
		free_l = maxf(free_l, drink_k)
		ap -= drink_k * 0.5
	# fidget: weapon check, stretch
	var fp2 := clampf(fidget_t / maxf(fidget_dur, 0.01), 0.0, 1.0)
	var fk := sin(fp2 * PI) if fidget != "" else 0.0
	if not melee and fidget == "weapon":
		ar += fk * 0.9; ay += fk * 0.35; ap += fk * 0.25
		free_l = maxf(free_l, smoothstep(0.35, 0.5, fp2) * (1.0 - smoothstep(0.6, 0.75, fp2)))
	if fidget == "stretch" and not melee:
		# the weapon goes up overhead in both hands, a lean back
		ap = lerpf(ap, 0.0, fk)
		ar = lerpf(ar, 0.0, fk)
		gpos = gpos.lerp(Vector3(0.12, 0.42, -0.02), fk)
		ay = lerpf(ay, 1.57, fk)
	if not melee:
		if km.has("wa"):          # a kit move's weapon pivot: extra pitch, yaw, roll about the grip (KMovesCare)
			var wa: Vector3 = km["wa"]
			ap += wa.x
			ay += wa.y
			ar += wa.z
		if km.has("wo"): gpos += km["wo"] as Vector3
		gbas = Basis.from_euler(Vector3(ap, ay, ar))
		ap = lp; ay = ly; ar = 0.0
	# the Warden's signature carry while standing (it comes up to the aim the moment they fire)
	var carried := ws.carry(Transform3D(gbas, gpos))
	gbas = carried.basis
	gpos = carried.origin
	free_l = maxf(free_l, ws.carry_free_l())
	# emotes: the weapon goes away, the hands do the talking
	var gvs := gun_vis * gun_scl
	aim.rotation = Vector3(ap, ay, ar)
	aim.position = Vector3(0, AIM_Y, 0)
	if gun:
		gun.transform = Transform3D(gbas * Basis.from_scale(Vector3.ONE * maxf(gvs, 0.001)), gpos)
		gun.visible = gun_vis > 0.02
		_keep_above_ground(gun, gun_pts)
	if offhand:
		offhand.transform = Transform3D(obas * Basis.from_scale(Vector3.ONE * maxf(gvs, 0.001)), opos)
		offhand.visible = gun_vis > 0.02
		_keep_above_ground(offhand, off_pts)
	if arm_l == null or arm_r == null:
		return
	# ---------------------------------------------------------------- hand targets
	var at := aim.transform
	var grip_r: Vector3 = hd["gr"]
	var grip_l: Vector3 = hd["gl"]
	var tr := at * (gun.transform * grip_r) if gun else sh_r + EMPTY_HAND      # (no weapon: it hangs at the side)
	var tl := Vector3.INF
	if hold == "twin" and offhand:
		tl = at * (offhand.transform * Vector3.ZERO)
	elif grip_l != Vector3.INF and gun:
		tl = at * (gun.transform * grip_l)
		tl = _reachable(sh_l, tl, at * (gun.transform * grip_r), REACH * arm_k * 0.97)
	tr = _reachable(sh_r, tr, tr, REACH * arm_k * 0.99)
	if tl == Vector3.INF:
		free_l = 1.0
	# free hands: relaxed at the sides, swinging when running (against the legs), pumping hard in a sprint
	var arm_amp := float(st["arm"])
	var elbow := float(st["elbow"])
	var swing_l := -sin(ph + PI) * r1 * back
	var swing_r := -sin(ph) * r1 * back
	var hang := 0.4 - elbow * 0.04
	var fl := sh_l + Vector3(-0.05 - 0.03 * elbow, -hang + 0.12 * r1, -0.04 - 0.06 * r1) + Vector3(0, absf(swing_l) * 0.05, swing_l * 0.2 * arm_amp)
	var fr := sh_r + Vector3(0.05 + 0.03 * elbow, -hang + 0.12 * r1, -0.04 - 0.06 * r1) + Vector3(0, absf(swing_r) * 0.05, swing_r * 0.2 * arm_amp)
	fl += Vector3(0, breath * 0.004 * still, 0)
	if arch == "mage":
		fl = fl.lerp(sh_l + Vector3(-0.34, -0.12, -0.1), r1)     # her free arm held out wide as she runs
	if hd.get("fist", false):
		# the off fist carried low and forward, ready (a brawler, not a shooter's hanging hand)
		fl = sh_l + Vector3(-0.1, -0.3 + 0.06 * r1, -0.2 + swing_l * 0.12 * arm_amp)
	fl += ws.arm_l
	# dodges: arms back (phase lunge), tucked (roll), shoulder guard (charge)
	if dash_k > 0.01:
		match dash_kind:
			"phase", "rush":
				fl = fl.lerp(sh_l + Vector3(-0.12, -0.25, 0.3), dash_k)
				free_l = maxf(free_l, dash_k)
			"charge":
				fl = fl.lerp(sh_l + Vector3(0.06, -0.12, -0.22), dash_k)
				free_l = maxf(free_l, dash_k)
	# air: arms rise for balance, out wide in a fall
	var ak := air_k * (1.0 - glide_k)
	if ak > 0.01 and not melee:
		fl = fl.lerp(sh_l + Vector3(-0.3, -0.18 + clampf(-vel.y / 9.0, 0.0, 1.0) * 0.2, -0.05), ak * free_l)
	# tricks and rolls: hug the knees
	var tuck_k := 0.0
	if trick != "" or roll_t >= 0.0:
		var tp := clampf(trick_t / maxf(trick_dur, 0.01), 0.0, 1.0)
		tuck_k = minf(1.0, sin(tp * PI) * 1.8) if trick != "" else 1.0
		if trick == "spin": tuck_k *= 0.3
		if trick == "spin":
			# the corkscrew: arms flung out
			var out := minf(1.0, sin(tp * PI) * 2.0)
			fl = fl.lerp(sh_l + Vector3(-0.38, 0.05, 0.0), out)
			free_l = maxf(free_l, out)
	var knee_hug_l := Vector3(-0.1, -0.32, -0.28)
	var knee_hug_r := Vector3(0.1, -0.32, -0.28)
	if tuck_k > 0.0:
		fl = fl.lerp(knee_hug_l, tuck_k)
		free_l = maxf(free_l, tuck_k)
	# glide: both hands up on the harness lines
	if glide_k > 0.01:
		fl = fl.lerp(sh_l + Vector3(0.02, 0.36, 0.06), glide_k)
		fr = fr.lerp(sh_r + Vector3(-0.02, 0.36, 0.06), glide_k)
	# skydiving: arms spread wide and forward
	if dive_k > 0.01:
		fl = fl.lerp(sh_l + Vector3(-0.32, 0.12, -0.22), dive_k)
		fr = fr.lerp(sh_r + Vector3(0.32, 0.12, -0.22), dive_k)
	# ledge and mantle: reaching up, then pushing down on the lip
	if ledge_k > 0.01:
		var mk := float(s.get("mantle", -1.0))
		var up_t := sh_l + Vector3(-0.05, 0.4, -0.15) if mk < 0.0 or mk < 0.35 else sh_l + Vector3(-0.08, -0.2, -0.3)
		var up_r := sh_r + Vector3(0.05, 0.4, -0.15) if mk < 0.0 or mk < 0.35 else sh_r + Vector3(0.08, -0.2, -0.3)
		fl = fl.lerp(up_t, ledge_k); fr = fr.lerp(up_r, ledge_k)
		free_l = maxf(free_l, ledge_k)
	# stomp: arms out for balance
	if stomp_k > 0.01:
		fl = fl.lerp(sh_l + Vector3(-0.32, -0.15, -0.05), stomp_k)
		free_l = maxf(free_l, stomp_k)
	# revive: the left hand reaches down over them
	if revive_k > 0.01:
		fl = fl.lerp(sh_l + Vector3(0.05, -0.32, -0.3), revive_k)
		free_l = maxf(free_l, revive_k)
	# holding interact: the hands on what's being worked (see _act_hands)
	if act_k > 0.01:
		var ah := _act_hands(sh_l, sh_r)
		fl = fl.lerp(ah[0], act_k)
		free_l = maxf(free_l, act_k)
		if float(ah[2]) > 0.0:
			fr = fr.lerp(ah[1], act_k)
			free_r = maxf(free_r, act_k * float(ah[2]))
	# base: a hand at the ear, calling it in
	if base_k > 0.01:
		fl = fl.lerp(sh_l + Vector3(0.08, 0.3, -0.08), base_k)
		free_l = maxf(free_l, base_k)
	# downed: crawling on the forearms, reaching ahead one hand then the other
	if down_k > 0.01:
		var c1 := sin(crawl_ph)
		fl = fl.lerp(sh_l + Vector3(-0.08, -0.18 + maxf(0.0, c1) * 0.06, -0.3 - c1 * 0.12), down_k)
		fr = fr.lerp(sh_r + Vector3(0.08, -0.18 + maxf(0.0, -c1) * 0.06, -0.3 + c1 * 0.12), down_k)
	# stun: arms dangle
	if stun_k > 0.01:
		free_l = maxf(free_l, stun_k * 0.7)
	# casting: palm thrust forward (the kin and the ultimate get both hands up)
	if cast_k > 0.0:
		var ct := sh_l + Vector3(0.06, 0.02, -0.4)
		if cast_slot == "ult": ct = sh_l + Vector3(0.0, 0.42, -0.12)
		if arch == "thief" and cast_slot == "utility":
			# the knife leaves the off hand: cocked back by the ear, flung out ahead
			ct = sh_l + Vector3(-0.08, 0.26, 0.14).lerp(Vector3(0.1, 0.1, -0.5), smoothstep(0.06, 0.18, cast_now))
		elif arch == "juggernaut" and cast_slot == "ult":
			ct = sh_l + Vector3(-0.32, 0.3, -0.12)          # the free fist thrown out wide and up
		elif arch == "archer":
			# the bow hand straight out ahead; for the volley, high to the sky
			ct = sh_l + (Vector3(0.0, 0.5, -0.2) if cast_slot == "ult" else Vector3(0.05, 0.08, -0.45))
		elif arch == "mage":
			# both palms out (the orb swings ahead with the left), or raised high for the ultimate
			ct = sh_l + (Vector3(0.05, 0.45, -0.18) if cast_slot == "ult" else Vector3(0.1, 0.12, -0.42))
		elif arch == "gunslinger" and cast_slot != "ult":
			# fanning the hammer: the left palm sweeps back over the gun
			ct = sh_l + Vector3(0.22, 0.0, -0.22).lerp(Vector3(0.3, -0.02, -0.08), smoothstep(0.05, 0.3, cast_now))
		elif arch == "bulwark":
			ct = sh_l + Vector3(0.12, 0.05, -0.4)           # a braced forearm, out in front
		fl = fl.lerp(ct, cast_k)
	# a kit move's free hands
	if not km.is_empty():
		if km.has("fl") and float(km["hw"]) > 0.0:
			var hw := clampf(float(km["hw"]), 0.0, 1.0)
			fl = fl.lerp(sh_l + (km["fl"] as Vector3), hw)
			free_l = maxf(free_l, hw)
		if km.has("fr") and float(km["rw"]) > 0.0:
			var rw := clampf(float(km["rw"]), 0.0, 1.0)
			fr = fr.lerp(sh_r + (km["fr"] as Vector3), rw)
			free_r = maxf(free_r, rw)
	# drink: flask to the mouth
	if drink_k > 0.0:
		fl = fl.lerp(sh_l + Vector3(0.16, 0.2, -0.17), drink_k)
	# fidgets with a free hand
	var ff := _fidget_hands()
	if ff.w > 0.0:
		fl = fl.lerp(Vector3(ff.x, ff.y, ff.z), ff.w)
		free_l = maxf(free_l, ff.w)
	if not melee and fidget == "stretch" and fk > 0.0:
		free_l = minf(free_l, 1.0 - fk)
	# emotes
	_emote_hands(em_t)
	free_l = maxf(free_l, emote_k * eh_fl)
	free_r = maxf(free_r, emote_k * eh_fr)
	fl = fl.lerp(eh_l, emote_k * eh_fl)
	fr = fr.lerp(eh_r, emote_k * eh_fr)
	if eh_flag > 0.0:
		_flag(emote_k * eh_flag)
	elif flag:
		flag.visible = false
	# the gun goes when it's stowed: the right hand is free then (and always with nothing held)
	free_r = maxf(free_r, 1.0 - gun_vis)
	free_r = maxf(free_r, ws.carry_free_r())
	if hold == "palm":
		free_r = 1.0
	free_l = maxf(free_l, 1.0 - gun_vis)
	if glide_k > 0.01 or dive_k > 0.01 or down_k > 0.01:
		free_r = maxf(free_r, maxf(glide_k, maxf(dive_k, down_k)))
	if tuck_k > 0.0:
		fr = fr.lerp(knee_hug_r, tuck_k)
		free_r = maxf(free_r, tuck_k * (1.0 if not melee else 0.0))
	if ledge_k > 0.01:
		free_r = maxf(free_r, ledge_k)
	var tl2 := (tl if tl != Vector3.INF else fl).lerp(fl, free_l) + arm_l_t
	var tr2 := tr.lerp(fr, free_r)
	# elbows: down and out holding a weapon, back when swinging free
	var pole_l := Vector3(-0.7, -0.6, 0.25).lerp(Vector3(-0.35, -0.2, 1.0), free_l)
	var pole_r := Vector3(0.7, -0.6, 0.25).lerp(Vector3(0.35, -0.2, 1.0), free_r)
	if glide_k > 0.01:
		pole_l = pole_l.lerp(Vector3(-1.0, -0.3, 0.2), glide_k); pole_r = pole_r.lerp(Vector3(1.0, -0.3, 0.2), glide_k)
	var bsh := Vector3(0, breath * 0.005 * still, 0)
	_ik(arm_l, el_l, sh_l + bsh, tl2, pole_l)
	_ik(arm_r, el_r, sh_r + bsh, tr2, pole_r)
	if hd.get("fist", false):
		_fists_to_hands(grip_r)
	elif gun and (free_r < 0.5 or hold == "twin"):
		_weapon_to_hand(grip_r)
	if hold == "twin" and offhand:
		_offhand_to_hand()      # (twin weapons stay in the hands a kit move carries: fl / fr)
	# the flask in the left hand
	if drink_k > 0.0 and flask == null and hand_l:
		flask = Node3D.new(); flask.name = "Flask"
		hand_l.add_child(flask)
		flask.position = Vector3(0, -0.06, -0.05)
		Models.part(flask, Models.sphere(0.07, 10), Models.toon(Color("8ff0a0"), true, 0.5), Vector3.ZERO, Vector3(1.0, 1.15, 1.0))
		Models.part(flask, Models.cyl(0.025, 0.03, 0.08, 8), Models.toon(Color("e8e0d0")), Vector3(0, 0.09, 0))
		Models.part(flask, Models.cyl(0.03, 0.03, 0.03, 8), Models.toon(Color("8a5a3a")), Vector3(0, 0.14, 0))
	if flask:
		flask.visible = drink_k > 0.05
		flask.rotation.x = -drink_k * 2.0

# ---------------------------------------------------------------- interact holds
## Holding interact (Hunter.holding(), synced in the snapshot flags): a pose for each thing, looping
## for the whole hold, and easing off cleanly when the hold stops or is interrupted.
##   scan     down on one knee, a calming hand out low, slowly patting the air
##   revive   on one knee, both hands on them, pressing
##   chest    squatting, both hands under the lid, heaving it up
##   dial     standing at the lectern, both hands on the dial, turning it
##   console  working the console's levers, one hand then the other
##   lever    a two-handed pull, leaning back into it
##   windup   the stomp's wind-up: weight back, the foot coming up, arms out
##   shrine   head bowed, hands together
##   beacon   a hand raised to the light
##   key      crouched at the hatch, turning a key
##   loot     crouched over a deathbox, rummaging
##   rune     both palms on the stone
##   offer    down on one knee, both hands held out together at the chest (the prologue's relic)
##   chop, mine, build   a tool swing (HunterTool): the weapon put away, the tool in both hands (one for the hammer)
const ACT_KNEEL := ["scan", "revive", "key", "loot", "offer"]
func _act_tick(dt: float, s: Dictionary, grounded: bool, spd: float) -> void:
	var want := String(s.get("act", ""))
	if not grounded or spd > 2.2 or s.get("downed", false) or float(s.get("stomp", -1.0)) >= 0.0:
		want = ""
	if want != "" and want != act_kind:
		act_kind = want
		act_t = 0.0
	act_t += dt
	act_k = _ease(act_k, 1.0 if want != "" else 0.0, 9.0 if want != "" else 12.0, dt)
	if act_k < 0.01 and want == "":
		act_kind = ""

## Leg angles for the hold: Vector4(hip_l, knee_l, hip_r, knee_r).
func _act_legs() -> Vector4:
	if HunterTool.ACTS.has(act_kind):
		return HunterTool.legs(act_kind, tool_ph)
	var w := sin(act_t * 3.0)
	match act_kind:
		"scan", "revive", "key", "loot", "offer":
			return Vector4(1.35, -1.45, -0.15, -1.9)
		"chest":
			var heave := 0.5 + 0.5 * sin(act_t * 3.4)
			return Vector4(1.0 - heave * 0.35, -1.4 + heave * 0.5, 0.95 - heave * 0.35, -1.35 + heave * 0.5)
		"lever":
			var p := 0.5 - 0.5 * cos(act_t * 2.6)
			return Vector4(0.5 + p * 0.2, -0.45 - p * 0.2, -0.25 - p * 0.15, -0.2)
		"windup":
			var up := smoothstep(0.0, 0.6, act_t)
			return Vector4(0.15, -0.35, 1.25 * up, -1.5 * up - 0.1)
		"shrine":
			return Vector4(0.25, -0.35, 0.25, -0.35)
	return Vector4(0.12 + w * 0.02, -0.22, 0.12 - w * 0.02, -0.22)

## How far forward the body leans into the hold (negative leans back).
func _act_pitch() -> float:
	if HunterTool.ACTS.has(act_kind):
		return HunterTool.pitch(act_kind, tool_ph)
	match act_kind:
		"scan": return 0.25 + 0.04 * sin(act_t * 1.6)
		"revive": return 0.4 + 0.06 * maxf(0.0, sin(act_t * 6.0))
		"key", "loot": return 0.35
		"chest": return 0.5 - 0.25 * (0.5 + 0.5 * sin(act_t * 3.4))
		"dial": return 0.18
		"console": return 0.22
		"rune": return 0.15
		"shrine": return 0.4
		"lever": return -0.15 - 0.15 * (0.5 - 0.5 * cos(act_t * 2.6))
		"windup": return -0.15 * smoothstep(0.0, 0.6, act_t)
		"beacon": return -0.12
	return 0.0

## Where the hands go: [left hand, right hand, how much the right hand lets go of the weapon].
func _act_hands(sh_l: Vector3, sh_r: Vector3) -> Array:
	if HunterTool.ACTS.has(act_kind):
		return HunterTool.hands(act_kind, tool_ph, sh_l, sh_r)
	var t := act_t
	match act_kind:
		"scan":
			var pat := sin(t * 1.8) * 0.05
			return [sh_l + Vector3(0.1, -0.22 + pat, -0.44), sh_r, 0.0]
		"revive":
			var press := maxf(0.0, sin(t * 6.0)) * 0.05
			return [sh_l + Vector3(0.1, -0.42 - press, -0.32), sh_r + Vector3(-0.1, -0.42 - press, -0.32), 1.0]
		"chest":
			var heave := 0.5 + 0.5 * sin(t * 3.4)
			return [sh_l + Vector3(0.05, -0.45 + heave * 0.22, -0.34), sh_r + Vector3(-0.05, -0.45 + heave * 0.22, -0.34), 1.0]
		"dial":
			var a := t * 2.6
			return [sh_l + Vector3(0.12 + cos(a) * 0.05, -0.12 + sin(a) * 0.05, -0.4), sh_r + Vector3(-0.12 + cos(a + PI) * 0.05, -0.12 + sin(a + PI) * 0.05, -0.4), 1.0]
		"console":
			var c1 := maxf(0.0, sin(t * 4.5)) * 0.07
			var c2 := maxf(0.0, -sin(t * 4.5)) * 0.07
			return [sh_l + Vector3(0.06, -0.2 - c1, -0.38), sh_r + Vector3(-0.06, -0.2 - c2, -0.38), 1.0]
		"lever":
			var p := 0.5 - 0.5 * cos(t * 2.6)
			return [sh_l + Vector3(0.14, 0.05 - p * 0.28, -0.45 + p * 0.22), sh_r + Vector3(-0.14, 0.05 - p * 0.28, -0.45 + p * 0.22), 1.0]
		"windup":
			return [sh_l + Vector3(-0.32, -0.12, -0.05), sh_r + Vector3(0.3, -0.1, -0.05), 0.6]
		"shrine":
			return [sh_l + Vector3(0.13, -0.16, -0.24), sh_r + Vector3(-0.13, -0.16, -0.24), 1.0]
		"beacon":
			return [sh_l + Vector3(0.05, 0.42 + sin(t * 2.0) * 0.03, -0.14), sh_r, 0.0]
		"key":
			var tw := sin(t * 5.0) * 0.04
			return [sh_l + Vector3(0.04, -0.4, -0.18), sh_r + Vector3(-0.04 + tw, -0.36, -0.36), 1.0]
		"loot":
			var r1 := sin(t * 4.0) * 0.08
			return [sh_l + Vector3(0.08, -0.46 + maxf(0.0, r1), -0.34), sh_r + Vector3(-0.08, -0.46 + maxf(0.0, -r1), -0.34), 1.0]
		"rune":
			return [sh_l + Vector3(0.12, -0.06, -0.42), sh_r + Vector3(-0.12, -0.06, -0.42), 1.0]
		"offer":
			return [sh_l + Vector3(0.1, -0.1, -0.36), sh_r + Vector3(-0.1, -0.1, -0.36), 1.0]
	return [sh_l, sh_r, 0.0]

## A support hand that can't reach its grip slides back along the weapon toward the trigger hand.
## Gauntlets are the fists: each one sits in its hand wherever the hand went (a kit move's reach, a heave
## overhead), so a move's pose is never held back by the weapon's aim.
func _fists_to_hands(grip: Vector3) -> void:
	var to_aim := aim.transform.affine_inverse()
	if gun and hand_r:
		gun.position = to_aim * (arm_r.transform * (el_r.transform * hand_r.position)) - gun.basis * grip
	if offhand and hand_l:
		offhand.position = to_aim * (arm_l.transform * (el_l.transform * hand_l.position)) - offhand.basis * grip

## A weapon whose trigger-hand grip is out of the arm's reach (a flip, a long lunge) comes to the hand: it never
## detaches (RIG_STANDARD: the weapon stays in the hand in every state).
func _weapon_to_hand(grip: Vector3) -> void:
	var hand := aim.transform.affine_inverse() * (arm_r.transform * (el_r.transform * hand_r.position))
	var off := hand - gun.transform * grip
	if off.length() > WEAPON_SLACK:
		gun.position += off

func _offhand_to_hand() -> void:
	var hand := aim.transform.affine_inverse() * (arm_l.transform * (el_l.transform * hand_l.position))
	if hand.distance_to(offhand.position) > WEAPON_SLACK:
		offhand.position = hand

static func _reachable(sh: Vector3, want: Vector3, back_to: Vector3, reach: float) -> Vector3:
	if sh.distance_to(want) <= reach:
		return want
	# walk from want toward back_to until it's within reach (a few halvings is plenty)
	var a := want
	var b := back_to
	if sh.distance_to(b) > reach:
		return want
	for i in 6:
		var m := (a + b) * 0.5
		if sh.distance_to(m) > reach: a = m
		else: b = m
	return b

## Two-bone IK: turns the upper arm (pivot) and the forearm (elbow) so the hand reaches t, with the
## elbow bending toward pole. All in the torso's space.
func _ik(piv: Node3D, elbow: Node3D, s: Vector3, tgt: Vector3, pole: Vector3) -> void:
	var d := tgt - s
	var dl := d.length()
	if dl < 0.001:
		d = Vector3(0, -1, 0); dl = 1.0
	var u := d / dl
	var up := UPPER * arm_k
	var fo := FORE * arm_k
	var dist := clampf(dl, absf(up - fo) + 0.02, up + fo - 0.003)
	var ca := clampf((up * up + dist * dist - fo * fo) / (2.0 * up * dist), -1.0, 1.0)
	var sa := sqrt(maxf(0.0, 1.0 - ca * ca))
	var v := pole - u * pole.dot(u)
	if v.length_squared() < 1e-6:
		v = Vector3(0, 0, 1) - u * u.z
	v = v.normalized()
	var e := s + u * (up * ca) + v * (up * sa)
	var hnd := s + u * dist
	var n := v.cross(u).normalized()
	var y1 := (s - e).normalized()
	var b1 := Basis(n, y1, n.cross(y1))
	var y2 := (e - hnd).normalized()
	var b2 := Basis(n, y2, n.cross(y2))
	piv.transform = Transform3D(b1, s)
	elbow.basis = b1.transposed() * b2

## The magazine drops out and goes back in during a reload.
func _reload_mag(r: float) -> void:
	if mag == null or not is_instance_valid(mag):
		return
	if r < 0.2:
		mag.visible = true
		mag.position = mag_base + Vector3(0, -r / 0.2 * 0.35, 0)
	elif r < 0.5:
		mag.visible = false
	elif r < 0.66:
		mag.visible = true
		mag.position = mag_base + Vector3(0, -(1.0 - (r - 0.5) / 0.16) * 0.3, 0)
	else:
		mag.position = mag_base

# ==================================================================== fidgets
## Picks a fidget now and then while standing still: each class and race has its own.
func _tick_fidget(dt: float, still: float, s: Dictionary) -> void:
	# a kit move playing (a held channel pose too) owns the hands: no fidget may override its pose
	var kit_pose := not km.is_empty()
	if fidget != "":
		fidget_t += dt
		var interrupted := still < 0.6 or float(s.get("fired", 99.0)) < 0.5 or String(s.get("emote", "")) != ""
		if fidget_t >= fidget_dur or interrupted or kit_pose:
			fidget = ""
			fidget_wait = 4.0 + _rand() * 7.0
		return
	if idle_t < 2.5 or still < 0.9 or kit_pose or ws.fidgeting():
		return
	fidget_wait -= dt
	if fidget_wait > 0.0:
		return
	var opts := ["look", "shoulders", "weapon", "stretch", "look"]
	if cls == "light": opts.append("bounce")
	if cls == "heavy": opts.append("neck"); opts.append("shoulders")
	opts.append_array(st.get("fidgets", []))
	if bool(s.get("kin_on_shoulder", false)): opts.append("kin"); opts.append("kin")
	match race:
		"owlet": opts.append("owl")
		"scalefolk": opts.append("bob")
		"vulpin": opts.append("tail")
		"sprig": opts.append("bounce")
	fidget = String(opts[int(_rand() * opts.size()) % opts.size()])
	fidget_t = 0.0
	fidget_dur = {"look": 2.6, "shoulders": 1.6, "weapon": 2.0, "stretch": 2.4, "bounce": 1.4, "neck": 1.8, "kin": 2.0, "owl": 2.8, "bob": 1.4, "tail": 1.6}.get(fidget, 2.0)

func _fidget_p() -> float:
	return clampf(fidget_t / maxf(fidget_dur, 0.01), 0.0, 1.0)

## Torso (pitch, yaw, roll) from the fidget.
func _fidget_body() -> Vector3:
	if fidget == "":
		return Vector3.ZERO
	var p := _fidget_p()
	var e := sin(p * PI)
	match fidget:
		"shoulders":
			return Vector3(sin(p * TAU) * 0.06, 0.0, sin(p * TAU * 2.0) * 0.07 * e)
		"stretch":
			return Vector3(0.22 * e, 0.0, 0.0)
		"bounce":
			return Vector3(-0.05 * e, 0.0, 0.0)
		"weapon":
			return Vector3(-0.08 * e, 0.15 * e, 0.0)
		"kin":
			return Vector3(0.0, 0.2 * e, 0.08 * e)
		"tail":
			return Vector3(0.0, sin(p * TAU * 2.0) * 0.12 * e, 0.0)
	return Vector3.ZERO

## Head (pitch, yaw, roll) from the fidget.
func _fidget_head() -> Vector3:
	if fidget == "":
		return Vector3.ZERO
	var p := _fidget_p()
	var e := sin(p * PI)
	match fidget:
		"look":
			# left, a beat, right, back
			return Vector3(0.05 * e, sin(p * TAU) * 0.75 * e, 0.0)
		"owl":
			# an owl's head turns a long, long way round
			return Vector3(0.0, sin(p * TAU) * 1.75 * minf(1.0, e * 1.6), sin(p * TAU * 2.0) * 0.12)
		"neck":
			return Vector3(0.0, 0.0, sin(p * TAU) * 0.45 * e)
		"shoulders":
			return Vector3(0.0, 0.0, -sin(p * TAU * 2.0) * 0.12 * e)
		"bob":
			return Vector3(sin(p * TAU * 3.0) * 0.2 * e, 0.0, 0.0)
		"kin":
			return Vector3(0.12 * e, 0.75 * e, 0.3 * e)
		"weapon":
			return Vector3(0.35 * e, 0.3 * e, 0.0)
		"stretch":
			return Vector3(-0.3 * e, 0.0, 0.0)
	return Vector3.ZERO

## A free hand from the fidget: (x, y, z) target in torso space, w its weight.
func _fidget_hands() -> Vector4:
	if fidget == "":
		return Vector4.ZERO
	var p := _fidget_p()
	var e := sin(p * PI)
	match fidget:
		"kin":
			# a scratch for the kin on the shoulder
			var sc := sin(p * TAU * 4.0) * 0.02
			return Vector4(sh_l.x + 0.12, sh_l.y + 0.08 + sc, -0.12, minf(1.0, e * 2.0))
		"neck":
			return Vector4(sh_l.x + 0.25, sh_l.y + 0.2, 0.05, minf(1.0, e * 2.0) * 0.8)
		"shoulders":
			return Vector4(sh_l.x + 0.15, sh_l.y + 0.02, -0.02, minf(1.0, e * 2.0) * 0.7)
	return Vector4.ZERO

# ==================================================================== emotes
## Torso (pitch, yaw, roll) for an emote.
func _emote_body(et: float) -> Vector3:
	var p := clampf(et / 2.4, 0.0, 1.0)
	match emote_id:
		"wave":
			return Vector3(0.05, 0.2, -0.08 + sin(et * 9.0) * 0.03)
		"laugh":
			return Vector3(0.25 + sin(et * 18.0) * 0.06, 0.0, sin(et * 9.0) * 0.05)
		"gg":
			var b := smoothstep(0.1, 0.4, p) * (1.0 - smoothstep(0.75, 0.95, p))
			return Vector3(-0.85 * b, 0.0, 0.0)
		"thanks":
			var b2 := smoothstep(0.1, 0.35, p) * (1.0 - smoothstep(0.6, 0.85, p))
			return Vector3(-0.4 * b2, 0.0, 0.0)
		"accept":
			return Vector3(-0.05, 0.15, 0.0)
		"refuse":
			return Vector3(0.08, 0.0, 0.0)
		"follow", "omw", "here":
			return Vector3(-0.08, -0.25, 0.0)
		"truce":
			return Vector3(0.12, 0.0, sin(et * 4.0) * 0.06)
	return Vector3.ZERO

## Head (pitch, yaw, roll) for an emote.
func _emote_head(et: float) -> Vector3:
	match emote_id:
		"laugh": return Vector3(-0.35 + sin(et * 18.0) * 0.08, 0.0, 0.0)
		"accept": return Vector3(sin(et * 9.0) * 0.25, 0.0, 0.0)      # a nod
		"refuse": return Vector3(0.05, sin(et * 10.0) * 0.45, 0.0)    # a shake
		"gg": return Vector3(0.3, 0.0, 0.0)
		"wave": return Vector3(-0.08, 0.15, 0.1)
		"truce": return Vector3(-0.3, 0.0, 0.0)
	return Vector3.ZERO

## Hand targets for an emote, into eh_*: l, r (torso space), fl, fr (how far each hand follows), flag.
var eh_l := Vector3.ZERO
var eh_r := Vector3.ZERO
var eh_fl := 0.0
var eh_fr := 0.0
var eh_flag := 0.0
func _emote_hands(et: float) -> void:
	var p := clampf(et / 2.4, 0.0, 1.0)
	eh_l = sh_l; eh_r = sh_r; eh_fl = 0.0; eh_fr = 1.0; eh_flag = 0.0
	match emote_id:
		"wave":
			eh_r = sh_r + Vector3(0.18 + sin(et * 9.0) * 0.1, 0.36, -0.08)
		"accept":
			eh_r = sh_r + Vector3(-0.05, -0.05, -0.36)      # a thumbs-up held out front
		"thanks":
			eh_r = sh_r + Vector3(-0.2, -0.12, -0.14)
		"laugh":
			# hands on the belly
			eh_r = sh_r + Vector3(-0.12, -0.34, -0.18); eh_l = sh_l + Vector3(0.12, -0.34, -0.18); eh_fl = 1.0
		"gg":
			# a bow: one hand to the chest, the other behind the back
			eh_r = sh_r + Vector3(-0.2, -0.14, -0.15); eh_l = sh_l + Vector3(0.1, -0.32, 0.2); eh_fl = 1.0
		"refuse":
			# arms crossed
			eh_r = sh_r + Vector3(-0.3, -0.24, -0.16); eh_l = sh_l + Vector3(0.3, -0.2, -0.2); eh_fl = 1.0
		"follow", "omw", "here":
			# point the way, then beckon
			var beck := smoothstep(0.55, 0.65, p) * sin(et * 10.0) * 0.08
			eh_r = sh_r + Vector3(0.0, 0.08 + beck, -0.44)
		"truce":
			# a white flag waved overhead
			eh_r = sh_r + Vector3(-0.05 + sin(et * 5.0) * 0.12, 0.42, -0.02); eh_flag = 1.0
		_:
			eh_fr = 0.0

## A little white flag in the right hand for the Truce emote.
func _flag(k: float) -> void:
	if flag == null and hand_r:
		flag = Node3D.new(); flag.name = "TruceFlag"
		hand_r.add_child(flag)
		Models.part(flag, Models.cyl(0.012, 0.012, 0.62, 6), Models.toon(Color("8a5a3a")), Vector3(0, 0.24, 0))
		var cloth := Models.part(flag, Models.box(0.26, 0.17, 0.012), Models.toon(Color("f4f1e6")), Vector3(0.14, 0.45, 0))
		cloth.name = "Cloth"
	if flag:
		flag.visible = k > 0.1
		flag.scale = Vector3.ONE * maxf(0.01, k)
		if flag.is_inside_tree():
			flag.global_rotation = Vector3(0, model.global_rotation.y, sin(t * 5.0) * 0.25)
		var c := flag.get_node_or_null("Cloth") as Node3D
		if c: c.rotation.y = sin(t * 11.0) * 0.35

# ==================================================================== cloth
## Skirt, cape, scarf and tail follow through on springs: they stream back when you run, lift
## when you fall, flutter in a glide, and swing with the hips and turns.
func _cloth(dt: float, vel: Vector3, spd: float, mf: float, ms: float, yaw: float, r1: float) -> void:
	var fall := clampf(-vel.y / 9.0, -1.0, 1.0) * (1.0 - glide_k)
	var wind := clampf(spd / 6.0, 0.0, 1.6) + glide_k * 1.0 + dive_k * 1.4
	var flut := sin(t * 13.0 + seed_ph) * 0.5 + sin(t * 21.0 + seed_ph * 2.0) * 0.3
	var turn := wrapf(yaw - torso_yaw_prev, -PI, PI) / dt
	torso_yaw_prev = yaw
	var spin := clampf(face_rate * 0.04 + turn * 0.02, -0.5, 0.5)
	if skirt:
		var wx := -clampf(mf / 6.0, -0.5, 1.0) * 0.28 - fall * 0.2 - glide_k * 0.25 + flut * 0.02 * wind
		var wz := clampf(ms / 6.0, -1.0, 1.0) * 0.18 + sin(ph) * 0.08 * r1 + spin * 0.4
		if snap:
			sk_x = wx; sk_z = wz
		else:
			var a := _spring(sk_x, sk_xv, wx, 110.0, 7.0, dt); sk_x = a.x; sk_xv = a.y
			var b := _spring(sk_z, sk_zv, wz, 110.0, 7.0, dt); sk_z = b.x; sk_zv = b.y
		skirt.rotation = Vector3(clampf(sk_x, -0.55, 0.3), 0.0, clampf(sk_z, -0.35, 0.35))
	if cape:
		var wx2 := -(0.05 + clampf(mf / 6.0, -0.3, 1.2) * 0.55 + fall * 0.5 + glide_k * 0.7 + dive_k * 1.0) - flut * 0.06 * wind
		var wz2 := -clampf(ms / 6.0, -1.0, 1.0) * 0.25 + spin * 0.6
		if snap:
			cp_x = wx2; cp_z = wz2
		else:
			var c := _spring(cp_x, cp_xv, wx2, 70.0, 5.0, dt); cp_x = c.x; cp_xv = c.y
			var d := _spring(cp_z, cp_zv, wz2, 70.0, 5.0, dt); cp_z = d.x; cp_zv = d.y
		cape.rotation = Vector3(clampf(cp_x, -1.5, 0.15), 0.0, clampf(cp_z, -0.5, 0.5))
	if scarf:
		var wx3 := -(clampf(mf / 6.0, -0.3, 1.3) * 0.7 + fall * 0.6 + glide_k * 0.6 + dive_k * 0.9) - flut * 0.1 * wind
		var wy3 := -clampf(ms / 6.0, -1.0, 1.0) * 0.4 + spin * 0.8 + sin(t * 9.0 + seed_ph) * 0.06 * wind
		if snap:
			sc_x = wx3; sc_y = wy3
		else:
			var e := _spring(sc_x, sc_xv, wx3, 55.0, 4.0, dt); sc_x = e.x; sc_xv = e.y
			var f := _spring(sc_y, sc_yv, wy3, 55.0, 4.0, dt); sc_y = f.x; sc_yv = f.y
		scarf.rotation = Vector3(clampf(sc_x, -1.3, 0.3), clampf(sc_y, -0.9, 0.9), 0.0)
	if tail:
		var wag := sin(t * (2.2 + r1 * 6.0) + seed_ph) * (0.18 + r1 * 0.15)
		if fidget == "tail":
			wag += sin(fidget_t * 12.0) * 0.5 * sin(_fidget_p() * PI)
		var stride_swing := 0.5 if arch == "tender" else 0.15      # her trailing tail sways with each quick step
		var wy4 := wag - clampf(ms / 6.0, -1.0, 1.0) * 0.3 + spin * 0.7 - sin(ph) * stride_swing * r1
		var wx4 := clampf(mf / 6.0, -0.5, 1.0) * 0.2 - fall * 0.3 + glide_k * 0.2
		if snap:
			tl_y = wy4; tl_x = wx4
		else:
			var g := _spring(tl_y, tl_yv, wy4, 60.0, 5.0, dt); tl_y = g.x; tl_yv = g.y
			var h := _spring(tl_x, tl_xv, wx4, 60.0, 5.0, dt); tl_x = h.x; tl_xv = h.y
		tail.rotation = Vector3(clampf(tl_x, -0.6, 0.6), clampf(tl_y, -0.9, 0.9), 0.0)
	if wings:
		var flap := sin(t * (4.0 + air_k * 22.0 + glide_k * 10.0) + seed_ph) * (0.08 + air_k * 0.35 + glide_k * 0.2)
		if fidget == "bounce" and race == "sprig":
			flap += sin(fidget_t * 30.0) * 0.4 * sin(_fidget_p() * PI)
		wings.rotation = Vector3(0.0, flap, 0.0)
