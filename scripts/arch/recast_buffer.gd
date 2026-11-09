class_name RecastBuffer
extends RefCounted
## The owner's recast rule (DECISIONS 2026-11-08): a recast press that comes just before its window opens, or while a
## prior move recovers, is kept for buffer_s and fires when the window opens; a window that closes unused leaves
## the slot showing EXPIRED for expired_s (RecastCue draws it). Both numbers are in content/rules/recast.json.
## One per kit. It reads the open window through ArchKit.recast_left / recast_slot, so every recast kit is covered.

var k: ArchKit
var held := {}          # slot -> s a press that found no window is still kept
var expired := {}       # slot -> s the EXPIRED state has left
var _was_open := false   # a window was open at the last step...
var _slot := ""         # ...on this slot
var _used := false      # a press took (or a cast began) since it opened

func _init(kit: ArchKit) -> void:
	k = kit

## A press on `slot` did nothing (cooling down, busy, or no window yet): keep it for the buffer.
func early(slot: String) -> void:
	held[slot] = float(Content.rules("recast")["buffer_s"])

## A cast or recast on `slot` went off: a press kept from before it belonged to the last cycle, and a window
## open now is not left unused.
func took(slot: String) -> void:
	held.erase(slot)
	_used = true

func tick(dt: float) -> void:
	var left := k.recast_left()
	var slot := k.recast_slot()
	var open := left > 0.0
	if open and (not _was_open or slot != _slot):
		_used = false
	elif _was_open and not open and not _used:
		expired[_slot] = float(Content.rules("recast")["expired_s"])
	_was_open = open
	_slot = slot
	for s in held.keys():
		held[s] = float(held[s]) - dt
		if open and s == slot and k.recast_fire():
			took(s)
		elif float(held[s]) <= 0.0:
			held.erase(s)
	for s in expired.keys():
		expired[s] = float(expired[s]) - dt
		if float(expired[s]) <= 0.0:
			expired.erase(s)
