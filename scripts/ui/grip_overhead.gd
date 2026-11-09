class_name GripOverhead
extends RefCounted
## Three small icons over every other hunter's nameplate, so rivals can read what they carry:
##   their two gloves (a frame in the glove's rarity colour, dimmed while it's on cooldown) and
##   their Boki's type badge (in the type colour; a soft glow when their bond meter is full: a
##   Merge is coming. A deliberate tell, kept subtle).
## Drawn with the nameplate (Hud._nameplate) in the row HudPlate leaves free under every plate
## (HudStyle.PLATE_ICON_ROW), so it moves and hides with it. Remote hunters' gloves, cooldowns and
## bond come over the net (GripNet). Look: HudStyle.

const ICON := 14.0            # px, each icon box
const GAP := 3.0              # px between icons
const EMPTY := Color(1, 1, 1, 0.12)

## The three icons' centres for a plate anchored at `sp` (exposed for checks).
static func centres(sp: Vector2) -> Array:
	var y := sp.y + HudStyle.PLATE_ICON_ROW + ICON * 0.5
	var out: Array = []
	for i in 3:
		out.append(Vector2(sp.x + (float(i) - 1.0) * (ICON + GAP), y))
	return out

## What the row shows for a hunter: [{kind, id, col, dim, glow}] x3 (also read by --equal-check).
static func row(h) -> Array:
	var out: Array = []
	for i in Gloves.SLOTS:
		var g: Dictionary = Gloves.worn(h, i)
		if g.is_empty() or not Gear.ALL.has(String(g["id"])):
			out.append({"kind": "glove", "id": "", "col": EMPTY, "dim": true, "glow": false})
		else:
			var gid := String(g["id"])
			out.append({"kind": "glove", "id": gid, "col": GripHud.rar_col(g), "icol": Gear.ALL[gid]["col"],
				"dim": float(h.gear_cd[i]) > 0.0, "glow": false})
	var k = h.kin
	if k != null and is_instance_valid(k):
		var kin_type := DexView.type_of(String(k.species))
		out.append({"kind": "boki", "id": kin_type, "col": DexView.type_col(kin_type),
			"dim": String(k.state) == "downed", "glow": h.ult >= 1.0})
	else:
		out.append({"kind": "boki", "id": "", "col": EMPTY, "dim": true, "glow": false})
	return out

static func draw(hud, sp: Vector2, h) -> void:
	if not sp.is_finite():
		return
	var c: CanvasItem = hud.c
	var cs := centres(sp)
	var items := row(h)
	for i in 3:
		var it: Dictionary = items[i]
		var ctr: Vector2 = cs[i]
		var a := 0.45 if it["dim"] else 1.0
		if it["kind"] == "boki":
			if String(it["id"]) == "":
				c.draw_arc(ctr, ICON * 0.5, 0, TAU, 14, EMPTY, 1.0, true)
				continue
			if it["glow"]:
				var pulse := 0.5 + 0.5 * sin(float(hud.m.time) * 4.0)
				c.draw_circle(ctr, ICON * 0.5 + 2.5 + pulse, Color(it["col"], 0.18 + 0.12 * pulse))
			DexView.draw_type(c, String(it["id"]), ctr, ICON * 0.5, a)
			continue
		var r := Rect2(ctr - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
		c.draw_style_box(HudStyle.box(Color(HudStyle.SHADE, 0.8 * a), 3, Color(it["col"], 0.95 * a), 1), r)
		if String(it["id"]) != "":
			Icons.draw(c, Gear.icon_of(String(it["id"])), ctr, ICON * 0.3, Color(it["icol"], a))
