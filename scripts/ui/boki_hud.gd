class_name BokiHud
extends RefCounted
## The Boki command system on the HUD (docs/decisions/0001), drawn through the in-match HUD `H`:
##   - the R slot is the bond meter: it fills with the bond, says MERGE (or LEAP / SURGE) when ready, and
##     counts the merge down with the form's tier name while it runs
##   - C and G show where the Boki is and what it is doing: from you / from the Boki, its order (follow, guard,
##     chase, return), the G hold ring, DOWN with the seconds until it comes round, and whether its carried
##     bonuses are on you (greyed while it is out)
##   - the G flick wheel (hold G, move the mouse, release): Chase, Guard, Return, Follow
##   - a downed Boki is marked in the world (label, timer, scoop bar, an arrow at the screen edge) and
##     on the minimap and the full map
## Kept out of hud.gd (a god file): hud.gd only calls these.

const DOWN_COL := Color("ff7a6a")

## The downed Bokis of the local player's team (the ones their squad can rescue).
static func squad_downed(m) -> Array:
	var out: Array = []
	if m.player == null:
		return out
	for k in m.kins:
		if k.state == "downed" and k.owner_h != null and k.team == m.player.team and not k.dead:
			out.append(k)
	return out

## The R slot: the bond meter / Merge. `ur` is its rect, `us` its size.
static func r_slot(H, p: Hunter, ur: Rect2, us: float) -> void:
	var ri := p.slot_info("r")
	var ulv := int(p.slot_lv["ult"])
	var col: Color = ri["col"]
	var form: Dictionary = ri.get("form", {})
	H._skill_slot("ult", "r", ur, "bond", Settings.key_cap("ultimate"), col, float(ri["cd"]) / maxf(0.01, float(ri["cd_max"])) if float(ri["cd"]) > 0.0 else 0.0, float(ri["cd"]), bool(ri["ready"]))
	var ult_at := int(Hunter.ULT_AT[0])
	if ulv <= 0:
		if p.lvl < ult_at:
			if p.lvl == ult_at - 1:
				var fh: float = ur.size.y * p.xp_frac()
				H._rounded(Rect2(Vector2(ur.position.x, ur.end.y - fh), Vector2(ur.size.x, fh)), Color(1.0, 0.82, 0.48, 0.28), 10)
			H._ctext(ur.get_center() + Vector2(0, 14), str(ult_at), 34, Color(H.INK, 0.85), H.big)
		elif p.can_level("ult"):
			var pulse := 0.5 + 0.5 * sin(H.m.time * 9.0)
			H._rounded(ur.grow(3.0 + pulse * 4.0), Color(1.0, 0.82, 0.48, 0.15 * pulse), 14, Color("ffd27a"), 3)
		return
	if ulv < Hunter.SLOT_MAX["ult"]:
		var tr := Rect2(ur.end - Vector2(18, 18), Vector2(16, 16))
		H._rounded(tr, Color(0.03, 0.03, 0.05, 0.9), 5, Color(H.MUTED, 0.6), 1)
		H._ctext(tr.get_center() + Vector2(0, 4.5), str(int(Hunter.ULT_AT[1])), 11, H.MUTED, H.big)
	var ctr := ur.get_center()
	if KinMerge.active(p):
		var ml: Dictionary = p.merge_st
		var left := clampf(float(ml["t"]) / maxf(0.1, float(ml["T"])), 0.0, 1.0)
		H.c.draw_arc(ctr, us * 0.5 + 4.0, -PI / 2, -PI / 2 + TAU * left, 48, Color("fff4c0"), 4.0, true)
		H._ctext(ctr + Vector2(0, us * 0.5 - 10), "%ds" % int(ceil(float(ml["t"]))), 11, Color("fff4c0"), H.big)
		_tag(H, ur, String((ml.get("form", {}) as Dictionary).get("tier_name", "MERGED")).to_upper(), col)
		return
	# the meter: a fill from the bottom and a ring, in the Boki's colour
	var bond := clampf(p.ult, 0.0, 1.0)
	var fh2: float = (ur.size.y - 6.0) * bond
	if fh2 > 0.0:
		H._rounded(Rect2(Vector2(ur.position.x + 3, ur.end.y - 3 - fh2), Vector2(ur.size.x - 6, fh2)), Color(col, 0.30 if bond < 1.0 else 0.45), 9)
	H.c.draw_arc(ctr, us * 0.5 + 3.0, -PI / 2, -PI / 2 + TAU * bond, 48, col, 3.0, true)
	var plan := String(ri.get("plan", ""))
	if bond < 1.0:
		H._ctext(ctr + Vector2(0, us * 0.5 - 10), "%d%%" % int(bond * 100.0), 11, Color(col, 0.95), H.big)
	else:
		var pulse2 := 0.5 + 0.5 * sin(H.m.time * 6.0)
		H._rounded(ur.grow(3.0 + pulse2 * 3.0), Color(0, 0, 0, 0), 14, Color(col, 0.55 + 0.4 * pulse2), 3)
		_tag(H, ur, {"merge": "MERGE", "leap": "LEAP", "surge": "SURGE", "far": "TOO FAR"}.get(plan, "MERGE"), col if plan != "far" else DOWN_COL)

