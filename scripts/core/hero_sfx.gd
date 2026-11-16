class_name HeroSfx
extends RefCounted
## A Hunter's own version of a shared sound: "<arch>_<kind>" (gunslinger_dash, archer_hurt,
## bulwark_step_wood) when its sound branch made one, else the shared fallback. Kinds the game asks
## for: dash, dash_air, hurt, down, death and step_<surface> (grass, stone, wood, snow). Answers are cached per
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

## The tick of `h`'s left-click weapon landing (its "hit" in content/weapons/<id>.json: hit_gun, hit_bow,
## hit_blade, hit_blunt, hit_magic or hit_thrown), else the shared `hit`. An ability's hit keeps the shared one.
static func hit_tick(h: Hunter, o: Dictionary) -> String:
	if h == null:
		return "hit"
	var lmb: bool = o.get("src", "") == "shot" or o.get("ab", "") in ["primary", "lmb"]
	return String(h.wpn.get("hit", "hit")) if lmb else "hit"

## The sound of `h`'s dash starting, chosen by the floor under it: in the air <arch>_dash_air, else the shared
## dash_air; on the ground <arch>_dash, else the shared dash_ground. A sound picked in the sound tester
## (SfxPicks) for the shared path wins over every Hunter's own. A remote Hunter's grounded flag isn't sent, so
## its height over the ground says it.
static func dash_name(h: Hunter) -> String:
	var in_air := (h.pos.y - h.ground() > Match.HOP_STAND) if h.remote else not h.grounded
	var shared := "dash_air" if in_air else "dash_ground"
	if SfxPicks.active(shared):
		return shared
	return of(h, "dash_air" if in_air else "dash", shared)

## Plays `h`'s own sound for `kind` at the hunter (nothing if it has none): the wordless voice lines.
static func voice(m: Match, h: Hunter, kind: String, vol_db := -4.0) -> void:
	var sname := of(h, kind, "")
	if sname != "":
		m.sfx(sname, h.pos, vol_db)
