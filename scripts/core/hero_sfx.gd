class_name HeroSfx
extends RefCounted
## A Hunter's own version of a shared sound: "<arch>_<kind>" (gunslinger_dash, archer_hurt,
## bulwark_step_wood) when its sound branch made one, else the shared fallback. Kinds the game asks
## for: dash, hurt, down, death and step_<surface> (grass, stone, wood, snow). Answers are cached per
## name, so footsteps stay cheap. Basic-attack hits also use it: hit (the attacker's confirm) and taken
## (the victim's thump), see hit_confirm. The sound sets are listed in content/sfx/<arch>.json (docs/AUDIO.md).

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

# random pitch range per hit, on top of the takes, so a string of hits never repeats
const HIT_PITCH := Vector2(0.93, 1.08)
const TAKEN_DB := -5.0                   # the thump of a hit you take, under the confirm (dB)

## A basic attack landed (Match.on_damage): the shooter hears `by`'s own hit confirm at the target (the
## shared hit when `by` has no set, an armour ring pitched up); a crit adds the shared crit on top.
## Ability hits keep the shared hit, their own kit sounds carry them.
static func hit_confirm(m: Match, by: Ent, target: Ent, crit: bool, armor_hit: bool, ability: bool) -> void:
	var pitch := 1.25 if armor_hit else randf_range(HIT_PITCH.x, HIT_PITCH.y)
	var attacker := by as Hunter
	m.sfx("hit" if ability else of(attacker, "hit", "hit"), target.pos, -5.0, pitch)
	if crit:
		m.sfx("crit", target.pos, -8.0, pitch)

## You took a basic attack from another Hunter: that Hunter's own "taken" thump, under the hurt voice.
static func hit_taken(m: Match, by: Ent, ability: bool) -> void:
	var attacker := by as Hunter
	if attacker != null and attacker != m.player and not ability:
		m.sfx(of(attacker, "taken", ""), m.player.pos, TAKEN_DB, randf_range(HIT_PITCH.x, HIT_PITCH.y))
