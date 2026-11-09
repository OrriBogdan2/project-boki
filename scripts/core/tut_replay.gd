class_name TutReplay
extends RefCounted
## Replays a tutorial from the pause menu (More): the same match tutorial (Tutorial / TutorialDrive) and
## garden tutorial (FarmTutorial / FarmGuide) that new saves run, on a throwaway copy of the save.
## While it runs Save.d is the copy and nothing is written to disk; leaving puts the real save object
## back untouched, so progress, inventory, Boki and Goals never change. You land on the farm again.

const DONE_S := 2.5        # s the farm shows "done" before the replay hands you back
const DONE_TOAST := "That's the tutorial again. Nothing was kept."

static var _real: Dictionary = {}     # the save you came from, never touched while replaying
static var _was_no_write := false
static var _on := false
static var _ending := false      # the farm told you it is done and the hand-back is counting down

static func active() -> bool:
	return _on

## The match tutorial on a copy of your save (the "replay" option makes Match._finish leave).
static func match_tutorial() -> void:
	_enter(Save.d.duplicate(true))
	Game.start_match({"tutorial": true, "replay": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})

## The garden tutorial on a brand new farm that has your Hunter and your active Boki.
static func garden_tutorial() -> void:
	_enter(_garden_save())
	Game.goto("home")

## The garden tutorial finished (or was skipped) on the farm `h`: a word, then back to the real farm.
static func farm_done(h: Node) -> void:
	if _ending:
		return
	_ending = true
	h._toast(DONE_TOAST)
	h.get_tree().create_timer(DONE_S).timeout.connect(leave)

## Back to the farm with the real save.
static func leave() -> void:
	if not _on:
		return
	_on = false
	_ending = false
	Save.d = _real
	Save.no_write = _was_no_write
	_real = {}
	Game.goto("home")

static func _enter(copy: Dictionary) -> void:
	_real = Save.d
	_was_no_write = Save.no_write
	Save.no_write = true
	Save.d = copy
	_on = true

static func _garden_save() -> Dictionary:
	var d := Save.fresh()
	for k in ["name", "arch", "cls", "weapon", "classes", "profile"]:
		if Save.d.has(k):
			d[k] = Save.d[k].duplicate(true) if Save.d[k] is Dictionary else Save.d[k]
	var kin: Dictionary = Save.kin(str(Save.d.get("active", ""))).duplicate(true)
	if kin.is_empty():
		kin = Save.new_kin("zapple", "Pip")
	kin["starter"] = true
	d["roster"].append(kin)
	d["active"] = kin["uid"]
	HomeLayout.new_fs(d)
	d["tutorial"] = {"home": true, "hatched": true}
	return d
