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
const SEAT_OUT := 1.0          # m from the rocket's axis to a rider's feet: they cling on outside the hull (0.75)
const SEAT_DOWN := 1.0         # m from the rocket's middle down to a rider's feet, so their heads stay under the fins

var m: Match
var team := 0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0                 # the launch heading: the skydive camera sits behind it (Cam.skydive)
var riders: Array = []         # Hunters aboard
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
	for h in match_node.hunters:
		if h.team == l.team and h.riding and h.rocket == null and is_same(match_node.ship_of(h), s):
			r.riders.append(h)
			h.rocket = r
			if not h.remote:
				h.teleport(r.pos)
	r.node = _model(Data.TEAM_COLORS[l.team % Data.TEAM_COLORS.size()])
	match_node.add_child(r.node)
	r._place_node()
	return r

## One step: the leader's machine flies it, everyone else follows the leader; it ends on the ground.
func tick(dt: float) -> void:
	for h in riders.duplicate():
		if not is_instance_valid(h) or h.out or (h.remote and not h.riding):
			riders.erase(h)      # (left, or jumped out on their own machine: the flags say so)
			if is_instance_valid(h): _unseat(h)
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
	_place_node()

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
	_unseat(h)
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
		_unseat(h)
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
		_unseat(h)
	riders.clear()
	if is_instance_valid(node):
		node.queue_free()

func _place_node() -> void:
	node.position = pos
	var d := vel.normalized() if vel.length() > 0.5 else Vector3.DOWN
	node.basis = Basis(Quaternion(Vector3.DOWN, d))

## A rider is drawn clinging on to the hull, facing it, in a gap between two fins, in the "ride" pose
## (WardenDropPose); glued to the rocket as it is drawn rather than to the hunter's smoothed position.
func seat(h: Hunter) -> void:
	var i := riders.find(h)
	if i < 0 or h.model == null:
		return
	var a := PI / 3.0 + TAU * i / 3.0       # (the fins stand at 0, 120 and 240 degrees round it)
	var out := node.basis * Vector3(sin(a), 0.0, cos(a))
	var up := node.basis.y
	h.model.position = node.position + out * SEAT_OUT - up * SEAT_DOWN - h.position
	h.model.basis = Basis(up.cross(out), up, out) * Basis.from_scale(h.model.scale)

static func _unseat(h: Hunter) -> void:
	h.rocket = null
	if h.model:
		h.model.position = Vector3.ZERO

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

## A small rocket, nose along its local -Y (it dives nose first): a body, a nose cone, three fins and a flame.
static func _model(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.75
	body.bottom_radius = 0.75
	body.height = 2.6
	_part(root, body, Color("e9edf2"), Vector3.ZERO)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.75
	nose.bottom_radius = 0.0
	nose.height = 1.2
	_part(root, nose, col, Vector3(0, -1.9, 0))
	for i in 3:
		var fin := _part(root, BoxMesh.new(), col, Vector3(0, 1.1, 0))
		fin.scale = Vector3(0.12, 0.9, 1.0)
		fin.rotation.y = TAU * i / 3.0
		fin.position = Vector3(sin(fin.rotation.y), 0, cos(fin.rotation.y)) * 0.85 + Vector3(0, 1.1, 0)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.55
	flame.height = 1.6
	var f := _part(root, flame, Color("ffb347"), Vector3(0, 2.2, 0))
	(f.material_override as StandardMaterial3D).emission_enabled = true
	(f.material_override as StandardMaterial3D).emission = Color("ff8a2a")
	return root

static func _part(root: Node3D, mesh: Mesh, col: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi
