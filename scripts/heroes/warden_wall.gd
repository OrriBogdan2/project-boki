class_name WardenWall
extends RefCounted
## The plant and push of a wall kick or bounce, on every Hero's clips (they have no wall clip: the air plays its rise
## or fall). On the contact frame (WallMoves: the kick's press, the bounce's hit) the leg nearest the wall reaches its
## sole onto the wall face below the hip, holds that spot while the body rises or recoils off it, the leg straightening
## into the push, and lets go as it runs out of leg or the hold ends. A kick eases the leg in over PLANT_IN; a body
## already leaving the wall fast (a bounce, a push-off) has the sole on it that frame. A wall further off than a short
## leg reaches leans the body in. A two-bone solve on the Hero's own leg (thigh length, and knee to sole off its rest
## pose) after the clips, so a small Hero and a big one both meet the wall. The move's timing is the hunter's; this only
## poses the body. Reads the state's wall_ev, wall_age, wall_at and wall_n (WallMoves), vel and grounded.

const PLANT_IN := 0.05       # s: the leg reaches the wall (the contact frame plus three at 60 fps)
const LET_GO := 0.12         # s: the leg eases back to the clip's
const BENT := 0.75           # of the leg's reach: hip to sole at contact (a crouched plant that then pushes)
const FADE_FROM := 0.92      # of the leg's reach: the plant starts to let go once the push stretches it past this
const SOLE_GAP := 0.02       # m (Hero scale): the sole stops this far in front of the face, not in the stone
const POLE_UP := 0.3         # the knee bends forward and a little up
const LEAN_FROM := 0.6       # of the leg's reach: a wall further from the hip than this leans the body in to it
const IMPACT := 3.0          # m/s off the wall at contact (a bounce, a push-off): the sole is on it that frame

var skel: Skeleton3D
var root: Node3D
var thigh: Array = []        # bone index, left then right
var shin: Array = []
var sole_k := 1.3            # knee to sole over hip to knee, in the rest pose
var w := 0.0                 # how much of the plant is shown
var side := 1                # the planted leg (0 left, 1 right)
var point := Vector3.ZERO    # the planted sole, world
var seen_ev := 0
var lean := Vector3.ZERO     # world: the body moved in to the wall while the plant shows (a short leg, a far wall)
var skel_at := Vector3.ZERO  # the skeleton node's own position, under the lean
var leaned := Vector3.ZERO   # world: the lean the skeleton carries now

static func make(model: Node3D, sk: Skeleton3D) -> WardenWall:
	var o := WardenWall.new()
	o.root = model
	o.skel = sk
	for sd in ["L", "R"]:
		o.thigh.append(WardenSkeleton.find(sk, "thigh." + sd))
		o.shin.append(WardenSkeleton.find(sk, "shin." + sd))
	if o.thigh.has(-1) or o.shin.has(-1):
		return null
	# the soles stand on the model's ground in the rest pose: the knee's height is the knee-to-sole reach
	var to_model := WardenGlb.model_xf(model, sk)
	var hip := to_model * sk.get_bone_global_rest(int(o.thigh[1])).origin
	var knee := to_model * sk.get_bone_global_rest(int(o.shin[1])).origin
	o.sole_k = knee.y / maxf(hip.distance_to(knee), 0.01)
	o.skel_at = sk.position
	return o

## One frame, after the clips (and the sway) posed the bones.
func step(dt: float) -> void:
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	var ev := int(s.get("wall_ev", 0))
	var live := float(s.get("wall_age", 99.0)) < WallMoves.POSE_HOLD and not bool(s.get("grounded", true)) \
			and float(s.get("mantle", -1.0)) < 0.0 and not bool(s.get("ledge", false))
	if ev != seen_ev and live:
		_plant(s)
	seen_ev = ev
	var want := 0.0
	if live:      # (how far the leg must reach with the body leaned all the way in)
		var hip := skel.global_transform * _hip() + lean - leaned
		var reach := _thigh_len() * (1.0 + sole_k) * skel.global_transform.basis.get_scale().y
		want = 1.0 - smoothstep(FADE_FROM, 1.0, hip.distance_to(point) / reach)
	w = move_toward(w, want, dt / (PLANT_IN if want > w else LET_GO))
	if lean != Vector3.ZERO:
		leaned = lean * w
		skel.position = skel_at + (skel.get_parent() as Node3D).global_transform.basis.inverse() * leaned
		if w <= 0.0:
			lean = Vector3.ZERO
	if w > 0.0:
		_solve()

## The contact frame: the sole's spot on the wall face, below the hip of the leg nearest the wall, the leg bent.
func _plant(s: Dictionary) -> void:
	var n2: Vector2 = s.get("wall_n", Vector2.ZERO)
	var n := Vector3(n2.x, 0.0, n2.y)
	var xf := skel.global_transform
	if w <= 0.0:
		var l := xf * skel.get_bone_global_pose(int(thigh[0])).origin
		var r := xf * skel.get_bone_global_pose(int(thigh[1])).origin
		side = 0 if l.dot(-n) > r.dot(-n) + 0.01 else 1
	var v: Vector3 = s.get("vel", Vector3.ZERO)
	var impact := v.dot(n) > IMPACT
	var hip := xf * _hip() + Vector3.UP * v.y * (0.0 if impact else PLANT_IN)      # (when the plant is in full)
	var k := xf.basis.get_scale().y
	var face: Vector3 = (s.get("wall_at", Vector3.ZERO) as Vector3) + n * SOLE_GAP * k
	var out := (hip - face).dot(n)
	var reach := _thigh_len() * (1.0 + sole_k) * k
	lean = -n * maxf(out - LEAN_FROM * reach, 0.0)
	out -= lean.length()
	hip += lean
	var bent := BENT * reach
	var drop := sqrt(maxf(bent * bent - out * out, 0.0))
	var across := hip - n * out
	point = Vector3(across.x, hip.y - drop, across.z)      # (on the face: across is the hip moved onto it)
	if impact:
		w = 1.0

## The planted sole, then the two bones that reach it (skeleton space), w of the way from the clip's pose.
func _solve() -> void:
	var inv := skel.global_transform.affine_inverse()
	var ti := int(thigh[side])
	var si := int(shin[side])
	var hip := _hip()
	var a := _thigh_len()
	var b := a * sole_k
	var dv := inv * point - hip
	var dist := clampf(dv.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := dv.normalized()
	var fwd := inv.basis * (root.global_transform.basis * Vector3.FORWARD)
	var pole := fwd.normalized() + inv.basis.y.normalized() * POLE_UP
	pole = (pole - dir * pole.dot(dir)).normalized()
	var along := (dist * dist + a * a - b * b) / (2.0 * dist)
	var knee := hip + dir * along + pole * sqrt(maxf(a * a - along * along, 0.0))
	_aim(ti, knee - hip)
	var kp := skel.get_bone_global_pose(si)
	_aim(si, hip + dir * dist - kp.origin)

## (checks) A leg's sole as posed now, world: its knee to sole reach down the shin.
func sole(leg: int) -> Vector3:
	var knee := skel.get_bone_global_pose(int(shin[leg]))
	var reach := knee.origin.distance_to(skel.get_bone_global_pose(int(thigh[leg])).origin) * sole_k
	return skel.global_transform * (knee.origin + knee.basis.y.normalized() * reach)

## Turns a bone's Y axis (the limb) toward `to`, w of the way from where the clips left it.
func _aim(bi: int, to: Vector3) -> void:
	var p := skel.get_bone_global_pose(bi)
	var arc := Quaternion(p.basis.y.normalized(), to.normalized())
	p.basis = Basis(Quaternion.IDENTITY.slerp(arc, w)) * p.basis
	skel.set_bone_global_pose(bi, p)

func _hip() -> Vector3:
	return skel.get_bone_global_pose(int(thigh[side])).origin

func _thigh_len() -> float:
	return _hip().distance_to(skel.get_bone_global_pose(int(shin[side])).origin)
