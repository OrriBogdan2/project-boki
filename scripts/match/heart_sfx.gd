class_name HeartSfx
extends RefCounted
## The Heart loop's and the Ways Out's sounds (tools/gen_sfx_heart.py, content/sfx/heart.json). It watches the
## Heart's state each tick and cues what changed, so the host and a client (whose state arrives by "ht" events)
## hear the same:
##   CHARGING   heart_charge  a rising hum at the Heart, pitch up with the charge (carries 70 m)
##   CARRIED    heart_take    the taker's sting; heart_reveal for everyone else (map-wide); the gate wakes
##              heart_beat    the carrier's own heartbeat loop
##   WAITING    heart_extract at the gate
## The tide's sounds are TideSfx's, ticked from update.
## Held loops use Sfx.loop_hold, so they end on their own when the match stops ticking.
## The Ways Out calls (LIMITED_WAY_OUTS section 9): call_out(event, seat, team) plays one flat sting and puts the
## same words in the feed and the toast lane, so sound and banner fire together. The Heart makes the calls of its
## own two seats; the quest seats call it the same way when they are built. Events:
##   open   ways_open         a seat opens
##   start  ways_start        a squad starts a seat (the early seat's start is the heart_take / heart_reveal sting)
##   taken  ways_taken_own    your squad left by it; ways_taken_other when another squad did
##   warn   ways_warn         a seat shuts in warn_before_shut_s (the Heart's final seat: the islands falling)
##   last   ways_last         one way out is left, a beat after the seat that made it so
## Each plays once per seat; a start repeats for a squad only after START_GAP_S (a ring that drained and refilled).
## The countdown: ways_tick once a second over the last TICK_FROM_S before a quest seat shuts or the islands fall
## (the final seat), louder and higher in the last TICK_LAST_S. Each game ticks for its own player only, and only
## while that seat is still reachable for them (_reachable), so a squad hears the clock of the seats it can take.

const CHARGE_KEY := "heart_charge"
const BEAT_KEY := "heart_beat"
const HUM_PITCH := Vector2(0.7, 1.6)   # playback speed of the charge hum at 0 % and 100 % charged
const HUM_DB := -4.0
const BEAT_DB := -3.0
const GATE_DB := 0.0
const CALL_DB := -2.0
const CALL_COL := Color("ffb4c0")      # the toast colour of a call
const START_GAP_S := 10.0              # s before the same squad starting the same seat sounds again
const LAST_DELAY_S := 1.5              # s the "last way out" sting waits behind the taken sting
const TICK_FROM_S := 10                # s before a seat shuts that the countdown starts ticking, one tick a second
const TICK_LAST_S := 3                 # the last s that tick stronger
const TICK_DB := -12.0                 # the soft tick, well under CALL_DB
const TICK_LAST_DB := -6.0             # the strong tick, still under CALL_DB
const TICK_LAST_PITCH := 1.2           # the strong tick's playback speed (a little higher)
const SEATS := {"lair": "the Sealed Lair", "early": "the Heart Gate", "uplink": "the Uplink", "final": "the Heart"}
const SHUT_KEY := {"lair": "lair_shut_s", "uplink": "uplink_shut_s"}   # heart.json "quest": when a quest seat shuts

var cues: Array = []                   # every one-shot cue in order, for the check
var ticks: Array = []                  # [seat, whole seconds left, dB] per countdown tick played, for the check
var tide: TideSfx                      # the Blight tide's onset, front rumble and close sting
var used := {}                         # seat -> true once a squad left by it
var _h: Heart
var _state := -1
var _opened := {}                      # seat -> true once it opened
var _said := {}                        # call key -> match time it last played
var _spent_t := -1.0                   # match time of the latest seat taken (the "last" sting waits behind it)
var _ticked := {}                      # seat -> the whole second it last ticked

func _init(heart: Heart) -> void:
	_h = heart
	tide = TideSfx.new(heart)

func update() -> void:
	var m := _h.m
	if _h.state != _state:
		if _state != -1:
			_on_change(_h.state)
		_state = _h.state
	if _state == Heart.S.CHARGING:
		var f := clampf(_h.charge / maxf(Heart.r("charge_s"), 0.01), 0.0, 1.0)
		Sfx.loop_hold(CHARGE_KEY, "heart_charge", _h.site, HUM_DB, lerpf(HUM_PITCH.x, HUM_PITCH.y, f))
	if _state == Heart.S.CARRIED and _h.carrier == m.player:
		Sfx.loop_hold(BEAT_KEY, "heart_beat", null, BEAT_DB)
	_watch_shut()
	for seat in ["lair", "uplink", "final"]:
		_watch_tick(seat)
	tide.update()

