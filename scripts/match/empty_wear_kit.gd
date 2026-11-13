class_name EmptyWearKit
extends RefCounted
## Draws the Empty's outfit items (EmptyWear) on the bare body. Clothes are shells over the reach of what is already
## on the body (EmptyFit: the void body, then each layer as it goes on), so every slider combination stays inside
## them; gloves and shoes are grown copies of the hand and foot; small parts (bands, soles, brims) sit on top.
## Layers go on bottom, top, shoes, gloves, headwear (EmptyWear.DRESS_ORDER).

const OFF := 0.014                  # m: a garment's surface out from what it covers
const BOOT_SNUG := 0.004            # m: boots and straps: thicker folds into itself at the ankle
const SNUG := 0.008                 # m: leggings, gloves, shoes
const LOOSE := 0.032                # m: baggy trousers
const TRIM := 0.006                 # m: a band stands this far out from the garment it edges
const HC := HeroHair.HC             # the head's centre, in torso space
const JOINTS := ["Knee", "Elbow", "Hand"]       # the rig's joints that hang from another limb part
const HEAD_Y := 0.75                # m up the torso: parts above this are the head's
const NECK_Y := 0.63                # m up the torso: a top's collar
const WAIST_Y := 0.13               # m up the torso: the top of the hips, where trousers and skirts start
const CROTCH_Y := -0.065            # m up the torso: the bottom of the hips
const ARM_TOP := 0.08               # m up the arm's pivot: the top of the shoulder
const THIGH := [0.05, -0.13, -0.29]     # m down the leg: the top, a shorts hem, the knee
const SHIN := [0.07, -0.18]             # m down the knee: the top of the knee, the ankle (above the foot)
const SKIRT_OVAL := 0.86            # a skirt's depth front to back, of its width
## Where a grown copy stops short of the rounded end that sits inside the body (HeroKit's boot and mitten):
const BOOT_TOP := -0.07             # m down the knee: the top of the boot's shaft
const WRIST := 0.055                # m up the hand: the mitten's cuff end
const HOOD_OPEN := 0.12             # of a turn: half the hood's front opening (the front is 0.75 of a turn round)
const SKIRT_ROWS := 12
const SKIRT_ROW := 0.025            # m: half a skirt row at its longest (reach_near's window)
## What each headwear leaves of the hair (HeroHair.human's cover).
const COVERS := {0: "hood", 1: "helm", 2: "hat", 3: "hat", 4: "hat"}

static var _grown := {}             # grown copies of the body's hand and foot meshes (by mesh and offset), the hood

var c: Dictionary
var body: Material
var torso: Node3D
var cover := ""

func _init(ctx: Dictionary, void_mat: Material) -> void:
	c = ctx
	body = void_mat
	torso = ctx["torso"]

## The rig's nodes that carry the body: the torso, each leg and knee, each arm's shoulder, elbow and hand.
static func body_nodes(ctx: Dictionary) -> Array:
	var out: Array = [ctx["torso"]]
	var legs := (ctx["torso"] as Node3D).get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		out.append(legs.get_node(nm))
		out.append(legs.get_node(nm + "/Knee"))
	for sd in ["L", "R"]:
		out.append_array(ctx["arms"][sd])
	return out

## What is on the torso below the head (and on its skirt), in torso space, as EmptyFit parts; mat null takes every
## material, else only parts in it.
static func torso_parts(t: Node3D, mat: Material) -> Array:
	var out: Array = []
	for pc in _parts(t, mat) + _parts(t.get_node("Skirt"), mat, (t.get_node("Skirt") as Node3D).transform):
		if ((pc[1] as Transform3D) * (pc[0] as Mesh).get_aabb()).get_center().y < HEAD_Y:
			out.append(pc)
	return out

static func _parts(n: Node3D, mat: Material, to := Transform3D.IDENTITY) -> Array:
	var out: Array = []
	for ch in n.get_children():
		var mi := ch as MeshInstance3D
		if mi and mi.mesh and (mat == null or mi.material_override == mat):
			out.append([mi.mesh, to * mi.transform])
	return out

## Puts one item on: slot id, item index, its three materials.
func wear(id: String, it: int, mats: Array) -> void:
	match id:
		"top":
			_top(it, mats)
		"bottom":
			_bottom(it, mats)
		"shoes":
			_shoes(it, mats)
		"gloves":
			_gloves(it, mats)
		"head":
			_head(it, mats)

