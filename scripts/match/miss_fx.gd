class_name MissFx
extends RefCounted
## Where a missed projectile ended, so a miss teaches range and leading: a small puff in the Hunter's ability colour
## where a shot struck terrain or a wall, and a wider, fainter one fading out where it ran out of range.
## Drawn by DJFx's pooled puffs (made at load, at most POOL_CAP alive, the oldest taken back): nothing is made
## in a fight. Every LMB and RMB shot ends through Match._shot_end; Sable's Bola, flown by her kit, calls it too.

const WALL_SIZE := 0.55       # m across a puff on terrain or a wall
const WALL_S := 0.22          # s it lasts
const RANGE_SIZE := 0.9       # m across the fade at max range
const RANGE_S := 0.42         # s it lasts
const RANGE_ALPHA := 0.55     # the max-range fade is fainter than a wall hit
const WALL_BACK := 0.6        # m a wall puff sits back from where the shot stopped, so a rock doesn't hide it
const LIFT := 0.1             # m above the point the shot ended
const SPECK_WHITE := 0.6      # how much of white the puff's specks carry

## A shot ended on nothing: why is "wall" or "expire" (anything else, a dome or a crate, draws its own effect).
static func shot_ended(m: Match, s: Dictionary, at: Vector3, why: String) -> void:
	var x: Dictionary = s["x"]
	if why != "wall" and why != "expire":
		return
	if x.has("boom") or x.has("lob") or x.get("mob", false) or x.get("melee", false):
		return
	var by = s["by"]
	if not is_instance_valid(by):
		return      # the shooter is gone (freed) before its shot ended
	if by is Kin:
		by = (by as Kin).owner_h
	if by is Hunter:
		var v: Vector2 = s["vel"]
		var back := Vector3(v.x, 0, v.y).normalized() * (WALL_BACK if why == "wall" else 0.0)
		puff(m, colour_of(by as Hunter), at - back, why == "wall")

## The Hunter's ability colour (their kit's colour; the class accent for one without a kit).
static func colour_of(h: Hunter) -> Color:
	return AimKit.hero_col(h) if h.ak != null else h.accent()

## One puff at `at`: a wall hit, or the fade at max range. Nothing for other people's shots far from the player
## or while a Hunter's stage owns the look.
static func puff(m: Match, col: Color, at: Vector3, wall: bool) -> void:
	if m == null or m.fx == null or m.fx.own_look:
		return
	var p: Hunter = m.player
	if p != null and Vector2(p.pos.x - at.x, p.pos.z - at.z).length() > AbilityFx.FAR:
		return
	var speck := col.lerp(Color.WHITE, SPECK_WHITE)
	var spot := at + Vector3(0, LIFT, 0)
	if wall:
		DJFx.of(m).puff(spot, col, WALL_SIZE, WALL_S, speck)
	else:
		DJFx.of(m).puff(spot, Color(col, RANGE_ALPHA), RANGE_SIZE, RANGE_S, speck)
