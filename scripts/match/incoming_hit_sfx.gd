class_name IncomingHitSfx
extends RefCounted
## The incoming-hit cue (docs/AUDIO.md): a hit on you plays hit_in from where it came from, on a placed Sfx
## voice so it pans, and a hit from behind or off screen tells you which way to turn. A shot plays from where it
## was fired (Match._shot_apply gives the hit its start as "from"): for a long shot the shooter may have moved
## or be out of sight. Any other hit plays at the attacker. The level follows the damage, not the distance:
## quiet for chip damage, loud for a heavy hit, and a shot from 40 m away is still heard. A flurry is one
## voice: a hit soon after the cue started folds into it and raises it to the flurry's damage so far (a shotgun
## volley sounds like its total); only a hit clearly louder on its own moves the cue to its source and restarts
## it. It takes its voice from the Sfx pool, so the voice cap counts it (a keep cue, content/rules/sfx_voices.json)
## and the downed muffle dulls it. Only hits on you from someone else: never your own hits, damage over time or
## falls (Juice.hit), the Blight or a hazard.

const SOUND := "hit_in"
const CHIP_DMG := 4.0        # damage at or under which the cue is at its quietest (an SMG or minigun round)
const HEAVY_DMG := 36.0      # damage at or over which it is at its loudest (a sniper round)
const CHIP_DB := -14.0       # dB: a chip hit's cue, well under the hurt voice
const HEAVY_DB := -4.0       # dB: a heavy hit's cue, level with the hurt voice
const HEAVY_PITCH := 0.85    # pitch of the heaviest cue (a chip hit plays at 1.0): a bigger hit sounds lower
const GAP_MS := 110          # ms after the cue starts in which further hits are the same flurry
const LOUDER_DB := 1.5       # dB louder than the cue a hit inside the flurry must be on its own to move it

static var _p = null                # the cue's voice
static var _st: AudioStream = null  # the take it plays: the voice is the cue's only while it still plays this
static var _t0 := -1000000          # ms: when the flurry started
static var _sum := 0.0              # the flurry's damage so far

## A hit of d on m.player (Juice.hit), from by, with the hit's options o.
static func hit(m: Match, by: Ent, d: float, o: Dictionary) -> void:
	var from = source(m.player, by, o)
	if from == null:
		return
	var now := Time.get_ticks_msec()
	var live := sounding()
	if live and now - _t0 < GAP_MS:
		_sum += d
		if level(d) < _p.volume_db + LOUDER_DB:
			_p.volume_db = level(_sum)
			return
	else:
		_sum = d
		_t0 = now
	if live:
		_p.stop()       # the flurry stays one voice: the cue moves to this hit
	_p = Sfx.play_voice(SOUND, from, level(_sum), lerpf(1.0, HEAVY_PITCH, _weight(_sum)))
	_st = _p.stream if _p != null else null

## Where a hit on p came from, or null when there is no one to turn to (you, your own Boki, the Blight).
static func source(p: Hunter, by: Ent, o: Dictionary):
	if by == null or by == p or by is Blight or (by is Kin and (by as Kin).owner_h == p):
		return null
	return o.get("from", by.pos)

## The cue's level for d damage in a flurry: CHIP_DB for chip damage up to HEAVY_DB for a heavy hit.
static func level(d: float) -> float:
	return lerpf(CHIP_DB, HEAVY_DB, _weight(d))

static func _weight(d: float) -> float:
	return clampf((d - CHIP_DMG) / (HEAVY_DMG - CHIP_DMG), 0.0, 1.0)

## The cue is still playing on its voice.
static func sounding() -> bool:
	return _p != null and is_instance_valid(_p) and _p.playing and _p.stream == _st

## The cue's voice while it sounds, else null (tooling: --incoming-hit-check).
static func voice():
	return _p if sounding() else null
