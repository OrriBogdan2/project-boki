class_name FireTap
extends RefCounted
## LMB tapped between two frames' reads. The key state a frame reads is "down now", so a press and release inside one
## render frame (a quick click on a slow frame or after a stall) read as no press at all. The other keys read
## "went down this frame", which keeps a tap; the held fire key latches that the same way: the tap stays down for
## the next fixed step, once, and the weapon sees one press (docs/MOVEMENT_FEEL.md "Low frame rates").

const TAP := "fire_tap"      # h.inp key: a tap waits for its fixed step

## Per frame from Match._gather_input: is the attack key down this step (held, or tapped and not stepped yet)?
static func down(h: Hunter, allowed: bool) -> bool:
	var held := Input.is_action_pressed("fire")
	if allowed and Input.is_action_just_pressed("fire") and not held:
		h.inp[TAP] = true
	elif not allowed:
		h.inp[TAP] = false
	return allowed and (held or bool(h.inp.get(TAP, false)))

## After each fixed step: a tap was down for that one step only.
static func stepped(h: Hunter) -> void:
	if h != null and h.inp.get(TAP, false):
		h.inp[TAP] = false
		h.inp["fire"] = false
