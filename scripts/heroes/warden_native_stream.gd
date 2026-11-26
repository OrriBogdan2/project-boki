class_name WardenNativeStream
extends RefCounted
## A held stream of shots on a native Hunter (data "stream" in warden_native.json, Neve's darts): instead of the
## attack clip from its first frame on every shot, the upper body eases into one calm window of the clip and sways
## through it (forth and back, never a jump) for as long as the stream's kit moves keep coming, then eases out.
## {"kmoves": [kit move ids], "clip": slot whose clip it is, "hold": [from s, to s], "rate": x, "gap": s, "fade": s}:
## the window plays at `rate` x its pace, eased in and out over `fade`; the stream ends `gap` s after the last of its
## moves started (the state's kmove_t, which the net carries, so a remote copy sways as the shooter's does).

var d: Dictionary
var u := -1.0  # s into the sway (-1: off)


static func make(data: Dictionary) -> WardenNativeStream:
	if not data.has("stream"):
		return null
	var st := WardenNativeStream.new()
	st.d = data["stream"]
	return st


## Whether the stream holds the upper body this frame (state `s`), and steps its sway by `dt`.
func step(s: Dictionary, dt: float) -> bool:
	var on: bool = String(s.get("kmove", "")) in d["kmoves"] and float(s.get("kmove_t", 99.0)) < float(d["gap"])
	u = maxf(u, 0.0) + dt * float(d.get("rate", 1.0)) if on else -1.0
	return on


## The clip time of the sway now: from the window's start to its end and back.
func at() -> float:
	var hold: Array = d["hold"]
	return float(hold[0]) + pingpong(maxf(u, 0.0), float(hold[1]) - float(hold[0]))
