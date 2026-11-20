class_name TutorialSummon
extends RefCounted
## The tutorial's Summon beat, taught only when the Boki rides as a wisp (KinWisp.mode; Tutorial owns
## one of these as `sm`). With the walking Boki the "gkey" beat stands in for it.
## "summon": press the Summon key, watch the ring drain on the Boki's slot and under it (a warning tick at
## WARN_S); calling it back early resets the cooldown and says so. It passes when the window ends (timer, the
## monster beaten, or the Boki knocked back), never on a downed hunter or Boki.

enum { ASK, OUT, ENDED }

const WARN_S := 3.0  # s of the window left when the tick sounds
const EARLY_S := 0.2  # s: a window sent back with more than this left was called back early
const BACK_T := 1.6  # s the "Back to a light" line stays before the step passes

var tu: Tutorial
var phase := ASK
var early := false  # called back early (the cooldown is reset, the step stays)
var knocked := false  # the Boki was beaten and flew back
var _prev_left := 0.0
var _warned := false
var _back_t := 0.0


func _init(t: Tutorial) -> void:
	tu = t


## Whether this match teaches the summon: the Boki rides as a wisp.
func active() -> bool:
	var k: Kin = tu.m.player.kin
	return k != null and k.wisp and k.summon != null


## A step starts: nothing is carried over from the last.
func begin() -> void:
	phase = ASK
	early = false
	knocked = false
	_prev_left = 0.0
	_warned = false
	_back_t = 0.0


## "summon": true once the window has ended and its closing line has been read.
func summon_done(dt: float) -> bool:
	var s: KinSummon = tu.m.player.kin.summon
	if phase == ASK and s.left > 0.0:
		phase = OUT
		early = false
		_warned = false
		_bark("I'm here!")
		_tip()
		tu.camps.spawn("summon")  # (one for it to fight, if the player beat the first)
	elif phase == OUT:
		if s.left > 0.0 and s.left <= WARN_S and not _warned:
			_warned = true
			tu.m.sfx("click", null, -4.0)
			_tip()
		if s.left <= 0.0:
			_ended(s)
		elif tu.camps.alive() == 0:
			s.end()  # (the monster is down: the Boki goes back to a light, a normal rest)
	if early and not s.out():
		s.cd = 0.0  # (calling it back early is forgiven: it can come out again at once)
		if tu.camps.alive() == 0:
			tu.camps.spawn("summon")  # (and something to come out at, if the monster fell as it went back)
	if phase == ENDED:
		_back_t += dt
	_prev_left = s.left
	return phase == ENDED and _back_t >= BACK_T and _fit()


## The banner's alt line key for a step now ("" for the step's own line).
func alt_key(sid: String) -> String:
	if sid == "summon":
		if early:
			return "summon_early"
		return ["", "summon_out", "summon_rest"][phase]
	return ""


## A downed hunter or Boki never passes a step.
func _fit() -> bool:
	var p := tu.m.player
	return not p.downed and p.kin.state != "downed"


func _bark(txt: String) -> void:
	tu.m.kin_bark(tu.m.player.kin, tu.fill(txt), "tut", 2.0)


func _ended(s: KinSummon) -> void:
	knocked = s.shrink <= 0.0
	if not knocked and _prev_left > EARLY_S and tu.camps.alive() > 0:
		early = true
		phase = ASK
		return
	phase = ENDED
	_bark("Phew!")
	_tip()


## The key of the plain line under the banner now (content/rules/tutorial.json "detail"), "" for none.
func detail_key() -> String:
	match phase:
		ASK:
			return "summon"
		OUT:
			return "summon_warn" if _warned else ""
		_:
			return "summon_knocked" if knocked else "summon_back"


## The plain line, sent to the message lane as the window moves on.
func _tip() -> void:
	var txt := tu.fill(String(Content.rules("tutorial")["detail"].get(detail_key(), "")))
	if txt != "" and tu.m.hud:
		tu.m.hud.tip(txt)
