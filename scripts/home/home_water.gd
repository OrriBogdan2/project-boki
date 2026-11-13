class_name HomeWater
extends RefCounted
## (feelfix) The farm's ponds are water you can wade into and swim in. The edge tiles are shallow
## (you wade, slower); the middle is deep (you swim: sunk to the shoulders, slower still, tipped into
## a stroke while you move, no dash, no tools; Space kicks you up out of the water). Going in splashes, a dash
## through the shallows sprays and running leaves a wake (WaterFx), swimming plays strokes and ripples, climbing
## out drips. Water is never void.
##
## home.gd calls: depth(x, z) each step, step(...) with it, speed_mul(...), drop_y() and tilt(...) for a hunter;
## home_gather.gd asks swimming. Boki in the water are BokiWade's.

const WADE_SPEED := 0.68     # walk-speed multiplier in the shallow edge
const SWIM_SPEED := 0.5      # walk-speed multiplier in the deep middle
const SINK_DEEP := 0.62      # m the hunter sinks swimming
const SINK_WADE := 0.14      # m the hunter sinks wading
const STROKE_TILT := 0.75    # rad tipped forward at full swim speed
const BREACH_V := 0.85       # share of a normal jump's lift when you kick up out of deep water

var h                        # the Home screen
var swimming := false
var k := 0.0                 # eased 0 dry .. 1 swimming (how far you've sunk in)
var wade_k := 0.0            # eased 0 .. 1 wading
var ph := 0.0                # the stroke's bob (rad)
var was := 0                 # last step's depth
var stroke_t := 0.0
var wfx: WaterFx             # the splash, spray and wake (made the first time you step in)

func _init(home) -> void:
	h = home

## Pond water under (x, z): 0 none, 1 shallow (a tile on the pond's edge: wade), 2 deep (swim).
func depth(x: float, z: float) -> int:
	var ix := int(floor(x)); var iz := int(floor(z))
	if not is_water(ix, iz):
		return 0
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if not is_water(ix + dx, iz + dz): return 1
	return 2

func is_water(ix: int, iz: int) -> bool:
	if not h.fs and ix >= 32 and ix <= 34 and iz >= 36 and iz <= 38:
		return true          # the classic farm's pond
	return h.hb != null and (h.hb.L()["water"] as Dictionary).has(HomeLayout.key(ix, iz))

## Walk-speed multiplier for the depth you're in.
func speed_mul(wdep: int, air: bool) -> float:
	return SWIM_SPEED if swimming else (WADE_SPEED if wdep == 1 and not air else 1.0)

## How far the hunter's model sits below the ground (sunk in, bobbing).
func drop_y() -> float:
	return k * SINK_DEEP + wade_k * SINK_WADE - (sin(ph) * 0.04 if k > 0.05 else 0.0)

## The hunter's basis, tipped forward into a stroke while moving (upright treading water when still).
func tilt(b: Basis, speed: float) -> Basis:
	if k <= 0.01: return b
	return b * Basis(Vector3.RIGHT, -STROKE_TILT * k * clampf(speed / maxf(0.1, h.SPEED * SWIM_SPEED), 0.0, 1.0))

## Splashes, strokes and sounds as you go in, swim about and climb out.
func step(wdep: int, d: float, mv: Vector2, air: bool) -> void:
	swimming = wdep == 2 and not air
	k = move_toward(k, 1.0 if wdep == 2 and not air else 0.0, d * (2.6 if wdep == 2 and not air else 7.0))     # rise out fast on a jump
	wade_k = move_toward(wade_k, 1.0 if wdep >= 1 else 0.0, d * 4.0)
	var fx = h.fx
	var at: Vector3 = h.ppos + Vector3(0, 0.08, 0)
	if wdep > 0 and was == 0:
		# in you go: a splash, bigger from a jump or a fall and for a bigger Hunter
		var hard := clampf(-h.pvy / 8.0, 0.0, 1.0)
		Sfx.play("splash", h.ppos, -8.0 + hard * 6.0, 0.08, 1.05 - hard * 0.1)
		if fx:
			if wfx == null:
				wfx = WaterFx.new()
				fx.add_child(wfx)
			wfx.set_body(WaterFx.size_of(Arch.of_save(), Data.class_of_save()))
			wfx.splash(at, hard)
	elif wdep == 0 and was > 0:
		Sfx.play("drip", h.ppos, -10.0)
		if fx: fx.burst(at + Vector3(0, 0.4, 0), Color("cfeaff"), 6, 1.4, 0.4)
	elif wdep == 2 and was == 1:
		Sfx.play("splash", h.ppos, -14.0, 0.1, 1.25)       # in over your head
	was = wdep
	if wdep == 0:
		stroke_t = 0.0
		return
	if wfx and wdep == 1 and not air:
		wfx.move(at, Vector2(h.pvel.x, h.pvel.z), h.dash_t > 0.0, d)
	var moving := mv.length() > 0.2
	ph += d * (6.5 if moving and wdep == 2 else 2.4)
	stroke_t -= d
	if stroke_t <= 0.0 and (moving or wdep == 2):
		stroke_t = 0.75 if wdep == 2 else 0.45
		if wdep == 2 or moving:
			Sfx.play("swim" if wdep == 2 else "step_grass", h.ppos, -15.0 if wdep == 2 else -20.0, 0.12)
		if fx and wdep == 2:      # (wading leaves its wake instead)
			fx.ring(at, 0.55 if moving else 0.4, Color(0.85, 0.95, 1.0, 0.55), 0.6)
			if moving: fx.burst(at + Vector3(0, 0.1, 0), Color("e8f7ff"), 4, 1.6, 0.35)

## Jumping while swimming: a kick up out of the water (a bit lower than a jump on land), with a
## splash and a spray of droplets. Returns the upward speed to use.
func breach(jump_v: float) -> float:
	var at: Vector3 = h.ppos + Vector3(0, 0.08, 0)
	Sfx.play("splash", h.ppos, -7.0, 0.08, 1.15)
	if h.fx:
		h.fx.burst(at + Vector3(0, 0.3, 0), Color("e8f7ff"), 18, 3.6, 0.55, 12.0, 1.0, Vector3.UP, 40.0)
		h.fx.ring(at, 1.1, Color(0.85, 0.95, 1.0, 0.8), 0.45)
	return jump_v * BREACH_V
