class_name GearPanel
extends RefCounted
## The gear you wear, drawn above the weapon card: five slots (active glove, passive glove, armor,
## boots, utility kit), each with its rarity colour, plus the upgrade line under your weapon. Hover
## a slot for what it does. Drawn by Hud with its own helpers (state: only the cached upgrade line).

const CELL := 38.0
const GAP := 6.0

static var _ups_key := -1        # hash of the perks the cached upgrade line was built for
static var _ups_txt := ""
static var _ups_w := 0.0

## Rect of slot i for a screen size (right-aligned, above the weapon card and its row of tonic / kit / throw slots).
static func cell_rect(sz: Vector2, i: int) -> Rect2:
	var total := Gear.SLOTS.size() * CELL + (Gear.SLOTS.size() - 1) * GAP
	var x := sz.x - 18.0 - 270.0 + (270.0 - total)
	return Rect2(Vector2(x + i * (CELL + GAP), sz.y - 18.0 - 62.0 - 66.0 - 22.0 - CELL), Vector2(CELL, CELL))

static func draw(hud, sz: Vector2, p: Hunter) -> void:
	for i in Gear.SLOTS.size():
		var r := cell_rect(sz, i)
		var g: Dictionary = p.gear[i]
		hud.hover_spots.append([r, "gslot:%d" % i])
		if g.is_empty() or not Gear.ALL.has(String(g["id"])):
			hud._rounded(r, Color(0.04, 0.05, 0.08, 0.62), 9, Color(1, 1, 1, 0.12), 1)
			Icons.draw(hud.c, _empty_icon(i), r.get_center(), CELL * 0.26, Color(hud.MUTED, 0.45))
			continue
		var rar := clampi(int(g["rar"]), 0, Data.RARITY.size() - 1)
		var rc: Color = Data.RARITY[rar]["color"]
		hud._rounded(r, Color(0.04, 0.05, 0.08, 0.9), 9, Color(rc, 0.85), 2)
		Icons.draw(hud.c, Gear.icon_of(String(g["id"])), r.get_center(), CELL * 0.28, Gear.ALL[String(g["id"])]["col"])
		if i < 2 and float(p.gear_cd[i]) > 0.0:
			var f := Gloves.cd_frac(p, i)
			hud.c.draw_rect(Rect2(r.position + Vector2(0, CELL * (1.0 - f)), Vector2(CELL, CELL * f)), Color(0, 0, 0, 0.5))
	var perks_key: int = p.perks.hash()      # the upgrade line only changes when the perks do (no string building per frame)
	if perks_key != _ups_key:
		_ups_key = perks_key
		_ups_txt = WeaponUps.summary(p)
		while _ups_txt.length() > 8 and hud.body.get_string_size(_ups_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > 330.0:
			_ups_txt = _ups_txt.substr(0, _ups_txt.length() - 4).strip_edges().trim_suffix(",") + "..."
		_ups_w = hud.body.get_string_size(_ups_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if _ups_txt != "":
		var r0 := cell_rect(sz, 0)
		var right := cell_rect(sz, Gear.SLOTS.size() - 1).end.x
		hud._text(Vector2(right - _ups_w, r0.position.y - 6.0), _ups_txt, 11, Color(hud.GOOD, 0.9), hud.body)

static func _empty_icon(i: int) -> String:
	return ["glove", "glove", "fortify", "dash"][i]

## The second hover line: the slot name, or for a glove whether it is active (and its key) or passive.
static func _kind_line(i: int, gid: String) -> String:
	if i >= 2:
		return Gear.WORN_NAMES[i]
	if Gear.active(gid):
		return "Active glove  ·  %s" % Gloves.key_cap(i)
	return "Passive glove  ·  always on"

## Hover text for slot i: [[line, colour, size?]...]
static func tip(p: Hunter, i: int) -> Array:
	var g: Dictionary = p.gear[i]
	var out: Array = []
	if g.is_empty() or not Gear.ALL.has(String(g["id"])):
		out.append([Gear.WORN_NAMES[i] + " (empty)", Color("a2a8bb")])
		var what: String = "a glove" if i < 2 else Gear.SLOT_NAMES[i].to_lower()
		var where := "Find %s in chests, vaults, on guards and bosses, or bring it from your armory." % what
		out.append([where, Color("a2a8bb"), 13])
		return out
	var it := Loot.gear(String(g["id"]), int(g["rar"]))
	out.append([Loot.name_of(it), Loot.col_of(it)])
	out.append([_kind_line(i, String(g["id"])), Color("a2a8bb"), 12])
	out.append([Gear.desc_of(String(g["id"]), int(g["rar"])), Color("eef1f8"), 14])
	out.append([Gear.stat_text(String(g["id"]), int(g["rar"])), Color("a2a8bb"), 13])
	return out
