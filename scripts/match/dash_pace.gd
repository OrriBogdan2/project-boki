class_name DashPace
extends RefCounted
## A dash is seen, however long the frames take (item 181). Your own dash and Lunge are 0.2-0.5s of sim, so a frame
## of 66ms (15 fps) eats a third of a Lunge and a first-use stall can eat all of it: the body is simply at the end.
## While the local player's dash runs, one drawn frame advances the sim by at most MAX_FRAME_S, so the travel and its
## pose always get their frames; on a slow machine that dash takes longer on the clock instead of being skipped.
## Above 30 fps nothing changes. Not online: the match's time there can't stop for one player's frames (the same
## reason as hitstop in Match._process).

const MAX_FRAME_S := 1.0 / 30.0    # two sim steps

## The sim time this drawn frame may advance.
static func frame_dt(m: Match, d: float) -> float:
	if m.net_on or m.player == null or m.player.roll_t <= 0.0:
		return d
	return minf(d, MAX_FRAME_S)
