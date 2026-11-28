class_name KinWelcome
extends RefCounted
## Coming home is a moment: after a real absence (an expedition, or the game closed a while) the
## Boki out on the farm notice you and run over, the ones that trust you most first, each with a
## "!" and then a hello when they reach you. It uses the whistle's come-to-you run (called_t in
## home.gd _move_kin). Napping Boki sleep on; wary ones (trust under SHY) don't come.

const AWAY_MIN := 120.0      # seconds away before they rush over (less is a trip to a menu)
const START_S := 1.2         # beat after you arrive before the first one notices you
const STAGGER_S := 0.35      # seconds between each next one
const SHY := 22.0            # under this trust it only watches you (as with the whistle)
const SLOT_M := 1.4          # how far from you each one stops
const SLOT_R := 0.45         # clearance a slot needs (a Boki's body is 0.3; it stops within 0.6)

## How long you were gone: call before Care catch-up moves the clocks on.
static func away_secs() -> float:
	var now := Time.get_unix_time_from_system()
	var gone := 0.0
	for rec in Save.d.get("roster", []):
		if not KinBox.is_boxed(rec):
			gone = maxf(gone, now - float(rec.get("needs_t", now)))
	return gone

static func start(home: Node, away: float) -> void:
	if away < AWAY_MIN or not home.visit.is_empty():
		return
	var keen: Array = home.kins.filter(func(k): return float(k["rec"].get("trust", 0.0)) >= SHY)
	keen.sort_custom(func(a, b): return float(a["rec"]["trust"]) > float(b["rec"]["trust"]))
	for i in keen.size():
		var angle := TAU * i / keen.size() + 0.4
		home.get_tree().create_timer(START_S + i * STAGGER_S).timeout.connect(_notice.bind(home, keen[i], angle))

## The spot beside you at this angle, or the nearest angle that is open ground: a spot on a post or
## a planter next to where you appear can't be reached, and the Boki would give up without a hello.
static func free_slot(home: Node, angle: float) -> Vector3:
	for n in 12:
		var a := angle + TAU / 12.0 * ceilf(n / 2.0) * (1.0 if n % 2 == 0 else -1.0)
		var slot := Vector3(cos(a), 0, sin(a)) * SLOT_M
		if home.world.occupy(home.ppos.x + slot.x, home.ppos.z + slot.z, SLOT_R, 0.0, true) == 0.0:
			return slot
	return Vector3(cos(angle), 0, sin(angle)) * SLOT_M

static func _notice(home: Node, k: Dictionary, angle: float) -> void:
	if not is_instance_valid(home) or not home.kins.has(k) or k.get("busy", false) or k.has("indoors") \
			or float(k.get("nap_t", 0.0)) > 0.0 or k.has("fetch"):
		return
	var slot := free_slot(home, angle)
	k["call_slot"] = slot
	k["called_t"] = 7.0
	k["welcome"] = true
	home._emote(k, "!")
	Sfx.play(KinVoice.cue(k["rec"]["species"], "alert"), k["pos"], -10.0, 0.15, Unique.voice(k["rec"]))
	var my_isle: int = home.world.island_of(home.ppos.x, home.ppos.z)
	if my_isle >= 0 and home.world.island_of(k["pos"].x, k["pos"].z) != my_isle:
		home._start_leap(k, home.ppos + slot)
