class_name KitWindup
## A wind-up's own sound (a plant, a charge, a whirl) ends the moment its cast is broken (a stun, a knock, a
## channel pulled too far): a sound still rising after the cast is gone tells both players it is coming. The
## kit keeps each wind-up's Sfx voice handles under its slot (ArchKit.windups); broken() fades those voices
## (Sfx.cut, no new player) and gives the caster a small "broken" tick. Checked in --match-audio-check.

const BROKEN := "cast_broken"     # content/sfx/ui.json, tools/gen_sfx_ui.py
const BROKEN_DB := -8.0           # dB: a small UI tick under the INTERRUPTED word, only the caster hears it

## Plays the wind-up sound at the caster and keeps its handle under the slot (with any still ringing).
static func play(k: ArchKit, slot: String, sname: String, vol_db: float, pitch := 1.0) -> void:
	keep(k, slot, Sfx.play(sname, k.h.pos, vol_db, 0.07, pitch))

## Keeps the handle of a wind-up sound something else started (a HeroVfx move's, HeroVfx.last_voice).
static func keep(k: ArchKit, slot: String, handle: int) -> void:
	var held: Array = (k.windups.get(slot, []) as Array).filter(Sfx.sounding)
	held.append(handle)
	k.windups[slot] = held

## The slot's cast was broken: its wind-up sounds stop with a short fade; the caster hears the tick.
static func broken(k: ArchKit, slot: String) -> void:
	for handle: int in k.windups.get(slot, []):
		Sfx.cut(handle)
	k.windups.erase(slot)
	if k.h.is_local():
		Sfx.play(BROKEN, null, BROKEN_DB, 0.04)
