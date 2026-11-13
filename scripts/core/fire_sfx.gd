class_name FireSfx
extends RefCounted
## The shot sound of a held-fire weapon (a rate under HELD_RATE: Vex's rifle, the SMG, the minigun, Neve's darts
## once they run that fast). One sample per shot at 12 shots a second stacks, clips and phases, so a hold is
## shaped here (docs/AUDIO.md):
## - the first shot of a burst is the weapon's base take at full level and with no pitch jitter: the crack
##   that says "it started"; a gap over BURST_GAP_S makes the next shot a first shot again;
## - the rest go round the other takes in turn (never the same one twice in a row), with a small pitch and
##   volume jitter, Sfx.STACK_DB under the first (the level the stacking rule gave a held shot, which
##   dropped shots no longer trigger);
## - one emitter keeps at most VOICES takes sounding; a shot that would be the next one is dropped, so a long
##   hold costs VOICES pool voices per Hunter whatever the rate (a squad of four: 12, the SFX bus budget).
const HELD_RATE := 0.15       # s a round: under this a weapon is held fire (content/weapons/*.json primary.rate)
const BURST_GAP_S := 0.3      # s of quiet that ends a burst
const VOICES := 3             # takes of one emitter sounding at once
const JITTER_DB := 1.0        # dB: the volume of the other shots varies by up to this much either way
const END_PAD_S := 0.06       # s a pool voice keeps playing past its file (the mixer's buffer)
const JITTER_PITCH := 0.03    # the pitch of the other shots varies by up to this share either way

static var _who := {}         # emitter id -> {"last": ms, "rr": next take, "ends": [ms each live take ends]}

## One round of `sname` from emitter `who` (a Hunter's instance id) at `pos`. `rate` is the weapon's s a round;
## `now` is the clock in ms (the check passes its own).
static func shot(who: int, sname: String, pos, vol_db: float, rate: float, now := Time.get_ticks_msec()) -> void:
	if rate >= HELD_RATE or Sfx.take_count(sname) < 2:
		Sfx.play(sname, pos, vol_db)
		return
	var e: Dictionary = _who.get(who, {})
	var ends: Array = e.get("ends", [])
	while not ends.is_empty() and int(ends[0]) <= now:
		ends.pop_front()
	var first := now - int(e.get("last", -100000)) > int(BURST_GAP_S * 1000.0)
	var rr: int = 1 if first else int(e.get("rr", 1))
	if first:
		ends.clear()
	elif ends.size() >= VOICES:
		_who[who] = {"last": now, "rr": rr, "ends": ends}
		return
	var n := Sfx.take_count(sname)
	var take := 0 if first else rr
	ends.append(now + int((Sfx.take_len(sname, take) * (1.0 + JITTER_PITCH) + END_PAD_S) * 1000.0))
	_who[who] = {"last": now, "rr": rr if first else 1 + rr % (n - 1), "ends": ends}
	if _who.size() > 32:
		_prune(now)
	if first:
		Sfx.play(sname, pos, vol_db, 0.0, 1.0, 0.0, take)
	else:
		var jitter := Sfx.rng.randf_range(-JITTER_DB, JITTER_DB)
		Sfx.play(sname, pos, vol_db - Sfx.STACK_DB + jitter, JITTER_PITCH, 1.0, 0.0, take)

static func _prune(now: int) -> void:
	for id in _who.keys():
		if now - int(_who[id]["last"]) > 2000:
			_who.erase(id)
