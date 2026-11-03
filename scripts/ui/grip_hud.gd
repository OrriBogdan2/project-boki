class_name GripHud
extends RefCounted
## The right side of the bottom HUD, beside the utility belt and the weapon card: three boxes, the
## way the grips sit in the game we take after.
##   Q   glove 1: its icon, a frame in its rarity colour, the cooldown sweep, the key cap
##   V   glove 2: the same
##   Merge  your Boki: its type badge in the type colour and a ring for the bond meter (full = the
##          Merge is ready; it brightens a moment when an ultimate fills it), grey with a "down" mark while it's
##          knocked out. Until the Merge unlocks and while merged it is BokiHud.r_slot (the lock, the time left).
##          Its key is the Merge action's ("ultimate"); the Boki's own ability and orders sit on the Boki button.
## Gloves never rank, so there are no pips. Reads the hunter and Boki through their own getters
## (Hunter.gear / gear_cd, Kin.runner, Kin.state, KinMerge.ready); draws on the HUD's canvas.
## Look: HudStyle (the same slot frames and key pills as the ability row).

const BOX := 54.0             # px, each box
const GAP := 8.0              # px between boxes
const EDGE := 12.0            # px between the last box and the weapon card
const BOND_FLASH_S := 0.8     # s: how long the bond ring brightens after an ultimate fills it (KinBond)

## Draws the three boxes left of the weapon card `wr`, bottom-aligned with it. Returns their rect.
static func draw(hud, p: Hunter, wr: Rect2) -> Rect2:
	var y := wr.end.y - BOX
	var x0 := wr.position.x - EDGE - 3.0 * BOX - 2.0 * GAP
	for i in Gloves.SLOTS:
		_glove(hud, p, i, Rect2(Vector2(x0 + i * (BOX + GAP), y), Vector2(BOX, BOX)))
	boki(hud, p, Rect2(Vector2(x0 + 2.0 * (BOX + GAP), y), Vector2(BOX, BOX)))
	return Rect2(Vector2(x0, y), Vector2(3.0 * BOX + 2.0 * GAP, BOX))

static func rar_col(g: Dictionary) -> Color:
	return Data.RARITY[clampi(int(g.get("rar", 0)), 0, Data.RARITY.size() - 1)]["color"]

static func _glove(hud, p: Hunter, i: int, r: Rect2) -> void:
	var g := Gloves.worn(p, i)
	var key := Gloves.key_cap(i)
	var id := "gear%d" % i
	if g.is_empty() or not Gear.ALL.has(String(g["id"])):
		hud.hover_spots.append([r, id])
		HudStyle.slot_frame(hud.c, r, HudStyle.MUTED, "off")
		Icons.draw(hud.c, "glove", r.get_center() + Vector2(0, -3), BOX * 0.2, Color(HudStyle.MUTED, 0.35))
		HudStyle.key_pill(hud.c, Vector2(r.get_center().x, r.end.y), key, HudStyle.MUTED)
		return
	var gid := String(g["id"])
	var gd: Dictionary = Gear.ALL[gid]
	var cd := float(p.gear_cd[i])
	var active := Gear.active(gid)
	hud._ab_slot(id, r, Gear.icon_of(gid), key if active else "", gd["col"], Gloves.cd_frac(p, i), cd, active
			and cd <= 0.0 and not p.downed)
	# the rarity frame (passive gloves say so instead of a key)
	var rar_frame := HudStyle.box(Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(rar_col(g), 0.95), 2)
	hud.c.draw_style_box(rar_frame, r.grow(2.0))
	if not active:
		HudStyle.ctext(hud.c, Vector2(r.get_center().x, r.end.y + 4), "PASSIVE", 8, Color(HudStyle.INK, 0.6))

