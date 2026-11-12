extends RefCounted
## --dash-jump-check: Space during a ground dash and an air dash, Shift in a jump's rise, and both on the same
## step, for all 12 Hunters. Each case is measured headless and must do what the hero's dash_jump row in
## content/dash_flow/<id>.json says ("ours"); docs/heroes/dash_interactions.md shows the rows next to the source.
## Modes: cancel (the jump goes at once and ends the dash, keeping `carry` of its speed), both (the jump goes and
## the dash runs on), ignore (the dash runs on and the press is dropped), end (the dash ends, no jump), buffer (the
## jump waits for the dash's end), dash (Shift: the air dash goes at once and ends the rise). Never touches the save.

const FLOW := preload("res://tools/dash_flow_check.gd")
const CASES := ["ground", "air", "rise", "same"]
const WATCH := 60               # steps after the dash's end that a buffered jump may still go off in
const RISE_STEPS := 6           # Shift 0.1 s into the jump: still rising (apex ~0.46 s)
const AIR_DASH_AT := 12         # the air dash goes 0.2 s into a jump
const CARRY_TOL := 0.05         # share of the dash's speed kept into the jump, +-

var bad := 0
var flow = FLOW.new()
var h: Hunter

func ok(cond: bool, what: String) -> void:
	print("DASHJUMP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		h = flow.hunter
		var rows: Dictionary = DashFlow.file_of(hero).get("dash_jump", {})
		for kind in CASES:
			var got: Dictionary = _measure(m, kind)
			var row: Dictionary = rows.get(kind, {})
			var want := String(row.get("ours", "missing"))
			var carry_ok := not row.has("carry") or absf(float(got["carry"]) - float(row["carry"])) <= CARRY_TOL
			ok(got["mode"] == want and carry_ok, "%s %s: %s carry %.2f (row: %s %s)" % [hero, kind, got["mode"],
					got["carry"], want, str(row.get("carry", ""))])
		m.queue_free()
		await main.get_tree().process_frame
	print("DASHJUMP DONE, failures: %d" % bad)
	main.get_tree().quit()

func _measure(m: Match, kind: String) -> Dictionary:
	flow._ready_up(m)
	h.inp["move"] = Vector2(0, -1)
	match kind:
		"ground":
			return _space_in_dash(m)
		"air":
			_tap(m, "jump")
			_steps(m, AIR_DASH_AT)
			return _space_in_dash(m)
		"rise":
			_tap(m, "jump")
			_steps(m, RISE_STEPS - 1)
			_tap(m, "dash")
			var flat := h.ak.in_dash() and h.vel.y <= 0.0
			return {"mode": "dash" if flat else "late", "carry": 0.0}
	var spent := h.dashes
	h.inp["dash"] = true
	_tap(m, "jump")
	h.inp["dash"] = false
	return _what_now(m, spent - h.dashes > 0.5, h.roll_speed)

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(Match.DT)

func _tap(m: Match, key: String) -> void:
	h.inp[key] = true
	m.step(Match.DT)
	h.inp[key] = false

func _hv() -> float:
	return Vector2(h.vel.x, h.vel.z).length()

## Space once the dash moves (a wind-up crouch or a lob's first steps go by first).
func _space_in_dash(m: Match) -> Dictionary:
	h.inp["dash"] = true
	var n := 0
	while not (h.ak.in_dash() and _hv() > h.base_speed) and n < 30:
		m.step(Match.DT)
		h.inp["dash"] = false
		n += 1
	h.inp["dash"] = false
	if not h.ak.in_dash():
		return {"mode": "no dash", "carry": 0.0}
	m.step(Match.DT)
	var speed := _hv()
	_tap(m, "jump")
	return _what_now(m, true, speed)

## What the step with Space in it did: a jump is a fresh JumpZVelocity (less one step of gravity).
func _what_now(m: Match, dashed: bool, speed: float) -> Dictionary:
	var jumped := h.vel.y > Hunter.JUMP_V * 0.9
	var carry := _hv() / speed if jumped and speed > 0.1 else 0.0
	if jumped:
		var mode := "jump"
		if h.ak.in_dash():
			mode = "both"
		elif dashed:
			mode = "cancel"
		return {"mode": mode, "carry": carry}
	if not h.ak.in_dash():
		return {"mode": "end", "carry": 0.0}
	var n := 0
	while h.ak.in_dash() and n < 300:
		m.step(Match.DT)
		n += 1
	for i in WATCH:
		if h.vel.y > Hunter.JUMP_V * 0.9:
			return {"mode": "buffer", "carry": 0.0}
		m.step(Match.DT)
	return {"mode": "ignore", "carry": 0.0}
