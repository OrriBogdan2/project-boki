class_name WeaponHud
extends RefCounted
## Your weapon on the HUD: a big pale silhouette between the vitals and the ability row (where the
## owner's 11-12 reference puts it, scripts/ui/HUD_SPEC.md), with the magazine, the reload or the
## melee combo under it. Hover it for the weapon's card. Bottom-anchored like HudVitals.

const AT := Vector2(210, 662.5)        # px: the silhouette's centre (ref: x 171..250, y 650..682)
const ICON_S := 42.0                 # Icons scale: a rifle spans about 76 px
const SIL := Color("eef6fb")         # the silhouette: near-white with a cool tint, like the ref
const ELEM_MIX := 0.35               # how far an element tints the silhouette
const AMMO_AT := Vector2(186, 700)   # px: the magazine count's baseline start
const AMMO_FS := 15
const MAX_FS := 10
const RELOAD := Color("ffe7a8")
const LOW_AMMO := 0.25               # of a magazine: the count turns red under this

static func draw(H, sz: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var b := Vector2(0, sz.y - 720.0)
	var ctr := AT + b
	var hover := Rect2(ctr - Vector2(42, 20), Vector2(84, 44))
	H.hover_spots.append([hover, "weapon"])
	BokiHud.aug_mark(H, p, Rect2(hover.position, Vector2(18, 18)), "lmb")
	RecastCue.slot(H, p, "lmb", Rect2(ctr - Vector2(26, 26), Vector2(52, 52)))      # the recall (Bulwark)
	var col := SIL
	if p.welem != "":
		var ec: Color = Loot.ELEMENTS[p.welem]["col"]
		col = SIL.lerp(ec, ELEM_MIX)
		c.draw_circle(ctr + Vector2(40, -14), 4.0, ec)
	if p.reload_t > 0.0:
		col = Color(col, 0.35)
	Icons.draw(H.c, p.wid, ctr, ICON_S, col)
	var at := AMMO_AT + b
	var mag := int(p.wpn["mag"])
	if p.wpn.get("melee", false):
		_combo(H, p, at)
	elif not p.wpn.get("ammo", true):
		pass                       # no ammo (Data.weapon_stats): no count to show
	elif p.reload_t > 0.0:
		var done := 1.0 - p.reload_t / float(p.wpn["reload"])
		HudStyle.strip(c, Rect2(ctr + Vector2(-38, 18), Vector2(76, 3)), done, RELOAD)
		HudStyle.lean_text(c, at, "RELOADING", MAX_FS, RELOAD)
	else:
		var ac := HudStyle.INK if p.ammo > mag * LOW_AMMO else HudStyle.HURT
		HudStyle.lean_text(c, at, str(p.ammo), AMMO_FS, ac)
		var aw := TextCache.width(HudStyle.BIG, str(p.ammo), AMMO_FS)
		HudStyle.lean_text(c, at + Vector2(aw + 3, 0), "/ %d" % mag, MAX_FS, HudStyle.MUTED)

## A melee weapon's combo: one pip per swing, lit while the chain is live, the finisher bigger.
static func _combo(H, p: Hunter, at: Vector2) -> void:
	var cn: int = (p.wpn.get("combo_dmg", p.wpn.get("combo", [1.0])) as Array).size()
	var live: bool = H.m.time - p.swing_at <= float(p.wpn["rate"]) + float(p.wpn.get("combo_reset", 0.6))
	for i in cn:
		var on := live and (p.combo_i % cn) > i
		var col := SIL if on else Color(1, 1, 1, 0.2)
		H.c.draw_circle(at + Vector2(6 + i * 12, -5), 4.5 if i == cn - 1 else 3.0, col)