## The Merge box: your Boki. Also used by nothing else; the overhead row has its own small version.
static func boki(hud, p: Hunter, r: Rect2) -> void:
	var k: Kin = p.kin
	var has_boki := k != null and is_instance_valid(k)
	if has_boki and (int(p.slot_lv["ult"]) <= 0 or KinMerge.active(p)):
		BokiHud.r_slot(hud, p, r)
		return
	var key := Settings.key_cap("ultimate")
	HudSlot.shown_keys["r"] = key
	hud.hover_spots.append([r, "r"])
	if not has_boki:
		HudStyle.slot_frame(hud.c, r, HudStyle.MUTED, "off")
		HudStyle.key_pill(hud.c, Vector2(r.get_center().x, r.end.y), key, HudStyle.MUTED)
		return
	var t := DexView.type_of(k.species)
	var tc := DexView.type_col(t)
	var down := k.state == "downed"
	var ctr := r.get_center()
	HudStyle.slot_frame(hud.c, r, tc, "off" if down else "ready")
	DexView.draw_type(hud.c, t, ctr + Vector2(0, -2), BOX * 0.3, 0.35 if down else 1.0)
	# the bond meter as a thin ring; bright and pulsing once the Merge is ready
	var bond := clampf(p.ult, 0.0, 1.0)
	hud.c.draw_arc(ctr, BOX * 0.5 + 3.0, 0, TAU, 36, Color(1, 1, 1, 0.08), 2.0, true)
	if bond > 0.0:
		var full := KinMerge.ready(p)
		var a := 0.7 + 0.3 * sin(float(hud.m.time) * 6.0) if full else 0.85
		hud.c.draw_arc(ctr, BOX * 0.5 + 3.0, -PI / 2, -PI / 2 + TAU * bond, 36, Color(HudStyle.GOLD, a),
				3.0 if full else 2.0, true)
	var flash := 1.0 - (float(hud.m.time) - float(p.get_meta("bond_flash_at", -9.0))) / BOND_FLASH_S
	if flash > 0.0:
		hud.c.draw_arc(ctr, BOX * 0.5 + 5.0, 0, TAU, 36, Color(1.0, 0.85, 0.3, 0.9 * flash), 3.0, true)
	if down:
		hud.c.draw_style_box(HudStyle.box(Color(0.2, 0.2, 0.22, 0.55), HudStyle.SLOT_RAD, Color(0, 0, 0, 0), 0), r)
		HudStyle.ctext(hud.c, ctr + Vector2(0, 5), "DOWN", 12, HudStyle.HURT)
	HudStyle.key_pill(hud.c, Vector2(ctr.x, r.end.y), key, HudStyle.MUTED if down else tc)

## The hover text for a glove box (hud ids "gear0", "gear1").
static func tip(p: Hunter, i: int) -> Array:
	var out: Array = []
	var g := Gloves.worn(p, i)
	var key := Gloves.key_cap(i)
	if g.is_empty() or not Gear.ALL.has(String(g["id"])):
		out.append(["Glove %d (empty)" % (i + 1), HudStyle.MUTED])
		out.append(["Glove  ·  %s" % key, HudStyle.MUTED, 12])
		var where := "Find gloves in chests, vaults and on bosses, or bring them from your armory. "
		where += "Either glove slot takes an active or a passive glove."
		out.append([where, HudStyle.INK, 14])
		return out
	var gid := String(g["id"])
	var gd: Dictionary = Gear.ALL[gid]
	var rn := String(Data.RARITY[clampi(int(g.get("rar", 0)), 0, Data.RARITY.size() - 1)]["name"])
	out.append([gd["name"], gd["col"]])
	out.append(["%s %s glove  ·  %s" % [rn, "active" if Gear.active(gid) else "passive",
			key if Gear.active(gid) else "always on"], HudStyle.MUTED, 12])
	out.append([Gear.desc_of(gid, int(g.get("rar", 1))), HudStyle.INK, 14])
	out.append([Gear.stat_text(gid, int(g.get("rar", 1))), HudStyle.MUTED, 13])
	return out

## The kit panel's glove rows: [key, name, description, colour] for each glove slot.
static func kit_lines(p: Hunter) -> Array:
	var out: Array = []
	for i in Gloves.SLOTS:
		var g := Gloves.worn(p, i)
		if not g.is_empty() and Gear.ALL.has(String(g["id"])):
			var gdd: Dictionary = Gear.ALL[String(g["id"])]
			out.append([Gloves.key_cap(i), String(gdd["name"]), Gear.desc_of(String(g["id"]), int(g.get("rar", 1))),
					gdd["col"]])
		else:
			out.append([Gloves.key_cap(i), "Glove (empty)",
					"Find gloves in chests, vaults and on bosses. Either kind of glove fits.", HudStyle.MUTED])
	return out
