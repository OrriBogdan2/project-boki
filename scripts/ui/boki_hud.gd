class_name BokiHud
extends RefCounted
## The Boki command system on the HUD (docs/decisions/0001), drawn through the in-match HUD `H`:
##   - the R slot is the bond meter and always the Merge: it fills with the bond, says MERGE (SURGE with no Boki) when
##     ready, RESCUE when the Boki is down (R does nothing), and while merged counts the merge down with the form's
##     ultimate (its name when ready, the seconds until it is)
##   - a merged hunter wears the form's name, a draining timer and the shell bar over their head (form_overhead)
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

## The Merge box (GripHud.boki) while the Merge is still locked or you are merged; GripHud draws the bond meter
## the rest of the time. `ur` is its rect. Every element has its own place so nothing overlaps:
##   inside the square   the icon (the shared slot art); the rank badge in the top-right corner
##   round the square    while merged, one ring along the outline: the time left (it pulses when R is ready)
##   under the square    the key cap of the Merge action (shared slot art)
##   above the square    the lock tag, or while merged one chip: the ultimate's unlock seconds / its name / the form
const RING_GROW := 4.0       # px: the ring sits this far outside the slot's edge
const CHIP_LIFT := 22.0      # px: the chip's top edge above the slot (clear of the rank pips at 7px and the "UNLOCK" tag)

static func r_slot(H, p: Hunter, ur: Rect2) -> void:
	var ri := p.slot_info("r")
	var ulv := int(p.slot_lv["ult"])
	var col: Color = ri["col"]
	var merged := KinMerge.active(p)
	var cd_left := float(ri["cd"])
	# (while merged the unlock seconds go in the chip, not as a number over the icon)
	H._skill_slot("ult", "r", ur, "bond", Settings.key_cap("ultimate"), col, 0.0, 0.0, bool(ri["ready"]))
	var ult_at := int(Hunter.ULT_AT[0])
	if ulv <= 0:
		if p.lvl < ult_at:
			if p.lvl == ult_at - 1:
				var fh: float = ur.size.y * p.xp_frac()
				H._rounded(Rect2(Vector2(ur.position.x, ur.end.y - fh), Vector2(ur.size.x, fh)), Color(1.0, 0.82, 0.48, 0.28), 10)
		elif p.can_level("ult"):
			var pulse := 0.5 + 0.5 * sin(H.m.time * 9.0)
			H._rounded(ur.grow(3.0 + pulse * 4.0), Color(1.0, 0.82, 0.48, 0.15 * pulse), 14, Color("ffd27a"), 3)
		return
	if ulv < Hunter.SLOT_MAX["ult"]:
		var tr := Rect2(Vector2(ur.end.x - 16, ur.position.y + 2), Vector2(14, 14))
		H._rounded(tr, Color(0.03, 0.03, 0.05, 0.9), 5, Color(H.MUTED, 0.6), 1)
		H._ctext(tr.get_center() + Vector2(0, 4), str(int(Hunter.ULT_AT[1])), 10, H.MUTED, H.big)
	if not merged:
		return
	var ml: Dictionary = p.merge_st
	var left := clampf(float(ml["t"]) / maxf(0.1, float(ml["T"])), 0.0, 1.0)
	var ready_ult := bool(ri.get("ready", false)) and String(ri.get("plan", "")) == "ult"
	var pl := 0.5 + 0.5 * sin(H.m.time * 8.0)
	_ring(H, ur.grow(RING_GROW), left, Color("fff4c0").lerp(col, pl * 0.6) if ready_ult else Color("fff4c0"), 4.0 if ready_ult else 3.0)
	var form_name := String((ml.get("form", {}) as Dictionary).get("name", "FUSED")).to_upper()
	var chip := form_name
	if ready_ult:
		chip = String(ri.get("name", "ULT")).to_upper()
	elif String(ri.get("plan", "")) == "ult" and not bool(ri.get("ulting", false)):
		chip = "ULT %.1fs" % cd_left
	var wl := MergeAugment.warn_left(p)
	if wl > 0.0:
		# the last seconds of the window: the slot flashes and the chip counts down
		var fl := 0.5 + 0.5 * sin(H.m.time * (10.0 + (3.0 - minf(wl, 3.0)) * 4.0))
		H._rounded(ur.grow(RING_GROW + 2.0 + fl * 3.0), Color(col, 0.18 * fl), 14, Color(1.0, 0.4, 0.3, 0.5 + 0.5 * fl), 3)
		chip = "ENDS %.1fs" % wl
	_chip(H, ur, chip, Color(1.0, 0.5, 0.4) if wl > 0.0 else col)

## A slot the Merge makes stronger: a ring and a small badge (the Boki's first letter) in the form's colour.
## slot: "lmb" | "rmb" | "e" | "dash". Nothing outside a live Merge.
static func aug_mark(H, p: Hunter, r: Rect2, slot: String) -> void:
	var mk := MergeAugment.mark(p, slot)
	if mk.is_empty():
		return
	var col: Color = mk["col"]
	var pl := 0.6 + 0.4 * sin(H.m.time * 5.0)
	H._rounded(r.grow(2.0), Color(col, 0.10), 11, Color(col, 0.55 + 0.35 * pl), 2)
	var b := Rect2(Vector2(r.position.x + 1, r.end.y - 14), Vector2(14, 14))
	H._rounded(b, Color(col, 0.95), 5)
	H._ctext(b.get_center() + Vector2(0, 4), String(mk["badge"]), 10, Color(0.05, 0.05, 0.08), H.big)

## The rest timer on the Boki card after the ultimate drained it.
static func rest_card(H, k: Kin, pc: Vector2, rr: float) -> void:
	if not k.resting():
		return
	H.c.draw_circle(pc, rr - 4, Color(0, 0, 0, 0.5))
	H._ctext(pc + Vector2(0, 5), "%d" % int(ceil(k.rest_t)), 14, H.INK, H.big)
	H._ctext(pc + Vector2(0, rr + 14), "RESTING", 9, Color(H.INK, 0.8), H.big)

## A progress ring that follows the slot's outline (a rounded square), from the top centre clockwise.
static func _ring(H, r: Rect2, frac: float, col: Color, width: float) -> void:
	if frac <= 0.0:
		return
	var rad := 15.0
	var pts := PackedVector2Array()
	var c0 := r.position + Vector2(rad, rad)
	var c1 := Vector2(r.end.x - rad, r.position.y + rad)
	var c2 := r.end - Vector2(rad, rad)
	var c3 := Vector2(r.position.x + rad, r.end.y - rad)
	pts.append(Vector2(r.get_center().x, r.position.y))
	for corner in [[c1, -PI / 2], [c2, 0.0], [c3, PI / 2], [c0, PI]]:
		var cc: Vector2 = corner[0]
		var a0: float = corner[1]
		for j in 7:
			var a: float = a0 + (PI / 2.0) * float(j) / 6.0
			pts.append(cc + Vector2(cos(a), sin(a)) * rad)
	pts.append(Vector2(r.get_center().x, r.position.y))
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var want := total * clampf(frac, 0.0, 1.0)
	var out := PackedVector2Array([pts[0]])
	var run := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if run + seg >= want:
			out.append(pts[i - 1].lerp(pts[i], (want - run) / maxf(seg, 0.001)))
			break
		out.append(pts[i])
		run += seg
	if out.size() >= 2:
		H.c.draw_polyline(out, col, width, true)

## The one line of text over the Merge box while merged (the ultimate's name, its unlock seconds, the form), centred above it.
static func _chip(H, ur: Rect2, text: String, col: Color) -> void:
	var tw: float = H.big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	var btr := Rect2(Vector2(ur.get_center().x - tw * 0.5, ur.position.y - CHIP_LIFT), Vector2(tw, 14))
	H._rounded(btr, Color(0.03, 0.03, 0.05, 0.95), 5, Color(col, 0.9), 1)
	H._ctext(btr.get_center() + Vector2(0, 4), text, 10, col, H.big)

## The Boki ability and G badges, after the ultimate tiles. Returns the x where the next badge starts.
static func cg_slots(H, p: Hunter, x: float, y: float, s: float) -> float:
	var k: Kin = p.kin
	if k == null or k.runner == null or k.runner.def_of("k1") == null:
		return x
	var kd: AbilitySpec = k.runner.def_of("k1")
	var down := k.state == "downed"
	var cr := Rect2(Vector2(x, y + s - 38.0), Vector2(38, 38))
	var cd_left: float = k.runner.cd_left("k1") if not k.runner.is_ready("k1") else 0.0
	H._ab_slot("kin_ab", cr, KinText.icon(kd), "AUTO", KinText.color(kd), k.runner.cd_frac("k1"), cd_left, k.runner.is_ready("k1") and k.ready_to_fight())
	var in_form := KinMerge.in_form(p)
	if in_form:
		H._rounded(cr, Color(0.04, 0.04, 0.06, 0.72), 8)          # (the Boki is part of you)
	var from_txt := "from Boki" if k.state in ["active", "flying", "returning", "flying_home"] else ("DOWN" if down else "through you")
	if in_form:
		from_txt = "FUSED"
	H._ctext(Vector2(cr.get_center().x, cr.position.y - 5), from_txt, 8, DOWN_COL if down else Color(H.INK, 0.5 if in_form else 0.7), H.big)
	x += 50.0
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
		H._ctext(Vector2(gr.get_center().x, gr.position.y - 17.0), "CARRY ON" if on else "CARRY OFF", 8, Color(k.sp["color"], 0.95) if on else Color(H.INK, 0.4), H.big)
	if down:
		H._rounded(gr, Color(0.3, 0.02, 0.02, 0.5), 12)
		H._ctext(gr.get_center() + Vector2(0, 4), str(int(ceil(k.down_t))), 14, DOWN_COL, H.big)
		mode = "DOWN"
	if in_form:
		H._rounded(gr, Color(0.04, 0.04, 0.06, 0.72), 8)
		mode = "FUSED"
	elif k.resting():
		H._rounded(gr, Color(0.04, 0.04, 0.06, 0.72), 8)
		H._ctext(gr.get_center() + Vector2(0, 4), str(int(ceil(k.rest_t))), 14, Color(H.INK, 0.8), H.big)
		mode = "RESTING"
	H._ctext(Vector2(gr.get_center().x, gr.position.y - 5), mode, 8, DOWN_COL if down else (Color(H.INK, 0.5) if in_form else Color(k.sp["color"], 0.95)), H.big)
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
	if KinDowned.contested(k):
		H._ctext(sp + Vector2(0, -62 + bob), "CONTESTED", 15, DOWN_COL, H.big)       # (an enemy stands on it: no pick-up until they leave)
	H._ctext(sp + Vector2(0, -24 + bob), ("Run into it to pick it up  ·  or %ds" if mine else "Back in %ds") % int(ceil(k.down_t)), 12, Color(H.INK, 0.9), H.big)
	H.c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-7, -14 + bob), sp + Vector2(7, -14 + bob), sp + Vector2(0, -4 + bob)]), col)
	H._bar(Rect2(sp + Vector2(-30, 2), Vector2(60, 5)), clampf(k.down_t / maxf(0.1, k.down_total), 0.0, 1.0), Color(col, 0.7))
	if k.rescue_t > 0.0:
		# the rescue: a ring closing round the Boki (a drop resets it)
		var rc := sp + Vector2(0, 22)
		H.c.draw_arc(rc, 20.0, 0.0, TAU, 40, Color(0, 0, 0, 0.45), 5.0, true)
		H.c.draw_arc(rc, 20.0, -PI / 2, -PI / 2 + TAU * KinDowned.scoop_k(k), 40, H.good() if k.rescue_on else H.good().darkened(0.3), 4.0, true)

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

## The shell bar: its own clearly lit bar in the form's colour (a dark bed, a bright rim, a pale leading edge). `flash` 0..1
## whitens it for a beat when the shell breaks.
static func shell_bar(H, r: Rect2, frac: float, glow: Color, flash := 0.0) -> void:
	H.c.draw_rect(r.grow(1.5), Color(0.02, 0.02, 0.04, 0.92))
	H.c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), glow.lerp(Color.WHITE, 0.15 + 0.7 * flash))
	if frac > 0.0:
		H.c.draw_rect(Rect2(r.position + Vector2(r.size.x * frac - 2.0, 0), Vector2(2.0, r.size.y)), Color(1, 1, 1, 0.9))
	H.c.draw_rect(r.grow(1.5), Color(glow.lerp(Color.WHITE, 0.3 + 0.5 * flash), 0.95), false, 1.4)

## How long ago a shell broke on this hunter, as a 1..0 flash (0 when it has not just broken).
static func shell_flash(H, h: Hunter) -> float:
	var t: float = H.m.time - float(h.get_meta("shell_break_at", -9.0))
	return clampf(1.0 - t / 0.5, 0.0, 1.0)

## Over a merged hunter's head, for everyone: the form's name, its draining timer, and the shell bar in the form's colour.
## `sp` is the plate's screen anchor (the top of the health bar); it sits above the name.
static func form_overhead(H, sp: Vector2, h: Hunter) -> void:
	var name := ""
	var glow := Color.WHITE
	var left := 0.0
	var total := 1.0
	var sh := MergeShell.view(h)
	var live := false
	if not h.merge_st.is_empty():
		var f: Dictionary = h.merge_st["form"]
		if String(h.merge_st.get("phase", "")) != "live":
			return
		name = String(f["name"])
		glow = f["glow"]
		left = float(h.merge_st["t"])
		total = float(h.merge_st["T"])
		live = true
	elif h.has_meta("mf_name") and float(h.get_meta("mf_left", 0.0)) > 0.0:
		name = String(h.get_meta("mf_name"))
		glow = h.get_meta("mf_glow", Color.WHITE)
		left = float(h.get_meta("mf_left", 0.0))
		total = maxf(0.1, float(h.get_meta("mf_dur", 10.0)))
		live = true
	var w := 66.0
	var x0 := sp.x - w * 0.5
	if not live:
		var fl := shell_flash(H, h)
		if fl > 0.0:
			shell_bar(H, Rect2(Vector2(x0, sp.y - 18.0), Vector2(w, 6.0)), 0.0, h.get_meta("shell_break_col", Color.WHITE), fl)
		return
	var fl2 := shell_flash(H, h)
	if sh.y > 0.0:
		shell_bar(H, Rect2(Vector2(x0, sp.y - 18.0), Vector2(w, 6.0)), sh.x / sh.y, glow, fl2)
	var tr := Rect2(Vector2(x0, sp.y - 24.0), Vector2(w, 3.0))
	H.c.draw_rect(tr, Color(0.03, 0.03, 0.05, 0.8))
	H.c.draw_rect(Rect2(tr.position, Vector2(w * clampf(left / total, 0.0, 1.0), 3.0)), Color(glow, 0.75))
	H._ctext(Vector2(sp.x, sp.y - 28.0), "%s  %ds" % [name.to_upper(), int(ceil(left))], 11, glow, H.big)