static func _tag(H, ur: Rect2, text: String, col: Color) -> void:
	var btr := Rect2(Vector2(ur.position.x + 2, ur.position.y - 7), Vector2(ur.size.x - 4, 13))
	H._rounded(btr, Color(0.03, 0.03, 0.05, 0.95), 5, Color(col, 0.9), 1)
	H._ctext(btr.get_center() + Vector2(0, 4), text, 9, col, H.big)

## C and G, the small badges after R. Returns the x where the next badge starts.
static func cg_slots(H, p: Hunter, x: float, y: float, s: float) -> float:
	var k: Kin = p.kin
	if k == null or k.runner == null or k.runner.def_of("k1") == null:
		return x
	var kd: AbilitySpec = k.runner.def_of("k1")
	var down := k.state == "downed"
	var cr := Rect2(Vector2(x, y + s - 38.0), Vector2(38, 38))
	var cd_left: float = k.runner.cd_left("k1") if not k.runner.is_ready("k1") else 0.0
	H._ab_slot("kin_ab", cr, KinText.icon(kd), Settings.key_cap("kin_ability"), KinText.color(kd), k.runner.cd_frac("k1"), cd_left, k.runner.is_ready("k1") and k.ready_to_fight())
	var from_txt := "from Boki" if k.state in ["active", "flying", "returning", "flying_home"] else ("DOWN" if down else "through you")
	H._ctext(Vector2(cr.get_center().x, cr.position.y - 5), from_txt, 8, DOWN_COL if down else Color(H.INK, 0.7), H.big)
	x += 46.0
	var gr := Rect2(Vector2(x, y + s - 34.0), Vector2(34, 34))
	var out := k.state in ["active", "flying", "returning", "flying_home"]
	var away := out and KinCommand.is_away(p, k)
	H._ab_slot("throw", gr, "recall" if away else "throw", Settings.key_cap("throw"), Color("cfe8ff"), 0.0, 0.0, k.ready_to_fight() and k.throw_cd <= 0.0)
	var hf := KinCommand.hold_frac(p)
	if hf > 0.0 and hf < 1.0 or bool(p.inp.get("g_fired", false)) and Input.is_action_pressed("throw"):
		H.c.draw_arc(gr.get_center(), 22.0, -PI / 2, -PI / 2 + TAU * hf, 28, Color("cfe8ff"), 3.0, true)
	var mode := String(KinFollow.NAMES.get(k.cmd, "Follow")).to_upper()
	if k.ks and (not k.ks.carry_passives.is_empty() or not k.ks.carry_on_shot.is_empty()):
		# its carried bonuses: on while it is on you, greyed while it is out beside you
		var on := p.kin_carry_on()
		H._ctext(Vector2(gr.get_center().x, gr.end.y + 9), "CARRY ON" if on else "CARRY OFF", 8, Color(k.sp["color"], 0.95) if on else Color(H.INK, 0.4), H.big)
	if down:
		H._rounded(gr, Color(0.3, 0.02, 0.02, 0.5), 12)
		H._ctext(gr.get_center() + Vector2(0, 4), str(int(ceil(k.down_t))), 14, DOWN_COL, H.big)
		mode = "DOWN"
	H._ctext(Vector2(gr.get_center().x, gr.position.y - 5), mode, 8, DOWN_COL if down else Color(k.sp["color"], 0.95), H.big)
	if KinWheel.is_open(p):
		wheel(H, p)
	return x + 42.0

## The flick wheel, drawn round where the mouse was when you started holding G. Four wedges with a label and a
## hint each, popped open with an ease-out-back, the one under your flick lit, your current order marked.
static func wheel(H, p: Hunter) -> void:
	var w: Dictionary = p.inp["wheel"]
	var o: Vector2 = w["o"]
	var pop := KinWheel.pop(p)
	var rin := 26.0 * pop
	var rout := float(KinWheel.rules()["radius_px"]) * pop
	var k: Kin = p.kin
	var kc := Color(k.sp["color"])
	var hints := {"chase": "stick to a foe", "guard": "hold this spot", "return": "back on you", "follow": "at your side"}
	for i in KinWheel.SEGMENTS.size():
		var sg: Dictionary = KinWheel.SEGMENTS[i]
		var a: float = (sg["dir"] as Vector2).angle()
		var pts := PackedVector2Array()
		for j in 11:
			var t := a - PI / 4.0 + 0.04 + (PI / 2.0 - 0.08) * float(j) / 10.0
			pts.append(o + Vector2(cos(t), sin(t)) * rout)
		for j in range(10, -1, -1):
			var t := a - PI / 4.0 + 0.04 + (PI / 2.0 - 0.08) * float(j) / 10.0
			pts.append(o + Vector2(cos(t), sin(t)) * rin)
		var lit := int(w["sel"]) == i
		H.c.draw_colored_polygon(pts, Color(kc, 0.62) if lit else Color(0.03, 0.04, 0.07, 0.72))
		var mid := o + (sg["dir"] as Vector2) * (rin + rout) * 0.5
		var is_now: bool = String(sg["id"]) == k.cmd
		H._ctext(mid + Vector2(0, -2), String(sg["label"]).to_upper(), 15, Color.WHITE if lit else Color(H.INK, 0.92), H.big)
		H._ctext(mid + Vector2(0, 12), String(hints[sg["id"]]), 10, Color(H.INK, 0.85 if lit else 0.55), H.big)
		if is_now:
			H.c.draw_circle(mid + Vector2(0, -20), 3.0, kc)
	H.c.draw_circle(o, rin - 4.0, Color(0.03, 0.04, 0.07, 0.8))
	var sel := int(w["sel"])
	if sel >= 0:
		H.c.draw_line(o, o + (KinWheel.SEGMENTS[sel]["dir"] as Vector2) * (rin - 6.0), kc, 3.0, true)

## A downed Boki of your squad, in the world: its name and the seconds until it comes round, the scoop
## bar, and an arrow at the screen edge when it is off screen. `sp` is its screen spot.
static func downed_label(H, k: Kin, sp: Vector2) -> void:
	var col := Color(k.sp.get("glow", k.sp["color"]))
	var bob := sin(H.m.time * 3.0) * 2.0
	if k.down_void:
		H._ctext(sp + Vector2(0, -34 + bob), "%s fell. Back in %ds" % [k.rec.get("name", "Your Boki"), int(ceil(k.down_t))], 15, DOWN_COL, H.big)
		return
	H._ctext(sp + Vector2(0, -42 + bob), "%s is down" % k.rec.get("name", "Your Boki"), 17, col.lerp(Color.WHITE, 0.3), H.big)
	var mine: bool = k.owner_h == H.m.player
	H._ctext(sp + Vector2(0, -24 + bob), ("Run into it  ·  or %ds" if mine else "Back in %ds") % int(ceil(k.down_t)), 12, Color(H.INK, 0.9), H.big)
	H.c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-7, -14 + bob), sp + Vector2(7, -14 + bob), sp + Vector2(0, -4 + bob)]), col)
	H._bar(Rect2(sp + Vector2(-30, 2), Vector2(60, 5)), clampf(k.down_t / maxf(0.1, k.down_total), 0.0, 1.0), Color(col, 0.7))
	if k.rescue_t > 0.0:
		H._bar(Rect2(sp + Vector2(-30, 9), Vector2(60, 6)), KinDowned.scoop_k(k), H.GOOD)

## The edge-of-screen arrow toward your downed Boki when it is off screen.
static func downed_arrow(H, k: Kin, sz: Vector2) -> void:
	var cam: Camera3D = H.m.cam
	var wp := k.position + Vector3(0, 1.0, 0)
	var sp := cam.unproject_position(wp)
	if not cam.is_position_behind(wp) and Rect2(Vector2(40, 40), sz - Vector2(80, 80)).has_point(sp):
		return
	var ctr := sz * 0.5
	var dir := (sp - ctr)
	if cam.is_position_behind(wp):
		dir = -dir
	dir = dir.normalized()
	var edge := ctr + dir * minf((sz.x * 0.5 - 50.0) / maxf(0.01, absf(dir.x)), (sz.y * 0.5 - 50.0) / maxf(0.01, absf(dir.y)))
	var col := Color(k.sp.get("glow", k.sp["color"]))
	var side := Vector2(-dir.y, dir.x)
	H.c.draw_colored_polygon(PackedVector2Array([edge + dir * 14.0, edge - dir * 8.0 + side * 10.0, edge - dir * 8.0 - side * 10.0]), col)
	H._ctext(edge - dir * 22.0 + Vector2(0, 4), "%ds" % int(ceil(k.down_t)), 11, Color(H.INK, 0.9), H.big)

## Your squad's downed Boki on a map: a ringed cross in its colour (the minimap draws it at `pv`).
static func map_dot(c: Control, pv: Vector2, k: Kin, r: float, time: float) -> void:
	var col := Color(k.sp.get("glow", k.sp["color"]))
	var ph := fmod(time * 1.2, 1.0)
	c.draw_circle(pv, r + 1.5, Color(0, 0, 0, 0.7))
	c.draw_circle(pv, r, col if not k.down_void else Color(DOWN_COL, 0.7))
	c.draw_line(pv + Vector2(-r, -r) * 0.55, pv + Vector2(r, r) * 0.55, Color(0.05, 0.03, 0.08), 1.8)
	c.draw_line(pv + Vector2(-r, r) * 0.55, pv + Vector2(r, -r) * 0.55, Color(0.05, 0.03, 0.08), 1.8)
	c.draw_arc(pv, r + 2.0 + ph * 8.0, 0, TAU, 20, Color(col, 1.0 - ph), 2.0, true)

## The G slot's tooltip lines (HUD hover): the orders, then what the Boki gives you on you and what you lose off you.
static func order_tip(H, p: Hunter) -> Array:
	var k: Kin = p.kin
	if k == null:
		return []
	var out: Array = []
	out.append(["Orders for %s" % k.rec.get("name", "your Boki"), k.sp["color"]])
	out.append(["Boki  ·  %s  ·  now: %s" % [Settings.key_cap("throw"), String(KinFollow.NAMES.get(k.cmd, "Follow"))], H.MUTED, 12])
	out.append([("Tap: Sic, your Boki dives on the cursor from above" if k.carry_style() == "perch" else "Tap: Sic, your Boki leaps at the cursor") + ". Whatever it hits is stunned, and your shots crit stunned foes. Tap while it is away to call it back.", H.INK, 14])
	out.append(["Hold and flick: up Chase (stick to a foe), right Guard (hold this spot), down Return (back on you), left Follow (at your side).", H.INK, 14])
	if k.ks and not k.ks.throw_effects.is_empty():
		out.append(["Its Sic also: " + KinText.effects(k.ks.throw_effects), KinRules.effects_color(k.ks.throw_effects), 13])
	if k.ks:
		out.append([KinText.carry(k.ks), KinRules.cat_color("sustain"), 13])
		var off := KinText.carry_off(k.ks)
		if off != "" and not p.kin_carry_on():
			out.append([off, H.MUTED, 13])
		var ob := KinText.owner_bonus(p.kin_bonus)
		if ob != "":
			out.append(["Owner bonus for the run: " + ob, H.GOLD, 13])
	return out
