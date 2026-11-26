class_name WardenNativeMoves
extends RefCounted
## The kit moves a native Hunter has its own clip for (data "kmoves" in warden_native.json, docs/art/wardens/
## MESHY_NATIVE.md): {kmove: {"clip": name, "then": name, "hold": bool, "hold_from": s, "rate": x, "fade": s,
## "upper": bool}}. The clips come from <art>_clips.glb by name like the slot clips (WardenNative._borrow_clips); a row
## whose clip no file has is dropped. While the kit's move is on the body its clip is laid at the move's own clock
## (state "kmove_t"), so a release move starts at the frame the arrow leaves. Past the clip's end: "hold_from" loops
## the clip from there to its end, "then" loops a second clip, "hold" keeps the last pose (a full-body row's default),
## and an upper row without either is over (the legs' clips show again). An "upper" row is laid on WardenNativeUpper,
## the torso, head and arms over whatever the legs play (walk, run, idle, the air); any other row is a full-body clip
## on the main player that owns the body while it shows.

const FADE := 0.06  # s: the previous clip into a full-body move's, unless the row says
const KEY := "km:%s"  # the name a move's clip has in WardenNative.plays
const THEN := "km:%s>"  # and its "then" loop's

var player: AnimationPlayer
var rows: Dictionary  # kit move id -> its row
var cur := ""  # the full-body move playing now ("" none)
var prev_t := 0.0  # its clock last frame (a clock that goes back is the same move again)
var upper_on := false  # an upper row is on the upper layer


func _init(p: AnimationPlayer, data: Dictionary) -> void:
	player = p
	rows = data.get("kmoves", {})


## The clips by their plays key: {"km:arc_draw": clip name, "km:lw_jet>": its loop}.
func clips() -> Dictionary:
	var out := {}
	for km in rows:
		out[KEY % km] = String(rows[km]["clip"])
		if rows[km].has("then"):
			out[THEN % km] = String(rows[km]["then"])
	return out


## Call once the clips are in the player (`plays` is WardenNative.plays, missing clips dropped): the "then" loops loop.
func ready(plays: Dictionary) -> void:
	for km in rows:
		if plays.has(THEN % km):
			player.get_animation(String(plays[THEN % km])).loop_mode = Animation.LOOP_LINEAR


## Whether the kit's move `km` has a clip here (played out or not): it plays no Meshy swing.
func has_clip(km: String, plays: Dictionary) -> bool:
	return rows.has(km) and plays.has(KEY % km)


## The clip move `km` shows `kt` s into it: {clip, t, upper, fade, km, kt}, or {} when it has none or has played out.
func pick(km: String, kt: float, plays: Dictionary) -> Dictionary:
	if not has_clip(km, plays):
		return {}
	var mv := _pick(rows[km], km, kt, plays)
	if not mv.is_empty():
		mv["km"] = km
		mv["kt"] = kt
	return mv


func _pick(row: Dictionary, km: String, kt: float, plays: Dictionary) -> Dictionary:
	var up := bool(row.get("upper", false))
	var clip := String(plays[KEY % km])
	var fade := float(row.get("fade", FADE))
	var length := player.get_animation(clip).length
	var pos := kt * float(row.get("rate", 1.0))
	var hold := float(row.get("hold_from", -1.0))
	if hold >= 0.0 and pos > hold and length > hold:
		return {"clip": clip, "t": hold + fposmod(pos - hold, length - hold), "upper": up, "fade": fade}
	if pos < length:
		return {"clip": clip, "t": pos, "upper": up, "fade": fade}
	if plays.has(THEN % km):
		var loop := String(plays[THEN % km])
		var t := fposmod(pos - length, player.get_animation(loop).length)
		return {"clip": loop, "t": t, "upper": up, "fade": FADE}
	if bool(row.get("hold", not up)):
		return {"clip": clip, "t": length, "upper": up, "fade": fade}
	return {}


## Lays full-body pick `mv` on the main player at its time; call before the player's advance by `dt`.
func play(mv: Dictionary, dt: float) -> void:
	var clip := String(mv["clip"])
	if mv["km"] != cur or float(mv["kt"]) < prev_t or player.assigned_animation != clip:
		player.play(clip, float(mv["fade"]))
	cur = String(mv["km"])
	prev_t = float(mv["kt"])
	player.speed_scale = 1.0
	player.seek(maxf(float(mv["t"]) - dt, 0.0), false)


## The body is back with the walk clips.
func release() -> void:
	cur = ""


## Hands the upper clip of `mv` (or none: {}, a full-body pick) to `up` at the move's time, and lets go when it is over.
func lay(mv: Dictionary, up: WardenNativeUpper) -> void:
	var on := not mv.is_empty() and bool(mv["upper"])
	if on:
		up.show_at(player.get_animation(String(mv["clip"])), float(mv["t"]))
	elif upper_on:
		up.stop()
	upper_on = on
