class_name ZoneHint
extends RefCounted
## A one-line tip about a kind of zone ("More teammates in the X fuel it faster!"): it shows the
## first time you enter that kind of zone in a match, fades out after SHOW_T, and comes back only
## on a later entry after REPEAT_GAP. Call alpha() each frame you are in the zone.

const SHOW_T := 4.0        # seconds the tip stays up, the last FADE_T of them fading out
const FADE_T := 1.0
const REPEAT_GAP := 180.0  # seconds after a showing before another entry shows it again
const STILL_IN := 0.5      # no call for this long means you had left the zone

var _start := {}           # kind -> match time its latest showing began
var _seen := {}            # kind -> match time of the latest call

## Opacity 0..1 of the tip for this kind of zone at match time `now`.
func alpha(kind: String, now: float) -> float:
	var entered: bool = now - float(_seen.get(kind, -1e9)) > STILL_IN
	_seen[kind] = now
	if entered and now - float(_start.get(kind, -1e9)) > SHOW_T + REPEAT_GAP:
		_start[kind] = now
	var age: float = now - float(_start.get(kind, -1e9))
	return clampf((SHOW_T - age) / FADE_T, 0.0, 1.0)
