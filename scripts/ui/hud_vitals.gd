class_name HudVitals
extends RefCounted
## The bottom-left vitals block: your portrait framed in your class colour with the run level on a
## coin ringed by XP, then to its right your health as a big number over a thick segmented bar
## (same segments and chip as your overhead plate), armour as a strip under it with its number and
## tier, shields past the end of health, the merged form's shell, and the archetype resource under
## that. The ability row sits below the bars (Hud._draw_abilities). Look: HudStyle.
## Hud keeps the state that checks read (lvl_pop, armor_lerp, hover_spots); this file only draws.

const BAR_W := 318.0       # px: health / armour width
const HP_H := 16.0         # px: the health bar
const AR_H := 5.0          # px: the armour strip under it
const LVL_POP := 0.35      # s: the level coin's pop

static func draw(H, sz: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var o: Vector2 = H._hud_origin(sz)
	var pr := Rect2(o, H.HUD_PORTRAIT)
	var hc: Color = p.accent()
	# the portrait, framed in your class colour (its name and class are under it)
	H._draw_portrait(pr, p, "down" if p.downed else "", hc)
	H.hover_spots.append([pr, "vitals"])
	level_coin(H, pr, p)
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
	var hp_col := HudStyle.hp_fill(HudStyle.SELF, frac, H.m.time)
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
	# progress to the next armour tier: a hairline under the armour strip in the next tier's colour
	if p.armor_tier < Hunter.ARMOR_TIERS.size() - 1:
		var nxt: Color = Hunter.ARMOR_TIERS[p.armor_tier + 1][1]
		c.draw_rect(Rect2(Vector2(x0, ar.end.y + 2), Vector2(w, 1)), Color(0, 0, 0, 0.35))
		c.draw_rect(Rect2(Vector2(x0, ar.end.y + 2), Vector2(w * p.armor_frac(), 1)), Color(nxt, 0.9))
	if p.ak and p.ak.has_meter():
		H._draw_res_bar(x0, ar.end.y + 4, w, p)
	_hidden_tag(H, sz, p)

## HIDDEN / CROUCHED / SPOTTED over the middle of the bar when you're in grass or crouching.
static func _hidden_tag(H, sz: Vector2, p: Hunter) -> void:
	var grass: bool = H.m.world.in_bush(p.pos.x, p.pos.z)
	if not (grass or p.crouch):
		return
	var txt := "SPOTTED"
	var fg: Color = HudStyle.HURT
	var bg := Color(0.25, 0.06, 0.05, 0.85)
	if p.reveal_t <= 0.0 and not ArcherKit.sensed_any(H.m, p):
		txt = "HIDDEN" if grass else "CROUCHED"
		fg = Color("8fe0a0") if grass else Color("c9d2e0")
		bg = Color(0.05, 0.12, 0.06, 0.85) if grass else Color(0.08, 0.09, 0.12, 0.85)
	var tw := HudStyle.BIG.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var hr := Rect2(Vector2(sz.x * 0.5 - tw * 0.5 - 12, sz.y - 104), Vector2(tw + 24, 20))
	H._rounded(hr, bg, 10)
	HudStyle.text(H.c, hr.position + Vector2(12, 15), txt, 13, fg)

## The run level on a coin over the portrait's corner, ringed by progress to the next level with a
## bright head dot; a level-up pops it and bursts a gold ring round the portrait.
static func level_coin(H, pr: Rect2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var gold := HudStyle.GOLD
	if H.lvl_seen >= 0 and p.lvl > H.lvl_seen and H.lvl_pop <= 0.0:
		H.lvl_pop = LVL_POP
	H.lvl_seen = p.lvl
	H.lvl_pop = maxf(0.0, H.lvl_pop - H.get_process_delta_time())
	var k: float = 1.0 - H.lvl_pop / LVL_POP
	var sc := 1.0 + 0.35 * sin(k * PI) if H.lvl_pop > 0.0 else 1.0
	if H.lvl_pop > 0.0:
		H._rounded(pr.grow(6.0 + k * 22.0), Color(0, 0, 0, 0), 16, Color(gold, 1.0 - k), 4)
		H._rounded(pr.grow(2.0 + k * 10.0), Color(gold, 0.18 * (1.0 - k)), 14)
	var bc := pr.position + Vector2(6, pr.size.y - 6)
	var r := 26.0 * sc
	# the coin sits in a notch of the frame: ringed in the frame's colour, a dark gap between
	c.draw_circle(bc, r + 4.0, Color(p.accent(), 0.9))
	c.draw_circle(bc, r + 2.0, HudStyle.SHADE_EDGE)
	c.draw_circle(bc, r, Color(0.03, 0.03, 0.05, 0.97))
	c.draw_arc(bc, r - 3.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 4.0, true)
	var xf := p.xp_frac()
	c.draw_arc(bc, r - 3.0, -PI / 2, -PI / 2 + TAU * xf, 48, gold, 4.0, true)
	if xf > 0.01 and xf < 0.999:
		var ha := -PI / 2 + TAU * xf
		c.draw_circle(bc + Vector2(cos(ha), sin(ha)) * (r - 3.0), 3.6, Color(1.0, 0.97, 0.85))
	var lvl_col := HudStyle.INK if H.lvl_pop <= 0.0 else HudStyle.INK.lerp(gold, 1.0 - k)
	HudStyle.ctext(c, bc + Vector2(0, 9.0 * sc), str(p.lvl), int(26.0 * sc), lvl_col)
	if p.skill_pts > 0:
		var pulse := 0.5 + 0.5 * sin(H.m.time * 5.0)
		var pts_at := bc + Vector2(22, -22)
		c.draw_circle(pts_at, 10.0 + pulse, gold)
		var pts_txt := "+%d" % p.skill_pts if p.skill_pts > 1 else "+"
		HudStyle.ctext(c, pts_at + Vector2(0, 5), pts_txt, 13, Color(0.1, 0.07, 0.02), 0)
	# the archetype's name under the portrait instead of just the class
	if p.ak:
		var arch_txt := Arch.name_of(p.arch).to_upper() + "  ·  " + String(p.cdat["name"]).to_upper()
		HudStyle.text(c, pr.position + Vector2(36, pr.size.y + 14), arch_txt, 10, Color(Arch.color(p.arch), 0.9))
