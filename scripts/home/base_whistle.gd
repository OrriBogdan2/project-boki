class_name BaseWhistle
extends RefCounted
## The garden whistle (base_mode only): tap the whistle key and your partner comes to you, hold it and the
## nearest other Boki comes too. Trust and mood decide how it answers: a trusting, happy Boki runs, a lukewarm
## one ambles over, a sulky one looks at you, waits a beat and walks slowly. Before it moves it makes an answer
## beat (0.12 s facing you, up to 0.45 s from behind): it stops, perks up (ears and nose up) and its front
## turns to you ahead of the body, using the Boki's Body node and the "pose"/"face" metas, no rig work. The run
## rides on home.gd's come-to-you run (called_t, call_slot, call_pace in _move_kin), so BaseLife leaves the Boki
## alone while it comes. Home only: a match never reads the whistle action (G owns
## the Boki there). Tuning: content/rules/base_life.json "whistle".

var h                       # the home (home.gd)
var R: Dictionary           # base_life.json "whistle"
var held := -1.0            # s the key has been down, -1 when it is up or the hold call is made
var hint: WhistleHint       # the one-time nudge to use the key (whistle_hint.gd)
var _other: Dictionary = {}   # the Boki a long hold will call
var _answering: Array = []    # the Boki in their answer beat (k["answer"] = {t, beat, sulky})

const PERK_FADE := 0.06       # s the perk takes to rise, and to fall at the end of the beat
const PERK_TILT := -0.14      # rad, nose up (KinPuppet "alert")
const PERK_TALL := 0.08       # share the body stretches up
const SULK_TILT := 0.1        # rad, nose down
const HEAD_LEAD := 0.45       # share of the turn to you the front takes ahead of the body (rad per rad, up to HEAD_MAX)
const HEAD_MAX := 1.2         # rad

func _init(home, rules: Dictionary) -> void:
	h = home
	R = rules["whistle"]
	hint = WhistleHint.new(self)

## How readily a Boki answers, 0 to 1: trust counts most, then its overall condition.
func eagerness(rec: Dictionary) -> float:
	return clampf(float(rec["trust"]) * 0.006 + Care.condition(rec) * 0.004, 0.0, 1.0)

## A sulky Boki (glum, or it does not trust you yet) only looks over.
func sulky(rec: Dictionary) -> bool:
	return Care.need(rec, "joy") < float(R["sulky_joy"]) or float(rec["trust"]) < float(R["shy_trust"])

## The key went down: the partner is called now, the nearest other Boki if it stays down.
func press() -> void:
	held = 0.0
	hint.used()
	var mine := partner()
	_call(mine, 0.4)
	_other = _nearest(mine)

func release() -> void:
	held = -1.0
	_other = {}

## Called every frame by BaseLife.step.
func step(d: float) -> void:
	hint.tick(d)
	_pose_answers(d)
	if held < 0.0:
		return
	held += d
	if held >= float(R["hold_s"]):
		held = -1.0
		_call(_other, 0.4 + PI)
		_other = {}

func partner() -> Dictionary:
	for k in h.kins:
		if k["rec"]["uid"] == Save.d.get("active", ""):
			return k
	return {}

## The closest Boki to you that is free to come and is not the partner.
func _nearest(mine: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	for k in h.kins:
		if k == mine or _busy(k):
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
	var sulk := sulky(rec)
	if sulk and (float(k.get("nap_t", 0.0)) > 0.0 or k.has("indoors")):
		return
	k["call_slot"] = Vector3(cos(angle), 0, sin(angle)) * float(R["slot_m"])
	k["call_pace"] = float(R["sulky_pace"]) if sulk else lerpf(float(R["pace"][0]), float(R["pace"][1]), eagerness(rec))
	if k.has("indoors"):
		h._house_alert([k])
		return
	k["nap_t"] = 0.0
	for key in ["nap_go", "nap_go_t", "going_in"]:
		k.erase(key)
	k["called_t"] = float(R["give_up_s"])
	h._emote(k, "…" if sulk else "!")
	if not sulk:
		Sfx.play("kin_alert", k["pos"], -12.0, 0.15, Unique.voice(rec))
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	var mine: int = h.world.island_of(h.ppos.x, h.ppos.z)
	if mine >= 0 and here != mine:
		h._start_leap(k, h.ppos + k["call_slot"])
	else:
		_start_answer(k, sulk)

## The answer beat: the Boki stops where it stands and holds (hold_t) while it perks up, or, sulky, droops and waits.
## It lasts perk_s plus up to turn_s for the turn to face you, so a Boki already facing you loses only perk_s.
func _start_answer(k: Dictionary, sulk: bool) -> void:
	var n := k["node"] as Node3D
	var beat := float(R["wait_s"]) if sulk else float(R["perk_s"]) + float(R["turn_s"]) * absf(_turn_to_you(k)) / PI
	k["answer"] = {"t": 0.0, "beat": beat, "sulky": sulk}
	k["hold_t"] = beat
	k["vel"] = Vector3.ZERO
	k["q_on"] = 0.0      # a habit in progress would fight the pose
	n.set_meta("pose", "whine" if sulk else "alert")
	n.set_meta("face", "sad" if sulk else "cheer")
	if not _answering.has(k):
		_answering.append(k)

## Radians from where the Boki faces to the direction of you, -PI to PI.
func _turn_to_you(k: Dictionary) -> float:
	var to := Vector2(h.ppos.x - k["pos"].x, h.ppos.z - k["pos"].z)
	return wrapf(atan2(-to.x, -to.y) - (k["node"] as Node3D).rotation.y, -PI, PI)

## Every frame: the perk (or droop) and the front's turn toward you, then back to rest when the beat is over.
func _pose_answers(d: float) -> void:
	for i in range(_answering.size() - 1, -1, -1):
		var k: Dictionary = _answering[i]
		var n := k["node"] as Node3D
		var body := n.get_node_or_null("Body") as Node3D
		var a: Dictionary = k["answer"]
		a["t"] = float(a["t"]) + d
		var left := float(a["beat"]) - float(a["t"])
		if left <= 0.0 or body == null or _busy(k) or k.has("indoors") or k.has("leap"):
			_answering.remove_at(i)
			k.erase("answer")
			n.set_meta("pose", "")
			n.set_meta("face", "")
			if body:
				body.rotation = Vector3.ZERO
				body.scale = Vector3.ONE
			continue
		var amp := clampf(minf(float(a["t"]), left) / PERK_FADE, 0.0, 1.0)
		var sulk: bool = a["sulky"]
		var head := clampf(_turn_to_you(k) * HEAD_LEAD, -HEAD_MAX, HEAD_MAX)
		body.rotation = Vector3(amp * (SULK_TILT if sulk else PERK_TILT), head, 0.0)
		body.scale = Vector3(1.0, 1.0 + (0.0 if sulk else amp * PERK_TALL), 1.0)
