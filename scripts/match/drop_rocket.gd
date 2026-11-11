class_name DropRocket
extends RefCounted
## Owner 2026-11-11: the drop is a squad mini rocket (docs/decisions/0061-rocket-drop.md). When the drop leader
## launches, the whole squad still aboard the skyship rides one rocket down (a solo rides a one-seat one).
## The leader steers it and everyone else sees where it will hit (DropReticle). Doing nothing lands the squad
## together where it hits. Anyone can jump out early (detach): they free-fall slower than the rocket and can open
## the glider whenever they like to travel further.
##
## Online the leader's machine flies it (the host for a bot leader); everyone else's copy follows the leader's
## synced position. Launch is the "rkt" event; jumping out and the glider ride the hunter flags.

const FALL := 24.0             # m/s, the rocket's top dive speed (a hunter free-falls at Hunter.DIVE_FALL, 13)
const FALL_ACCEL := 20.0       # m/s^2, how fast it reaches FALL after leaving the ship
const SPEED := 16.0            # m/s, top flat speed the leader steers it at
const ACCEL := 20.0            # m/s^2, how fast it answers the leader's keys
const VOID_EJECT_Y := 7.0      # m: still over the abyss at island level, everyone is thrown out with the glider open
const SEAT_GAP := 1.3          # m between the squad as it steps out where the rocket hit
const BOT_LEAD_T := 0.5        # s: a bot leader aims to be over its spot this long before the rocket hits
const STEP := 0.1              # s, projection step for the landing marker
const SEATS := 3               # pegs round the hull: one for each of a squad
const HULL_R := 0.75           # m: the body's radius
const SEAT_Y := -0.7           # m along the body from its middle (local +Y is the tail): the pegs' height
const GRIP_R := 0.9            # m from the axis: the grab bar over each peg
const BAR_PAD := 0.12          # m: the bar runs this much wider than the hands that hold it
const REACH := 0.3             # rig units: how far ahead of the shoulder the ride pose holds the hands (HunterAnim)

var m: Match
var team := 0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0                 # the launch heading: the skydive camera sits behind it (Cam.skydive)
var riders: Array = []         # Hunters aboard
var seats := {}                # Hunter -> its peg (0..2); a seat stays with its rider when another jumps out
var seat0 := 0.0               # peg 0's angle round the hull: on the skydive camera's side once the nose dips
var bars := {}                 # Hunter -> its bar (a node), sized to that rider's hands
var prev := Vector3.ZERO       # last step's position (the node is drawn between the two)
var safe := Vector3.INF        # where it flies with no keys held: a bot leader's spot, or an island off the abyss
var node: Node3D
var done := false

static func launch(match_node: Match, l: Hunter) -> DropRocket:
	var r := DropRocket.new()
	r.m = match_node
	r.team = l.team
	var s: Dictionary = match_node.ship_of(l)
	var dir: Vector3 = s.get("dir", Vector3.FORWARD)
	r.pos = match_node.ship_pos_of(s) + Vector3(0, -2.0, 0)
	r.vel = Vector3(dir.x, 0.0, dir.z) * SPEED * 0.6
	r.yaw = atan2(-dir.x, -dir.z)
	r.seat0 = atan2(-dir.x, -dir.z)
	r.prev = r.pos
	for h in match_node.hunters:
		if h.team == l.team and h.riding and h.rocket == null and is_same(match_node.ship_of(h), s):
			r.seats[h] = mini(r.riders.size(), SEATS - 1)
			r.riders.append(h)
			h.rocket = r
			if not h.remote:
				h.teleport(r.pos)
	r.node = _model(Data.TEAM_COLORS[l.team % Data.TEAM_COLORS.size()], r.seat0, r.riders.size())
	for h in r.riders:
		r.bars[h] = r.node.get_node("Bar%d" % r.seats[h])
	match_node.add_child(r.node)
	r.place(1.0)
	return r

