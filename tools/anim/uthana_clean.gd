class_name UthanaClean
extends RefCounted
## The Uthana cleanup pass (docs/UTHANA_RANK.md): a raw text-to-motion clip, retargeted onto one of our rigs, baked into
## a game-ready clip on that rig. Every step is data (tools/anim/uthana_recipes.json), run in this order per frame:
##   warp     trim and retime: [src s, dst s(, blend s)] knots, piecewise linear. Two knots on one src s are a hold, a
##            short dst span over a long src span is a snap, two knots on one dst s are a cut (crossfaded over blend s);
##            this is where a move is synced to its kit's timings
##   yaw      the clip turned onto the rig's forward (-Z): "auto" (the shoulders at the first knot), degrees, or
##            {at: src s, from?, to?, ours?: [clip, s]}: the line from bone `from` to bone `to` at `at` turned onto
##            -Z, or onto the same line in our clip (an archer aims side-on), else the shoulders at `at` (a swing is
##            aimed where it lands, not where it starts)
##   in_place the clip moved so the root starts over the rig's origin (travel inside the clip, a lunge, stays)
##   arm_fix  a rest-pose fix per bone (Albert's splayed shield arm): the turn that takes the bone's direction in a
##            calibration pose of the raw clip onto the same bone in our own clip, put on every frame
##   ik       two-bone IK over a window: a hand onto a point on another bone, or round an orbit over it (Breaker's
##            overhead whirl, locked to the kit's spin phase: warden_clips.gd seeks the loop past hold_from by it)
##   carry    a prop bone held where our own clip holds it relative to a hand (the bow string, a nocked arrow)
##   floor    "clamp": nothing goes under the floor; "pin": the lower foot sits on it (idles that float)
const FPS := 30.0
const FLOOR_MIN := 0.04          ## m: the lowest a non-foot bone may sit above the floor
const IK_EASE := 0.08            ## s: an IK window blends in and out over this
## Bones the floor step ignores: props, springs and markers may dip under the floor (a bow tip on a fallen body)
const NOT_BODY := ["spring_", "anchor_", "halo_", "bow", "arrow", "weapon_", "x_weapon", "x_shield", "x_fish", "cape"]

## A motion-only Uthana GLB as an Animation on our Skeleton3D (Godot names node "thigh.L" "thigh_L").
static func load_motion(path: String) -> Animation:
	var n: Node = load(path).instantiate()
	var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
	for t in a.get_track_count():
		var bone := String(a.track_get_path(t)).split(":")[0].get_file()
		if bone.ends_with("_L") or bone.ends_with("_R"):
			bone = bone.left(-2) + "." + bone.right(1)
		a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
	n.free()
	return a

## Bone index -> {rot, pos} track indices of `a` on `sk`.
static func tracks(a: Animation, sk: Skeleton3D) -> Dictionary:
	var out := {}
	for t in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(t)).split(":")[-1])
		if b < 0: continue
		var e: Dictionary = out.get(b, {})
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D: e["rot"] = t
			Animation.TYPE_POSITION_3D: e["pos"] = t
		out[b] = e
	return out

## Local bone transforms of `a` at t (bones it has no track for rest).
static func sample(a: Animation, sk: Skeleton3D, tr: Dictionary, t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in sk.get_bone_count():
		var x := sk.get_bone_rest(b)
		var e: Dictionary = tr.get(b, {})
		var q := a.rotation_track_interpolate(e["rot"], t) if e.has("rot") else x.basis.get_rotation_quaternion()
		var p := a.position_track_interpolate(e["pos"], t) if e.has("pos") else x.origin
		out.append(Transform3D(Basis(q), p))
	return out

static func globals(sk: Skeleton3D, loc: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	for b in sk.get_bone_count():
		var par := sk.get_bone_parent(b)
		g.append(loc[b] if par < 0 else g[par] * loc[b])
	return g

## [src s, weight] pairs at output time t: piecewise linear over the [src, dst(, blend)] knots; inside a cut's blend
## the old span runs on and fades into the new one.
static func warp(knots: Array, t: float) -> Array:
	for i in range(1, knots.size()):
		var a: Array = knots[i - 1]
		var b: Array = knots[i]
		if t < float(b[1]) or i == knots.size() - 1:
			var span := maxf(0.0001, float(b[1]) - float(a[1]))
			var src := lerpf(float(a[0]), float(b[0]), clampf((t - float(a[1])) / span, 0.0, 1.0))
			if i >= 2 and a.size() > 2 and is_equal_approx(float(a[1]), float(knots[i - 2][1])):
				var w := smoothstep(0.0, float(a[2]), t - float(a[1]))
				if w < 1.0: return [[float(knots[i - 2][0]) + (t - float(a[1])), 1.0 - w], [src, w]]
			return [[src, 1.0]]
	return [[float(knots[0][0]), 1.0]]

## The raw pose at output time t (warp's blend of up to two source times).
static func pose(a: Animation, sk: Skeleton3D, tr: Dictionary, knots: Array, t: float) -> Array[Transform3D]:
	var ws := warp(knots, t)
	var p := sample(a, sk, tr, ws[0][0])
	if ws.size() > 1:
		var q := sample(a, sk, tr, ws[1][0])
		for b in p.size(): p[b] = p[b].interpolate_with(q[b], ws[1][1])
	return p

## Facing (game yaw: forward = (-sin, -cos)) of the shoulders in skeleton space.
static func facing(sk: Skeleton3D, g: Array[Transform3D]) -> float:
	var lr := g[sk.find_bone("upper_arm.R")].origin - g[sk.find_bone("upper_arm.L")].origin
	var f := Vector3.UP.cross(lr)
	return atan2(-f.x, -f.z)

## The recipe's yaw (rad) that turns the clip onto -Z.
static func yaw_of(sk: Skeleton3D, ap: AnimationPlayer, raw: Animation, tr: Dictionary, r: Dictionary,
		knots: Array) -> float:
	var y: Variant = r.get("yaw", "auto")
	if y is float or y is int: return deg_to_rad(float(y))
	var at := float(knots[0][0]) if y is String else float(y["at"])
	var g := globals(sk, sample(raw, sk, tr, at))
	if y is Dictionary and y.has("from"):
		var want := 0.0
		if y.has("ours"):
			var oa := ap.get_animation(String(y["ours"][0]))
			want = _heading(sk, globals(sk, sample(oa, sk, tracks(oa, sk), float(y["ours"][1]))), y)
		return want - _heading(sk, g, y)
	return -facing(sk, g)

## The heading of the line from bone y.from to bone y.to.
static func _heading(sk: Skeleton3D, g: Array[Transform3D], y: Dictionary) -> float:
	var f := g[sk.find_bone(String(y["to"]))].origin - g[sk.find_bone(String(y["from"]))].origin
	return atan2(-f.x, -f.z)

## The arm fix: per bone of `chain` (parent first), the turn in its parent's space that takes the raw pose's bone
## direction onto ours (our clip `ours` at 0 s vs the raw calibration clip averaged over its length).
static func arm_fix(sk: Skeleton3D, ap: AnimationPlayer, ours: String, uth: Animation, chain: Array) -> Dictionary:
	var oa := ap.get_animation(ours)
	var og := globals(sk, sample(oa, sk, tracks(oa, sk), 0.0))
	var ut := tracks(uth, sk)
	var fix := {}
	for name: String in chain:
		var b := sk.find_bone(name)
		var c := _child(sk, b)
		var acc := Vector3.ZERO
		var n := 0
		var t := 0.0
		while t < uth.length:
			var loc := sample(uth, sk, ut, t)
			_apply_fix(sk, loc, fix)
			acc += _dir_in_parent(sk, globals(sk, loc), b, c)
			n += 1
			t += 0.25
		var want := _dir_in_parent(sk, og, b, c)
		fix[b] = Quaternion(acc.normalized(), want)
	return fix

static func _child(sk: Skeleton3D, b: int) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) == b: return i
	return -1

static func _dir_in_parent(sk: Skeleton3D, g: Array[Transform3D], b: int, c: int) -> Vector3:
	var par := g[sk.get_bone_parent(b)].basis.orthonormalized()
	return (par.inverse() * (g[c].origin - g[b].origin)).normalized()

static func _apply_fix(sk: Skeleton3D, loc: Array[Transform3D], fix: Dictionary) -> void:
	for b: int in fix:
		loc[b].basis = Basis(fix[b]) * loc[b].basis

## Two-bone IK of chain [upper, fore, hand] onto `target` (skeleton space), weight w; the hand keeps its own turn.
static func two_bone(sk: Skeleton3D, loc: Array[Transform3D], chain: Array[int], target: Vector3, w: float,
		hand_turn := Basis.IDENTITY) -> void:
	var g := globals(sk, loc)
	var s := g[chain[0]].origin
	var e := g[chain[1]].origin
	var h := g[chain[2]].origin
	var la := (e - s).length()
	var lb := (h - e).length()
	var to := target - s
	var d := clampf(to.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var u := to.normalized()
	var pole := (e - s) - u * (e - s).dot(u)
	if pole.length() < 0.0001: pole = Vector3.DOWN - u * u.dot(Vector3.DOWN)
	var v := pole.normalized()
	var ca := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var e2 := s + la * (ca * u + sqrt(1.0 - ca * ca) * v)
	var h2 := s + u * d
	var q1 := Quaternion((e - s).normalized(), (e2 - s).normalized())
	var h1 := e2 + q1 * (h - e)
	var q2 := Quaternion((h1 - e2).normalized(), (h2 - e2).normalized())
	var gu := Basis(Quaternion.IDENTITY.slerp(q1, w)) * g[chain[0]].basis
	var gf := Basis(Quaternion.IDENTITY.slerp(q2 * q1, w)) * g[chain[1]].basis
	var par := g[sk.get_bone_parent(chain[0])].basis
	loc[chain[0]].basis = par.inverse() * gu
	loc[chain[1]].basis = gu.inverse() * gf
	var turn := Basis(Quaternion.IDENTITY.slerp(hand_turn.get_rotation_quaternion(), w))
	loc[chain[2]].basis = gf.inverse() * (turn * g[chain[2]].basis)

## The cleaned clip of recipe `r` (see the header) on `sk`; `ap` holds our own clips (carry), `fix` is arm_fix()'s.
static func clean(sk: Skeleton3D, ap: AnimationPlayer, raw: Animation, r: Dictionary, fix: Dictionary) -> Animation:
	var tr := tracks(raw, sk)
	var knots: Array = r.get("warp", [[0.0, 0.0], [raw.length, raw.length]])
	var length := float(knots[-1][1])
	var turn := Basis(Vector3.UP, yaw_of(sk, ap, raw, tr, r, knots))
	var start := turn * globals(sk, sample(raw, sk, tr, float(knots[0][0])))[0].origin
	var feet := _bones(sk, ["x_foot.", "foot."])
	var rest_g := globals(sk, _rests(sk))
	var foot_y := INF
	for f in feet: foot_y = minf(foot_y, rest_g[f].origin.y)
	var carry := _carry_rel(sk, ap, r.get("carry", []))
	var body_bones: Array[int] = []
	for b in range(1, sk.get_bone_count()):
		if not (b in feet or NOT_BODY.any(func(n: String) -> bool: return sk.get_bone_name(b).begins_with(n))):
			body_bones.append(b)
	var frames: Array = []
	for i in int(round(length * FPS)) + 1:
		var t := minf(i / FPS, length)
		var loc := pose(raw, sk, tr, knots, t)
		loc[0] = Transform3D(turn * loc[0].basis, turn * loc[0].origin)
		if r.get("in_place", true):
			loc[0].origin.x -= start.x
			loc[0].origin.z -= start.z
		_apply_fix(sk, loc, fix)
		for k: Dictionary in r.get("ik", []):
			_ik(sk, loc, k, t)
		_floor(sk, loc, String(r.get("floor", "clamp")), feet, foot_y, body_bones)
		for c: Dictionary in carry:
			_carry(sk, loc, c, t)
		frames.append(loc)
	return _bake(sk, frames, tr, length, carry)

## Window weight: 1 inside [from, to], easing to 0 over IK_EASE outside it.
static func _win(k: Dictionary, t: float) -> float:
	return clampf(minf(t - float(k["from"]) + IK_EASE, float(k["to"]) + IK_EASE - t) / IK_EASE, 0.0, 1.0)

static func _ik(sk: Skeleton3D, loc: Array[Transform3D], k: Dictionary, t: float) -> void:
	var w := _win(k, t) * float(k.get("w", 1.0))
	if w <= 0.0: return
	var chain: Array[int] = []
	for name: String in k["chain"]: chain.append(sk.find_bone(name))
	var g := globals(sk, loc)
	var off: Array = k.get("offset", [0, 0, 0])
	var on := g[sk.find_bone(String(k["on"]))]
	if not k.has("orbit"):
		two_bone(sk, loc, chain, on * Vector3(off[0], off[1], off[2]), w)
		return
	# orbit {r, turns}: round a level circle `offset` above the bone, phase 0 at the rig's right (+X), turning as the
	# kit's spin does (bjorn_fx.gd hold(): PHASE = (turn - facing + PI/2) / TAU); the hand turns with it
	var o: Dictionary = k["orbit"]
	var ph := clampf((t - float(k["from"])) / maxf(0.001, float(k["to"]) - float(k["from"])), 0.0, 1.0)
	var rel := ph * TAU * float(o.get("turns", 1.0)) - PI * 0.5
	var c := on.origin + Vector3(off[0], off[1], off[2])
	var at := c + float(o["r"]) * Vector3(-sin(rel), 0.0, -cos(rel))
	two_bone(sk, loc, chain, at, w, Basis(Vector3.UP, rel + PI * 0.5))

## carry [{bone, hand, ours, at, from, to}]: `bone`'s transform relative to `hand` in our clip `ours` at `at` s.
static func _carry_rel(sk: Skeleton3D, ap: AnimationPlayer, spec: Array) -> Array:
	var out := []
	for c: Dictionary in spec:
		var oa := ap.get_animation(String(c["ours"]))
		var g := globals(sk, sample(oa, sk, tracks(oa, sk), float(c["at"])))
		var b := sk.find_bone(String(c["bone"]))
		var h := sk.find_bone(String(c["hand"]))
		out.append({"b": b, "h": h, "rel": g[h].affine_inverse() * g[b], "from": c["from"], "to": c["to"]})
	return out

static func _carry(sk: Skeleton3D, loc: Array[Transform3D], c: Dictionary, t: float) -> void:
	var w := _win(c, t)
	if w <= 0.0: return
	var g := globals(sk, loc)
	var b: int = c["b"]
	var want: Transform3D = g[c["h"]] * c["rel"]
	var par := g[sk.get_bone_parent(b)]
	loc[b] = loc[b].interpolate_with(par.affine_inverse() * want, w)

## Root height: nothing under the floor ("clamp"), or the lowest foot on it ("pin").
static func _floor(sk: Skeleton3D, loc: Array[Transform3D], mode: String, feet: Array[int], foot_y: float,
		body_bones: Array[int]) -> void:
	var g := globals(sk, loc)
	var low := INF
	for f in feet: low = minf(low, g[f].origin.y - foot_y)
	var body := INF
	for b in body_bones: body = minf(body, g[b].origin.y - FLOOR_MIN)
	var lift := maxf(0.0, -minf(low, body))
	if mode == "pin": lift = -low if low > 0.0 and body - low >= 0.0 else lift
	loc[0].origin.y += lift

static func _rests(sk: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in sk.get_bone_count(): out.append(sk.get_bone_rest(b))
	return out

static func _bones(sk: Skeleton3D, prefixes: Array) -> Array[int]:
	var out: Array[int] = []
	for b in sk.get_bone_count():
		for p: String in prefixes:
			if sk.get_bone_name(b).begins_with(p): out.append(b)
	return out

## Frames (local transforms) into an Animation: a rotation track per bone the raw clip moves (or the fix or IK
## touched), position tracks on the root and on the bones the raw clip moved.
static func _bake(sk: Skeleton3D, frames: Array, tr: Dictionary, length: float, carry: Array) -> Animation:
	var moved := {}
	for c: Dictionary in carry: moved[c["b"]] = true
	var a := Animation.new()
	a.length = length
	for b in sk.get_bone_count():
		var path := NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b))
		var rt := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(rt, path)
		var pt := -1
		if b == 0 or tr.get(b, {}).has("pos") or moved.has(b):
			pt = a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(pt, path)
		for i in frames.size():
			var x: Transform3D = frames[i][b]
			var t := minf(i / FPS, length)
			a.rotation_track_insert_key(rt, t, x.basis.get_rotation_quaternion())
			if pt >= 0: a.position_track_insert_key(pt, t, x.origin)
	return a
