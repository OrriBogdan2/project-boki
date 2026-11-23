class_name WardenBeats
extends RefCounted
## A Hero's two result beats (win, lose), played by the results card: the state key "beat" names one, "beat_t" is the
## seconds since it began. The data is the Hero's content/rules/warden_anim/<art>.json "beats": {name: {"clip": an
## existing clip, "loop_from": s}}, and "upper": false (the default) gives the body to the clip, legs too.

const NAMES := ["win", "lose"]

## The beats of this Hero that the .glb can play: {name: {clip, loop_from, upper}}.
static func build(lib: AnimationLibrary, beats: Dictionary) -> Dictionary:
	var out := {}
	for nm in beats:
		var b: Dictionary = beats[nm]
		var clip := String(b.get("clip", ""))
		if clip != "" and lib.has_animation(clip):
			out[nm] = {"clip": clip, "loop_from": float(b.get("loop_from", 0.0)), "upper": bool(b.get("upper", false))}
	return out

## Where in the clip a beat that began `t` seconds ago stands: it plays once, then loops from "loop_from".
static func time_of(length: float, from: float, t: float) -> float:
	if t < length or length - from < 0.05:
		return minf(t, length - 0.001)
	return from + fmod(t - from, length - from)
