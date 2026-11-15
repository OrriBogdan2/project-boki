class_name QuestSfx
extends RefCounted
## The quest seats' own sounds (tools/gen_sfx_quest.py, content/sfx/quest.json). QuestSeats owns it and calls
## update() each tick; it watches the seats' states (moved by the host, mirrored by a client) and cues what changed
## for this game's squad, so every game hears its own:
##   quest_take        your squad takes on a seat (IN_USE with your team, a takeover included)
##   quest_rival_rise  a rival squad passes RIVAL_AT of its seat while your squad is on a quest (holds a seat, or
##                     is at that seat's site contesting it); again only after it falls back under REARM_AT
##   quest_win         a seat is taken by your squad
##   quest_lose        a seat your squad was on is taken by another squad, or your squad's hold ends without a
##                     take (the boss fight lost, the uplink drained or taken over, the window shut)
##   quest_site        a quiet positional loop at each seat while it is OPEN or IN_USE (keyed loop_hold: it ends
##                     on its own when the seat stops or the match stops ticking)
## The stings are flat and play once per event; the shared pool's MIN_GAP and stacking cap are the voice limits
## (at most two seat loops and one sting per seat change, docs/AUDIO.md).

const RIVAL_AT := 0.75      # progress share (0-1) of a rival's seat that sounds the tense cue
const REARM_AT := 0.5       # it sounds again only after that progress falls back under this
const STING_DB := -2.0      # the flat stings, level with the Ways Out calls (HeartSfx.CALL_DB)
const SITE_DB := -8.0       # the site loop sits quietly under the match
const SITE_KEY := "quest_site_"

var cues: Array = []        # every one-shot cue in order, for the check
var _seats: QuestSeats
var _on := {}               # seat kind -> true while your squad is on it (holds it, or contests a rival there)
var _last := {}             # seat kind -> Vector2i(state, team) last tick (a client joining late hears nothing old)
var _risen := {}            # seat kind -> true once the rival cue sounded for its current hold

func _init(seats: QuestSeats) -> void:
	_seats = seats

func update() -> void:
	var p: Hunter = _seats.m.player
	if p == null:
		return
	var holds := false
	for s: QuestSeat in _seats.seats():
		holds = holds or (s.state == QuestSeat.S.IN_USE and s.team == p.team)
	for s: QuestSeat in _seats.seats():
		_watch(s, p.team, holds)
		if s.state in [QuestSeat.S.OPEN, QuestSeat.S.IN_USE]:
			Sfx.loop_hold(SITE_KEY + s.kind, "quest_site", s.site(), SITE_DB)

func _watch(s: QuestSeat, me: int, holds: bool) -> void:
	var last: Vector2i = _last.get(s.kind, Vector2i(s.state, s.team))
	var held := last.x == QuestSeat.S.IN_USE and last.y == me
	var mine := s.state == QuestSeat.S.IN_USE and s.team == me
	var rival_on := s.state == QuestSeat.S.IN_USE and s.team >= 0 and s.team != me
	if mine and not held:
		_cue("quest_take")
	elif s.state == QuestSeat.S.TAKEN and last.x != QuestSeat.S.TAKEN and (s.team == me or _on.has(s.kind)):
		_cue("quest_win" if s.team == me else "quest_lose")
	elif held and not mine:
		_cue("quest_lose")
	if mine or (rival_on and _at_site(s, me)):
		_on[s.kind] = true
	else:
		_on.erase(s.kind)
	_last[s.kind] = Vector2i(s.state, s.team)
	if not rival_on or s.progress() < REARM_AT:
		_risen.erase(s.kind)
	elif s.progress() >= RIVAL_AT and (holds or _on.has(s.kind)) and not _risen.has(s.kind):
		_risen[s.kind] = true
		_cue("quest_rival_rise")

## Is one of this squad standing at the seat (in the uplink's yard, inside the lair)?
func _at_site(s: QuestSeat, team: int) -> bool:
	var m := _seats.m
	for h in m.hunters:
		if h.team != team or h.out or h.extracted:
			continue
		if s.kind == "uplink" and m.exits.in_yard(s.ref, h):
			return true
		if s.kind == "lair" and m.lairs and m.lairs.inside(s.ref, h.pos, 0.5):
			return true
	return false

func _cue(sname: String) -> void:
	cues.append(sname)
	_seats.m.sfx(sname, null, STING_DB)
