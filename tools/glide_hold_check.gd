extends "res://tools/abyss_check.gd"
## --glide-hold-check (DECISIONS "holding Space NEVER opens the glider"): with a player's keys
## (inp glide_press_only) the glider opens only from a fresh press in the air; Space held from the jump, or
## held while LMB fires, never opens it; a press-opened glider re-opens after a fold while still held.
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const SECS := 2.0       # how long each scenario runs

## One scenario: stand on flat ground, then step SECS with `script` (Callable(i) -> void) setting inputs each
## step. Returns the seconds the glider was open.
func _scenario(script: Callable) -> float:
	_reset(w.random_ground() + Vector3(0, 0.3, 0), Vector3.ZERO)
	for i in 20: m.step(Match.DT)
	h.inp["glide_press_only"] = true
	var open_t := 0.0
	for i in int(SECS / Match.DT):
		h.inp["jump"] = false
		h.inp["fire"] = false
		h.inp["glide_btn"] = false
		script.call(i)
		m.step(Match.DT)
		if h.gliding: open_t += Match.DT
	_reset(h.pos, Vector3.ZERO)
	return open_t

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(w.random_ground())
	h.ctrl = "local"
	m.opts["god"] = true
	var held := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
	ok(_scenario(held) == 0.0, "jump and hold Space for 2s: never glides")
	var held_fire := func(i: int) -> void:
		held.call(i)
		h.inp["fire"] = true
	ok(_scenario(held_fire) == 0.0, "LMB held, jump and hold Space for 2s: never glides")
	var held_btn := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 5          # the button goes down on the ground, then the jump
		h.inp["glide_btn"] = true
	ok(_scenario(held_btn) == 0.0, "glide button held since before the jump: never glides")
	var double := func(i: int) -> void:
		h.inp["glide"] = i == 0 or i >= 12
		h.inp["jump"] = i == 0 or i == 12
	ok(_scenario(double) > 0.5, "jump, release, press Space again and hold: glides")
	var btn := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
		h.inp["glide_btn"] = i >= 12
	ok(_scenario(btn) > 0.5, "jump, then a fresh glide-button press and hold: glides")
	var fold := {"closed": false, "reopened": false}
	var refold := func(i: int) -> void:
		double.call(i)
		if i == 30:
			h.glide_cd = 0.4            # a heal's fold: still held, it comes back
		if i > 31 and h.glide_cd > 0.0:
			fold["closed"] = not h.gliding
		if fold["closed"] and h.gliding:
			fold["reopened"] = true
	_scenario(refold)
	ok(fold["closed"] and fold["reopened"], "a press-opened glider re-opens after a fold while still held")
	var dash_hold := func(i: int) -> void:
		held.call(i)
		if i == 20:
			h.roll_t = 0.1
			h.roll_dir = Vector2(1, 0)
			h.roll_speed = 14.0
	ok(_scenario(dash_hold) == 0.0, "Space held since the jump, an air dash ending: still no glider")
	m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
