class_name DashPace
extends RefCounted
## A dash is seen, however long the frames take (item 181): it keeps its frames, and its first use doesn't stall.
## Your own dash and Lunge are 0.2-0.5s of sim, so a frame
## of 66ms (15 fps) eats a third of a Lunge and a first-use stall can eat all of it: the body is simply at the end.
## While the local player's dash runs, one drawn frame advances the sim by at most MAX_FRAME_S, so the travel and its
## pose always get their frames; on a slow machine that dash takes longer on the clock instead of being skipped.
## Above 30 fps nothing changes. Not online: the match's time there can't stop for one player's frames (the same
## reason as hitstop in Match._process).

const MAX_FRAME_S := 1.0 / 30.0    # two sim steps
const REHEARSE_QUIET := 12         # frames with no new pipeline end it (Forward+ builds them on background threads) ...
const REHEARSE_MAX := 60           # ... and it's over after this many at most

## The sim time this drawn frame may advance.
static func frame_dt(m: Match, d: float) -> float:
	if m.net_on or m.player == null or m.player.roll_t <= 0.0:
		return d
	return minf(d, MAX_FRAME_S)

## The last of Match.warm_up, behind the loading screen: one of every effect a dash or Lunge draws, on the view and
## settings play starts with, held until the pipelines settle. Forward+, cold cache: Sable's first dash built 15
## pipelines mid-move and Kael's first Lunge 12; with this, none at draw time (--dash-frames-check).
static func rehearse(m: Match) -> void:
	var cam: Camera3D = m.cam
	var at: Vector3 = cam.global_position - cam.global_transform.basis.z * 6.0
	var fx: Fx = m.fx
	fx.burst(at, Color.WHITE, 6)
	fx.dust(at, 4)
	fx.ring(at, 1.5, Color.WHITE)
	fx.flash(at, Color.WHITE)
	fx.spark(at, Vector3.UP, Color.WHITE, 4)
	fx.slash(at, 0.0, 2.0, 1.6, Color.WHITE)
	fx.beam(at, at + Vector3.RIGHT, Color.WHITE)
	fx.ghost(at, 0.0, Color.WHITE, 1.0)
	fx.word(at, "!", Color.WHITE, false)
	var marks: Array = [fx.telegraph_circle(at, 1.5, Color.WHITE),
		fx.telegraph_rect(at, Vector2.UP, 3.0, 1.0, Color.WHITE)]
	HeroVfx.of(m).prewarm(at)
	DJFx.of(m).prewarm(at)
	var built := _pipelines()
	var quiet := 0
	var frames := 0
	while frames < REHEARSE_MAX and quiet < REHEARSE_QUIET:
		await m.get_tree().process_frame
		if not is_instance_valid(m) or not m.is_inside_tree():
			return
		frames += 1
		var now := _pipelines()
		quiet = quiet + 1 if now == built else 0
		built = now
	for mark: Node3D in marks:
		fx.end_telegraph(mark)
	HeroVfx.of(m).prewarm_end()
	DJFx.of(m).prewarm_end()

static func _pipelines() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)
