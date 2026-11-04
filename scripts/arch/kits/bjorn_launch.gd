class_name BjornLaunch
extends RefCounted
## Breaker's perfect swing (docs/heroes/bulwark.md, "LMB hold"): let go of the Crushing Blow in the window
## right after it reaches full charge (lmb "perfect.window" s, flagged by the hammer's flash and a click)
## and the slam throws his whole weight forward: "perfect.dist" m over "perfect.time" s, feet off the ground
## (bul_launch), then a skid as he lands. The launch rides the dash plumbing (Hunter.dash_with), so its end
## hands its speed to the glider by the shared rules (Hunter.glide_handoff): carried off a drop he opens the
## glider by himself, and glide or jump pressed during it jumps him out of it into a glide.

## m: a launch that ends this far over the ground below (or over the abyss) opens the glider by itself
const GLIDE_DROP := 2.0

var k: BulwarkKit
var h: Hunter
var left := 0.0                # s of the launch still to run (0: none)
var speed := 0.0               # m/s the launch runs at (checks: what the glider must keep)
var glide_was := false         # glide / jump was already held as it started (only a fresh press jumps out)
var launches := 0              # (checks) perfect swings let go

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h

func pd() -> Dictionary:
	return k.lmb_def().get("perfect", {})

## True while a let-go would be a perfect swing: from full charge until "window" s after it.
func in_window(held_t: float) -> bool:
	return k.smash_k() >= 0.99 and held_t <= float(k.lmb_def()["full"]) + float(pd().get("window", 0.18))

func running() -> bool:
	return left > 0.0

## The perfect swing let go: the launch along `dir`, from the ground or the air (out of a jump or a dash: in the
## air it holds his height like an air dash, then the glider takes its speed or he falls on).
func start(dir: Vector2) -> void:
	launches += 1
	k.play("bul_launch")
	var t := float(pd().get("time", 0.3))
	speed = float(pd().get("dist", 4.0)) / t
	left = t
	glide_was = bool(h.inp.get("glide", false))
	h.dash_with({"type": "dash", "speed": speed, "time": t, "invuln": 0.0, "dir": dir, "trail": ""})
	k.step_until = k.m.time + t

## Every step: a mantle ends it; a fresh glide or jump press jumps out into a glide; past its end, off a drop the
## glider opens by itself, and on the ground his feet plant in a scuff of dust (the skid is bul_launch's).
func tick(dt: float) -> void:
	if left <= 0.0:
		return
	left -= dt
	var glide_now := bool(h.inp.get("glide", false))
	if h.mantling():
		h.roll_t = 0.0
	elif glide_now and not glide_was and h.grounded and h.roll_t > 0.0:
		h.do_jump()            # the dash's own jump-out: it keeps the launch's speed for the glider
	glide_was = glide_now
	if h.roll_t > 0.0 and left > 0.0:
		return
	left = 0.0
	if h.gliding or not h.grounded:
		if k.anim_id == "bul_launch":
			k.anim_id = ""
		if _drop_below() >= GLIDE_DROP:
			h.auto_glide = true
	else:
		h.m.fx.dust(h.pos, 5)

## How far the ground under him lies below (the abyss counts as a long way).
func _drop_below() -> float:
	var g: float = h.m.world.ground_at(h.pos.x, h.pos.z)
	if g <= World.VOID + 1.0:
		return 99.0
	return h.pos.y - g
