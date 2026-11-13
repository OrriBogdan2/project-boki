class_name Spectate
extends RefCounted
## You're out and your team is still in it: whose view you watch. The fire and secondary keys
## (rebindable) step through the living teammates, the camera, minimap and Boki card follow the one
## you watch, and a strip at the bottom shows their health, armour and abilities with one Give up
## button. Match owns one of these; it only forwards input and draws through HudPanels.

const WATCH_DELAY := 2.5      # seconds after you die before the camera moves to a teammate
const STRIP_H := 110.0        # px: the bottom strip's height
const STRIP_W := 560.0        # px: its widest
const SLOT := 34.0            # px: one ability tile
const SLOTS := ["sec", "dash", "k1", "x"]      # right click, dash, E, the hero ultimate

var m: Match
var watched: Hunter
var give_rect := Rect2()      # where the Give up button was drawn (screen px)

func _init(match_node: Match) -> void:
	m = match_node

## Teammates still in it, in hunter order.
func mates() -> Array:
	var out: Array = []
	for x in m.hunters:
		if x.team == m.player.team and x != m.player and not x.out and not x.extracted:
			out.append(x)
	return out

## The teammate being watched, or null while you're alive, gone, or just died.
func current() -> Hunter:
	var p := m.player
	if p == null or not p.out or p.gone or m.time - float(p.get_meta("died_at", m.time)) < WATCH_DELAY:
		return null
	var list := mates()
	if list.is_empty():
		return null
	if not list.has(watched):
		watched = list[0]
	return watched

## Whose view the minimap and Boki card show: the watched teammate, else you.
func viewed() -> Hunter:
	var w := current()
	return w if w else m.player

## Step to the next (+1) or previous (-1) living teammate, wrapping round.
func cycle(step: int) -> void:
	var list := mates()
	if current() != null:
		watched = list[wrapi(list.find(watched) + step, 0, list.size())]

## Fire / secondary while watching: switch teammate. Returns true when the press was used.
func input(event: InputEvent) -> bool:
	if m.paused or m.over or m.flow.ending() or current() == null:
		return false
	var fire := event.is_action_pressed("fire")
	if not fire and not event.is_action_pressed("secondary"):
		return false
	if fire and event is InputEventMouseButton and give_rect.has_point((event as InputEventMouseButton).position):
		m.give_up()
	else:
		cycle(1 if fire else -1)
	return true

## The bottom strip and the watched teammate's Boki card.
func draw(H, sz: Vector2) -> void:
	var w := current()
	if w == null:
		give_rect = Rect2()
		return
	H._draw_kin_card(sz, w)
	var wide := minf(STRIP_W, sz.x - 32.0)
	var r := Rect2(Vector2((sz.x - wide) * 0.5, sz.y - 18.0 - STRIP_H), Vector2(wide, STRIP_H))
	H._panel(r, Color(0.05, 0.06, 0.09, 0.88))
	H._text(r.position + Vector2(14, 26), "Watching %s (%s)" % [w.pname, HeroTitle.title(w.arch)], 17, H.INK, H.big)
	give_rect = Rect2(Vector2(r.end.x - 106, r.position.y + 6), Vector2(96, 28))
	H._rounded(give_rect, Color(0.35, 0.1, 0.1, 0.9), 8, Color(H.BAD, 0.7), 1)
	H._ctext(give_rect.get_center() + Vector2(0, 5), "Give up", 14, H.INK, H.big)
	_vitals(H, w, Rect2(r.position + Vector2(14, 38), Vector2(r.size.x - 28, 14)))
	var x := r.position.x + 14.0
	var y := r.end.y - SLOT - 10.0
	for slot in SLOTS:
		var info := w.slot_info(slot)
		if String(info["icon"]) == "":
			continue
		_slot(H, info, Rect2(Vector2(x, y), Vector2(SLOT, SLOT)))
		x += SLOT + 8.0
	if mates().size() > 1:
		var hint := "%s / %s: switch teammate" % [Settings.key_cap("fire"), Settings.key_cap("secondary")]
		H._text(Vector2(r.end.x - 314, y + 22), hint, 13, H.MUTED, null, HORIZONTAL_ALIGNMENT_RIGHT, 300.0)

## Health over armour, with the numbers.
func _vitals(H, w: Hunter, hr: Rect2) -> void:
	var frac := clampf(w.hp / maxf(1.0, w.max_hp), 0.0, 1.0)
	H._bar(hr, frac, H.GOOD if frac >= 0.3 else H.HP_LOW)
	H._text(hr.position + Vector2(6, 12), "%d / %d" % [int(ceil(w.hp)), int(w.max_hp)], 12, Color.BLACK, H.big)
	if w.max_armor > 0.5:
		H._bar(Rect2(hr.position + Vector2(0, 17), Vector2(hr.size.x, 6)), w.armor / w.max_armor, w.armor_col())

## One ability tile: its icon, dimmed by what is left of the cooldown, with the seconds.
func _slot(H, info: Dictionary, r: Rect2) -> void:
	var col: Color = info["col"]
	H._rounded(r, Color(0.03, 0.03, 0.05, 0.9), 6, Color(col, 0.6), 1)
	Icons.draw(H.c, String(info["icon"]), r.get_center(), SLOT * 0.7, col)
	var cd := float(info["cd"])
	if cd > 0.0:
		var left := clampf(cd / maxf(0.01, float(info["cd_max"])), 0.0, 1.0)
		H.c.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * left)), Color(0, 0, 0, 0.6))
		if cd >= 1.0:
			H._ctext(r.get_center() + Vector2(0, 5), str(int(ceil(cd))), 13, H.INK, H.big)
