class_name DropPing
extends RefCounted
## Middle mouse in the sky: riding in or falling, it pings the ground under the
## cursor for your squad, where you mean to land. ext/clarity-96's PingInput is the same key everywhere
## once it lands (the "ping" action): then this stands aside and only in_sky stays in use.

static var _was_down := false

## Riding in, falling or gliding down: your Boki is on your back, so the Boki keys are off.
static func in_sky(m: Match) -> bool:
	var p := m.player
	return p != null and not p.out and (p.riding or p.dropping or p.drop_glide)

## Per frame from Match._gather_input.
static func poll(m: Match, map_up: bool) -> void:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not m.paused
	var pressed := down and not _was_down
	_was_down = down
	if pressed and not map_up and in_sky(m) and not InputMap.has_action("ping"):
		place(m, m.get_viewport().get_mouse_position())

## A squad ping on the ground under screen point `sp`. Returns where it landed.
static func place(m: Match, sp: Vector2) -> Vector3:
	var at := ground_at(m, sp)
	m.squad_ping(m.player, at)
	return at

## The camera's ray through `sp` met with the terrain (two refinements, as Match._mouse_aim does).
static func ground_at(m: Match, sp: Vector2) -> Vector3:
	var o := m.cam.project_ray_origin(sp)
	var d := m.cam.project_ray_normal(sp)
	if d.y > -0.0001:
		return m.player.pos         # (the ray runs flat or up: no ground under it)
	var p := o + d * (-o.y / d.y)
	for _i in 2:
		var g := m.world.ground_at(p.x, p.z)
		if g <= World.VOID + 1.0:
			break
		p = o + d * ((g - o.y) / d.y)
	return p
