class_name FarmKeyHints
extends RefCounted
## The farm's key row along the bottom. A key's hint shows until you have used the key USES times, then it
## goes. Whistle and build come once the farm tutorial is over. Use counts live in tutorial.key_uses.

const USES := 3      # presses of a key after which its hint goes
## id, the actions that count as a use, the key cap text ("" = the first action's key), the label
const KEYS := [
	["walk", ["left", "right", "up", "down"], "W A S D", "walk"],
	["jump", ["jump"], "Space", "jump"],
	["interact", ["interact"], "", "use"],
	["whistle", ["whistle"], "", "whistle"],
	["build", ["build"], "", "build"],
	["menu", ["menu"], "Esc", "menu"],
]
const AFTER_TUTORIAL := ["whistle", "build"]

var box: PanelContainer
var row: HBoxContainer = null
var shown := -1      # bit i set: KEYS[i] is on the row

func _init(hint_box: PanelContainer) -> void:
	box = hint_box
	_rebuild(_wanted())

## Per frame: counts presses, and rebuilds the row when a hint goes or comes.
func tick() -> void:
	var counts: Dictionary = Save.d["tutorial"].get_or_add("key_uses", {})
	for k in KEYS:
		if Array(k[1]).any(func(a): return Input.is_action_just_pressed(a)):
			counts[k[0]] = int(counts.get(k[0], 0)) + 1
	var want := _wanted()
	if want != shown:
		_rebuild(want)

func _wanted() -> int:
	var counts: Dictionary = Save.d["tutorial"].get("key_uses", {})
	var bits := 0
	for i in KEYS.size():
		var id := String(KEYS[i][0])
		if int(counts.get(id, 0)) < USES and not (id in AFTER_TUTORIAL and FarmTutorial.active()):
			bits |= 1 << i
	return bits

func _rebuild(bits: int) -> void:
	shown = bits
	if row:
		box.remove_child(row)
		row.free()
	var pairs: Array = []
	for i in KEYS.size():
		if bits >> i & 1:
			var k: Array = KEYS[i]
			pairs.append([String(k[2]) if k[2] != "" else Settings.key_cap(String(k[1][0])), k[3]])
	row = UI.key_hints(pairs, 12, Color(1, 1, 1, 0.78))
	box.add_child(row)
	box.modulate.a = 0.85 if bits != 0 else 0.0      # nothing left to say: the pill goes clear
