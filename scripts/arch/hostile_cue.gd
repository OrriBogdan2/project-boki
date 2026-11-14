class_name HostileCue
extends RefCounted
## The threat tell by ear (docs/AUDIO.md): a rival's E, R or X cast sounds like a teammate's, so every one of
## them also plays `hostile_cast`, one short low edge shared by all Hunters, when the caster is on another
## team than yours. You and your allies get none. It is positional like any sound and carries the 30 m of its
## `reach` (content/sfx/ult_cues.json), on the SFX bus and the pool voices like every other one-shot.
## E and R start here from CombatBus.ability_used (Hunter._on_ability_used), so no kit plays it itself; X plays
## it from UltCue. Kits only run in their owner's game, so the cast also sends ["fx", "hcast", nid].

const NAME := "hostile_cast"
const DB := -4.0       # dB: under the cast it rides on, so it colours the cast rather than covering it

## The caster's game: a slot that starts a threat plays the layer here and in every other game.
static func on_used(h: Hunter, slot: String) -> void:
	if not starts_threat(h, slot):
		return
	if h.m.net_on and not h.remote:
		h.m.net_fx(["hcast", h.nid])
	play(h.m.player, h)

## E, and R once: at its fuse, or as it fires when it has none (ArchKit.use_r sends "ult" after a fuse too).
static func starts_threat(h: Hunter, slot: String) -> bool:
	if slot == "ult":
		return h.ak == null or h.ak.fuse_time() <= 0.0
	return slot == "kin" or slot == "ult_fuse"

static func net_in(m: Node, x: Array) -> void:
	var who: Variant = m.ents_by_id.get(String(x[2]), null)
	if who is Hunter and not (who as Hunter).is_local():
		play(m.player, who as Hunter)

## The one rule: only a caster on another team than `you` (your own game's Hunter) is heard as a threat.
static func play(you: Hunter, caster: Hunter) -> void:
	if you != null and caster.team != you.team:
		Sfx.play(NAME, caster.pos, DB)
