class_name MobSpares
extends Node3D
## Ready-built plain monster models, so a wave, a guard pack or a camp waking mid-fight does not build
## (about 30 ms each) in the frame it appears. Kinds already met get a few spares, built one every few
## frames while the match runs; a spare is pristine (the spawn dresses it) and sits hidden under this node.
## Bosses, Blight kinds and the Shrubling have their own builders and are built on demand as before.

const TARGET := 4
const EVERY := 3
var _spare := {}        # kind -> Array of models
var _frame := 0

func _init() -> void:
	name = "MobSpares"
	visible = false

static func plain(kind: String) -> bool:
	var md: Dictionary = Data.MOBS[kind]
	return kind != "shrubling" and not (md.get("blight", false) or md.get("boss", false) or md.get("ward", false))

## A model for `kind`: a spare if one is ready, else built now. Remembers the kind so it gets spares.
func take(kind: String) -> Node3D:
	if not plain(kind):
		return Models.mob(kind)
	var a: Array = _spare.get(kind, [])
	_spare[kind] = a
	if a.is_empty():
		return Models.mob(kind)
	var n: Node3D = a.pop_back()
	remove_child(n)
	return n

func ready(kind: String) -> int:
	return (_spare.get(kind, []) as Array).size()

func _process(_dt: float) -> void:
	_frame += 1
	if _frame % EVERY != 0:
		return
	for k in _spare:
		var a: Array = _spare[k]
		if a.size() < TARGET:
			var n := Models.mob(k)
			add_child(n)
			a.append(n)
			return
