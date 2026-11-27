class_name DayNight
extends RefCounted
## The day/night cycle of a real expedition (content/rules/day_night.json, docs/SPAWNS.md). It runs on the
## session clock: a day phase, then a night phase, over and over, starting in day. The light turns smoothly
## (DayNightLook); at the swap the night camps and the night elite stand up and the day camps lie down
## (DayNightSpawns). Every spot and time is worked out the same on every peer from the map and the match seed,
## so the warning (map ping and feed line warn_s before night) needs no Net message.
## It runs where the raid condition is clear (a rolled storm or fog keeps its own look) and in tools that ask.

const LAST_CALL_S := 10.0  # the second warning, this many seconds before night
const NIGHT_COL := Color("8aa6ff")
const DAY_COL := Color("ffd27a")

var m: Match
var cfg: Dictionary
var look: DayNightLook
var spawns: DayNightSpawns
var night := false  # the phase the last tick saw
var calls: Array = []  # seconds before the next night still to call out
var calls_for := -1  # the night (index) those calls are for
var _started := false


func _init(match_node: Match) -> void:
	m = match_node
	cfg = Content.rules("day_night")
	look = DayNightLook.new(m, cfg)
	spawns = DayNightSpawns.new(m, self)


## Whether this match has a cycle: a real expedition under the clear raid condition, or a tool that forces it.
func on() -> bool:
	return m.opts.get("day_night", false) or (m.raid == "clear" and RaidLook.rolls(m.opts))


## The length of one phase, in seconds: the reference's, scaled to this session.
func phase_len() -> float:
	return float(cfg["phase_s"]) * m.sess_len() / float(cfg["ref_session_s"])


## Which phase the session clock `t` falls in: 0 is the first day, 1 the first night, 2 the second day...
func phase_index(t: float) -> int:
	return maxi(0, floori(t / phase_len()))


func is_night(t: float) -> bool:
	return phase_index(t) % 2 == 1


## Seconds until the phase ends (the next swap).
func left_in_phase(t: float) -> float:
	return (phase_index(t) + 1) * phase_len() - t


## How dark the light is at session time t: 0 full day, 1 full night, turning over ramp x phase_len
## seconds centred on each swap.
func dark_at(t: float) -> float:
	var half := float(cfg["ramp"]) * phase_len() * 0.5
	var i := phase_index(t)
	var into := t - i * phase_len()
	var base := 1.0 if i % 2 == 1 else 0.0
	if into < half and i > 0:
		return lerpf(1.0 - base, base, smoothstep(-half, half, into))
	if into > phase_len() - half:
		return lerpf(base, 1.0 - base, smoothstep(phase_len() - half, phase_len() + half, into))
	return base


## The index of the night that is on or next to come (0 for the first night).
func next_night(t: float) -> int:
	return phase_index(t) / 2 if is_night(t) else (phase_index(t) + 1) / 2


## Session time a night starts: the first night after day 0 begins at one phase.
func night_start(n: int) -> float:
	return (2 * n + 1) * phase_len()


func tick() -> void:
	if not on():
		return
	var t := m.sess_time()
	if not _started:
		_started = true
		night = is_night(t)
		spawns.start(night)
	look.set_dark(dark_at(t))
	if is_night(t) != night:
		night = not night
		spawns.swap(night)
		_announce_phase()
	if not night:
		_warn(t)


## The warning before night: a ping at the night elite's spot and a feed line, warn_s and LAST_CALL_S before.
func _warn(t: float) -> void:
	var n := next_night(t)
	if calls_for != n:
		calls_for = n
		calls = [float(cfg["warn_s"]), LAST_CALL_S]
	var left := night_start(n) - t
	if calls.is_empty() or left > float(calls[0]):
		return
	calls.pop_front()
	var at := spawns.boss_spot(n)
	if at != Vector3.INF:
		m.ping(at, NIGHT_COL)
	var text := "Night falls in %d s: monsters wake at the dark camps" % ceili(left)
	m.add_feed(text)
	if m.hud and m.player and not m.player.out:
		m.hud.toast_small(text, NIGHT_COL)


func _announce_phase() -> void:
	var text := "Night has fallen. The dark camps are awake" if night else "Day breaks. The day camps are back"
	m.add_feed(text)
	if m.hud and m.player and not m.player.out:
		m.hud.toast(text, NIGHT_COL if night else DAY_COL)
