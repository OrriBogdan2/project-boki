class_name BurrRide
extends RefCounted
## A Coin Blast stuck to a placed wall (a raised aegis, a Rink Wall, a rock): it keeps its place on the wall as
## the wall moves and turns, and when the wall breaks or runs out the coin drops to the ground with its fuse
## still running, so it still blasts. The wall is a Verbs wall (`Verbs.walls`), so every placed barrier counts.

const FALL_G := 18.0      # m/s^2: how fast the coin drops once its wall is gone
const REST := 0.2         # m above the ground a dropped coin comes to rest (as a coin stuck to the ground)

## Pins coin `b`, now at `at` with its blast cone pointing `out`, to wall `w` in the wall's own frame.
static func pin(b: Dictionary, w: Dictionary, at: Vector3, out: Vector2) -> void:
	var f := _frame(w)
	var rel: Vector2 = Vector2(at.x, at.z) - (f[0] as Vector2)
	b["on"] = w
	b["spot"] = Vector3(rel.dot(f[1] as Vector2), at.y - float(w["y"]), rel.dot(f[2] as Vector2))
	b["lout"] = Vector2(out.dot(f[1] as Vector2), out.dot(f[2] as Vector2))

## One frame of a stuck coin: ride its wall while the wall stands, else fall.
static func tick(b: Dictionary, walls: Array, world: World, dt: float) -> void:
	if b.has("on"):
		var w: Dictionary = b["on"]
		if walls.has(w):
			var f := _frame(w)
			var s: Vector3 = b["spot"]
			var o: Vector2 = b["lout"]
			var flat: Vector2 = (f[0] as Vector2) + (f[1] as Vector2) * s.x + (f[2] as Vector2) * s.z
			b["pos"] = Vector3(flat.x, float(w["y"]) + s.y, flat.y)
			b["out"] = ((f[1] as Vector2) * o.x + (f[2] as Vector2) * o.y).normalized()
			return
		b.erase("on")
		b["vy"] = 0.0
	if b.has("vy"):
		var p: Vector3 = b["pos"]
		b["vy"] = float(b["vy"]) + FALL_G * dt
		p.y -= float(b["vy"]) * dt
		var floor_y: float = world.ground_at(p.x, p.z) + REST
		if p.y <= floor_y:
			p.y = floor_y
			b.erase("vy")
		b["pos"] = p

## [middle, along, normal] of a wall segment on the flat.
static func _frame(w: Dictionary) -> Array:
	var a: Vector2 = w["a"]
	var along: Vector2 = ((w["b"] as Vector2) - a).normalized()
	return [(a + (w["b"] as Vector2)) * 0.5, along, Vector2(-along.y, along.x)]
