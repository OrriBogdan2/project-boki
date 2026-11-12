class_name HudVitals
extends RefCounted
## The bottom-left vitals block, laid out after the owner's reference (scripts/ui/HUD_SPEC.md): a big
## round portrait, the armour badge beside it, then a leaning dark plate over its foot holding armour
## (segmented, its number on a tab) over thick segmented health (same segments and chip as your
## overhead plate), a thin shield / shell strip under that; the health number big and leaning under
## the plate, then the level badge with the XP bar and the class resource bar. The ability row sits
## to the right (Hud._draw_abilities). Look: HudStyle.
## Hud keeps the state that checks read (lvl_pop, armor_lerp, hover_spots); this file only draws.

# Layout in px of the 1280x720 frame, measured from the owner's reference (scripts/ui/HUD_SPEC.md);
# y counts down from the frame's top and is anchored to the bottom edge (sz.y - 720 + y).
const PORT_C := Vector2(66, 596)   # the round portrait's centre
const PORT_R := 50.0               # ... and radius
const BADGE_C := Vector2(165, 613) # the armour badge beside it (ArmorHud)
const KIN_C := Vector2(31, 561)    # your Boki's card on the portrait's top-left (Hud._draw_kin_card)
const PLATE_X := 52.0              # the leaning plate: top-left x (its bottom sits LEAN_K * height left)
const PLATE_Y := 638.0
const PLATE_W := 112.0
const PLATE_H := 35.0
const AR_Y := 639.5                # armour: segmented, over health
const AR_H := 4.5
const HP_Y := 645.0                # health: thick, segmented
const HP_H := 15.0
const BAR_W := 107.5               # armour and health width along their top edge (ref 162 px at 1080p)
const SH_Y := 662.0                # the strip under health: shield, or the merged form's shell
const SH_H := 3.0
const NUM_Y := 683.0               # the health number's baseline
const NUM_FS := 21
const MAX_FS := 10
const XP_Y := 687.0                # the level bar: level number, then XP
const XP_X := 30.0
const XP_W := 116.0
const XP_H := 9.0
const RES_Y := 699.0               # the class resource bar under it
const RES_H := 8.0
const SLOT_X := 260.0              # the ability row (Hud._draw_abilities): first slot's left edge
const SLOT_Y := 652.0              # ... its top
const SLOT := 36.0                 # ... slot size
const SLOT_GAP := 8.0              # ... between slots
const LVL_POP := 0.35              # s: the level badge's pop

