class_name DashFlow
extends RefCounted
## What an ability press does while its hunter dashes (docs/decisions/0010-dash-ability-flow.md). Each hero's rows
## live in content/dash_flow/<hero>.json: per dash (ground or air) and slot, the press fires mid-dash, waits for the
## dash to end ("buffer", the default for a missing row) or cancels the dash. A press is never dropped.

const BUFFER_S := 0.15      # s: a held press waits at most this long past the dash's end while the hunter can't act
const SLOTS := ["lmb", "rmb", "e", "x", "q"]
const MODES := ["fire", "buffer", "cancel"]
## The one-step Hunter.inp press each slot reads. LMB is the held "fire" key; X comes in through HunterKeys.
const KEY_OF := {"rmb": "sec", "e": "sig", "q": "gear1"}
const DEFAULT_ROW := {"mode": "buffer", "carry": false, "variant": "", "source": ""}

static var _files := {}     # hero id -> its content/dash_flow file (empty when it has none)

var kit: ArchKit
var held := {}              # slot -> seconds it has waited since the dash ended
var air := false            # the dash running now set off in the air
var _was_dashing := false
var _fire_was := false
var _replaying := false

func _init(owner_kit: ArchKit) -> void:
	kit = owner_kit

## The hero's whole dash-flow file ({} when it has none: every press buffers).
static func file_of(hero: String) -> Dictionary:
	if not _files.has(hero):
		var path := "res://content/dash_flow/%s.json" % hero
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_files[hero] = parsed if parsed is Dictionary else {}
	return _files[hero]

## The row for a press of `slot` during a ground or air dash, missing fields filled from DEFAULT_ROW.
static func row_of(hero: String, slot: String, in_air: bool) -> Dictionary:
	var dash: Dictionary = file_of(hero).get("dash", {})
	var given: Dictionary = dash.get("air" if in_air else "ground", {}).get(slot, {})
	return DEFAULT_ROW.merged(given, true)

## The reverse row: Shift pressed during `slot`'s wind-up or recovery ({} when the kit still decides on its own).
static func into_dash_of(hero: String, slot: String) -> Dictionary:
	return file_of(hero).get("into_dash", {}).get(slot, {})

## This hunter's row for `slot` in the dash running now (kits read carry and variant from it).
func row(slot: String) -> Dictionary:
	return row_of(kit.id, slot, air)

## Each step, before Hunter.tick reads its presses: routes the presses made during a dash by the rows and lets the
## held ones go once the dash is over.
func route(dt: float) -> void:
	var h := kit.h
	var dashing := _sync()
	var fire_down := bool(h.inp.get("fire", false))
	var fire_pressed := fire_down and not _fire_was
	_fire_was = fire_down
	if not dashing:
		_release(dt)
		return
	if fire_pressed:
		_press("lmb")          # a held LMB is left alone: holding it through the dash fires at the end anyway
	for slot in KEY_OF:
		var key: String = KEY_OF[slot]
		if h.inp.get(key, false) and _press(slot) == "buffer":
			h.inp[key] = false

## X during a dash (HunterKeys.ult_pressed asks first): true when the press is held for the dash's end.
func take_x() -> bool:
	if _replaying or not _sync():
		return false
	return _press("x") == "buffer"

## Whether the hunter is dashing now, noting whether a dash that just set off did so in the air.
func _sync() -> bool:
	var dashing := kit.in_dash()
	if dashing and not _was_dashing:
		air = not kit.h.grounded
	_was_dashing = dashing
	return dashing

func _press(slot: String) -> String:
	var r := row(slot)
	var mode := String(r["mode"])
	if mode == "buffer":
		held[slot] = 0.0
	elif mode == "cancel":
		_cancel(bool(r["carry"]))
	return mode

## The press ends the dash; without carry the hunter keeps no more than run speed out of it.
func _cancel(carry: bool) -> void:
	var h := kit.h
	h.roll_t = 0.0
	_was_dashing = false
	if carry:
		return
	var flat := Vector2(h.vel.x, h.vel.z).limit_length(h.base_speed)
	h.vel = Vector3(flat.x, h.vel.y, flat.y)

func _release(dt: float) -> void:
	for slot in held.keys():
		if kit.busy() and float(held[slot]) < BUFFER_S:
			held[slot] = float(held[slot]) + dt
			continue
		held.erase(slot)
		_replay(slot)

## The held press goes now, through the slot's own path (which casts or answers with its deny cue).
func _replay(slot: String) -> void:
	var h := kit.h
	match slot:
		"lmb":
			h.inp["fire"] = true       # a tap; still held, the weapon already fires on its own
		"x":
			_replaying = true
			HunterKeys.ult_pressed(h)
			_replaying = false
		_:
			h.inp[KEY_OF[slot]] = true
