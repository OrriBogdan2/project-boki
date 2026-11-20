class_name BoxReviveFx
extends RefCounted
## How a deathbox revive reads from across the fight (BoxRevive): a thin tether from the reviver's chest
## to the soul over the box in the reviver's side colour (who), and a core inside the soul that grows
## with the progress (how far). Both go the moment the channel stops; when it completes the soul rises
## a little and fades instead of bursting (DECISIONS: no rings or bursts that aren't gameplay).
## Driven by the box's rev_prog / rev_by while Match._update_box_hums has it on, so the same fx show
## for a local channel and a remote one (BoxRevive.mirror_remote).

const CHEST_Y := 1.0        # m above the reviver's feet where the tether starts
const TETHER_W := 0.06      # m: thin, but still a line from 25 m at match zoom
const CORE_R := 0.24        # m: the full core, just inside the soul's 0.28 m halo
const CORE_MIN := 0.12      # core scale at 0 % so a fresh channel already shows a dot
const RISE_M := 1.4         # m the soul rises on completion
const RISE_S := 0.45        # s the rise takes while it fades

## One step while a box revive is on: places the tether and sizes the core.
static func place(m: Match, b: Dictionary, prog: float) -> void:
	var by = b.get("rev_by")
	var soul := _soul(b)
	if not is_instance_valid(by) or soul == null:
		clear(b)
		return
	var col := SideColor.of(m, by as Hunter)
	var tether := b.get("tether_node") as Node3D
	if tether == null or not is_instance_valid(tether):
		tether = _build_tether(m, col)
		b["tether_node"] = tether
	var from := (by as Hunter).pos + Vector3(0, CHEST_Y, 0)
	var to := soul.global_position
	tether.position = from
	if from.distance_to(to) > 0.05:
		tether.look_at(to, Vector3.UP)
	tether.scale = Vector3(1, 1, from.distance_to(to))
	var core := soul.get_node_or_null("Core") as MeshInstance3D
	if core == null:
		core = Models.part(soul, Models.sphere(CORE_R, 10), Models.glow_mat(col))
		core.name = "Core"
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.visible = true
	core.scale = Vector3.ONE * lerpf(CORE_MIN, 1.0, clampf(prog, 0.0, 1.0))

## The channel stopped (done, interrupted, or the reviver left): tether and core go.
static func clear(b: Dictionary) -> void:
	var tether := b.get("tether_node") as Node3D
	if tether and is_instance_valid(tether):
		tether.queue_free()
	b.erase("tether_node")
	var soul := _soul(b)
	var core := soul.get_node_or_null("Core") if soul else null
	if core:
		(core as Node3D).visible = false

## The revive completed: a full core in the reviver's colour lifts off the box and fades.
static func rise(m: Match, b: Dictionary, by: Hunter) -> void:
	var soul := _soul(b)
	if soul == null or not soul.is_visible_in_tree():
		return
	var col := SideColor.of(m, by)
	var mat := Models.glow_mat(col)
	var orb := Models.part(m, Models.sphere(CORE_R, 10), mat, soul.global_position)
	orb.name = "SoulRise"
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := orb.create_tween().set_parallel()
	var up := tw.tween_property(orb, "position:y", orb.position.y + RISE_M, RISE_S)
	up.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(c: Color): mat.set_shader_parameter("color", c), col, Color(col, 0.0), RISE_S)
	tw.chain().tween_callback(orb.queue_free)

static func _soul(b: Dictionary) -> Node3D:
	var n := b.get("node") as Node3D
	return n.get_node_or_null("Soul") as Node3D if n and is_instance_valid(n) else null

static func _build_tether(m: Match, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "ReviveTether"
	m.add_child(root)
	var mesh := Models.box(TETHER_W, TETHER_W, 1.0)
	var line := Models.part(root, mesh, Models.glow_mat(Color(col, 0.85)), Vector3(0, 0, -0.5))
	line.name = "Line"
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