# ------------------------------------------------------------------------------------------ fits
func _torso_fit() -> EmptyFit:
	return EmptyFit.of(torso_parts(torso, null))

## The torso and both legs, in torso space (what a skirt or a long top hangs round).
func _lower_fit() -> EmptyFit:
	var parts := torso_parts(torso, null)
	var to_torso := torso.transform.affine_inverse()
	var legs := torso.get_parent().get_node("Legs") as Node3D
	for nm in ["LegL", "LegR"]:
		var leg := legs.get_node(nm) as Node3D
		var at := to_torso * legs.transform * leg.transform
		parts.append_array(_parts(leg, null, at))
		parts.append_array(_parts(leg.get_node("Knee"), null, at * (leg.get_node("Knee") as Node3D).transform))
	return EmptyFit.of(parts)

func _put(n: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> void:
	Models.part(n, mesh, mat, at)

## A shell round whatever the node carries and the joints next to it (the knee below a thigh, the thigh above a knee),
## from y_top down to y_bot (node space), `off` out.
func _tube(n: Node3D, y_top: float, y_bot: float, off: float, mat: Material, u0 := 0.0, u1 := 1.0) -> void:
	var parts := _parts(n, null)
	for nm in JOINTS:
		var below := n.get_node_or_null(nm) as Node3D
		if below:
			parts.append_array(_parts(below, null, below.transform))
	if String(n.name) in JOINTS:
		var above := n.get_parent() as Node3D
		parts.append_array(_parts(above, null, n.transform.affine_inverse()))
	_put(n, EmptyFit.of(parts).tube(y_top, y_bot, off, u0, u1), mat)

## Both sides: each leg (or its knee, or each arm's joint `joint` 0 shoulder, 1 elbow, 2 hand) gets the shell.
func _legs(knee: bool, y_top: float, y_bot: float, off: float, mat: Material) -> void:
	var legs := torso.get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		_tube(legs.get_node(nm + "/Knee" if knee else nm), y_top, y_bot, off, mat)

func _arms(joint: int, y_top: float, y_bot: float, off: float, mat: Material) -> void:
	for sd in ["L", "R"]:
		_tube(c["arms"][sd][joint], y_top, y_bot, off, mat)

# ------------------------------------------------------------------------------------------ tops
func _top(it: int, mats: Array) -> void:
	var fit := _torso_fit()
	var hems := [0.06, 0.06, 0.06, 0.36, 0.04, 0.0, 0.07]
	var hem: float = hems[it]
	_put(torso, fit.tube(NECK_Y, hem, OFF), mats[0])
	match it:
		0:   # tank: no sleeves, a band at the hem
			_put(torso, fit.tube(hem + 0.025, hem, OFF + TRIM), mats[1])
		1:   # tee: short sleeves, a collar
			_sleeves(mats, false)
			_put(torso, fit.tube(NECK_Y, NECK_Y - 0.03, OFF + TRIM), mats[1])
		2:   # long sleeve: to the wrist, cuffed
			_sleeves(mats, true)
		3:   # crop top: ends under the chest, cap sleeves in the detail colour
			_put(torso, fit.tube(hem + 0.03, hem, OFF + TRIM), mats[1])
			_arms(0, ARM_TOP, -0.03, OFF, mats[2])
		4:   # jerkin: a front panel and a belt
			_sleeves(mats, false)
			_put(torso, fit.tube(0.56, hem + 0.02, OFF + TRIM, 0.63, 0.87), mats[2])
			_put(torso, fit.tube(0.14, 0.09, OFF + TRIM * 2.0), mats[1])
		5:   # hoodie: long sleeves, the hood down round the neck, a front pocket
			_sleeves(mats, true)
			_put(torso, fit.tube(0.26, 0.1, OFF + TRIM, 0.64, 0.86), mats[2])
			_put(torso, fit.tube(NECK_Y + 0.01, NECK_Y - 0.05, OFF + 0.03), mats[0])      # the hood, down
		6:   # tunic: short sleeves, a skirt to mid-thigh, a belt
			_sleeves(mats, false)
			_skirt(hem + 0.02, -0.19, 0.05, mats[0])
			_put(torso, fit.tube(0.13, 0.085, OFF + TRIM * 2.0), mats[1])

## Sleeves over the shoulders: short ones to mid-arm, long ones to the wrist with a cuff in the trim colour.
func _sleeves(mats: Array, long: bool) -> void:
	_arms(0, ARM_TOP, -0.215 if long else -0.1, OFF, mats[0])
	if long:
		_arms(1, 0.07, -0.19, OFF, mats[0])
		_arms(1, -0.16, -0.195, OFF + TRIM, mats[1])

## A skirt from y_top (torso space) down to y_bot, round everything it hangs over: never narrower going down, an
## oval front to back, flaring by `flare` m at the hem. Hung from the "Skirt" pivot, which HunterAnim sways.
func _skirt(y_top: float, y_bot: float, flare: float, mat: Material) -> void:
	var fit := _lower_fit()
	var steps := SKIRT_ROWS
	var wide := PackedFloat32Array()
	var run := 0.0
	for k in steps + 1:
		var y := lerpf(y_top, y_bot, float(k) / steps)
		run = maxf(run, maxf(fit.widest(y), maxf(fit.widest(y - SKIRT_ROW), fit.widest(y + SKIRT_ROW))))
		wide.append(run)
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var y := lerpf(y_top, y_bot, v)
		var f := v * steps
		var k := mini(int(f), steps - 1)
		var r := lerpf(wide[k], wide[k + 1], f - k) + OFF + flare * v * v
		var oval := r / sqrt(pow(cos(th), 2.0) + pow(sin(th) / SKIRT_OVAL, 2.0))
		var rr := maxf(oval, fit.reach_near(th, y, SKIRT_ROW) + OFF)
		return Vector3(cos(th) * rr, y, sin(th) * rr)
	var ao := func(_u: float, v: float) -> float: return lerpf(0.8, 1.0, smoothstep(0.0, 0.3, v))
	var skirt := torso.get_node("Skirt") as Node3D
	_put(skirt, HeroKit.surf("", fn, EmptyFit.COLS, SKIRT_ROWS, ao), mat, -skirt.position)

# ------------------------------------------------------------------------------------------ bottoms
func _bottom(it: int, mats: Array) -> void:
	var off: float = [OFF, OFF, SNUG, LOOSE, OFF, OFF][it]
	var fit := _torso_fit()
	_put(torso, fit.tube(WAIST_Y, CROTCH_Y, off), mats[0])
	_put(torso, fit.tube(WAIST_Y, WAIST_Y - 0.03, off + TRIM), mats[1])
	match it:
		0:   # shorts, hemmed
			_legs(false, THIGH[0], THIGH[1], off, mats[0])
			_legs(false, THIGH[1] + 0.025, THIGH[1], off + TRIM, mats[1])
		1, 2, 3:   # trousers, leggings, baggy trousers (cuffed at the ankle)
			_legs(false, THIGH[0], THIGH[2], off, mats[0])
			_legs(true, SHIN[0], SHIN[1], off, mats[0])
			if it == 3:
				_legs(true, SHIN[1] + 0.035, SHIN[1], off + TRIM, mats[1])
		4:   # skirt to above the knee
			_skirt(WAIST_Y - 0.02, -0.16, 0.06, mats[0])
		5:   # long skirt to the ankle
			_skirt(WAIST_Y - 0.02, -0.35, 0.1, mats[0])

# ------------------------------------------------------------------------------------------ shoes
func _shoes(it: int, mats: Array) -> void:
	var legs := torso.get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		var knee := legs.get_node(nm + "/Knee") as Node3D
		var foot := _body_part(knee, func(mi: MeshInstance3D) -> bool: return not mi.mesh is SphereMesh)
		if foot:
			_shoe(knee, foot, it, mats)

func _shoe(knee: Node3D, foot: MeshInstance3D, it: int, mats: Array) -> void:
	var low := foot.mesh.get_aabb().position.y
	if it != 5:
		_grown_part(knee, foot, SNUG + 0.004, -INF, low + 0.022, mats[1])
	match it:
		0:   # boots to mid-shin
			_grown_part(knee, foot, BOOT_SNUG, -INF, BOOT_TOP, mats[0])
		1:   # shoes, below the ankle
			_grown_part(knee, foot, SNUG, -INF, -0.165, mats[0])
		2:   # tall boots to the knee, a band at the top
			_grown_part(knee, foot, BOOT_SNUG, -INF, BOOT_TOP, mats[0])
			_tube(knee, SHIN[0], -0.09, OFF, mats[0])
			_tube(knee, SHIN[0], SHIN[0] - 0.025, OFF + TRIM, mats[1])
		3:   # sandals: two straps over the foot and one round the shin
			for band in [[-0.2, -0.188], [-0.214, -0.204]]:
				_grown_part(knee, foot, BOOT_SNUG, band[0], band[1], mats[0])
			_tube(knee, -0.12, -0.15, OFF, mats[0])
		4:   # wraps round the shin and over the foot
			for band in [[-0.1, -0.08], [-0.14, -0.12], [-0.18, -0.16], [-0.21, -0.195]]:
				_grown_part(knee, foot, SNUG + 0.002, band[0], band[1], mats[0])
		5:   # clogs: chunky, on a thick sole
			_grown_part(knee, foot, SNUG * 2.0, -INF, -0.17, mats[0])
			_grown_part(knee, foot, SNUG * 2.0 + 0.006, -INF, low + 0.035, mats[1])

# ------------------------------------------------------------------------------------------ gloves
func _gloves(it: int, mats: Array) -> void:
	for sd in ["L", "R"]:
		var hand: Node3D = c["arms"][sd][2]
		var elbow: Node3D = c["arms"][sd][1]
		var palm := _body_part(hand, func(mi: MeshInstance3D) -> bool: return mi.mesh == HeroKit.mitten())
		var thumb := _body_part(hand, func(mi: MeshInstance3D) -> bool: return mi.mesh == HeroKit.thumb())
		if palm == null or thumb == null:
			continue
		match it:
			0, 1, 3:   # mitts; gauntlets with a big flared cuff; long gloves up the forearm
				_grown_part(hand, palm, SNUG, -INF, WRIST, mats[0])
				_grown_part(hand, thumb, SNUG, -INF, INF, mats[0])
				if it == 1:
					_tube(elbow, -0.12, -0.21, OFF + 0.01, mats[1])
				elif it == 3:
					_tube(elbow, 0.0, -0.21, SNUG, mats[0])
				_grown_part(hand, palm, SNUG + TRIM, 0.03, 0.06, mats[1])
			2:   # fingerless: the palm and thumb's root
				_grown_part(hand, palm, SNUG, -0.045, WRIST, mats[0])
				_grown_part(hand, thumb, SNUG, -0.01, INF, mats[0])
				_grown_part(hand, palm, SNUG + TRIM, 0.03, 0.06, mats[1])
			4:   # bracers on the forearm, banded at both ends; the hand bare
				_tube(elbow, -0.06, -0.205, OFF, mats[0])
				_tube(elbow, -0.06, -0.085, OFF + TRIM, mats[1])
				_tube(elbow, -0.18, -0.205, OFF + TRIM, mats[1])
			5:   # wraps: the palm and thumb under two bands, the fingertips bare
				_grown_part(hand, palm, SNUG, -0.07, WRIST, mats[0])
				_grown_part(hand, thumb, SNUG, -INF, INF, mats[0])
				for band in [[-0.02, 0.0], [-0.055, -0.035]]:
					_grown_part(hand, palm, SNUG + TRIM, band[0], band[1], mats[1])
				_tube(elbow, -0.17, -0.2, SNUG, mats[1])

# ------------------------------------------------------------------------------------------ headwear
func _head(it: int, mats: Array) -> void:
	var gear: Node3D = c["gear"]
	cover = COVERS.get(it, "")
	match it:
		0:   # hood, open at the front, with a trimmed edge
			var fit := _head_fit()
			_put(gear, fit.tube(HC.y + 0.32, HC.y - 0.14, OFF, 0.75 + HOOD_OPEN, 1.75 - HOOD_OPEN), mats[0])
			_put(gear, fit.tube(HC.y - 0.09, HC.y - 0.14, OFF + TRIM, 0.75 + HOOD_OPEN, 1.75 - HOOD_OPEN), mats[1])
		1:   # helm, a crest down the middle and a brow band
			var fit := _head_fit()
			_put(gear, fit.tube(HC.y + 0.32, HC.y - 0.07, OFF), mats[0])
			_put(gear, Models.box(0.035, 0.08, 0.34), mats[1], HC + Vector3(0, 0.22, 0.02))
			_put(gear, fit.tube(HC.y + 0.1, HC.y + 0.06, OFF + TRIM), mats[2])
		2:   # wide hat: a low crown, a wide brim, a hat band and a feather
			_hat_crown(gear, mats, 0.08, OFF)
			_put(gear, HeroGear.brim("empty_wide", 0.2, 0.38, 0.03, 0.0, 0.01), mats[0], HC + Vector3(0, 0.08, 0))
			var tip := HC + Vector3(0.2, 0.16, 0.06)
			var quill := [tip, tip + Vector3(0.04, 0.12, 0.08), tip + Vector3(0.05, 0.2, 0.2)]
			_put(gear, HeroKit.lock_mesh("empty_feather", quill, 0.05, 0.25, Vector3.BACK), mats[2])
		3:   # cap with a bill
			_hat_crown(gear, mats, 0.06, OFF)
			_put(gear, Models.box(0.28, 0.018, 0.16), mats[0], HC + Vector3(0, 0.07, -0.29))
			_put(gear, Models.sphere(0.022, 8), mats[2], HC + Vector3(0, 0.33, 0.0))
		4:   # beanie: a knit dome with a folded brim and a pompom
			_hat_crown(gear, mats, 0.03, OFF)
			_put(gear, Models.sphere(0.06, 10), mats[2], HC + Vector3(0, 0.28, 0.0))
		5:   # headband with a knot at the back
			_put(gear, _head_fit().tube(HC.y + 0.1, HC.y + 0.055, SNUG), mats[0])
			_put(gear, Models.sphere(0.035, 8), mats[2], HC + Vector3(0, 0.07, 0.25))

## A crown fitted over the void head from its top down to `brim` m above the head's centre, and a band round its foot.
func _hat_crown(gear: Node3D, mats: Array, brim: float, off: float) -> void:
	var fit := _head_fit()
	var top := HC.y + 0.32
	_put(gear, fit.tube(top, HC.y + brim, off), mats[0])
	_put(gear, fit.tube(HC.y + brim + 0.05, HC.y + brim, off + TRIM), mats[1])

## The void head's reach (its shell, in torso space: the head is moved under HeadPivot after dressing).
func _head_fit() -> EmptyFit:
	var head := torso.get_node("Head") as MeshInstance3D
	var shell := head.get_node("Hollow") as MeshInstance3D
	return EmptyFit.of([[shell.mesh, head.transform * shell.transform]])

# ------------------------------------------------------------------------------------------ grown copies
## The first void part on node that passes `which`.
func _body_part(n: Node3D, which: Callable) -> MeshInstance3D:
	for ch in n.get_children():
		var mi := ch as MeshInstance3D
		if mi and mi.material_override == body and which.call(mi):
			return mi
	return null

## A copy of a body part grown `off` along its normals, only its triangles between heights lo and hi (the part's own
## space), placed where the part is.
func _grown_part(n: Node3D, src: MeshInstance3D, off: float, lo: float, hi: float, mat: Material) -> MeshInstance3D:
	return Models.part(n, grown(src.mesh, off, lo, hi), mat, src.position, src.scale, src.rotation)

## A mesh grown `off` along its normals, keeping the triangles whose corners all lie between heights lo and hi.
static func grown(mesh: Mesh, off: float, lo: float, hi: float) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return ArrayMesh.new()
	var key := "%d|%.4f|%.4f|%.4f" % [mesh.get_instance_id(), off, lo, hi]
	if _grown.has(key):
		return _grown[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrs := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
		var src: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
		for k in vs.size():
			vs[k] += ns[k] * off
		var keep := PackedInt32Array()
		for t in range(0, src.size(), 3):
			var ys := [vs[src[t]].y, vs[src[t + 1]].y, vs[src[t + 2]].y]
			if ys.min() >= lo and ys.max() <= hi:
				keep.append_array([src[t], src[t + 1], src[t + 2]])
		if keep.is_empty():
			continue
		arrs[Mesh.ARRAY_VERTEX] = vs
		arrs[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	var light := out
	_grown[key] = light
	return light
