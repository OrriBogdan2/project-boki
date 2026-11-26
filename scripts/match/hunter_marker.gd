class_name HunterMarker
extends RefCounted
## The hit marker above a Hunter and the balloon it renders on a hit.


## Which marker shows where shots hit you: "balloon" (below a lip), "ring" (high over land), or ""
## when your body itself is the target.
static func hit_marker(h: Hunter) -> String:
	if not h.hittable():
		return ""
	if h.below_lip:
		return "balloon"
	if not h.grounded or h.remote:  # (a remote hunter's grounded flag isn't sent; its height is)
		var g := h.ground()
		if g > World.VOID + 1.0 and h.pos.y - g > Match.HOP_STAND:
			return "ring"
	return ""


## A shot connected: if it hit you through your marker, the marker flashes.
static func marker_hit(h: Hunter) -> void:
	if hit_marker(h) != "":
		h.mk_flash = Hunter.MARKER_FLASH


## The marker's colour as the local player sees it.
static func _marker_col(h: Hunter) -> Color:
	var lp: Ent = h.m.local_player()
	if lp == h:
		return Color(SideColor.you().lerp(Color.WHITE, 0.45), 0.45)  # your own: faint
	if lp and lp.team != h.team:
		return SideColor.foe()  # an enemy
	if lp:
		return Color(SideColor.ally(), Hunter.MARKER_ALLY_A)  # an ally
	return Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]  # watching: team colours


static func _build_marker(h: Hunter) -> void:
	if Hunter.mk_quad == null:
		Hunter.mk_quad = Models.flat_quad(2.0)  # unit-radius ring, scaled to the hit radius
		Hunter.mk_aura = Models.glow_mat(Color(0.75, 0.35, 1.0, 0.4))
		Hunter.mk_string = Models.toon(Color(0.95, 0.95, 0.95), false)
	h.balloon = Node3D.new()
	h.balloon.top_level = true
	h.add_child(h.balloon)
	h.mk_ring = Models.part(h.balloon, Hunter.mk_quad, null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ring")
	h.mk_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.mk_ball = Models.part(h.balloon, Models.sphere(1.0), null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ball")
	h.mk_knot = Models.part(
		h.balloon, Models.cyl(0.03, 0.06, 0.1), null, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Knot"
	)
	h.mk_aura_n = Models.part(
		h.balloon, Models.sphere(1.0), Hunter.mk_aura, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Aura"
	)
	h.mk_aura_n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.mk_str = Models.part(
		h.balloon, Models.cyl(0.012, 0.012, 1.0, 4), Hunter.mk_string, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "String"
	)
	h.mk_str.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Builds the hit-marker balloon hidden, with its materials, under the loading screen (Match.warm_up): built
## lazily, its first showing in a fight compiled its shaders mid-frame (item 94's repeatable hitch).
static func warm_marker(h: Hunter) -> void:
	if h.balloon == null:
		_build_marker(h)
	var mat_list := h._marker_mats(_marker_col(h))
	h.mk_ring.material_override = mat_list["ring"]
	h.mk_ball.material_override = mat_list["ball"]
	h.mk_knot.material_override = mat_list["knot"]
	h.balloon.visible = false


static func _render_balloon(h: Hunter, delta: float) -> void:
	h.mk_flash = maxf(0.0, h.mk_flash - delta)
	var kind_name := hit_marker(h) if h.visible and h.model and h.model.visible else ""
	if kind_name == "":
		if h.balloon:
			h.balloon.visible = false
		h.mk_kind = ""
		return
	if h.balloon == null:
		_build_marker(h)
	h.balloon.visible = true
	var ring := h.mk_ring
	var ball := h.mk_ball
	var knot := h.mk_knot
	var aura := h.mk_aura_n
	var string := h.mk_str
	var hot := h.gliding and h.glide_fuel <= 0.001
	var col := _marker_col(h)
	if kind_name == "ring" and hot:
		col = Color(0.75, 0.35, 1.0, col.a)  # overheated: one more hit spikes you
	var flashing := h.mk_flash > 0.0
	if col != h.mk_col or flashing != h.mk_flashing or kind_name != h.mk_kind:
		var mat_list := h._marker_mats(Color.WHITE if flashing else col)
		ring.material_override = mat_list["ring"]
		ball.material_override = mat_list["ball"]
		knot.material_override = mat_list["knot"]
		h.mk_col = col
		h.mk_flashing = flashing
		h.mk_kind = kind_name
	var hr := h.hit_radius()
	var pop := 1.0 + 0.3 * (h.mk_flash / Hunter.MARKER_FLASH)
	# the stance follows the drawn body (sim heights, offset onto the interpolated position)
	var stance: float = h.m.shot_stance_y(h)
	var at := Vector3(
		h.position.x, stance if kind_name == "balloon" else h.position.y - (h.pos.y - stance), h.position.z
	)
	h.balloon.global_position = at
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3.ONE * hr * pop
	ball.visible = kind_name == "balloon"
	knot.visible = ball.visible
	aura.visible = ball.visible and hot
	if kind_name == "balloon":
		var bob := sin(h.m.time * 3.0) * 0.06
		var c := Vector3(0, Hunter.MARKER_BALL_Y + bob, 0)
		ball.position = c
		ball.scale = Vector3(hr, hr * 1.15, hr) * pop
		knot.position = c - Vector3(0, hr * 1.15 + 0.03, 0)
		aura.position = c
		aura.scale = Vector3.ONE * hr * 1.45 * (1.0 + 0.08 * sin(h.m.time * 9.0))
		# the string runs down from the knot to the hunter hanging below
		var bot_y := knot.position.y - 0.05
		var span := maxf(0.1, at.y + bot_y - (h.position.y + 1.6))
		string.position = Vector3(0, bot_y - span * 0.5, 0)
		string.scale = Vector3(1, span, 1)
	else:
		# a faint tether from the feet down to the ring
		var span := maxf(0.05, h.position.y + 0.1 - at.y)
		string.position = Vector3(0, span * 0.5, 0)
		string.scale = Vector3(1, span, 1)