## One step: the leader's machine flies it, everyone else follows the leader; it ends on the ground.
func tick(dt: float) -> void:
	prev = pos
	for h in riders.duplicate():
		if not is_instance_valid(h) or h.out or (h.remote and not h.riding):
			riders.erase(h)      # (left, or jumped out on their own machine: the flags say so)
			if is_instance_valid(h): h.rocket = null
	if riders.is_empty():
		_end()
		return
	var l: Hunter = m.skydrop.leader(team)
	if l != null and l.remote and l.rocket == self and l.riding:
		vel = l.vel
		pos = l.pos
	else:
		var hv := Vector2(vel.x, vel.z).move_toward(_steer(l) * SPEED, ACCEL * dt)
		vel = Vector3(hv.x, move_toward(vel.y, -FALL, FALL_ACCEL * dt), hv.y)
		_fly(dt)
		if done:
			return
	for h in riders:
		if not h.remote:
			h.vel = vel
	place(1.0)

func _fly(dt: float) -> void:
	var w: World = m.world
	var nxt := pos + vel * dt
	nxt.x = clampf(nxt.x, 1.0, w.w - 1.0)
	nxt.z = clampf(nxt.z, 1.0, w.h - 1.0)
	if w.is_void(nxt.x, nxt.z):
		pos = nxt
		if pos.y < VOID_EJECT_Y:
			for h in riders.duplicate():
				if not h.remote: detach(h, false)
			_end()
		return
	var g: float = w.ground_at(nxt.x, nxt.z)
	if nxt.y > g:
		pos = nxt
		return
	# down: a cliff face ahead stops it where it is (it never lands inside the rock)
	var at := Vector3(nxt.x, g, nxt.z)
	if g > pos.y and not w.is_void(pos.x, pos.z):
		at = Vector3(pos.x, w.ground_at(pos.x, pos.z), pos.z)
	_impact(at)

## Where the leader points it: the person's keys, or a bot flying to its spot. Let go (or no one
## steering) over the abyss, it heads for the nearest island, so doing nothing always lands the squad.
func _steer(l: Hunter) -> Vector2:
	var flying := l != null and l.rocket == self
	var mv: Vector2 = l.inp.get("move", Vector2.ZERO) if flying and l.ctrl != "bot" else Vector2.ZERO
	if mv.length() > 0.1:
		safe = Vector3.INF
		return mv
	if flying and l.ctrl == "bot":
		safe = l.ai.get("land", pos)
	elif safe == Vector3.INF and project()["void"]:
		safe = island_near(m.world, pos)
	if safe == Vector3.INF:
		return Vector2.ZERO
	var land := safe
	var to := Vector2(land.x - pos.x, land.z - pos.z)
	var left := maxf(0.2, (pos.y - land.y) / FALL - BOT_LEAD_T)
	return to.normalized() * minf(1.0, to.length() / left / SPEED) if to.length() > 0.5 else Vector2.ZERO

## The nearest island spot to `p` (a spawn or a portal spot): where a drop with no keys drifts to.
static func island_near(w: World, p: Vector3) -> Vector3:
	var best := p
	var bd := 1e9
	for sp in w.spawns + w.portal_spots:
		var d := Vector2(sp.x - p.x, sp.z - p.z).length()
		if d < bd:
			bd = d
			best = sp
	return best

## Jump out early: a free fall (slower than the rocket), the glider any time after. `dive` false opens it at once.
func detach(h: Hunter, dive := true) -> bool:
	if not riders.has(h):
		return false
	if m.skydrop.is_lead(h) and riders.size() > 1:
		m.skydrop.pass_lead(h, riders[1] if riders[0] == h else riders[0])
	riders.erase(h)
	h.rocket = null
	h.riding = false
	h.dropping = true
	h.diving = dive
	h.gliding = true
	h.glide_k = 1.0 if dive else 0.0
	h.grounded = false
	h.drop_from = Vector2(pos.x, pos.z)
	h.teleport(pos)
	h.vel = vel
	if not dive:
		h.vel.y = Hunter.DEPLOY_POP
	if h == m.player:
		m.sfx("whoosh", null, -4.0, 1.2)
	return true

