class_name PadFlight
extends RefCounted
## A jump pad's launch (the map's pads and the pocket Spring pad), after SUPERVIVE: a ballistic throw
## under the world's gravity that the keys barely steer (HunterMove.air_control), and at the apex the
## glider opens by itself (DECISIONS: pad and updraft auto-glides are the one exception to "a held Space
## never opens the glider"); from there it is a glide, steered as any glide and keeping the launch's speed.
## A map pad is aimed at its landing: left alone (or a bot) the glide is carried onto the landing and the
## glider folds over it, as a lair's escape updraft does; a steering player keeps the glider. The source's
## data names no pad launch, so HunterMove.pad_vy and pad_clear are [est] on its gravity.

const PUSH := 7.0           # m/s at least: a hands-off glide is carried toward the landing this fast
const LAND_R := 2.5         # m from the landing a hands-off glide folds within at the latest
const POCKET_RUN := 6.0     # m/s at least along your heading off a pocket pad, so you clear it
const SET_DOWN := 1.3       # of run speed: the most you keep into the drop onto the landing

## Off a map pad: thrown so the arc alone would come down on `land`, clearing a higher landing's lip
## by HunterMove.pad_clear.
static func launch_to(h: Hunter, land: Vector3) -> void:
	var g := Hunter.H_GRAV
	var dy := land.y - h.pos.y
	var vy := maxf(HunterMove.pad_vy, sqrt(2.0 * g * (maxf(dy, 0.0) + HunterMove.pad_clear)))
	var apex := vy * vy / (2.0 * g)
	var flight := vy / g + sqrt(2.0 * (apex - dy) / g)       # s up to the apex, then down to the landing's height
	var flat := Vector2(land.x - h.pos.x, land.z - h.pos.z)
	_throw(h, flat / flight, vy, land)

## Off a pocket pad: straight up, keeping the run you brought (at least POCKET_RUN) along your heading.
static func launch_up(h: Hunter) -> void:
	var hv := Vector2(h.vel.x, h.vel.z)
	var dir := hv.normalized() if hv.length() > 0.5 else h.aim_dir()
	_throw(h, dir * maxf(hv.length(), POCKET_RUN), HunterMove.pad_vy, Vector3.INF)

static func _throw(h: Hunter, hv: Vector2, vy: float, land: Vector3) -> void:
	h.vel = Vector3(hv.x, vy, hv.y)
	h.grounded = false
	h.roll_t = 0.0
	h.grap = {}
	h.glide_cd = 0.0
	h.pad_flight = {"land": land, "open": false}

## Each step of a pad flight: the glider opens at the apex, then a hands-off glide is carried to the
## landing and folded over it. The flight is over on landing, or once a press or a hand-opened glider
## makes it the player's own glide.
static func step(h: Hunter) -> void:
	if h.pad_flight.is_empty():
		return
	if h.downed or h.out or (h.grounded and h.vel.y <= 0.0):
		h.pad_flight = {}
		return
	if not h.pad_flight["open"]:
		if h.vel.y > 0.0:
			return
		h.pad_flight["open"] = true
		if h.gliding or not h.can_glide():
			h.pad_flight = {}        # opened by hand already, or a state that can't glide: a plain fall
			return
		h.auto_glide = true
		return
	var land: Vector3 = h.pad_flight["land"]
	if not h.auto_glide or not land.is_finite():
		h.pad_flight = {}            # a fresh press took the glider, or a pocket pad: nothing to carry to
		return
	var steering: bool = h.ctrl != "bot" and (h.inp.get("move", Vector2.ZERO) as Vector2).length() > 0.2
	if steering:
		return
	var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
	var hv := to.normalized() * maxf(Vector2(h.vel.x, h.vel.z).length(), PUSH)
	var set_v := minf(hv.length(), h.base_speed * SET_DOWN)
	var drop_t := sqrt(2.0 * maxf(0.0, h.pos.y - land.y) / Hunter.H_GRAV)      # s the fall from here takes
	if to.length() <= maxf(LAND_R, set_v * drop_t):
		h.auto_glide = false         # where the drop comes down on the landing: fold the glider and drop
		hv = to.normalized() * set_v
		h.pad_flight = {}
	h.vel.x = hv.x
	h.vel.z = hv.y
