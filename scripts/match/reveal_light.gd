class_name RevealLight
extends RefCounted
## A rival who gives herself away (shooting or striking 1.2 s, a glove 0.6 s, taking damage 1.0 s: Hunter.reveal_t)
## is seen outside your sight wedge for that long (Match.sees). This lights a soft circle round up to three such
## rivals in view, so the screen shows why she is visible out there; shaders/vis.gdshaderinc draws it (VIS_REVEAL_R),
## numbers in docs/specs/VISION_LOOK.md. On a client the reveal arrives with each rival's state (Net flag 4096).

## The circles the shader draws at once (vis.gdshaderinc).
const SLOTS: Array[StringName] = [&"vis_reveal0", &"vis_reveal1", &"vis_reveal2"]
const FADE := 0.3     # s: the circle fades out over the reveal's last this-much (a client's reveal is refreshed to it)

## How strongly `h`'s circle is lit for you: 0 none, 1 full, fading over the reveal's last FADE s.
static func strength(m: Match, h: Hunter) -> float:
	if h.team == m.player.team or h.unseen or h.out or h.extracted or h.riding:
		return 0.0
	return clampf(h.reveal_t / FADE, 0.0, 1.0)

## Called each frame by Match._update_vision while your sight is drawn.
static func push(m: Match) -> void:
	var n := 0
	for h in m.hunters:
		if n >= SLOTS.size():
			break
		var k := strength(m, h)
		if k <= 0.0:
			continue
		RenderingServer.global_shader_parameter_set(SLOTS[n], Vector3(h.pos.x, h.pos.z, k))
		n += 1
	RenderingServer.global_shader_parameter_set("vis_reveals", float(n))
