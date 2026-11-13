class_name SfxCast
extends RefCounted
## What a Hunter of this game sounds like on the other players' games. A kit runs only where its Hunter is
## owned, so every sound it starts while that Hunter acts (its sim: a cast, its dash, its weapon; a step Match.later
## scheduled from it; where its shot ends) is also sent as a Net fx event, ["fx", "snd", name, x, y, z, dB, pitch],
## and played at the same place there. It follows Sfx.played, so only sounds that really started go out (none
## that Sfx merged or dropped), and a move needs no id to be heard. UltCue sends its own tagged cue; its sounds
## are held back here.

static var _who: Variant = null      # the owned Hunter whose doing this is (see scope); null for anything else
static var _quiet := false           # UltCue's turn: its cue goes out through its own event

static func sim(h: Hunter, dt: float) -> void:
	scope(h)
	h.sim(dt)
	scope(null)

## Whose doing the sounds from here on are: `e` when it is a Hunter of this game in an online match, else nobody.
static func scope(e: Variant) -> void:
	_who = null
	if is_instance_valid(e) and e is Hunter and (e as Hunter).m.net_on and not (e as Hunter).remote:
		_who = e
		if not Sfx.played.is_connected(_started):
			Sfx.played.connect(_started)

## The Hunter now in scope, for work that runs later.
static func current() -> Variant:
	return _who

## Sounds in `play` go out through their own event, not this one.
static func hold_back(play: Callable) -> void:
	_quiet = true
	play.call()
	_quiet = false

static func _started(sname: String, at, vol_db: float, pitch: float) -> void:
	if _who == null or at == null or _quiet:
		return
	var m: Match = _who.m
	m.net_fx(["snd", sname, m._r(at.x), m._r(at.y), m._r(at.z), snappedf(vol_db, 0.1), snappedf(pitch, 0.01)])

static func net_in(m: Match, x: Array) -> void:
	if x.size() >= 8 and String(x[2]).is_valid_filename():
		m.sfx(String(x[2]), Vector3(x[3], x[4], x[5]), float(x[6]), float(x[7]))
