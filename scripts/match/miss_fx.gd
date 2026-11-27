class_name MissFx
extends RefCounted
## Where a missed projectile ended, so a miss teaches range and leading: a small puff in the Hunter's ability colour
## where a shot struck terrain or a wall, and a wider, fainter one fading out where it ran out of range. A weapon round
## of a Hunter with its own `<arch>_miss` sound (Sparkle's `mage_miss`) also fizzles out there.
## Drawn by DJFx's pooled puffs (made at load, at most POOL_CAP alive, the oldest taken back): nothing is made
## in a fight. Every LMB and RMB shot ends through Match._shot_end; Sable's Bola, flown by her kit, calls it too.

const WALL_SIZE := 0.55  # m across a puff on terrain or a wall
const WALL_S := 0.22  # s it lasts
const RANGE_SIZE := 0.9  # m across the fade at max range
const RANGE_S := 0.42  # s it lasts
const RANGE_ALPHA := 0.55  # the max-range fade is fainter than a wall hit
const WALL_BACK := 0.6  # m a wall puff sits back from where the shot stopped, so a rock doesn't hide it
const LIFT := 0.1  # m above the point the shot ended
const SPECK_WHITE := 0.6  # how much of white the puff's specks carry
const MISS_DB := -8.0  # a Hunter's own miss sound (<arch>_miss): under every hit
const LANDED_MOVE := "slug_hit"  # the move look (content/vfx/<arch>.json) whose "sfx" sound a weapon round landing
const LANDED_KEEP := 64  # volleys remembered by `_landed` (cleared past this)

static var _landed := {}  # "volley|surface" -> true: that volley already sounded on that surface


## A shot ended on nothing: why is "wall" or "expire" (anything else, a dome or a crate, draws its own effect).
static func shot_ended(m: Match, s: Dictionary, at: Vector3, why: String) -> void:
	var x: Dictionary = s["x"]
	if why != "wall" and why != "expire":
		return
	if x.has("boom") or x.has("lob") or x.get("mob", false) or x.get("melee", false):
		return
	var by = s["by"]
	if not is_instance_valid(by):  # (its shooter left the match while the shot flew)
		return
	if by is Kin:
		by = (by as Kin).owner_h
	if is_instance_valid(by) and by is Hunter:
		var v: Vector2 = s["vel"]
		var back := Vector3(v.x, 0, v.y).normalized() * (WALL_BACK if why == "wall" else 0.0)
		puff(m, colour_of(by as Hunter), at - back, why == "wall")
		if not x.has("src") and s["by"] == by:  # the Hunter's own weapon round (not its Boki's): HeroSfx "miss"
			var snd := HeroSfx.of(by as Hunter, "miss", "")
			if snd != "":
				m.sfx(snd, at, MISS_DB)


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


## A Hunter's own weapon round ended on something solid: its "slug_hit" move look (a Hunter with no such move says
## nothing) sounds it by what it struck, as the flags "hunter" (a Hunter or its Boki), "mob" and "wall" (terrain, a
## wall, a crate or a dome); "mine" is on when the player fired it (Match.on_damage already plays your own hit, so the
## look's own-hit sounds say `"unless": "mine"`). A volley sounds once per surface, so a seven-slug scattergun costs
## at most three voices; running out of range or being caught says nothing here. Called by Match._shot_end.
static func shot_landed(m: Match, s: Dictionary, at: Vector3, e: Ent, why: String) -> void:
	var x: Dictionary = s["x"]
	var by = s["by"]
	if (
		x.has("src")
		or x.has("boom")
		or x.has("lob")
		or x.get("mob", false)
		or x.get("melee", false)
	):
		return
	if not is_instance_valid(by) or not by is Hunter or why in ["expire", "caught"]:
		return
	var surface := ""
	if e is Hunter or e is Kin:
		surface = "hunter"
	elif e is Mob:
		surface = "mob"
	elif e == null and (why == "wall" or s.get("prop", false)):
		surface = "wall"
	if surface == "":
		return
	var vol := String(x.get("pg", ""))
	if vol != "":
		var key := "%s|%s" % [vol, surface]
		if _landed.has(key):
			return
		if _landed.size() > LANDED_KEEP:
			_landed.clear()
		_landed[key] = true
	var v: Vector2 = s["vel"]
	HeroVfx.of(m).play(
		by as Hunter,
		LANDED_MOVE,
		at,
		v.normalized() if v.length() > 0.01 else Vector2.RIGHT,
		{surface: true, "mine": by == m.player}
	)
