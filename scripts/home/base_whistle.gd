class_name BaseWhistle
extends RefCounted
## The garden whistle (base_mode only): tap the whistle key and your partner comes to you, hold it and the
## nearest other Boki comes too. Trust and mood decide how it answers: a trusting, happy Boki runs, a lukewarm
## one ambles over, a sulky one looks at you and stays. It rides on home.gd's come-to-you run (called_t,
## call_slot, call_pace in _move_kin), so BaseLife leaves the Boki alone while it comes. Home only: a match
## never reads the whistle action (G owns the Boki there). Tuning: content/rules/base_life.json "whistle".

var h                       # the home (home.gd)
var R: Dictionary           # base_life.json "whistle"
var held := -1.0            # s the key has been down, -1 when it is up or the hold call is made
var _other: Dictionary = {}   # the Boki a long hold will call

const TAP := "garden_whistle_tap"
const HOLD := "garden_whistle_hold"
const ANSWER_DB := -12.0      # dB: a Boki's answer sits under the whistle

func _init(home, rules: Dictionary) -> void:
	h = home
	R = rules["whistle"]
	Sfx.streams[TAP] = Synth.whistle()
	Sfx.streams[HOLD] = Synth.whistle(true)

## How readily a Boki answers, 0 to 1: trust counts most, then its overall condition.
func eagerness(rec: Dictionary) -> float:
	return clampf(float(rec["trust"]) * 0.006 + Care.condition(rec) * 0.004, 0.0, 1.0)

## A sulky Boki (glum, or it does not trust you yet) only looks over.
func sulky(rec: Dictionary) -> bool:
	return Care.need(rec, "joy") < float(R["sulky_joy"]) or float(rec["trust"]) < float(R["shy_trust"])

## The key went down: the partner is called now, the nearest other Boki if it stays down.
func press() -> void:
	held = 0.0
	GardenSfx.cue(TAP, h.ppos)
	var partner := _partner()
	_call(partner, 0.4)
	_other = _nearest(partner)

func release() -> void:
	held = -1.0
	_other = {}

## Called every frame by BaseLife.step.
func step(d: float) -> void:
	if held < 0.0:
		return
	held += d
	if held >= float(R["hold_s"]):
		held = -1.0
		GardenSfx.cue(HOLD, h.ppos)
		_call(_other, 0.4 + PI)
		_other = {}

func _partner() -> Dictionary:
	for k in h.kins:
		if k["rec"]["uid"] == Save.d.get("active", ""):
			return k
	return {}

## The closest Boki to you that is free to come and is not the partner.
func _nearest(partner: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	for k in h.kins:
		if k == partner or _busy(k):
			continue
		var d: float = Vector2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z).length()
		if d < best_d:
			best = k
			best_d = d
	return best

static func _busy(k: Dictionary) -> bool:
	return k.get("busy", false) or k.has("fetch") or k.has("bath") or k.has("leap")

func _call(k: Dictionary, angle: float) -> void:
	if k.is_empty() or _busy(k):
		return
	var rec: Dictionary = k["rec"]
	var asleep := HomeChimes.asleep(k)
	if sulky(rec):
		if not asleep and not k.has("indoors"):
			h._emote(k, "…")
			_answer(k, "garden_sulk_" + GardenSfx.size_word(rec))
			k["hold_t"] = float(R["look_s"])
		return
	k["call_slot"] = Vector3(cos(angle), 0, sin(angle)) * float(R["slot_m"])
	k["call_pace"] = lerpf(float(R["pace"][0]), float(R["pace"][1]), eagerness(rec))
	if k.has("indoors"):
		h._house_alert([k])
		return
	k["nap_t"] = 0.0
	for key in ["nap_go", "nap_go_t", "going_in"]:
		k.erase(key)
	k["called_t"] = float(R["give_up_s"])
	h._emote(k, "!")
	if not asleep:
		_answer(k, "kin_happy" if eagerness(rec) >= float(R["happy_at"]) else "kin_unsure")
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	var mine: int = h.world.island_of(h.ppos.x, h.ppos.z)
	if mine >= 0 and here != mine:
		h._start_leap(k, h.ppos + k["call_slot"])

## The called Boki's voice at its own spot, in its own pitch.
func _answer(k: Dictionary, sname: String) -> void:
	GardenSfx.cue(sname, k["pos"], Unique.voice(k["rec"]), ANSWER_DB)
