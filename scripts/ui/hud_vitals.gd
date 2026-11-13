class_name HudVitals
extends RefCounted
## The bottom-left vitals block: your portrait framed in your class colour with the XP tracker (run
## level and a bar toward the next level) along its top edge, then to its right your health as a big
## number over a thick segmented bar, armour as a strip under it with its number and
## tier, shields past the end of health, the merged form's shell, and the archetype resource under
## that. The ability row sits below the bars (Hud._draw_abilities). Look: HudStyle.
## Hud keeps the state that checks read (lvl_pop, xp_pop, armor_lerp, hover_spots); this only draws.

const BAR_W := 318.0       # px: health / armour width
const HP_H := 16.0         # px: the health bar
const AR_H := 5.0          # px: the armour strip under it
const LVL_POP := 0.35      # s: the level-up burst round the portrait
const XP_POP := 0.4        # s: the pop of the level number and bar when XP lands
const XP_H := 6.0          # px: the XP bar's height
const BAR_X := 44.0        # px: where the XP bar starts, right of the LV number
const XP_FILL_K := 6.0     # 1/s: how fast the shown XP closes on the real XP
const XP_FILL_MIN := 25.0  # XP/s: the slowest the fill moves, so small gains still finish

static func draw(H, sz: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var o: Vector2 = H._hud_origin(sz)
	var pr := Rect2(o, H.HUD_PORTRAIT)
	var hc: Color = p.accent()
	# the portrait, framed in your class colour (its name and class are under it)
	H._draw_portrait(pr, p, "down" if p.downed else "", hc)
	H.hover_spots.append([pr, "vitals"])
	ArmorHud.badge(H, pr, p)
	if p.lives < 50 and p.lives > 1:
		for i in p.lives:
			c.draw_circle(pr.position + Vector2(pr.size.x - 10 - i * 11.0, 10), 4.0, Color("ff7a8a"))
	var x0 := pr.end.x + 16.0
	var w := BAR_W
	var y0 := o.y + 16.0
	var dt: float = H.get_process_delta_time()
	var frac := clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var af := clampf(p.armor / maxf(1.0, p.max_armor), 0.0, 1.0)
	H.armor_lerp = move_toward(H.armor_lerp, af, dt * (0.5 if H.armor_lerp > af else 4.0))
	H.hover_spots.append([Rect2(Vector2(x0, y0 - 20), Vector2(w, 52)), "vitals"])
	# the numbers: health big, max small; armour and its tier on the right
	var hp_col := HudStyle.hp_fill(SideColor.you(), frac, H.m.time)
	var hp_txt := str(int(ceil(p.hp)))
	HudStyle.text(c, Vector2(x0, y0 + 1), hp_txt, 26, HudStyle.INK if frac >= 0.3 else hp_col)
	var hw := HudStyle.BIG.get_string_size(hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	HudStyle.text(c, Vector2(x0 + hw + 4, y0 + 1), "/ %d" % int(p.max_hp), 14, HudStyle.MUTED)
	if p.armor > 0.5:
		var at := "%d" % int(ceil(p.armor))
		var aw := HudStyle.BIG.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		HudStyle.text(c, Vector2(x0 + w - aw, y0 + 1), at, 15, p.armor_col())
		var tn := String(Hunter.ARMOR_TIERS[p.armor_tier][0]).to_upper()
		var tw := HudStyle.BIG.get_string_size(tn, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		HudStyle.text(c, Vector2(x0 + w - aw - 8 - tw, y0), tn, 10, Color(p.armor_col(), 0.75))
	# health: thick, segmented, the chip and flash shared with your overhead plate
	var hr := Rect2(Vector2(x0, y0 + 6), Vector2(w, HP_H))
	H._rounded(hr.grow(2.0), HudStyle.SHADE, 4)
	var flash: float = H.plates.flash_of(p) * 0.6
	HudStyle.seg_bar(c, hr, p.hp, p.max_hp, hp_col, H._chip_of(p, frac), HudPlate.shield_frac(p), flash)
	# under it: the merged form's shell while merged, else armour (with its own trail as it drops)
	var ar := Rect2(Vector2(x0, hr.end.y + 3), Vector2(w, AR_H))
	var shv := MergeShell.view(p)
	if shv.y > 0.0 and not p.merge_st.is_empty():
		var fcol: Color = (p.merge_st["form"] as Dictionary)["glow"]
		BokiHud.shell_bar(H, ar.grow_individual(0, 2, 0, 2), shv.x / shv.y, fcol, BokiHud.shell_flash(H, p))
		var shell_x := x0 + w - (70 if p.armor <= 0.5 else 170)
		HudStyle.text(c, Vector2(shell_x, y0 + 1), "SHELL %d" % int(ceil(shv.x)), 13, fcol)
	else:
		var fl := BokiHud.shell_flash(H, p)
		if fl > 0.0:
			BokiHud.shell_bar(H, ar.grow_individual(0, 2, 0, 2), 0.0, p.get_meta("shell_break_col", Color.WHITE), fl)
		if p.max_armor > 0.5:
			c.draw_rect(ar.grow(1.0), HudStyle.SHADE)
			HudStyle.strip(c, ar, H.armor_lerp, HudStyle.CHIP)
			c.draw_rect(Rect2(ar.position, Vector2(ar.size.x * af, ar.size.y)), p.armor_col())
	ArmorHud.bar(H, x0, ar.end.y + 2, w, p)    # progress to the next armour tier, under the strip
	if p.ak and p.ak.has_meter():
		H._draw_res_bar(x0, ar.end.y + 4, w, p)
	xp_row(H, pr, x0, w, p)
	_hidden_tag(H, sz, p)

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

## The XP tracker on the block's top edge, just above the health number: LV and the run level, then a
## thin bar toward Hunter.XP_TO. XP landing (camp or kill) pops the number, brightens the bar and
## fills it smoothly (through a level-up too); unspent skill points pulse the whole bar gold, and a
## level-up bursts a gold ring round the portrait.
static func xp_row(H, pr: Rect2, x0: float, w: float, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var gold := HudStyle.GOLD
	var dt: float = H.get_process_delta_time()
	if H.lvl_seen >= 0 and p.lvl > H.lvl_seen and H.lvl_pop <= 0.0:
		H.lvl_pop = LVL_POP
	H.lvl_seen = p.lvl
	H.lvl_pop = maxf(0.0, H.lvl_pop - dt)
	var lk: float = 1.0 - H.lvl_pop / LVL_POP
	if H.lvl_pop > 0.0:
		H._rounded(pr.grow(6.0 + lk * 22.0), Color(0, 0, 0, 0), 16, Color(gold, 1.0 - lk), 4)
		H._rounded(pr.grow(2.0 + lk * 10.0), Color(gold, 0.18 * (1.0 - lk)), 14)
	var fill := xp_step(H, p, dt)
	var pop: float = H.xp_pop / XP_POP
	var sc := 1.0 + 0.35 * sin((1.0 - pop) * PI) if pop > 0.0 else 1.0
	var base_y := pr.position.y - 5.0
	HudStyle.text(c, Vector2(x0, base_y), "LV", 11, HudStyle.MUTED)
	var num_col := HudStyle.INK.lerp(gold, maxf(pop, 1.0 - lk if H.lvl_pop > 0.0 else 0.0))
	HudStyle.text(c, Vector2(x0 + 19.0, base_y), lvl_text(p), int(16.0 * sc), num_col)
	var bar_x := x0 + BAR_X
	var rank_ready := p.skill_pts > 0 and Hunter.SLOT_MAX.keys().any(func(s): return p.can_level(s))
	var pip_w := 22.0 if rank_ready else 0.0
	var br := Rect2(Vector2(bar_x, base_y - 9.0 - 1.5 * pop), Vector2(x0 + w - bar_x - pip_w, XP_H + 3.0 * pop))
	H._rounded(br.grow(1.5), HudStyle.SHADE, 3)
	c.draw_rect(br, Color(1, 1, 1, 0.12))
	c.draw_rect(Rect2(br.position, Vector2(br.size.x * fill, br.size.y)), gold.lerp(Color.WHITE, 0.6 * pop))
	if rank_ready:
		var pulse := 0.5 + 0.5 * sin(H.m.time * 5.0)
		c.draw_rect(br, Color(gold, 0.15 + 0.45 * pulse))
		var pts_at := Vector2(x0 + w - 9.0, br.get_center().y)
		c.draw_circle(pts_at, 8.0 + pulse, gold)
		var pts_txt := "+%d" % p.skill_pts if p.skill_pts > 1 else "+"
		HudStyle.ctext(c, pts_at + Vector2(0, 4), pts_txt, 11, Color(0.1, 0.07, 0.02), 0)

## Advances the shown XP toward p.xp (so the bar fills through a level-up), starts the gain pop when
## XP lands (once per gain) and returns the bar's fill 0..1 within the shown level.
static func xp_step(H, p: Hunter, dt: float) -> float:
	if H.xp_seen >= 0.0 and p.xp > H.xp_seen:
		H.xp_pop = XP_POP
	H.xp_seen = p.xp
	H.xp_pop = maxf(0.0, H.xp_pop - dt)
	if H.xp_shown < 0.0 or H.xp_shown > p.xp:
		H.xp_shown = p.xp
	H.xp_shown = minf(p.xp, H.xp_shown + maxf(XP_FILL_MIN, (p.xp - H.xp_shown) * XP_FILL_K) * dt)
	var i := 1
	while i < Hunter.XP_TO.size() and H.xp_shown >= float(Hunter.XP_TO[i]):
		i += 1
	if i >= Hunter.XP_TO.size():
		return 1.0
	var a := float(Hunter.XP_TO[i - 1])
	return clampf((H.xp_shown - a) / (float(Hunter.XP_TO[i]) - a), 0.0, 1.0)

static func lvl_text(p: Hunter) -> String:
	return str(p.lvl)
