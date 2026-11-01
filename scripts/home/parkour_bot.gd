class_name ParkourBot
extends RefCounted
## Runs the parkour course with the real controls: each frame, before the home moves the player,
## it sets what a player would be pressing (walk, Space to jump and hold to glide, Shift to dash)
## through the home's sim_input, which the movement code reads in place of the keyboard. Used by
## --parkour-check (every class) and the course's screenshot demos.

const PH := ["line up", "gaps", "climb", "glide", "pad", "dash gap 1", "dash gap 2", "raft", "finish", "done"]

var h
var c: HomeParkour
var ph := 0
var ph_t := 0.0
var jump_down := false        # holding Space (to glide)
var dashed := false
var on_raft := false
var done := false
var log: Array = []          # [phase, seconds] as each phase ends
var notes: Array = []

func _init(home) -> void:
	h = home
	c = home.training.course

func release_all() -> void:
	h.sim_input = {"move": Vector2.ZERO, "held": {}, "just": {}}
	jump_down = false

## Hands the controls back to the keyboard.
func stop() -> void:
	h.sim_input = {}
	done = true

func _standing() -> bool:
	var g: float = h._ground_h(h.ppos.x, h.ppos.z)
	return h.climb.is_empty() and h.pvy == 0.0 and not h.gliding and g > World.VOID + 1.0 and absf(h.py - g) < 0.03

func _steer(to: Vector2, slow := 1.0) -> Vector2:
	var dv := to - Vector2(h.ppos.x, h.ppos.z)
	var dir := dv.normalized() if dv.length() > 0.05 else Vector2.ZERO
	var k := clampf(dv.length() / 0.6, 0.0, 1.0) * slow
	h.sim_input["move"] = dir * k
	return dir

func _tap_jump() -> void:
	h.sim_input["just"]["jump"] = true
	h.sim_input["held"]["jump"] = true

func _tap_dash() -> void:
	h.sim_input["just"]["dash"] = true

## The ground a little way ahead is sky, or a ledge above your feet: time to jump.
func _need_jump(dir: Vector2, look := 0.55) -> bool:
	if dir == Vector2.ZERO:
		return false
	var a := Vector2(h.ppos.x, h.ppos.z) + dir * look
	var g: float = h._ground_h(a.x, a.y)
	return g <= World.VOID + 1.0 or g > h.py + 0.3

func _next() -> void:
	log.append([PH[ph], snappedf(ph_t, 0.01)])
	ph += 1
	ph_t = 0.0
	dashed = false

func drive(d: float) -> void:
	if done:
		return
	ph_t += d
	# taps last one frame; Space stays held while gliding
	h.sim_input = {"move": Vector2.ZERO, "held": {"jump": jump_down}, "just": {}}
	var st := _standing()
	var p := Vector2(h.ppos.x, h.ppos.z)
	match ph:
		0:   # behind the Start gate
			_steer(Vector2(48.6, 59.5))
			if p.distance_to(Vector2(48.6, 59.5)) < 0.3 and st: _next()
		1:   # two gaps, the second a step up (a short jump caught by a mantle)
			var dir := _steer(Vector2(63.2, 59.5))
			if st and _need_jump(dir): _tap_jump()
			if st and h.ppos.x > 62.2 and absf(h.py - 0.8) < 0.05: _next()
		2:   # a hop, a jump at the wall, a high pull-up
			var dir := _steer(Vector2(70.6, 59.5))
			if st and _need_jump(dir, 0.45): _tap_jump()
			if st and absf(h.py - 5.6) < 0.05 and h.ppos.x > 69.4: _next()
		3:   # off the tower, glide through the rings, fold the glider over the landing
			var dir := _steer(Vector2(83.0, 59.5))
			if st and h.ppos.x < 75.0 and _need_jump(dir):
				_tap_jump(); jump_down = true
			if not st and h.ppos.x >= 80.7 and jump_down:
				jump_down = false; h.sim_input["held"]["jump"] = false
			if st and h.ppos.x > 80.0 and absf(h.py - 0.8) < 0.05:
				jump_down = false
				_next()
		4:   # onto the jump pad; it throws you onto the ledge
			if h.dash_t > 0.0 or not st:
				release_all()
			else:
				_steer(Vector2(HomeParkour.PAD.x, HomeParkour.PAD.z))
			if st and absf(h.py - 3.2) < 0.05 and h.ppos.x < 73.0: _next()
		5:   # a 5m gap: a short dash on the ground, and jump out of it at the edge
			var dir := _steer(Vector2(60.5, 65.5))
			if st and not dashed and h.ppos.x < 69.6 and h.dash_charges >= 1.0:
				_tap_dash(); dashed = true
			if st and dashed and _need_jump(dir, 0.3): _tap_jump()
			if st and not dashed and _need_jump(dir, 0.3) and h.dash_charges < 1.0:
				release_all()      # no charge yet: wait at the edge for it
			if st and absf(h.py - 3.2) < 0.05 and h.ppos.x < 62.9 and h.ppos.x > 58.9: _next()
		6:   # a 5m gap: jump, then the long dash in the air
			var dir := _steer(Vector2(51.6, 65.5))
			if st and _need_jump(dir, 0.3):
				if h.ex_cd > 0.0: release_all()      # the long dash is cooling down: wait for it
				else: _tap_jump()
			if not st and not dashed and h.pvy < 2.5 and h.climb.is_empty():
				_tap_dash(); dashed = true
			if st and absf(h.py - 3.2) < 0.05 and h.ppos.x < 53.9: _next()
		7:   # wait for the raft, step on, ride it over, step off onto the podium
			if not on_raft:
				if c.raft_x > 48.3 and ph_t > 0.2:
					_steer(Vector2(c.raft_x, HomeParkour.RAFT_Z))
					if st and h.world.is_void(h.ppos.x, h.ppos.z) and absf(h.ppos.x - c.raft_x) < 0.5: on_raft = true
				else:
					_steer(Vector2(50.55, 65.5))
			else:
				if c.raft_x < 45.7:
					_next()
				else:
					_steer(Vector2(c.raft_x, HomeParkour.RAFT_Z))
		8:   # through the Finish gate
			_steer(Vector2(40.2, 65.5))
			if c.stats["finished"] > 0 or (st and h.ppos.x < 40.5):
				_next()
				release_all()
				done = true
