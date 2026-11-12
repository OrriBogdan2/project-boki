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
		var slot := Vector3(cos(TAU * i / keen.size() + 0.4), 0, sin(TAU * i / keen.size() + 0.4)) * 1.4
		home.get_tree().create_timer(START_S + i * STAGGER_S).timeout.connect(_notice.bind(home, keen[i], slot))

static func _notice(home: Node, k: Dictionary, slot: Vector3) -> void:
	if not is_instance_valid(home) or not home.kins.has(k) or k.get("busy", false) or k.has("indoors") \
			or float(k.get("nap_t", 0.0)) > 0.0 or k.has("fetch"):
		return
	k["call_slot"] = slot
	k["called_t"] = 7.0
	k["welcome"] = true
	home._emote(k, "!")
	Sfx.play("kin_alert", k["pos"], -10.0, 0.15, Unique.voice(k["rec"]))
	var my_isle: int = home.world.island_of(home.ppos.x, home.ppos.z)
	if my_isle >= 0 and home.world.island_of(k["pos"].x, k["pos"].z) != my_isle:
		home._start_leap(k, home.ppos + slot)
