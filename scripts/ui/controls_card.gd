class_name ControlsCard
extends RefCounted
## The Esc menu's Controls card: your Hunter's slots with their icons, then the moves every Hunter
## has. Every key cap is read from Settings.key_cap at build time (a rebind shows at once); no key
## is written here (--keys-check scans for that). Each row carries meta "actions": the actions
## whose caps it shows, in order.

const ROW_ICON := 26.0       # px: the icon beside each row
const KEY_CELL := 96.0       # px: room for the caps, so the names line up

## Everyone's moves: [icon, [actions shown as caps], what it does]. A cap is repeated to say "twice".
const EVERYONE := [
	["jump", ["jump", "jump"], "Glide: jump, then jump again and hold"],
	["throw", ["throw"], "Summon your Boki, or call it back"],
	["bond", ["ultimate"], "Fuse with your Boki (full bond bar)"],
	["swap", ["throw"], "Hold for the Boki order wheel"],
	["scanner", ["ping"], "Ping a spot, a foe or loot"],
	["cloak", ["crouch"], "Sneak: slower and quieter"],
]

## Your Hunter's slots: [icon, [actions], name], read from the Hunter's data file.
static func hunter_rows(id: String) -> Array:
	var d := Arch.def(id)
	var out: Array = [[Arch.signature(id), ["fire"], "Attack"]]
	for pair in [["rmb", "secondary"], ["e", "signature"], ["x", "hunter_ult"], ["dash", "dash"]]:
		var sd: Dictionary = d.get(pair[0], {})
		out.append([String(sd.get("icon", "")), [pair[1]], String(sd.get("name", ""))])
	return out

## Fills `v` with the card for Hunter `id` (two columns: yours, then everyone's).
static func fill(v: VBoxContainer, id: String) -> void:
	var cols := UI.hbox(28)
	cols.add_child(_column("Your Hunter", Arch.label(id), Arch.color(id), hunter_rows(id)))
	cols.add_child(_column("Everyone", "", UI.INK, EVERYONE))
	v.add_child(cols)

static func _column(title: String, sub: String, col: Color, rows: Array) -> VBoxContainer:
	var c := UI.vbox(8)
	c.custom_minimum_size.x = 330
	c.add_child(UI.section(title if sub == "" else "%s: %s" % [title, sub], col.lerp(UI.INK, 0.4)))
	for r in rows:
		c.add_child(_row(r[0], r[1], r[2], col))
	return c

static func _row(icon: String, actions: Array, text: String, col: Color) -> HBoxContainer:
	var row := UI.hbox(8)
	row.set_meta("actions", actions)
	row.add_child(UI.IconDot.new(icon, col, ROW_ICON))
	var caps := UI.hbox(3)
	caps.custom_minimum_size.x = KEY_CELL
	for a in actions:
		caps.add_child(UI.keycap(Settings.key_cap(String(a)), 13))
	row.add_child(caps)
	var l := UI.label(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 190
	row.add_child(l)
	return row
