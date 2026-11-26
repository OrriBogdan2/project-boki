class_name WardenNativeMoves
extends RefCounted
## The kit moves a native Hunter has its own clip for (data "kmoves" in warden_native.json, docs/art/wardens/
## MESHY_NATIVE.md): {kmove: {"clip": name, "hold_from": s, "rate": x, "fade": s}}. While the kit's move is on the body
## the clip is laid at the move's own clock (state "kmove_t"), so a release move starts at the frame the arrow leaves.
## A clip with "hold_from" loops from there to its end for as long as the move lasts and not a frame longer: the kit
## ends the draw move the moment the hold input goes, and the body falls back to the walk clips. A move with "body":
## true also carries its keyed whole-body channels (HunterAnim.KMOVES "lift" and the spin "fy") on the model's root over
## the clip, for what no Meshy clip keys (Gil sunk to the waist in Ground Swim, his Riptide turn winding up).

const FADE := 0.06  # s: the previous clip into a move's, unless the data says
const KEY := "km:%s"  # the name a move's clip has in WardenNative.plays

var player: AnimationPlayer
var moves: Dictionary
var cur := ""  # the move playing now ("" none)
var prev_t := 0.0  # its clock last frame (a clock that goes back is the same move again)
var bodied := false  # a "body" move moved the root last frame (it goes home once the move ends)


func _init(p: AnimationPlayer, data: Dictionary) -> void:
	player = p
	moves = data.get("kmoves", {})


## The clips by their plays key: {"km:arc_draw": clip name}.
func clips() -> Dictionary:
	var out := {}
	for km in moves:
		out[KEY % km] = String(moves[km]["clip"])
	return out


## Whether this frame's kit move has a clip here (`plays` is WardenNative.plays: a clip no file has is dropped there).
func owns(s: Dictionary, plays: Dictionary) -> bool:
	var km := String(s.get("kmove", ""))
	return moves.has(km) and plays.has(KEY % km)


## Lays the move's clip at its clock; `plays` is WardenNative.plays. Call when owns(s, plays), before the advance.
func play(s: Dictionary, plays: Dictionary, dt: float) -> void:
	var km := String(s.get("kmove", ""))
	var m: Dictionary = moves[km]
	var clip := String(plays[KEY % km])
	var t := float(s.get("kmove_t", 0.0))
	if km != cur or t < prev_t or player.assigned_animation != clip:
		player.play(clip, float(m.get("fade", FADE)))
	cur = km
	prev_t = t
	player.speed_scale = 1.0
	player.seek(maxf(at(m, t, player.get_animation(clip).length) - dt, 0.0), false)


## The root of the Meshy model (`glb`, turned PI to face -Z) under a "body" move: down by its keyed lift, turned by
## its spin. Call every frame after the clips advance; a frame with no such move puts the root back once.
func pose(s: Dictionary, glb: Node3D) -> void:
	var km := String(s.get("kmove", ""))
	if not (moves.has(km) and bool(moves[km].get("body", false))):
		if bodied:
			glb.position.y = 0.0
			glb.rotation.y = PI
			bodied = false
		return
	var k := HunterAnim.km_sample(km, float(s.get("kmove_t", 0.0)))
	glb.position.y = float(k.get("lift", 0.0))
	glb.rotation.y = PI + float(k.get("fy", 0.0))
	bodied = true


## The clip time at move clock `t`: the hold loop wraps from "hold_from", a clip with none stops on its last frame.
static func at(m: Dictionary, t: float, length: float) -> float:
	var pos := t * float(m.get("rate", 1.0))
	var hold := float(m.get("hold_from", -1.0))
	if hold >= 0.0 and pos > hold and length > hold:
		return hold + fposmod(pos - hold, length - hold)
	return minf(pos, length)


## The body is back with the walk clips.
func release() -> void:
	cur = ""