static func draw(H, sz: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var b := Vector2(0, sz.y - 720.0)
	var ctr := PORT_C + b
	var pr := Rect2(ctr - Vector2(PORT_R, PORT_R), Vector2(PORT_R, PORT_R) * 2.0)
	_portrait(H, ctr, p)
	H.hover_spots.append([pr, "vitals"])
	ArmorHud.badge(H, BADGE_C + b, p)
	if p.lives < 50 and p.lives > 1:
		for i in p.lives:
			c.draw_circle(ctr + Vector2(PORT_R * 0.7 - i * 11.0, -PORT_R * 0.7), 4.0, Color("ff7a8a"))
	var dt: float = H.get_process_delta_time()
	var frac := clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var af := clampf(p.armor / maxf(1.0, p.max_armor), 0.0, 1.0)
	H.armor_lerp = move_toward(H.armor_lerp, af, dt * (0.5 if H.armor_lerp > af else 4.0))
	var top := Vector2(PLATE_X, PLATE_Y) + b
	H.hover_spots.append([Rect2(top - Vector2(PLATE_H * HudStyle.LEAN_K, 0), Vector2(PLATE_W, PLATE_H)), "vitals"])
	HudStyle.slant(c, top, PLATE_W, PLATE_H, HudStyle.FRAME)
	var k := HudStyle.LEAN_K
	# armour over health, both segmented (the plate's segment size); its number on a tab over the plate
	var ap := Vector2(PLATE_X + 4.0 - k * (AR_Y - PLATE_Y), AR_Y) + b
	if p.max_armor > 0.5:
		var ar_step := HudStyle.seg_step(p.max_armor)
		HudStyle.slant_bar(c, ap, BAR_W, AR_H, p.armor, p.max_armor, p.armor_col(), ar_step, H.armor_lerp)
	if p.armor > 0.5:
		var at := "%d" % int(ceil(p.armor))
		var tw := HudStyle.BIG.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
		HudStyle.slant(c, top + Vector2(2, -8), tw, 8, HudStyle.FRAME)
		HudStyle.text(c, top + Vector2(6, -0.5), at, 10, p.armor_col(), 3)
	var hp_col := HudStyle.hp_fill(HudStyle.SELF, frac, H.m.time)
	var hp_at := Vector2(PLATE_X + 4.0 - k * (HP_Y - PLATE_Y), HP_Y) + b
	HudStyle.slant_bar(c, hp_at, BAR_W, HP_H, p.hp, p.max_hp, hp_col, HudStyle.seg_step(p.max_hp), H._chip_of(p, frac))
	var flash: float = H.plates.flash_of(p) * 0.6
	if flash > 0.0:
		HudStyle.slant(c, hp_at, BAR_W, HP_H, Color(1, 1, 1, 0.55 * flash))
	_under_bar(H, Vector2(PLATE_X + 16.0 - k * (SH_Y - PLATE_Y), SH_Y) + b, p)
	# the numbers under the plate: health big and leaning, max small
	var hp_txt := str(int(ceil(p.hp)))
	var num := Vector2(PLATE_X - 10.0, NUM_Y) + b
	HudStyle.lean_text(c, num, hp_txt, NUM_FS, HudStyle.INK if frac >= 0.3 else hp_col, 4)
	var hw := HudStyle.BIG.get_string_size(hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_FS).x
	HudStyle.lean_text(c, num + Vector2(hw + 6, -1), "/ %d" % int(p.max_hp), MAX_FS, HudStyle.MUTED, 3)
	level_bar(H, b, p)
	if p.ak and p.ak.has_meter():
		_res_bar(H, Vector2(XP_X - 6.0, RES_Y) + b, p)
	_hidden_tag(H, sz, p)

## The round portrait on a pale disc in your class colour: hit flash, low-health pulse, red while down.
static func _portrait(H, ctr: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	c.draw_circle(ctr, PORT_R + 3.0, Color(p.accent().lerp(Color.WHITE, 0.6), 0.9))
	var ak := Portraits.arch_of(p)
	var px := Vector2i(int(PORT_R * 2.0), int(PORT_R * 2.0))
	var tex: Texture2D = Portraits.cut(ak, Portraits.art_path(ak), px) if Portraits.has_art(ak) else H.portrait(p)
	if tex:
		HudStyle.round_tex(c, ctr, PORT_R, tex)
	var hurt: float = H.plates.flash_of(p)
	var low := clampf((0.3 - p.hp / maxf(1.0, p.max_hp)) / 0.3, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(H.m.time * 8.0)
	if p.downed:
		c.draw_circle(ctr, PORT_R, Color(0.95, 0.2, 0.32, 0.35 + 0.2 * pulse))
	elif hurt > 0.02:
		c.draw_circle(ctr, PORT_R, Color(HudStyle.HURT, 0.4 * hurt))
	if low > 0.02 or p.downed:
		var a := (1.0 if p.downed else low) * (0.55 + 0.45 * pulse)
		c.draw_arc(ctr, PORT_R - 1.5, 0, TAU, 48, Color(HudStyle.FOE, a), 3.0, true)

## The thin strip under health: a shield with its number, or the merged form's shell (with its flash).
static func _under_bar(H, at: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var w := BAR_W - 12.0
	var shv := MergeShell.view(p)
	if shv.y > 0.0 and not p.merge_st.is_empty():
		var fcol: Color = (p.merge_st["form"] as Dictionary)["glow"]
		HudStyle.slant(c, at, w, SH_H, Color(fcol.darkened(0.7), 0.9))
		HudStyle.slant(c, at, w * shv.x / shv.y, SH_H, fcol.lerp(Color.WHITE, 0.7 * BokiHud.shell_flash(H, p)))
		_tab(c, at + Vector2(w - 26.0, SH_H + 1.0), "SHELL %d" % int(ceil(shv.x)), fcol)
		return
	var fl := BokiHud.shell_flash(H, p)
	if fl > 0.0:
		HudStyle.slant(c, at, w, SH_H, Color(p.get_meta("shell_break_col", Color.WHITE), fl))
	if p.shield > 0.5:
		HudStyle.slant(c, at, w * HudPlate.shield_frac(p), SH_H, HudStyle.SHIELD_BAR)
		_tab(c, at + Vector2(w - 26.0, SH_H + 1.0), "%d" % int(ceil(p.shield)), HudStyle.SHIELD_BAR)

## A small value tab hanging under a strip's right end.
static func _tab(c: CanvasItem, at: Vector2, s: String, col: Color) -> void:
	var tw := HudStyle.BIG.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
	HudStyle.slant(c, at, tw, 8.0, HudStyle.FRAME)
	HudStyle.text(c, at + Vector2(1, 7.5), s, 9, col, 2)

## The class resource as the bottom bar: counted kinds in pips, the rest a fill; its value after it,
## the bar outlined while it is full (the kit's payoff is ready).
static func _res_bar(H, at: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var kit: ArchKit = p.ak
	var rd := kit.res_def()
	var col := kit.res_col()
	var counted := String(rd.get("kind", "")) in ["count", "on_targets"]
	var step := 1.0 / float(rd.get("max", 3)) if counted else 0.0
	HudStyle.slant(c, at, XP_W, RES_H, HudStyle.FRAME)
	HudStyle.slant_bar(c, at + Vector2(1, 1), XP_W - 2.0, RES_H - 2.0, kit.res_frac(), 1.0, col, step)
	var full := kit.tell == "full"
	HudStyle.text(c, at + Vector2(XP_W + 4.0, RES_H), kit.res_text(), 10, col if full else HudStyle.INK, 3)
	if full:
		var pulse := 0.5 + 0.5 * sin(H.m.time * 8.0)
		var edge := HudStyle.slant_pts(at, XP_W, RES_H)
		edge.append(at)
		c.draw_polyline(edge, Color(col, 0.4 + 0.5 * pulse), 1.5, true)

## HIDDEN / CROUCHED / SPOTTED over the middle of the bar when you're in grass or crouching.
static func _hidden_tag(H, sz: Vector2, p: Hunter) -> void:
	var grass: bool = H.m.world.in_bush(p.pos.x, p.pos.z)
	if not (grass or p.crouch):
		return
	var txt := "SPOTTED"
	var fg: Color = HudStyle.HURT
	var bg := Color(0.25, 0.06, 0.05, 0.85)
	if p.reveal_t <= 0.0:
		txt = "HIDDEN" if grass else "CROUCHED"
		fg = Color("8fe0a0") if grass else Color("c9d2e0")
		bg = Color(0.05, 0.12, 0.06, 0.85) if grass else Color(0.08, 0.09, 0.12, 0.85)
	var tw := HudStyle.BIG.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var hr := Rect2(Vector2(sz.x * 0.5 - tw * 0.5 - 12, sz.y - 104), Vector2(tw + 24, 20))
	H._rounded(hr, bg, 10)
	HudStyle.text(H.c, hr.position + Vector2(12, 15), txt, 13, fg)

## The run level on a small badge, then progress to the next level as the leaning XP bar; a level-up
## pops the badge and bursts a gold ring round the portrait; points to spend show as a gold + on it.
static func level_bar(H, b: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var gold := HudStyle.GOLD
	if H.lvl_seen >= 0 and p.lvl > H.lvl_seen and H.lvl_pop <= 0.0:
		H.lvl_pop = LVL_POP
	H.lvl_seen = p.lvl
	H.lvl_pop = maxf(0.0, H.lvl_pop - H.get_process_delta_time())
	var k: float = 1.0 - H.lvl_pop / LVL_POP
	var sc := 1.0 + 0.35 * sin(k * PI) if H.lvl_pop > 0.0 else 1.0
	if H.lvl_pop > 0.0:
		c.draw_arc(PORT_C + b, PORT_R + 6.0 + k * 22.0, 0, TAU, 48, Color(gold, 1.0 - k), 4.0, true)
	var at := Vector2(XP_X, XP_Y) + b
	HudStyle.slant(c, at, XP_W, XP_H, HudStyle.FRAME)
	HudStyle.slant(c, at + Vector2(1, 1), (XP_W - 2.0) * p.xp_frac(), XP_H - 2.0, HudStyle.XP)
	var bc := Vector2(XP_X - 12.0, XP_Y + XP_H * 0.5) + b
	var r := 7.5 * sc
	c.draw_circle(bc, r + 1.5, HudStyle.XP.darkened(0.3))
	c.draw_circle(bc, r, HudStyle.FRAME)
	var lvl_col := HudStyle.INK if H.lvl_pop <= 0.0 else HudStyle.INK.lerp(gold, 1.0 - k)
	HudStyle.ctext(c, bc + Vector2(0, 4.0 * sc), str(p.lvl), int(11.0 * sc), lvl_col, 3)
	if p.skill_pts > 0:
		var pulse := 0.5 + 0.5 * sin(H.m.time * 5.0)
		var pts_at := bc + Vector2(-2, -15)
		c.draw_circle(pts_at, 7.0 + pulse, gold)
		var pts_txt := "+%d" % p.skill_pts if p.skill_pts > 1 else "+"
		HudStyle.ctext(c, pts_at + Vector2(0, 4), pts_txt, 10, Color(0.1, 0.07, 0.02), 0)
