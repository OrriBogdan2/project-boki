class_name BokiMoves
extends HBoxContainer
## A Boki's moves as a row of icon tiles, name only. Hovering a tile, or
## focusing it with a keyboard or controller, shows a small tip with what the move does, its numbers
## and how it is used. The bond move (its Fusion) gets its own gold tile. Used on the new-Boki screen
## (KinReveal) and the Boki page's Training tab.
##
##   v.add_child(BokiMoves.new(species_id, rec))

const TILE := Vector2(96, 86)          # px, one move tile
const ICON_PX := 30.0
const TIP_W := 300.0                   # px, the tip's text width
const BOND_COL := Color("ffd84a")      # the Fusion's colour (same gold as the Boki page)

var tiles: Array[Control] = []
var tips: Array[String] = []           # per tile: the tip's text, in plain lines
var shown := -1                        # the tile whose tip is open
var tip: PanelContainer
var tip_box: VBoxContainer

func _init(species: String, rec := {}) -> void:
	add_theme_constant_override("separation", 8)
	var sp: Dictionary = Data.KIN.get(species, {})
	var kspec := KinLib.kin(species)
	var abl: Array = sp.get("abilities", [])
	for i in abl.size():
		var ad := KinLib.ability(String(abl[i]))
		if ad == null:
			continue
		var slot := "k1" if i == 0 else "k2"
		var eff := KinLib.effective(ad, slot, kspec, rec)
		var lines := [KinText.ability(eff), "%s  ·  %ss cooldown" % [_when(ad, slot), KinText.n(ad.cooldown)]]
		_add(ad.display_name, KinText.icon(ad), KinText.color(ad).lerp(UI.INK, 0.2), lines, false)
	var ud := KinLib.merge(String(sp.get("ultimate", "")))
	if ud:
		var head: Array = KinText.merge(ud, kspec != null and kspec.carry_style == "mount")
		var what := String(head[0]) if not head.is_empty() else ""
		var lines := [what, "Fill the bond meter, then press %s to fuse" % Settings.key_caps("ultimate")]
		_add(ud.display_name, "bond", BOND_COL, lines, true)
	tip = UI.card(Color(0.06, 0.06, 0.08, 0.96), 12, 10)
	UI.set_card_border(tip, UI.LINE, 1)
	tip.top_level = true
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip.z_index = 10
	tip_box = UI.vbox(4)
	tip.add_child(tip_box)
	add_child(tip)

## When it goes off: its first ability on its own once it is out, the others on their own cue.
func _when(ad: AbilitySpec, slot: String) -> String:
	if slot == "k1":
		return "Uses it on its own once you send it out (%s)" % Settings.key_cap("throw")
	var w := KinText.when(ad)
	return w if w != "" else "Uses it on its own"

func _add(nm: String, icon: String, col: Color, lines: Array, bond: bool) -> void:
	var t := PanelContainer.new()
	var fill := Color(col, 0.16 if bond else 0.08)
	var edge_w := 2 if bond else 1
	var edge := Color(col, 0.85 if bond else 0.35)
	var sb := UI.frame(fill, 10, edge, edge_w, 6, 6, 0.0)
	t.add_theme_stylebox_override("panel", sb)
	var focus_sb := UI.frame(fill, 10, UI.ACCENT_HI, 2, 6, 6, 0.0)
	t.custom_minimum_size = TILE
	t.focus_mode = Control.FOCUS_ALL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(v)
	if bond:
		var cap := UI.label("Bond move", 10, col, UI.semi)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cap)
	var ic := UI.IconDot.new(icon, col, ICON_PX)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nl := UI.label(nm, 12, UI.INK, UI.semi)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = TILE.x - 12.0
	v.add_child(nl)
	var i := tiles.size()
	t.mouse_entered.connect(func(): show_tip(i))
	t.focus_entered.connect(func():
		show_tip(i)
		t.add_theme_stylebox_override("panel", focus_sb))
	t.mouse_exited.connect(func(): if not t.has_focus(): hide_tip(i))
	t.focus_exited.connect(func():
		hide_tip(i)
		t.add_theme_stylebox_override("panel", sb))
	tiles.append(t)
	tips.append("\n".join([nm] + lines.filter(func(s): return String(s) != "")))
	add_child(t)

## Opens tile i's tip just above it (below it when there is no room above).
func show_tip(i: int) -> void:
	if i < 0 or i >= tiles.size():
		return
	shown = i
	for c in tip_box.get_children():
		tip_box.remove_child(c)
		c.free()
	var lines := tips[i].split("\n")
	for j in lines.size():
		var head := j == 0           # the move's name
		var col := UI.INK if j < 2 else UI.MUTED     # name and what it does bright, how it's used muted
		var l := UI.label(lines[j], 15 if head else 13, col)
		if head:
			l.add_theme_font_override("font", UI.semi)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = TIP_W
		tip_box.add_child(l)
	tip.visible = true
	tip.size = Vector2.ZERO        # shrink to the new text
	var r := tiles[i].get_global_rect()
	var at := Vector2(r.position.x, r.position.y - tip.get_combined_minimum_size().y - 6.0)
	if at.y < 4.0:
		at.y = r.end.y + 6.0
	var view := get_viewport_rect().size
	at.x = clampf(at.x, 4.0, maxf(4.0, view.x - tip.get_combined_minimum_size().x - 4.0))
	tip.global_position = at

func hide_tip(i: int) -> void:
	if shown == i:
		shown = -1
		tip.visible = false
