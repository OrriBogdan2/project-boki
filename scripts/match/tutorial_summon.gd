class_name TutorialSummon
extends RefCounted
## The tutorial's two Summon beats (Tutorial owns one as `sm`; briefs/boki-art/TUTORIAL_COMBAT_V2.md 5 and 6).
## "summon": press the Summon key, watch the ring drain on the Boki's slot and under it (a warning tick at
## WARN_S, "Back to a light" when it shrinks); calling it back early resets the cooldown and says so. It passes
## when the window ends (timer, the monster beaten, or the Boki knocked back), never on a downed hunter or Boki.
## "fight": the pack in two waves (the second as the ring nears ready); it passes when all are down and the
## Boki was summoned again after the ring went bright. A pack that falls first sends one more skitter.

enum {ASK, OUT, ENDED}

const WARN_S := 3.0       # s of the window left when the tick sounds
const EARLY_S := 0.2      # s: a window sent back with more than this left was called back early
const WAVE2_CD := 4.0     # s of the cooldown left when the pack's second wave lands
const BACK_T := 1.6       # s the "Back to a light" line stays before the beat passes

var tu: Tutorial
var phase := ASK
var early := false       # called back early (the cooldown is reset, the beat stays)
var knocked := false     # the Boki was beaten and flew back
var detail := ""         # the plain line under the pill
var _m: Match
var _prev_left := 0.0
var _warned := false
var _back_t := 0.0
var bright := false      # the ring went bright in the pack beat
var second := false      # summoned again after that
var wave2 := false
var extra := false

func _init(t: Tutorial) -> void:
	tu = t
	_m = t.m

func begin() -> void:
	phase = ASK
	early = false
	knocked = false
	detail = ""
	_prev_left = 0.0
	_warned = false
	_back_t = 0.0
	bright = false
	second = false
	wave2 = false
	extra = false

## Is the player in a state where a beat may pass? A downed hunter or Boki never passes one.
func _fit() -> bool:
	var p := _m.player
	return not p.downed and (p.kin == null or p.kin.state != "downed")

func _bark(txt: String) -> void:
	var k: Kin = _m.player.kin
	_m.kin_bark(k, tu.fill(txt), "tut", 2.0)

## Beat 5. True when the window has ended and its closing line has been read.
func summon_done(dt: float) -> bool:
	var k: Kin = _m.player.kin
	var s: KinSummon = k.summon
	if phase == ASK and s.left > 0.0:
		phase = OUT
		early = false
		_warned = false
		_bark("I'm here!")
		tu.foes(["spitter"], true)      # (one for it to fight)
	elif phase == OUT:
		if s.left > 0.0 and s.left <= WARN_S and not _warned:
			_warned = true
			_m.sfx("click", null, -4.0)
		if s.left <= 0.0:
			_ended(s)
		elif tu.live_foes() == 0:
			s.end()      # (the pack is down: the Boki goes back to a light, a normal rest)
	if early and not s.out():
		s.cd = 0.0      # (calling it back early is forgiven: it can come out again at once)
	if phase == ENDED:
		_back_t += dt
	_prev_left = s.left
	detail = _detail5(s)
	return phase == ENDED and _back_t >= BACK_T and _fit()

func _ended(s: KinSummon) -> void:
	knocked = s.shrink <= 0.0
	if not knocked and _prev_left > EARLY_S and tu.live_foes() > 0:
		early = true
		phase = ASK
		return
	phase = ENDED
	_bark("Phew!")

func _detail5(s: KinSummon) -> String:
	var key := ""
	match phase:
		ASK: key = "summon"
		OUT: key = "summon_warn" if _warned else ""
		ENDED: key = "summon_knocked" if knocked else "summon_back"
	return tu.fill(String(Content.rules("tutorial")["detail"].get(key, "")))

## Beat 6 on entering: the first wave (what is left of the last beat joins it).
func start_pack() -> void:
	tu.foes(["skitter", "spitter"])

## Beat 6. True when the pack is down and the Boki was summoned a second time.
func pack_done() -> bool:
	var k: Kin = _m.player.kin
	var s: KinSummon = k.summon if k else null
	if s == null:      # (a kit with no Boki: the pack in two waves, no summon)
		if not wave2 and tu.live_foes() == 0:
			wave2 = true
			tu.foes(["skitter"], true)
		return wave2 and tu.live_foes() == 0
	var rested := not s.out() and s.cd <= 0.0
	if rested and not bright:
		bright = true
		_bark("Ready again!")
	if s.out() and bright:
		second = true
	if not wave2 and s.cd <= WAVE2_CD:
		wave2 = true
		tu.foes(["skitter"], true)
	var dead := tu.live_foes() == 0 and wave2
	if dead and bright and not second and not extra:
		extra = true
		tu.foes(["skitter"], true)      # (the pack fell before the ring was bright: one more to summon for)
	detail = tu.fill(String(Content.rules("tutorial")["detail"]["fight"]))
	return dead and second and _fit()

## The banner's alt line for this beat now ("" for the step's own line).
func alt_key(sid: String) -> String:
	if sid == "summon":
		if early:
			return "summon_early"
		return ["", "summon_out", "summon_rest"][phase]
	if sid == "fight" and not bright and tu.live_foes() == 0:
		return "pack_wait"
	return ""
