class_name DashTrail
extends RefCounted
## The one dash and barge after-image, the same for all 12 Hunters: a short streak of see-through copies of the
## body in the Hunter's own ability colour, laid behind them while the dash runs and gone before it ends. No
## ring, disc or burst: those mean damage or an area (docs/decisions: "Movement and combat feel").

const GAP := 0.05        # s between two copies
const LIFE := 0.2        # s each copy takes to fade; the last one is gone 0.2 s after the dash
const ALPHA := 0.35      # a copy's opacity at first: see-through, so the trail never covers the live body
const BACK := 0.35       # m a copy sits behind the body along its travel

## Called every frame from Hunter.render; `h.ghost_t` counts down to the next copy.
static func tick(h: Hunter, dt: float) -> void:
	if h.roll_t <= 0.0:
		h.ghost_t = 0.0
		return
	h.ghost_t -= dt
	if h.ghost_t > 0.0:
		return
	h.ghost_t = GAP
	VVFx.of(h.m).echo(h, Arch.color(h.arch), LIFE, ALPHA, BACK)
