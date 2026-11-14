class_name MatchFlow
extends RefCounted
## The match flow as one explicit machine (docs/decisions/0061-match-flow-machine.md, briefs/STATE_MACHINES.md
## M10): LOADING > PLANNING > DROP > PLAY > CLOSING > ENDING > OVER, forward only. ENDING and OVER are owned here
## (Match._end_soon / _finish go through end() and finish()); the phases before them advance in tick(), each match
## step, through guards that read the drop squad, the local player's drop, the Heart and the clock. The HUD phase
## word, the Esc menu and the results trigger ask this machine, so they can't disagree. Local only: nothing here
## is on the wire.

enum S {LOADING, PLANNING, DROP, PLAY, CLOSING, ENDING, OVER}
const NAMES: PackedStringArray = ["LOADING", "PLANNING", "DROP", "PLAY", "CLOSING", "ENDING", "OVER"]
const TABLE := {
	S.LOADING: [S.PLANNING, S.DROP, S.PLAY, S.ENDING, S.OVER],     # (a check can decide or stop it before a step)
	S.PLANNING: [S.DROP, S.ENDING, S.OVER],
	S.DROP: [S.PLAY, S.ENDING, S.OVER],
	S.PLAY: [S.CLOSING, S.ENDING, S.OVER],               # (OVER straight away: Practice.leave, checks stopping)
	S.CLOSING: [S.ENDING, S.OVER],
	S.ENDING: [S.OVER],
	S.OVER: [],
}
const FALLING_S := 30.0      # s left on the match clock when the islands fall (HUD "ISLANDS FALLING", red clock)
const WORDS := {S.PLANNING: "PLANNING", S.DROP: "DROPPING"}    # the HUD phase word (CLOSING: closing_word())

var fsm := Fsm.new(NAMES, TABLE, S.LOADING, "match")
var m: Match

func _init(match_node: Match) -> void:
	m = match_node
	fsm.guard(S.PLANNING, func(_from: int) -> bool: return _planning())
	fsm.guard(S.DROP, func(_from: int) -> bool: return _in_air() and not _planning())
	fsm.guard(S.PLAY, func(_from: int) -> bool: return not _in_air() and not _planning())
	fsm.guard(S.CLOSING, func(_from: int) -> bool: return _closing())

## Each match step: the phases before the end move on when their guard says so (asked first, so a phase that
## isn't due yet is never counted as refused). The first step leaves LOADING. False once over (nothing moves).
func tick(dt: float) -> bool:
	if is_over():
		return false
	fsm.tick(dt)
	var to := -1
	match fsm.state:
		S.LOADING: to = S.PLANNING if _planning() else _drop_or_play()
		S.PLANNING: to = _drop_or_play()
		S.DROP: to = S.PLAY
		S.PLAY: to = S.CLOSING
	if to >= 0 and fsm.can(to):
		fsm.go(to, "step")
	return true

## The match is decided (Match._end_soon): false if it already was.
func end(why: String) -> bool:
	return not ending() and fsm.go(S.ENDING, why)

## The results are due (Match._finish), or a tool stops the match: false if it was already over.
func finish(why: String) -> bool:
	return not is_over() and fsm.go(S.OVER, why)

func ending() -> bool:
	return fsm.state >= S.ENDING

func is_over() -> bool:
	return fsm.is_in(S.OVER)

## The Esc menu may open: the match is built and not yet decided.
func can_pause() -> bool:
	return fsm.state > S.LOADING and fsm.state < S.ENDING

## Under FALLING_S on the clock (the HUD's red clock and bar).
func falling() -> bool:
	return m.length - m.time < FALLING_S

## The word in the HUD clock bar for this phase ("" while playing and once decided).
func word() -> String:
	if fsm.is_in(S.CLOSING):
		return "ISLANDS FALLING" if falling() else "FINAL SEAT"
	return String(WORDS.get(fsm.state, ""))

func _planning() -> bool:
	return m.skydrop != null and m.skydrop.planning

## DROP while the local player is on the ship or in the air, else PLAY.
func _drop_or_play() -> int:
	return S.DROP if _in_air() else S.PLAY

func _in_air() -> bool:
	return m.player != null and (m.player.dropping or m.player.riding)

## Ways Out: the Heart's final seat is up (or done), or the islands are falling.
func _closing() -> bool:
	var final_seat := m.heart != null and m.heart.state >= Heart.S.FINAL
	return final_seat or falling()
