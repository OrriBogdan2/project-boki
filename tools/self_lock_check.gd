extends RefCounted
## --self-lock-check, the owner's rule: a hunter's own ability holds them in place only as long as it needs, and never
## shoves them back unless it is a movement ability. Every hero walks across the aim, taps each slot, and keeps
## walking: one SELFLOCK line a slot says how long the walk was held (s) and how far the cast moved them along and
## against the aim (m). Asserts Vex's Palm Lance: she walks again by MOVE_BY after the press and the beam never
## shoves her back. Reuses the dash-flow check's training match and slot presses. Never touches the save.

const SLOTS := ["lmb", "rmb", "e", "x"]  # the dash is a movement ability by design
const WALK_IN := 0.3  # s walked before the press, so the speed is steady
const WATCH := 3.0  # s watched after the press
const HELD_K := 0.25  # a step slower than this share of the free walk is held
const MOVE_BY := 0.25  # s: Vex walks again this soon after her E (the launch only)
const BACK_MAX := 0.05  # m: the most a cast may move her against her aim (no self shove)

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()


func ok(cond: bool, what: String, got := "") -> void:
	var tag := "ok  " if cond else "FAIL"
	print("SELFLOCK %s %s%s" % [tag, what, "" if got == "" else " (" + got + ")"])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		for slot in SLOTS:
			var r := _trial(m, slot)
			print(
				(
					"SELFLOCK %-11s %-3s went %-5s held %.2f s (first free %.2f s) back %.2f m fwd %.2f m"
					% [hero, slot, r["went"], r["held"], r["free"], r["back"], r["fwd"]]
				)
			)
			if hero == "gunslinger" and slot == "e":
				ok(
					bool(r["went"]) and float(r["free"]) <= MOVE_BY,
					"Vex E: she walks again within %.2f s of the press" % MOVE_BY,
					"%.2f s" % r["free"]
				)
				ok(float(r["back"]) < BACK_MAX, "Vex E: the beam never shoves her back", "%.2f m" % r["back"])
		m.queue_free()
		await main.get_tree().process_frame
	print("SELFLOCK DONE, failures: %d" % bad)
	main.get_tree().quit()


## Walks across the aim, presses `slot` for one step and walks on for WATCH s. "held": s of steps under HELD_K of
## the free walk; "free": s from the press to the walk's first step past the first hold (-1: never walked again);
## "back"/"fwd": m moved against/along the aim.
func _trial(m: Match, slot: String) -> Dictionary:
	flow._ready_up(m)
	var h := flow.hunter
	var aim := h.aim_dir()
	var walk := Vector2(-aim.y, aim.x)
	h.inp["move"] = walk
	flow._steps(m, int(WALK_IN / Match.DT))
	var free_v := maxf(1.0, Vector2(h.vel.x, h.vel.z).dot(walk))
	var p0 := h.pos
	var before := flow._snap()
	flow._press(slot)
	var r := {"went": false, "held": 0.0, "free": -1.0, "back": 0.0, "fwd": 0.0}
	for i in int(WATCH / Match.DT):
		m.step(Match.DT)
		h.inp["fire"] = false
		h.inp["move"] = walk
		r["went"] = bool(r["went"]) or flow._went_off(before, slot)
		var along := Vector2(h.pos.x - p0.x, h.pos.z - p0.z).dot(aim)
		r["back"] = maxf(float(r["back"]), -along)
		r["fwd"] = maxf(float(r["fwd"]), along)
		if Vector2(h.vel.x, h.vel.z).dot(walk) < free_v * HELD_K:
			r["held"] = float(r["held"]) + Match.DT
		elif float(r["held"]) > 0.0 and float(r["free"]) < 0.0:
			r["free"] = (i + 1) * Match.DT
	if float(r["held"]) <= 0.0:
		r["free"] = 0.0
	h.inp["move"] = Vector2.ZERO
	return r
