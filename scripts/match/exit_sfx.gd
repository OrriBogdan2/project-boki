class_name ExitSfx
extends RefCounted
## Exit sounds (docs/AUDIO.md): a tick a second for the last COUNT_S s before a skiff comes in, leaves or an
## uplink lift shuts (a squad's own exit ticks at UI level, a rival's from where it stands), the skiff's
## thrum while you stand on its deck, a cancel cue when you leave it and the casting-off sting.

const COUNT_S := 10             # s: the last seconds that tick, once each
const TICK_PITCH := Vector2(1.0, 1.5)   # first and last tick of the countdown
const TICK_DB := -2.0
const BOARD_DB := -8.0          # dB: the deck thrum sits under the fight
const CANCEL_DB := -2.0
const STING_DB := -2.0

static var record := false      # --extract-check: log every cue in `heard` as [name, positional]
static var heard: Array = []

static func _play(m: Match, sname: String, at, db: float, pitch := 1.0) -> void:
	if record:
		heard.append([sname, at != null])
	if at == null:
		Sfx.play(sname, null, db, 0.0, pitch)
	else:
		m.sfx(sname, at, db, pitch)

static func _mine(m: Match, x: Dictionary) -> bool:
	return m.player != null and int(x.get("team", -1)) == m.player.team

## One tick a second, rising in pitch, for the last COUNT_S seconds of the timer `t` of exit `x`
## (x["count"] remembers the last second ticked).
static func countdown(m: Match, x: Dictionary, at: Vector3, t: float) -> void:
	var sec := ceili(t)
	if sec > COUNT_S or sec < 1 or sec == int(x.get("count", 0)):
		return
	x["count"] = sec
	var pitch := lerpf(TICK_PITCH.y, TICK_PITCH.x, float(sec - 1) / float(COUNT_S - 1))
	_play(m, "warn_tick", null if _mine(m, x) else at, TICK_DB, pitch)

## Every boarding tick: the thrum holds while the local hunter is on the deck; stepping off, going down or
## dying with the skiff still at the pier breaks it.
static func boarding(m: Match, x: Dictionary) -> void:
	var key := "board%d" % int(x["i"])
	var on: bool = m.player != null and m.player in x["aboard"]
	if on:
		if record and not Sfx.loop_on(key):
			heard.append(["board_hum", false])
		Sfx.loop_hold(key, "board_hum", null, BOARD_DB)
	elif x.get("deck", false):
		Sfx.loop_stop(key)
		_play(m, "board_cancel", null, CANCEL_DB)
	x["deck"] = on

## The skiff casts off: a sting for the squad aboard, a distant one (the sound's reach) for everyone else.
static func depart(m: Match, x: Dictionary) -> void:
	Sfx.loop_stop("board%d" % int(x["i"]))
	x["deck"] = false
	var squad: bool = m.player != null and (x["aboard"] as Array).any(func(h): return h.team == m.player.team)
	_play(m, "depart_sting", null if squad else x["berth"], STING_DB)
