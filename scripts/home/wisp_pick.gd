class_name WispPick
extends RefCounted
## Where you choose your Boki wisp's trail, sparkle colour and orbit (BokiWispCosmetics): one chip row per
## line on the Hunters screen, under the glider. A click wears it from now on.

const LABELS := {"trail": "Boki wisp trail", "sparkle": "Boki wisp sparkles", "orbit": "Boki wisp orbit"}

static func pick(home: Node, hunter_id: String, width: float) -> Control:
	var v := UI.vbox(4)
	v.set_meta("wisp_pick", true)
	for line in BokiWispCosmetics.LINES:
		v.add_child(UI.label(LABELS[line], 12, UI.MUTED, UI.caps))
		var flow := HFlowContainer.new()
		flow.custom_minimum_size.x = width
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		v.add_child(flow)
		var opts := BokiWispCosmetics.options(line)
		for id in opts:
			var b := UI.choice(String(opts[id]["name"]), id == BokiWispCosmetics.equipped(line),
					func(): _wear(home, hunter_id, line, id), 0)
			b.set_meta("wisp_" + line, id)
			b.tooltip_text = String(opts[id]["desc"])
			flow.add_child(b)
	return v

static func _wear(home: Node, hunter_id: String, line: String, id: String) -> void:
	if not BokiWispCosmetics.equip(line, id):
		return
	Save.save_game()
	Sfx.play("hover", null, -6.0)
	HomeClasses.open(home, hunter_id)
