class_name RecastBuffer
extends RefCounted
## The owner's recast rule (DECISIONS 2026-11-08): a recast press that comes a moment before its window opens is
## kept for recast_buffer_s and fires on the open, and a window that closes unused flashes EXPIRED on its slot
## (RecastExpired) for recast_expired_s. One per kit, so no kit carries its own; both numbers are in
## content/rules/tuning.json. Slots are the HUD's: "k1" (E) and "x" (the hero ultimate).

var k: ArchKit
var held := {}          # slot -> s a too-early press is still kept
var expired := {}       # slot -> s the EXPIRED flash has left
var x_open := false     # X's window was open last step
var x_taken := false    # a press took X's window since it opened

func _init(kit: ArchKit) -> void:
	k = kit

## A press found no window to recast: keep it for the buffer.
func early(slot: String) -> void:
	held[slot] = float(Content.rules("tuning")["recast_buffer_s"])

## A fresh cast starts: a press kept from before it belonged to the last cycle, so it goes.
func cast(slot: String) -> void:
	held.erase(slot)

## A press recast the hero ultimate.
func took_x() -> void:
	x_taken = true

## E's window ran out with nobody pressing.
func expire_e() -> void:
	_flash("k1")

func tick(dt: float) -> void:
	var open := k.ult_recastable()
	if open and not x_open:
		x_taken = false
	elif x_open and not open and not x_taken:
		_flash("x")
	x_open = open
	for slot in held.keys():
		held[slot] = float(held[slot]) - dt
		if float(held[slot]) <= 0.0 or _fire(slot):
			held.erase(slot)
	for slot in expired.keys():
		expired[slot] = float(expired[slot]) - dt
		if float(expired[slot]) <= 0.0:
			expired.erase(slot)

## The kept press, if its window is open now: true when it went.
func _fire(slot: String) -> bool:
	if slot == "k1":
		return k.e_t > 0.0 and k.e_recastable() and not k.busy() and k.e_recast()
	if k.ult_recastable() and k.ult_recast():
		took_x()
		return true
	return false

func _flash(slot: String) -> void:
	expired[slot] = float(Content.rules("tuning")["recast_expired_s"])
