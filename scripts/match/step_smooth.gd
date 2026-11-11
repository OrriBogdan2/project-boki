class_name StepSmooth
extends RefCounted
## Stepping onto a terrace snaps the body up (Hunter's step_up, so hit boxes and ledge rules stay exact), and a
## short drop is a fall. The drawn Hunter and the camera ease both instead: Hunter.drawn_y chases the body's y
## at a capped speed. Only the drawn node moves, never Hunter.pos (the collision body). FootPlant reads the
## drawn body, so it takes over once the drawn body is within its slack of the ground.

static var cfg := FeelConfig.new()

## After h's render has put its node on the body's y: eases the node's y behind it, never further than the
## lags allow (a mantle or a fall outruns the ease and is drawn where it is). The higher the body is above the
## ground, the less it is eased (a jump or a glide is drawn where it is); a teleport is drawn at once.
static func ease(h: Hunter, dt: float) -> void:
	var want := h.position.y
	var gap := want - h.drawn_y
	if absf(gap) > cfg.step_snap_max:
		h.drawn_y = want
	else:
		var cap := cfg.step_max_speed * dt
		var eased := h.drawn_y + clampf(gap * (1.0 - exp(-cfg.step_ease_rate * dt)), -cap, cap)
		eased = clampf(eased, want - cfg.step_lag_up, want + cfg.step_lag_down)
		var air: float = h.pos.y - h.m.world.ground_at(h.pos.x, h.pos.z)
		h.drawn_y = lerpf(eased, want, smoothstep(cfg.step_free_from, cfg.step_free_to, air))
	h.position.y = h.drawn_y

## Where the camera follows h: its drawn spot, so the view rises with the body and not ahead of it.
static func view(h: Hunter, alpha: float) -> Vector3:
	var p := h.render_pos(alpha)
	p.y = h.position.y
	return p
