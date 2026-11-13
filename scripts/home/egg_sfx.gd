class_name EggSfx
extends RefCounted
## An egg nearing its hatch says so by sound, with no pop-up (docs/AUDIO.md). The sounds follow what the
## egg itself stores, never a clock of their own: a Rare Egg's warmth in its Incubator cradle
## (Incubator.progress) and, for a pair's egg in the Nook's nest, only whether it is ready.
##   past KNOCK_AT  egg_knock: a gentle wobble in the straw and a faint knock from inside, once
##   past CRACK_AT  egg_crack: a small crack every CRACK_S while you are near
##   ready          egg_ready: a chime from the egg, once
## Each plays at the egg and only within EARSHOT_M of it. A step the egg reached while you were out of
## earshot (on an expedition, across the garden) plays when you next come near, once a session.

enum Step { NONE, KNOCK, CRACKS, READY }

const KNOCK_AT := 0.5       # progress (0..1) at which the egg wobbles and knocks
const CRACK_AT := 0.9       # progress from which it cracks while you are near
const CRACK_S := 4.0        # s between two small cracks
const EARSHOT_M := 10.0     # m from the egg; the Incubator and the Nook's nest stand 2.5 m apart

static var heard := {}      # egg key -> the last Step you heard from it this session
static var crack_in := {}   # egg key -> s until its next crack while you are near

## Call every frame for each egg in the garden: key names the egg (its id, or "nest"), progress is the
## share of its hatch it stores (0..1), at is where it sits.
static func hear(key: String, progress: float, at: Vector3, dt: float) -> void:
	var step := _step(progress)
	# an egg that cooled, or a new egg in the nest, starts over
	var last := mini(int(heard.get(key, Step.NONE)), step)
	heard[key] = last
	if Vector2(at.x - Sfx.listener.x, at.z - Sfx.listener.z).length() > EARSHOT_M:
		return
	if step > last:
		heard[key] = step
		if step == Step.KNOCK:
			GardenSfx.cue("egg_knock", at)
		elif step == Step.READY:
			GardenSfx.cue("egg_ready", at)
	if step == Step.CRACKS:
		var left := float(crack_in.get(key, 0.0)) - dt
		if left <= 0.0:
			GardenSfx.cue("egg_crack", at)
			left = CRACK_S
		crack_in[key] = left

static func _step(progress: float) -> Step:
	if progress >= 1.0:
		return Step.READY
	if progress >= CRACK_AT:
		return Step.CRACKS
	return Step.KNOCK if progress >= KNOCK_AT else Step.NONE
