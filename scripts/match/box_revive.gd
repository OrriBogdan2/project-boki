class_name BoxRevive
extends RefCounted
## Bringing a teammate back at their deathbox (docs/decisions/0018). Hold interact at the box for
## time_for() seconds while their soul is there (Life.soul_here). While you channel you can't attack,
## you take Hunter.CONSUME_VULN times the damage and a real hit spills it, exactly like drinking a
## tonic (Hunter.hurt, Hunter._interrupt_consume), and moving, dashing, jumping, gliding or a stun
## breaks it too. Let go of interact and hold it again to start over. Everyone nearby hears it
## (Match._update_box_hums). The teammate comes back at the box with their Boki (Life.box_revive).
## Numbers: content/rules/revive.json.

const RULES_PATH := "res://content/rules/revive.json"
const MOVE_DEADZONE := 0.1        # stick length that counts as moving (a resting stick drifts below it)
const NO_ATTACK := ["sig", "skill", "sec", "ult", "swap", "util1", "util2", "util3", "util4",
	"gear1", "gear2", "fire", "throw", "kin_ab"]
const DONE_COL := Color("bff5c0")

static var _rules := {}

## The revive numbers (content/rules/revive.json), read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## Seconds to bring a Hunter back from their box.
static func time_for() -> float:
	return float(rules()["box_revive_s"])

## The prompt at a teammate's box.
static func prompt(h: Hunter, o: Hunter) -> String:
	if h.box_reviving():
		return "Bringing %s back  ·  moving or a hit stops it" % o.pname
	var key := Settings.key_cap("interact")
	return "Hold %s to bring %s back  ·  %.1fs, you take more damage" % [key, o.pname, time_for()]

## One step of holding interact at a teammate's box (Match._update_interact).
static func hold(m: Match, h: Hunter, b: Dictionary, dt: float) -> void:
	h.set_hold("revive")
	if h.get_meta("box_broke", false):
		h.box_t = 0.0
		return
	var need := time_for()
	if h.box_t <= 0.0:
		h.vuln_fx_t = 0.0
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "VULNERABLE", Color("ff6a4a"))
	h.box_t += dt
	# everyone sees (and hears: Match._update_box_hums) a box revive going up, and who's doing it
	b["rev_prog"] = h.box_t / need
	b["rev_by"] = h
	b["rev_at"] = m.time
	h.box_rev_at = m.time
	if h.box_t < need:
		return
	h.box_t = 0.0
	b["rev_at"] = -9.0
	h.box_rev_at = -9.0
	m.sfx("revive_done", b["pos"], 3.0)
	m.fx.ring(b["pos"] + Vector3(0, 0.1, 0), 2.6, DONE_COL, 0.5)
	m.fx.burst(b["pos"] + Vector3(0, 1.0, 0), DONE_COL, 26, 4.5, 0.7, -2.0, 1.2)
	Life.box_revive(m, b, h)

## Every step while channelling (Hunter's input step): no attacks; moving, dashing, jumping,
## gliding or a stun breaks the channel instead.
static func guard_inputs(h: Hunter) -> void:
	var walking: bool = (h.inp.get("move", Vector2.ZERO) as Vector2).length() > MOVE_DEADZONE
	var leaping: bool = h.inp.get("dash", false) or h.inp.get("jump", false) or h.roll_t > 0.0
	if walking or leaping or h.gliding or h.stun_t > 0.0:
		if h.box_t > 0.0:        # (not when interact was just let go)
			h.m.fx.word(h.pos + Vector3(0, 2.3, 0), "INTERRUPTED", Color("ff8a5a"))
			cancel(h)
		return
	for key in NO_ATTACK:
		h.inp[key] = false

## Breaks a box revive in progress (the caller shows it); holding interact afresh starts it over.
static func cancel(h: Hunter) -> void:
	if not h.box_reviving():
		return
	h.box_t = 0.0
	h.box_rev_at = -9.0
	h.set_meta("box_broke", true)
