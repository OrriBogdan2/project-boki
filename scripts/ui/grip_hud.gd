class_name GripHud
extends RefCounted
## The right side of the bottom HUD, beside the utility belt and the weapon card: three boxes, the
## way the grips sit in the game we take after.
##   Q   glove 1: its icon, a frame in its rarity colour, the cooldown sweep, the key cap
##   V   glove 2: the same
##   C   your Boki: its type badge in the type colour, the C ability's cooldown sweep, a thin ring
##       for the bond meter (full = Merge ready on R), grey with a "down" mark while it's knocked out
## Gloves never rank, so there are no pips. Reads the hunter and Boki through their own getters
## (Hunter.gear / gear_cd, Kin.runner, Kin.state, KinMerge.ready); draws on the HUD's canvas.

const BOX := 54.0             # px, each box
const GAP := 8.0              # px between boxes
const EDGE := 12.0            # px between the last box and the weapon card
const BOND_COL := Color("ffd27a")
const DOWN_COL := Color("ff7a6a")

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
		hud._rounded(r, Color(0.05, 0.06, 0.09, 0.55), 12, Color(1, 1, 1, 0.08), 2)
		Icons.draw(hud.c, "glove", r.get_center() + Vector2(0, -3), BOX * 0.2, Color(hud.MUTED, 0.35))
		hud._keycap(Vector2(r.get_center().x, r.end.y), key, hud.MUTED)
		return
	var gid := String(g["id"])
	var gd: Dictionary = Gear.ALL[gid]
	var cd := float(p.gear_cd[i])
	var active := Gear.active(gid)
	hud._ab_slot(id, r, Gear.icon_of(gid), key if active else "", gd["col"], Gloves.cd_frac(p, i), cd, active and cd <= 0.0 and not p.downed)
	# the rarity frame (passive gloves say so instead of a key)
	hud._rounded(r.grow(2.0), Color(0, 0, 0, 0), 13, Color(rar_col(g), 0.95), 2)
	if not active:
		hud._ctext(Vector2(r.get_center().x, r.end.y + 4), "PASSIVE", 8, Color(hud.INK, 0.6), hud.big)

## The C box: your Boki. Also used by nothing else; the overhead row has its own small version.
static func boki(hud, p: Hunter, r: Rect2) -> void:
	var k: Kin = p.kin
	var key := Settings.key_cap("kin_ability")
	hud.hover_spots.append([r, "kin_ab"])
	if k == null or not is_instance_valid(k):
		hud._rounded(r, Color(0.05, 0.06, 0.09, 0.55), 12, Color(1, 1, 1, 0.08), 2)
		hud._keycap(Vector2(r.get_center().x, r.end.y), key, hud.MUTED)
		return
	var t := DexView.type_of(k.species)
	var tc := DexView.type_col(t)
	var down := k.state == "downed"
	var ctr := r.get_center()
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.9), 12, Color(tc, 0.7) if not down else Color(0.5, 0.5, 0.5, 0.5), 2)
	DexView.draw_type(hud.c, t, ctr + Vector2(0, -2), BOX * 0.3, 0.35 if down else 1.0)
	if k.runner != null and k.runner.def_of("k1") != null and not k.runner.is_ready("k1") and not down:
		hud._sweep(ctr, BOX * 0.42, k.runner.cd_frac("k1"), Color(0, 0, 0, 0.55))
		hud._ctext(ctr + Vector2(0, 6), "%d" % int(ceil(k.runner.cd_left("k1"))), 16, hud.INK, hud.big)
	# the bond meter as a thin ring; bright and pulsing once the Merge is ready
	var bond := clampf(p.ult, 0.0, 1.0)
	hud.c.draw_arc(ctr, BOX * 0.5 + 3.0, 0, TAU, 36, Color(1, 1, 1, 0.08), 2.0, true)
	if bond > 0.0:
		var full := KinMerge.ready(p)
		var a := 0.7 + 0.3 * sin(float(hud.m.time) * 6.0) if full else 0.85
		hud.c.draw_arc(ctr, BOX * 0.5 + 3.0, -PI / 2, -PI / 2 + TAU * bond, 36, Color(BOND_COL, a), 3.0 if full else 2.0, true)
	if down:
		hud._rounded(r, Color(0.2, 0.2, 0.22, 0.55), 12)
		hud._ctext(ctr + Vector2(0, 5), "DOWN", 12, DOWN_COL, hud.big)
	hud._keycap(Vector2(ctr.x, r.end.y), key, tc if not down else hud.MUTED)

## The hover text for a glove box (hud ids "gear0", "gear1").
static func tip(p: Hunter, i: int) -> Array:
	var out: Array = []
	var g := Gloves.worn(p, i)
	var key := Gloves.key_cap(i)
	if g.is_empty() or not Gear.ALL.has(String(g["id"])):
		out.append(["Glove %d (empty)" % (i + 1), Color("a9b0bf")])
		out.append(["Glove  ·  %s" % key, Color("a9b0bf"), 12])
		out.append(["Find gloves in chests, vaults and on bosses, or bring them from your armory. Either glove slot takes an active or a passive glove.", Color("f3eee2"), 14])
		return out
	var gid := String(g["id"])
	var gd: Dictionary = Gear.ALL[gid]
	var rn := String(Data.RARITY[clampi(int(g.get("rar", 0)), 0, Data.RARITY.size() - 1)]["name"])
	out.append([gd["name"], gd["col"]])
	out.append(["%s %s glove  ·  %s" % [rn, "active" if Gear.active(gid) else "passive", key if Gear.active(gid) else "always on"], Color("a9b0bf"), 12])
	out.append([Gear.desc_of(gid, int(g.get("rar", 1))), Color("f3eee2"), 14])
	out.append([Gear.stat_text(gid, int(g.get("rar", 1))), Color("a9b0bf"), 13])
	return out

## The kit panel's glove rows: [key, name, description, colour] for each glove slot.
static func kit_lines(p: Hunter) -> Array:
	var out: Array = []
	for i in Gloves.SLOTS:
		var g := Gloves.worn(p, i)
		if not g.is_empty() and Gear.ALL.has(String(g["id"])):
			var gdd: Dictionary = Gear.ALL[String(g["id"])]
			out.append([Gloves.key_cap(i), String(gdd["name"]), Gear.desc_of(String(g["id"]), int(g.get("rar", 1))), gdd["col"]])
		else:
			out.append([Gloves.key_cap(i), "Glove (empty)", "Find gloves in chests, vaults and on bosses. Either kind of glove fits.", Color("a9b0bf")])
	return out
