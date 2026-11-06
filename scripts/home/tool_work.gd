class_name ToolWork
extends RefCounted
## The player's tool swing at home, shared by chopping (axe), mining (pickaxe) and hammering a
## building site (hammer). It keeps the swing's clock and calls the owner's hit when the head lands
## (HunterTool.IMPACT of the swing). While the interact key is held the swing loops; let go and the
## swing in progress finishes, then the tool goes away. Home passes anim_state() to HunterAnim.

var tool := ""                   # "axe" | "pickaxe" | "hammer" | "" when not working
var swing_t := 0.0               # seconds into the current swing
var target := Vector3.ZERO       # what is being worked on, to face it
var test_hold := false           # checks and screenshots: the key stays down
var _landed := false
var _on_hit: Callable

## Starts working with `kind` on `at`. on_hit() -> bool is called on every impact; false stops the work.
## first_t skips part of the first wind-up so a press answers quickly.
func begin(kind: String, at: Vector3, on_hit: Callable, first_t := 0.0) -> void:
	tool = kind
	target = at
	swing_t = first_t
	_landed = swing_t >= HunterTool.period(kind) * HunterTool.IMPACT
	_on_hit = on_hit

## Is the interact key down?
func held() -> bool:
	return test_hold or Input.is_action_pressed("interact")

func active() -> bool:
	return tool != ""

func stop() -> void:
	tool = ""

## Advances the swing. `held` is whether the key is still down.
func tick(dt: float, held: bool) -> void:
	if tool == "":
		return
	var period := HunterTool.period(tool)
	swing_t += dt
	if not _landed and swing_t >= period * HunterTool.IMPACT:
		_landed = true
		if not _on_hit.call():
			stop()
			return
	if swing_t >= period:
		swing_t -= period
		_landed = false
		if not held:
			stop()

## Which way to face from `from`.
func face_from(from: Vector3) -> float:
	return atan2(-(target.x - from.x), -(target.z - from.z))

## What home hands to HunterAnim every frame.
func anim_state() -> Dictionary:
	if tool == "":
		return {"holster": true}
	return {"holster": true, "tool": tool, "tool_t": swing_t, "act": HunterTool.act_of(tool)}
