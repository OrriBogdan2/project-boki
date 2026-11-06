class_name HeroSfx
extends RefCounted
## A Hunter's own version of a shared sound: "<arch>_<kind>" (gunslinger_dash, archer_hurt,
## bulwark_step_wood) when its sound branch made one, else the shared fallback. Kinds the game asks
## for: dash, hurt, down, death and step_<surface> (grass, stone, wood, snow). Answers are cached per
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

## Plays `h`'s own sound for `kind` at the hunter (nothing if it has none): the wordless voice lines.
static func voice(m: Match, h: Hunter, kind: String, vol_db := -4.0) -> void:
	var sname := of(h, kind, "")
	if sname != "":
		m.sfx(sname, h.pos, vol_db)
