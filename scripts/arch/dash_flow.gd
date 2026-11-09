class_name DashFlow
extends RefCounted
## What an ability press does while its hunter dashes (docs/decisions/0010-dash-ability-flow.md). Each hero's rows
## live in content/dash_flow/<hero>.json: per dash (ground or air) and slot, the press fires mid-dash, waits for the
## dash to end ("buffer", the default for a missing row) or cancels the dash. A press is never dropped.
## The same file's combo rows (docs/decisions/0015-combo-flow.md) cover jumps and holds: a press mid-jump, a jump
## or Shift out of an ability, and a hold carried through a dash, a jump or a mantle; a missing one combines.

const BUFFER_S := 0.15      # s: a held press waits at most this long past the dash's end while the hunter can't act
const SLOTS := ["lmb", "rmb", "e", "x", "q"]
const MODES := ["fire", "buffer", "cancel"]
## The one-step Hunter.inp press each slot reads. LMB is the held "fire" key; X comes in through HunterKeys.
const KEY_OF := {"rmb": "sec", "e": "sig", "q": "gear1"}
const DEFAULT_ROW := {"mode": "buffer", "carry": false, "variant": "", "source": ""}
## The moves an ability combines with (docs/decisions/0015-combo-flow.md): a ground dash, an air dash, a jump.
const MOVES := ["ground", "air", "jump"]
## Owner rule (item 51): every ability combines with every move. A row that says otherwise is an exception and
## carries a reason and a source.
const COMBINE := {"jump": "fire", "into": "fire", "hold": "keep"}

static var _files := {}     # hero id -> its content/dash_flow file (empty when it has none)

var kit: ArchKit
var held := {}              # slot -> seconds it has waited since the dash ended
var landing := {}           # slot -> true: pressed mid-jump, its jump row holds it for the landing
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

## A press of `slot` mid-jump (in the air, not dashing): "fire" (the default) or the exception "buffer" (held for
## the landing).
static func jump_row_of(hero: String, slot: String) -> Dictionary:
	return _combo_row(file_of(hero).get("jump", {}).get(slot, {}), COMBINE["jump"])

## The reverse row for a move pressed during `slot`'s wind-up or recovery: Shift (into_dash, "ground" or "air")
## or a jump (into_jump). "fire" or "cancel" act at once; the exceptions "buffer" (waits for the ability's end) and
## "lock" (refused while it runs) don't. The kits act on these rows.
static func into_row_of(hero: String, slot: String, move: String) -> Dictionary:
	var rows: Dictionary = file_of(hero).get("into_jump" if move == "jump" else "into_dash", {})
	var given: Dictionary = rows.get(slot, {})
	return _combo_row(given.get("air", given) if move == "air" else given, COMBINE["into"])

## Whether a hold or charge of `slot` survives `move` (a MOVES entry, or "mantle"): "keep" (the default) or
## "cancel" (an exception: the move ends it with nothing released).
static func hold_row_of(hero: String, slot: String, move: String) -> Dictionary:
	var rows: Dictionary = file_of(hero).get("hold", {}).get(slot, {})
	return _combo_row(rows.get(move, {}), COMBINE["hold"])

static func _combo_row(given: Dictionary, mode: String) -> Dictionary:
	return {"mode": String(given.get("mode", mode)), "reason": String(given.get("reason", "")),
			"source": String(given.get("source", ""))}

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
		_route_jump(fire_pressed)
		return
	if fire_pressed:
		_press("lmb")          # a held LMB is left alone: holding it through the dash fires at the end anyway
	for slot in KEY_OF:
		var key: String = KEY_OF[slot]
		if h.inp.get(key, false) and _press(slot) == "buffer":
			h.inp[key] = false

## X during a dash (HunterKeys.ult_pressed asks first): true when the press is held for the dash's end, or
## mid-jump for the landing.
func take_x() -> bool:
	if _replaying:
		return false
	if not _sync():
		return _press_mid_jump("x")
	return _press("x") == "buffer"

## The move the hunter is making now, for the hold rows: "mantle", a dash ("ground" or "air", by where it set
## off), "jump" (in the air off a jump or a ledge), or "" (none).
func move_now() -> String:
	var h := kit.h
	if h.mantling():
		return "mantle"
	if kit.in_dash() or h.roll_t > 0.0:
		return "air" if _dash_set_off_in_air() else "ground"
	return "" if h.grounded else "jump"

## The dash a Shift press starts now ("ground" or "air"), for a kit's on_dash.
func dash_move() -> String:
	return "ground" if kit.h.grounded else "air"

## Whether the move under way (or `move`) ends a hold or charge of `slot`, by its hold row. Every kit asks
## this where a move used to end its holds, so the rows decide.
func ends_hold(slot: String, move := "") -> bool:
	var now := move if move != "" else move_now()
	return now != "" and String(hold_row_of(kit.id, slot, now)["mode"]) == "cancel"

## A dash is under way whose row keeps a hold of `slot`: the hold waits, neither charging on nor going off, and
## a release made in it goes when the dash ends.
func pauses_hold(slot: String) -> bool:
	var now := move_now()
	return now in ["ground", "air"] and not ends_hold(slot, now)

## Whether the hunter is dashing now, noting whether a dash that just set off did so in the air.
func _sync() -> bool:
	var dashing := kit.in_dash()
	if dashing and not _was_dashing:
		air = not kit.h.grounded
	_was_dashing = dashing
	return dashing

func _dash_set_off_in_air() -> bool:
	if _was_dashing:
		return air
	return not kit.h.grounded

## Presses made mid-jump: a slot whose jump row says "buffer" is held for the landing.
func _route_jump(fire_pressed: bool) -> void:
	var h := kit.h
	if h.grounded:
		for slot in landing.keys():
			landing.erase(slot)
			_replay(slot)
		return
	if fire_pressed and _press_mid_jump("lmb"):
		h.inp["fire"] = false
	for slot in KEY_OF:
		var key: String = KEY_OF[slot]
		if h.inp.get(key, false) and _press_mid_jump(slot):
			h.inp[key] = false

func _press_mid_jump(slot: String) -> bool:
	if kit.h.grounded or String(jump_row_of(kit.id, slot)["mode"]) != "buffer":
		return false
	landing[slot] = true
	return true

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
