class_name HeroSfx
extends RefCounted
## A Hunter's own version of a shared sound: "<arch>_<kind>" (gunslinger_dash, archer_hurt,
## bulwark_step_wood) when its sound branch made one, else the shared fallback. Kinds the game asks
## for: dash, dash_air, hurt, down, death and step_<surface> (grass, stone, wood, snow; sand, water and
## metal fall back to StepSurface's steps per weight class). Answers are cached per
## name, so footsteps stay cheap. The sound sets are listed in content/sfx/<arch>.json (docs/AUDIO.md).

static var _has := {}          # sound name -> whether audio/ has it

## The sound to play for `kind` on hunter `h`: its own if it has one, else `fallback` ("" plays nothing).
static func of(h: Hunter, kind: String, fallback: String) -> String:
	if h == null or h.arch == "":
		return fallback
	var own := "%s_%s" % [h.arch, kind]
	if not _has.has(own):
		_has[own] = Sfx.ensure(own)
	return own if _has[own] else fallback

## The sound of `h`'s dash starting: <arch>_dash_air with no floor under it, else <arch>_dash, else the shared
## dash. A remote Hunter's grounded flag isn't sent, so its height over the ground says it.
static func dash_name(h: Hunter) -> String:
	var ground_name := of(h, "dash", "dash")
	var in_air := (h.pos.y - h.ground() > Match.HOP_STAND) if h.remote else not h.grounded
	return of(h, "dash_air", ground_name) if in_air else ground_name

## Plays `h`'s own sound for `kind` at the hunter (nothing if it has none): the wordless voice lines.
static func voice(m: Match, h: Hunter, kind: String, vol_db := -4.0) -> void:
	var sname := of(h, kind, "")
	if sname != "":
		m.sfx(sname, h.pos, vol_db)

## Land loudness range: the volume (dB) of a landing at LAND_SOFT_FALL m/s and at LAND_HARD_FALL m/s,
## and the dB a weight class adds (light under medium, heavy over it).
const LAND_SOFT_DB := -17.0
const LAND_HARD_DB := -8.0
const LAND_SOFT_FALL := 4.0
const LAND_HARD_FALL := 20.0
const WEIGHT_DB := {"light": -2.0, "medium": 0.0, "heavy": 3.0}
const KICK_WHO_R := 1.5      # m: a wall hop belongs to the hunter standing this near its spot

## `kind` in `h`'s weight class (jump_heavy, land_light, kick_medium, glide_open_heavy), else `fallback`.
static func weighted(h: Hunter, kind: String, fallback: String) -> String:
	var own := "%s_%s" % [kind, Arch.weight(h.arch) if h != null else ""]
	if not _has.has(own):
		_has[own] = Sfx.ensure(own)
	return own if _has[own] else fallback

## The dB `h`'s weight class adds to its jump and landing (light under medium, heavy over it).
static func class_db(h: Hunter) -> float:
	return float(WEIGHT_DB.get(Arch.weight(h.arch), 0.0))

## How loud a landing is at fall speed `fall` (m/s, positive down): soft at a hop, hard at a long drop.
static func land_db(fall: float) -> float:
	var t := clampf((fall - LAND_SOFT_FALL) / (LAND_HARD_FALL - LAND_SOFT_FALL), 0.0, 1.0)
	return lerpf(LAND_SOFT_DB, LAND_HARD_DB, t)

## The wall hop's push at `at` (every game hears the "whop" event): the nearest hunter's weight class.
static func kick(m: Match, at: Vector3, pitch: float, vol_db: float) -> void:
	var who: Hunter = null
	var best := KICK_WHO_R * KICK_WHO_R
	for h in m.hunters:
		var d2 := (h as Hunter).pos.distance_squared_to(at)
		if d2 < best:
			best = d2
			who = h
	var weight_db := float(WEIGHT_DB.get(Arch.weight(who.arch), 0.0)) if who != null else 0.0
	m.sfx(weighted(who, "kick", "step_stone"), at, vol_db + weight_db, pitch)