func _on_change(to: int) -> void:
	match to:
		Heart.S.CHARGING:
			call_out("open", "early")
		Heart.S.CARRIED:
			_cue("heart_take" if _h.carrier == _h.m.player else "heart_reveal", null, 0.0)
			_cue("heart_gate_open", _h.gate, GATE_DB)
		Heart.S.WAITING:
			_cue("heart_extract", _h.gate, GATE_DB)
		Heart.S.FINAL:
			call_out("open", "final")

## The warning before an open seat shuts, and the "last way out" once one seat is left.
func _watch_shut() -> void:
	var m := _h.m
	var warn := float(Heart.rules()["quest"]["warn_before_shut_s"])
	for seat in _opened:
		var left_s := shut_at(seat) - m.sess_time()
		if not used.has(seat) and left_s > 0.0 and left_s <= warn:
			call_out("warn", seat)
	if _spent_t >= 0.0 and m.time - _spent_t >= LAST_DELAY_S and ways_left().size() == 1:
		var seat: String = ways_left()[0]
		_spent_t = -1.0
		call_out("last", seat)

## One tick per whole second left, the last TICK_FROM_S before the seat shuts, if you can still reach it.
func _watch_tick(seat: String) -> void:
	var sec := ceili(shut_at(seat) - _h.m.sess_time())
	if sec < 1 or sec > TICK_FROM_S or _ticked.get(seat, 0) == sec or not _reachable(seat):
		return
	_ticked[seat] = sec
	var strong := sec <= TICK_LAST_S
	var db := TICK_LAST_DB if strong else TICK_DB
	ticks.append([seat, sec, db])
	_h.m.sfx("ways_tick", null, db, TICK_LAST_PITCH if strong else 1.0)

## Can this game's player still leave by the seat: still in the match, the seat not taken or shut, and no other
## squad on it (a quest seat a rival is sealed in or charging; your own squad's charge still races the clock,
## your own lair fight does not, the clock leaves it be).
func _reachable(seat: String) -> bool:
	var p: Hunter = _h.m.player
	if p == null or p.out or p.extracted or used.has(seat):
		return false
	if seat == "final":
		return _h.state == Heart.S.FINAL
	var qs: QuestSeats = _h.m.exits.seats if _h.m.exits else null
	if qs == null:
		return false
	var s: QuestSeat = qs.lair if seat == "lair" else qs.uplink
	if s == null:
		return false
	return s.state == QuestSeat.S.OPEN or (seat == "uplink" and s.state == QuestSeat.S.IN_USE and s.team == p.team)

## The session second a seat shuts at (INF: it stays open until the islands fall, or never).
func shut_at(seat: String) -> float:
	if SHUT_KEY.has(seat):
		return float(Heart.rules()["quest"][SHUT_KEY[seat]])
	var len_s := _h.m.sess_len()
	return len_s if seat == "final" and len_s < 1.0e8 else INF

## The seats still to be had: not taken, not shut by the clock, and the early seat goes with the final one.
func ways_left() -> Array:
	var out: Array = []
	for seat in SEATS:
		if not used.has(seat) and shut_at(seat) > _h.m.sess_time() and not (seat == "early" and used.has("final")):
			out.append(seat)
	return out

## One call: its cue and its words, once (see the header). team: the squad a start or a taken is about.
func call_out(ev: String, seat: String, team := -1) -> void:
	var m := _h.m
	var key := "%s %s" % [ev, seat] + (" %d" % team if ev == "start" else "")
	if _said.has(key) and (ev != "start" or m.time - float(_said[key]) < START_GAP_S):
		return
	_said[key] = m.time
	var cue := "ways_" + ev
	var seat_name: String = SEATS[seat]
	var text := ""
	match ev:
		"open":
			_opened[seat] = true
			text = "%s is open" % seat_name
		"start":
			text = "%s started %s" % [_squad(team), seat_name]
		"taken":
			used[seat] = true
			_spent_t = m.time
			cue = "ways_taken_own" if _mine(team) else "ways_taken_other"
			text = "%s left by %s. %s." % [_squad(team), seat_name, _left_words()]
		"warn":
			text = "%s shuts in %d s" % [seat_name, int(Heart.rules()["quest"]["warn_before_shut_s"])]
		"last":
			text = "Last way out: %s" % seat_name
	text = text.substr(0, 1).to_upper() + text.substr(1)
	_cue(cue, null, CALL_DB)
	m.add_feed(text)
	if m.hud:
		m.hud.toast_small(text, CALL_COL)

func _left_words() -> String:
	var n := ways_left().size()
	if n == 0:
		return "No ways out left"
	return "1 way out left" if n == 1 else "%d ways out left" % n

func _mine(team: int) -> bool:
	return _h.m.player != null and _h.m.player.team == team

func _squad(team: int) -> String:
	if _mine(team):
		return "Your squad"
	return _h.m.truce.squad_name(team) if _h.m.truce else "a squad"

func _cue(sname: String, at, vol: float) -> void:
	cues.append(sname)
	_h.m.sfx(sname, at, vol)
