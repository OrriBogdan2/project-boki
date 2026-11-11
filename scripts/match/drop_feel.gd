class_name DropFeel
extends RefCounted
## The opening drop's numbers and motion, from content/rules/drop.json (decision 0049): the skyship's
## height and speed, the launch, the dive you hold, the canopy and its flare, the landing's impact and
## each Hunter's ribbon in the dive. DropLaunch, DropReticle, DropSquad and DropView read the numbers here.

static var _rules: Dictionary = _load()
static var _ship: Dictionary = _rules["ship"]
static var ship_height: float = _ship["height"]
static var ship_speed: float = _ship["speed"]
static var ride_cam_dist: float = _ship["ride_cam_dist"]
static var launch_cam_dist: float = _ship["launch_cam_dist"]
static var plan_s: float = _ship["plan_s"]
static var _launch: Dictionary = _rules["launch"]
static var launch_speed: float = _launch["speed"]
static var launch_lift: float = _launch["lift"]
static var lock_s: float = _launch["lock_s"]
static var separate_after_s: float = _launch["separate_after_s"]
static var _dive: Dictionary = _rules["dive"]
static var dive_fall: float = _dive["fall"]
static var dive_speed: float = _dive["speed"]
static var dive_accel: float = _dive["accel"]
static var _canopy: Dictionary = _rules["canopy"]
static var canopy_fall: float = _canopy["fall"]
static var canopy_speed: float = _canopy["speed"]
static var canopy_accel: float = _canopy["accel"]
static var brake: float = _canopy["brake"]
static var pop_vy: float = _canopy["pop_vy"]
static var open_h: float = _canopy["open_h"]
static var _flare: Dictionary = _rules["flare"]
static var _land: Dictionary = _rules["land"]
static var _ribbon: Dictionary = _rules["ribbon"]
static var _ribbon_fade: GradientTexture2D

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/drop.json"))
	assert(parsed is Dictionary, "content/rules/drop.json did not parse")
	return parsed

## One block of content/rules/drop.json ("view", "cloud", "wind": DropView and GliderSfx).
static func rules(block: String) -> Dictionary:
	return _rules[block]

## The next flat velocity: it ramps toward `mv * top speed` (a no-key drift decelerates, never snaps).
static func steer(hv: Vector2, mv: Vector2, diving: bool, dt: float) -> Vector2:
	var want := mv * top_speed(diving)
	var gain := dive_accel if diving else canopy_accel
	var turning := hv.dot(want) < hv.length_squared() * 0.8      # slowing, reversing or letting go
	return hv.move_toward(want, (brake if turning else gain) * dt)

## Top flat speed, in the dive or under the canopy.
static func top_speed(diving: bool) -> float:
	return dive_speed if diving else canopy_speed

## The next fall speed: the dive's or the canopy's sink, and the canopy's flare over the last few metres.
static func fall_vy(vy: float, diving: bool, above: float, dt: float) -> float:
	var sink := dive_fall if diving else canopy_fall
	var rate: float = (_dive if diving else _canopy)["vy_rate"]
	var goal := -sink
	if not diving and above < _flare["height"] and sink > _flare["fall"]:
		goal = -lerpf(_flare["fall"], sink, clampf(above / _flare["height"], 0.0, 1.0))
		rate = maxf(rate, _flare["rate"])
	return lerpf(vy, goal, 1.0 - exp(-rate * dt))

## Too low to dive at `p`: the canopy opens by itself here.
static func low(w: World, p: Vector3) -> bool:
	if w.is_void(p.x, p.z):
		return p.y < _canopy["void_open_y"]
	return p.y - w.ground_at(p.x, p.z) < open_h

## Every step of a dropping Hunter: dive or canopy. Under the canopy, holding crouch folds it into the
## dive and letting go opens it again. The dive a drop starts in (the launch, a drop with no ship) needs
## no key and lasts until the canopy opens. It opens near the ground unless your own dive key holds it
## shut, and a follower in formation does what their leader does.
static func tick_canopy(h: Hunter) -> void:
	var is_low := low(h.m.world, h.pos)
	var held: bool = h.drop_follow.diving if h.drop_follow != null else bool(h.inp.get("crouch", false))
	if not h.diving:
		h.dive_hold = held and not is_low and not h.grounded
		h.diving = h.dive_hold
	elif (is_low and not holds_shut(h)) or (not held and (h.dive_hold or h.drop_follow != null)):
		h._deploy()

## Your own dive key held over ground: the canopy stays shut below open_h too, for a Hard Landing.
static func holds_shut(h: Hunter) -> bool:
	return h.drop_follow == null and bool(h.inp.get("crouch", false)) and not h.m.world.is_void(h.pos.x, h.pos.z)

## Touchdown. The dive held to the ground is a Hard Landing; any other is soft: dust, a squash and a thud,
## no ring (a ground ring means gameplay), no self-shake (item 50).
static func land(m: Match, h: Hunter) -> void:
	if h.diving and holds_shut(h):
		HardLanding.land(m, h)
		return
	m.fx.dust(h.pos, int(_land["dust"]))
	m.sfx("land", h.pos, -2.0, 0.8)
	h.squash = _land["squash"]

## Per frame, from every Hunter's render: one thin team-colour ribbon trailing a Hunter in the dive, so
## you can read where the other squads are heading. Made on their first dive, freed once they are down.
static func ribbon(h: Hunter) -> void:
	var r: MeshInstance3D = h.get_node_or_null("DiveRibbon")
	if r == null:
		if h.dropping and h.diving:
			_new_ribbon(h)
		return
	if not h.dropping:
		r.queue_free()
		return
	var v := h.net_vel if h.remote else h.vel
	var cam := h.get_viewport().get_camera_3d()
	r.visible = h.diving and not h.out and v.length() > 1.0 and cam != null
	if not r.visible:
		return
	# a quad along the way they came, turned to face the camera
	var back := -v.normalized()
	var mid := h.pos + Vector3(0, 1.0, 0) + back * v.length() * float(_ribbon["trail_s"]) * 0.5
	var side := back.cross(cam.global_position - mid).normalized() * float(_ribbon["width"])
	r.global_transform = Transform3D(Basis(side, back * v.length() * float(_ribbon["trail_s"]), side.cross(back)), mid)

static func _new_ribbon(h: Hunter) -> void:
	if _ribbon_fade == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.85))      # at the Hunter...
		g.set_color(1, Color(1, 1, 1, 0.0))       # ...fading out behind
		_ribbon_fade = GradientTexture2D.new()
		_ribbon_fade.gradient = g
		_ribbon_fade.width = 4
		_ribbon_fade.height = 32
		_ribbon_fade.fill_from = Vector2(0, 1)
		_ribbon_fade.fill_to = Vector2(0, 0)
	var r := MeshInstance3D.new()
	r.name = "DiveRibbon"
	r.top_level = true
	r.mesh = QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	mat.albedo_texture = _ribbon_fade
	r.material_override = mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.visible = false
	h.add_child(r)