## The rocket hits: a small, clean impact and the squad steps out around it, on open ground.
func _impact(at: Vector3) -> void:
	m.fx.dust(at, 26)
	m.fx.ring(at, 2.6, Color(1, 1, 1, 0.6), 0.3)
	m.sfx("land", at, 0.0, 0.6)
	var taken: Array = []
	for h in riders:
		h.rocket = null
		if h.remote:
			continue
		var spot: Vector3 = m.world.free_spot_near(at, taken, SEAT_GAP, 0.45, 6.0)
		taken.append(spot)
		h.riding = false
		h.teleport(spot)
		h.vel = Vector3.ZERO
		h.grounded = true
		m.on_drop_landed(h)
	riders.clear()
	_end()

func _end() -> void:
	done = true
	for h in riders:
		h.rocket = null
	riders.clear()
	if is_instance_valid(node):
		node.queue_free()

## Draw the body between its last two steps, nose along its course. A rider's render calls it before seating itself.
func place(alpha: float) -> void:
	node.position = prev.lerp(pos, alpha)
	var d := vel.normalized() if vel.length() > 0.5 else Vector3.DOWN
	node.basis = Basis(Quaternion(Vector3.DOWN, d))

## A rider's render: the hull drawn for this frame and the rider standing on its peg.
func seat(h: Hunter, alpha: float) -> void:
	place(alpha)
	if h.anim == null:      # (its first frame: not posed yet)
		h.position = seat_of(h).origin
		return
	var hands := _hands(h)
	var t := seat_of(h, hands.z)
	h.position = t.origin
	h.model.basis = t.basis.scaled_local(h.model.scale)
	_fit_bar(h, hands)

## What the rider's hands do, in world metres on the model's own axes (last frame's pose): x the gap between them,
## y their height over the feet, z how far ahead of the feet they hold, w their middle's offset to the right.
func _hands(h: Hunter) -> Vector4:
	var a := h.anim
	var l: Vector3 = h.model.to_local(seen_at(h, "hand.L", a.hand_l))
	var r: Vector3 = h.model.to_local(seen_at(h, "hand.R", a.hand_r))
	var mid := (l + r) * 0.5
	var s := h.model.scale
	return Vector4(absf(l.x - r.x) * s.x, mid.y * s.y, -mid.z * s.z, mid.x * s.x)

## Where the player sees `bone` of a rider (world): the skinned hero's own bone, else `node`'s point `at`.
static func seen_at(h: Hunter, bone: String, node: Node3D, at := Vector3.ZERO) -> Vector3:
	var sk := h.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bi := WardenSkeleton.find(sk, bone) if sk != null else -1
	if bi < 0:
		return node.global_transform * at
	return sk.global_transform * sk.get_bone_global_pose(bi).origin

## The rider's bar sits where its hands are: its height, its length (the gap plus BAR_PAD), its two posts at the ends.
func _fit_bar(h: Hunter, hands: Vector4) -> void:
	var bar: Node3D = bars[h]
	bar.position.y = SEAT_Y + hands.y
	var half := hands.x * 0.5 + BAR_PAD * 0.5
	var rod := bar.get_node("Len") as Node3D
	rod.scale.x = half * 2.0
	rod.position.x = hands.w
	for i in 2:
		(bar.get_node("Post%d" % i) as Node3D).position.x = hands.w + half * (1.0 if i == 0 else -1.0)

## Where a rider stands: its feet on its peg, facing the hull, the body along the rocket (world frame).
func seat_of(h: Hunter, hands_z := REACH) -> Transform3D:
	var a := seat0 + TAU * float(seats.get(h, 0)) / SEATS
	var out := GRIP_R + REACH * h.model.scale.z
	if h.anim != null:
		out = GRIP_R + lerpf(REACH * h.model.scale.z, hands_z, h.anim.ride_k)
	var b := node.basis * Basis(Vector3.UP, a)
	return Transform3D(b, node.position + node.basis * Vector3(sin(a) * out, SEAT_Y, cos(a) * out))

## Where it hits if it keeps its course: {"at", "void"} (the landing marker everyone aboard sees).
func project() -> Dictionary:
	var w: World = m.world
	var p := pos
	var v := vel
	for i in 200:
		var void_here := w.is_void(p.x, p.z)
		if (void_here and p.y < VOID_EJECT_Y) or (not void_here and p.y <= w.ground_at(p.x, p.z)):
			return {"at": Vector3(p.x, 0.0 if void_here else w.ground_at(p.x, p.z), p.z), "void": void_here}
		v.y = move_toward(v.y, -FALL, FALL_ACCEL * STEP)
		p += v * STEP
	return {"at": Vector3(p.x, 0.0, p.z), "void": true}

## A small rocket, nose along its local -Y (it dives nose first): a body, a nose cone, three fins, a flame, and for
## each of `n` riders a peg with a grab bar over it (pegs start at angle `a0` round the hull, the fins sit between).
static func _model(col: Color, a0: float, n: int) -> Node3D:
	var root := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = HULL_R
	body.bottom_radius = HULL_R
	body.height = 3.4
	_part(root, body, Color("e9edf2"), Vector3.ZERO)
	var nose := CylinderMesh.new()
	nose.top_radius = HULL_R
	nose.bottom_radius = 0.0
	nose.height = 1.4
	_part(root, nose, col, Vector3(0, -2.4, 0))
	for i in SEATS:
		var a := a0 + TAU * (i + 0.5) / SEATS
		var fin := _part(root, BoxMesh.new(), col, Vector3.ZERO)
		fin.scale = Vector3(0.12, 0.9, 1.0)
		fin.rotation.y = a
		fin.position = Vector3(sin(a), 1.2, cos(a)) * 0.85
	for i in n:
		_seat(root, i, a0 + TAU * i / SEATS, col)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.55
	flame.height = 1.6
	var f := _part(root, flame, Color("ffb347"), Vector3(0, 2.5, 0))
	(f.material_override as StandardMaterial3D).emission_enabled = true
	(f.material_override as StandardMaterial3D).emission = Color("ff8a2a")
	return root

## A peg to stand on and a bar on two posts to hold, at angle `a` round the hull. The bar's height and length follow the
## rider's hands (`_fit_bar`); they start at a medium rider's.
static func _seat(root: Node3D, i: int, a: float, col: Color) -> void:
	var radial := Vector3(sin(a), 0, cos(a))
	var peg := _part(root, BoxMesh.new(), Color("3b4350"), radial * (HULL_R + 0.3) + Vector3(0, SEAT_Y - 0.04, 0))
	peg.scale = Vector3(0.5, 0.08, 0.7)
	peg.rotation.y = a
	var bar := Node3D.new()
	bar.name = "Bar%d" % i
	bar.position = radial * GRIP_R + Vector3(0, SEAT_Y + 0.9, 0)
	bar.rotation.y = a
	root.add_child(bar)
	var rod := _part(bar, BoxMesh.new(), col, Vector3.ZERO)
	rod.name = "Len"
	rod.scale = Vector3(0.5, 0.06, 0.06)
	for k in 2:
		var post := _part(bar, BoxMesh.new(), col, Vector3(0.2, 0, -(GRIP_R - HULL_R) * 0.5))
		post.name = "Post%d" % k
		post.scale = Vector3(0.05, 0.05, GRIP_R - HULL_R)

static func _part(root: Node3D, mesh: Mesh, col: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi
