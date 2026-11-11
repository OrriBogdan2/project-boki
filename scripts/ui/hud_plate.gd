class_name HudPlate
extends RefCounted
## Overhead plates (one per hunter): the name or a status word, the run level on a coin, health in
## fixed-size segments with armour as a thin strip under it and shields as a pale fill past the end
## of health, a chip that holds then drains after a hit, a white flash on the frame when struck, an
## armour-break crack, the status row to the right, and a downed plate with a
## knock burst. Hud owns one of these (hud.plates) and calls draw() / draw_self() per hunter; the
## same chip tracker feeds the mob and boss bars and the squad list (chip_of), and the same status row
## (row, draw_row) sits under monster and Boki bars and on the squad rows.
## Look and sizes: HudStyle. Layout around the anchor `sp` (the point over the head):
##   name / status word ............ sp.y - 7
##   frame (health + armour) ....... sp.y .. sp.y + PAD*2 + HP_H + 1 + AR_H
##   status row (others) ........... right of the frame, on its vertical centre (row, draw_row)
##   loadout icon row (others) ..... sp.y + HudStyle.PLATE_ICON_ROW and down: left free here

const CHIP_HOLD := 0.4         # s the lost chunk stays after the last hit
const CHIP_DRAIN := 1.6        # of the bar per second once it drains (plus an ease-out)
const FLASH_T := 0.14          # s the frame flashes white when struck
const BREAK_T := 0.45          # s of the armour-break crack
const BURST_T := 1.1           # s of the knock burst over someone who just went down
const LVL_POP_T := 0.7        # s of the pulse on a plate's level badge when that hunter levels up
const PRUNE_T := 5.0           # s unseen before a hunter's plate state is dropped
const PLATE_OFFSET := 2.35     # m over the feet where a plate sits unless the archetype sets its own
const ROW_MAX := 4             # icons a status row shows at most; the lowest in the order wait
const ROW_R := 8.0             # px radius of a status icon's disc (reads at 1280x720 at the match camera)
const ROW_RING_W := 2.5        # px width of the ring round it that empties with the time left
const ROW_STEP := 2.0 * (ROW_R + ROW_RING_W) + 1.0   # px between two icons' centres
const RING_REFRESH := 0.15     # s the time left must jump up to restart a ring (a re-applied status, not net jitter)
const RING_LAPSE := 0.25       # s a status may go undrawn before its ring starts over when it is seen again
const READY_COL := Color("ffd23f")   # rim of a mark whose payoff is ready
const STOPS := ["concussion", "binding", "bolas"]   # stun, root, Ground: what stops them, ahead of your marks

## nid -> {chip, hold, frac, armor, flash, brk, down, burst, seen, tot (the status row's ring clocks)}
var st := {}
var now := 0.0
var _prune_at := 0.0
## What the last draw showed for each nid (checks and tools read this): {segs, armor, shield,
## downed, word, chip}
var shown := {}

## How high over this hunter's feet their plate sits: the archetype's optional `plate_offset` (in its
## content/archetypes JSON, so taller and shorter heroes clear their own heads), else PLATE_OFFSET.
static func plate_offset(h: Hunter) -> float:
	return float(Arch.def(h.arch).get("plate_offset", PLATE_OFFSET))

## Advances the clock (Hud._process) and forgets hunters not drawn for a while.
func tick(dt: float) -> void:
	now += dt
	if now >= _prune_at:
		_prune_at = now + PRUNE_T
		for k in st.keys():
			if now - float(st[k]["seen"]) > PRUNE_T:
				st.erase(k)
				shown.erase(k)

func _state(e: Ent) -> Dictionary:
	var s: Dictionary = st.get(e.nid, {})
	if s.is_empty():
		s = {"chip": 1.0, "hold": 0.0, "frac": -1.0, "armor": -1.0, "flash": 0.0, "brk": 0.0, "down": false,
			"burst": 0.0, "lvl": -1, "lvl_pop": 0.0, "seen": now}
		st[e.nid] = s
	return s

## The trailing fraction behind `frac` for this entity: it holds CHIP_HOLD after the last drop,
## then drains toward frac; a heal pulls it up at once.
func chip_of(e: Ent, frac: float, dt: float) -> float:
	var s := _state(e)
	if float(s.get("at", -1.0)) == now and now > 0.0:
		return float(s["chip"])         # asked twice in one frame: the squad list and the plate
	s["at"] = now
	s["seen"] = now
	var was := float(s["frac"])
	if was >= 0.0 and frac < was - 0.0005:
		s["hold"] = CHIP_HOLD
		s["flash"] = FLASH_T
	elif was < 0.0:
		s["chip"] = frac
	s["frac"] = frac
	s["hold"] = maxf(0.0, float(s["hold"]) - dt)
	s["flash"] = maxf(0.0, float(s["flash"]) - dt)
	var ch := maxf(float(s["chip"]), frac)
	if float(s["hold"]) <= 0.0:
		var gap := ch - frac
		ch = maxf(frac, ch - dt * (CHIP_DRAIN * 0.5 + gap * 6.0))
	s["chip"] = ch
	return ch

func flash_of(e: Ent) -> float:
	return clampf(float(_state(e)["flash"]) / FLASH_T, 0.0, 1.0)

## Watches armour and the downed state for the crack and the knock burst.
func _watch(h: Hunter, dt: float) -> Dictionary:
	var s := _state(h)
	var ar := h.armor
	if float(s["armor"]) > 0.5 and ar <= 0.5 and h.max_armor > 0.5:
		s["brk"] = BREAK_T
	s["armor"] = ar
	s["brk"] = maxf(0.0, float(s["brk"]) - dt)
	if h.downed and not bool(s["down"]):
		s["burst"] = BURST_T
	s["down"] = h.downed
	s["burst"] = maxf(0.0, float(s["burst"]) - dt)
	if int(s["lvl"]) >= 0 and h.lvl > int(s["lvl"]):
		s["lvl_pop"] = LVL_POP_T
	s["lvl"] = h.lvl
	s["lvl_pop"] = maxf(0.0, float(s["lvl_pop"]) - dt)
	return s

## What's happening to someone, as [icon, colour, word, seconds left (or -1)], worst first. The
## crowd-control kinds (stun, root, Ground, Daze, Slow) always carry their time left.
static func statuses(e: Ent) -> Array:
	var out: Array = []
	if e.stun_t > 0.0: out.append(["concussion", Color("fff27a"), "STUNNED", e.stun_t])
	if e.root_t > 0.0: out.append(["binding", Color("8fe0a0"), "ROOTED", e.root_t])
	if KitStatus.grounded(e): out.append(["bolas", KitStatus.GROUND_COL, "GROUNDED", KitStatus.grounded_left(e)])
	if KitStatus.rattled(e): out.append(["burst", KitStatus.RATTLE_COL, "DAZED", KitStatus.rattled_left(e)])
	if e.slow_t > 0.0: out.append(["snare", Color("9ae8ff"), "SLOWED", e.slow_t])
	if e.burn_t > 0.0: out.append(["fireball", Color("ff9a5a"), "BURNING", -1.0])
	var hunter := e as Hunter
	if hunter and hunter.weak_t > 0.0: out.append(["swap", Color("ffb36a"), "WEAKENED", hunter.weak_t])
	if hunter and hunter.shield > 0.0: out.append(["brightshield", Color("d8ecff"), "", -1.0])
	if e.guard_t > 0.0: out.append(["anchor", Color("f2e6cf"), "", -1.0])
	return out

## The status row `viewer` sees on `e`, at most ROW_MAX, each {icon, col, left, total, n, ready}: what stops them
## (stun, root, Ground), then the viewer's own marks on them (ArchKit.combo_marks, through RecastCue), then the
## rest of `sts` (statuses(e)). A mark takes the place of a status drawn with its icon (Vex's Daze, Cinder's Ablaze
## over the plain burn). A status's ring runs over the longest time left seen since it went on.
func row(viewer: Hunter, e: Ent, sts: Array) -> Array:
	var out: Array = []
	var mine: Array = []
	if viewer and viewer.ak:
		for mk in viewer.ak.cue.get("marks", []):
			if mk["e"] == e:
				mine.append(mk)
	if sts.is_empty() and mine.is_empty():
		return out
	var s := _state(e)
	s["seen"] = now
	var tot: Dictionary = s.get("tot", {})       # icon -> Vector3(ring total, time left, plate clock) last drawn
	s["tot"] = tot
	var taken := {}
	for mk in mine:
		taken[mk["icon"]] = true
	for x in sts:
		if x[0] in STOPS and not taken.has(x[0]):
			out.append(_status_item(x, tot))
	for mk in mine:
		out.append({"icon": mk["icon"], "col": viewer.ak.res_col(), "left": float(mk["left"]),
			"total": float(mk["total"]), "n": int(mk["n"]), "ready": bool(mk["ready"])})
	for x in sts:
		if x[0] not in STOPS and not taken.has(x[0]):
			out.append(_status_item(x, tot))
	out.resize(mini(out.size(), ROW_MAX))
	return out

func _status_item(x: Array, tot: Dictionary) -> Dictionary:
	var left := float(x[3])
	return {"icon": x[0], "col": x[1], "left": left, "total": _ring_total(tot, String(x[0]), left), "n": 0,
		"ready": false}

## How long the clock behind `left` runs, for its ring: the most left seen since the status went on. Re-applied
## (left jumps up past RING_REFRESH) or unseen for RING_LAPSE, it starts full again. -1 for a status with no clock.
func _ring_total(tot: Dictionary, icon: String, left: float) -> float:
	if left < 0.0:
		return -1.0
	var was: Vector3 = tot.get(icon, Vector3(0.0, 0.0, -INF))
	var total := was.x
	if left > was.y + RING_REFRESH or now - was.z > RING_LAPSE:
		total = left
	total = maxf(total, left)
	tot[icon] = Vector3(total, left, now)
	return total

## Draws a status row (from row()) from `at`, its left end at the vertical centre, or centred on `at`.
static func draw_row(c: CanvasItem, at: Vector2, items: Array, centred := false) -> void:
	var left_end := at.x - (items.size() * ROW_STEP - 1.0) * 0.5 if centred else at.x
	var x := left_end + ROW_R + ROW_RING_W
	for it in items:
		_row_icon(c, Vector2(x, at.y), it)
		x += ROW_STEP

## One status: its icon on a dark disc, a ring in its colour emptying with the time left (whole and faint with no
## clock), a gold rim on a mark whose payoff is ready, and the stack count at the lower right.
static func _row_icon(c: CanvasItem, at: Vector2, it: Dictionary) -> void:
	var col: Color = it["col"]
	var out_r := ROW_R + ROW_RING_W
	var ring_r := ROW_R + ROW_RING_W * 0.5
	c.draw_circle(at, out_r + 1.0, HudStyle.SHADE)
	var left := float(it["left"])
	if left < 0.0:
		c.draw_arc(at, ring_r, 0.0, TAU, 24, Color(col, 0.45), ROW_RING_W, true)
	else:
		var frac := clampf(left / maxf(0.05, float(it["total"])), 0.0, 1.0)
		c.draw_arc(at, ring_r, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, col, ROW_RING_W, true)
	if bool(it["ready"]):
		c.draw_arc(at, out_r + 1.0, 0.0, TAU, 24, READY_COL, 1.5, true)
	Icons.draw(c, String(it["icon"]), at, ROW_R * 0.6, col)
	if int(it["n"]) > 0:
		HudStyle.ctext(c, at + Vector2(ROW_R, ROW_R + 2.0), str(it["n"]), 10, HudStyle.INK, 3)

## Shield as a fraction of max health (what the bar draws past the end of health).
static func shield_frac(h: Hunter) -> float:
	return clampf(h.shield / maxf(1.0, h.max_hp), 0.0, 1.0)

## Another hunter's plate. `show_name`: Hud's rule (allies always; rivals near, hovered or down).
func draw(H, sp: Vector2, h: Hunter, show_name: bool) -> void:
	if not sp.is_finite() or absf(sp.x) > 20000.0 or absf(sp.y) > 20000.0:
		return
	sp = sp.round()
	var c: CanvasItem = H.c
	var dt: float = H.get_process_delta_time()
	var viewer: Hunter = H.m.player
	var role := HudStyle.role_col(viewer, h)
	var s := _watch(h, dt)
	var w := HudStyle.PLATE_W
	var x0 := sp.x - w * 0.5
	var frame := _frame_rect(x0, sp.y, w)
	if h.downed:
		_downed(H, c, sp, h, frame, s, role)
		return
	var frac := clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
	var ch := chip_of(h, frac, dt)
	var fl := flash_of(h)
	HudStyle.plate_frame(c, frame, Color(role, 0.55), fl)
	var hr := Rect2(Vector2(x0, sp.y + HudStyle.PLATE_PAD), Vector2(w, HudStyle.PLATE_HP_H))
	HudStyle.seg_bar(c, hr, h.hp, h.max_hp, HudStyle.hp_fill(role, frac, H.m.time), ch, shield_frac(h), fl * 0.6)
	var has_ar := _armor(c, h, Rect2(Vector2(x0, hr.end.y + 1.0), Vector2(w, HudStyle.PLATE_AR_H)), s)
	var pop := float(s["lvl_pop"]) / LVL_POP_T
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), h.lvl, role, pop)
	# the name, or what's being done to them (stunned, rooted ...) in its colour
	var sts := statuses(h)
	var word := ""
	var word_col := Color("9ae8ff")
	for x in sts:
		if String(x[2]) != "":
			word = String(x[2])
			word_col = x[1]
			break
	if word != "":
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), word, 12, word_col)
	elif show_name:
		var name_col := Color(role.lerp(Color.WHITE, 0.55), 0.95)
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), h.pname, HudStyle.PLATE_NAME_FS, name_col)
	var items := row(viewer, h, sts)
	draw_row(c, Vector2(frame.end.x + 3.0, frame.get_center().y), items)
	if h.ak and h.ak.tell != "":
		_resource_tell(c, H.m.time, Vector2(x0 + w + 5.0, frame.position.y - 3.0), h)
	shown[h.nid] = {"segs": HudStyle.seg_count(h.max_hp), "armor": has_ar, "shield": h.shield > 0.0, "downed": false,
		"word": word, "chip": ch, "lvl": h.lvl, "lvl_pop": float(s["lvl_pop"]), "row": items}

## An archetype's resource tell, readable from the other side: a glow at half, bright and quick at full.
static func _resource_tell(c: CanvasItem, time: float, at: Vector2, h: Hunter) -> void:
	var rc: Color = h.ak.res_col()
	var full: bool = h.ak.tell == "full"
	var tk := 0.5 + 0.5 * sin(time * (8.0 if full else 3.0))
	if full:
		c.draw_circle(at, 3.0 + 1.5 * tk, Color(rc, 0.5 + 0.4 * tk))
	else:
		c.draw_circle(at, 3.0, Color(rc, 0.45))

## Your own plate over your head: wider, with your health number.
func draw_self(H, sp: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var dt: float = H.get_process_delta_time()
	var s := _watch(p, dt)
	var w := HudStyle.PLATE_W_SELF
	var x0 := sp.x - w * 0.5
	var frame := _frame_rect(x0, sp.y, w)
	var frac := clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var ch := chip_of(p, frac, dt)
	var fl := flash_of(p)
	HudStyle.plate_frame(c, frame, Color(HudStyle.SELF, 0.5), fl)
	var hr := Rect2(Vector2(x0, sp.y + HudStyle.PLATE_PAD), Vector2(w, HudStyle.PLATE_HP_H))
	var fill := HudStyle.hp_fill(HudStyle.SELF, frac, H.m.time)
	HudStyle.seg_bar(c, hr, p.hp, p.max_hp, fill, ch, shield_frac(p), fl * 0.6)
	var has_ar := _armor(c, p, Rect2(Vector2(x0, hr.end.y + 1.0), Vector2(w, HudStyle.PLATE_AR_H)), s)
	HudStyle.text(c, Vector2(frame.end.x + 5.0, hr.end.y + 1.0), str(int(ceil(p.hp))), 13, Color(1, 1, 1, 0.92))
	var pop := float(s["lvl_pop"]) / LVL_POP_T
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), p.lvl, HudStyle.SELF, pop)
	var sts := statuses(p)
	var word := ""
	if not sts.is_empty():
		draw_row(c, Vector2(sp.x, frame.end.y + 18.0), row(p, p, sts), true)
		word = String(sts[0][2])
		if word != "":
			HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), word, 12, sts[0][1])
	shown[p.nid] = {"segs": HudStyle.seg_count(p.max_hp), "armor": has_ar, "shield": p.shield > 0.0, "downed": false,
		"word": word, "chip": ch, "lvl": p.lvl, "lvl_pop": float(s["lvl_pop"])}

static func _frame_rect(x0: float, y: float, w: float) -> Rect2:
	var pad := HudStyle.PLATE_PAD
	var frame_h := HudStyle.PLATE_HP_H + HudStyle.PLATE_AR_H + pad * 2.0 + 1.0
	return Rect2(Vector2(x0 - pad, y), Vector2(w + pad * 2.0, frame_h))

## The armour strip under health: the tier's colour, an empty track once broken (it can come
## back), and a white crack that flies apart the moment it breaks. Returns whether it's drawn.
func _armor(c: CanvasItem, h: Hunter, r: Rect2, s: Dictionary) -> bool:
	if h.max_armor <= 0.5:
		return false
	var col: Color = h.armor_col() if h.armor_tier > 0 or h.armor > 0.5 else HudStyle.ARMOR
	HudStyle.strip(c, r, h.armor / h.max_armor, col)
	var b := float(s["brk"]) / BREAK_T
	if b > 0.0:
		var k := 1.0 - b
		c.draw_rect(r.grow(1.0), Color(1, 1, 1, 0.8 * b))
		var pts := PackedVector2Array()
		for i in 5:
			var x := r.position.x + r.size.x * (0.1 + 0.2 * i)
			var dir := Vector2(-0.6 + 0.3 * i, 1.0 if i % 2 == 0 else -1.0).normalized()
			var a := Vector2(x, r.get_center().y) + dir * (2.0 + 10.0 * k)
			pts.append(a)
			pts.append(a + dir * 4.0)
		c.draw_multiline(pts, Color(col.lerp(Color.WHITE, 0.5), b), 2.0)
	return true

## Every hunter's run level, rivals included, on a badge pinned to the lower-left corner of their
## frame (over where the bars start, so it reads with the health). A rounded tab in the hunter's
## role colour with the number in our display font; it grows into a wider pill at 10+, takes a gold
## rim once their ultimate is open (level 6+), and when they level up it swells, flashes gold and
## throws a gold ring (`pop` 1 -> 0 over LVL_POP_T).
static func level_badge(c: CanvasItem, corner: Vector2, lvl: int, role: Color, pop := 0.0) -> void:
	var ult_open := lvl >= int(Hunter.ULT_AT[0])
	var txt := str(lvl)
	var k := 1.0 - pop
	var sc := 1.0 + 0.45 * sin(k * PI) if pop > 0.0 else 1.0
	var tab_h := 15.0 * sc
	var w := maxf(tab_h, (TextCache.width(HudStyle.BIG, txt, 12) + 7.0) * sc)
	var ctr := corner + Vector2(-w * 0.5 + 6.0, -2.0)
	var r := Rect2(ctr - Vector2(w, tab_h) * 0.5, Vector2(w, tab_h))
	var rim: Color = HudStyle.GOLD if ult_open else role
	if pop > 0.0:
		c.draw_arc(ctr, 9.0 + 22.0 * k, 0, TAU, 28, Color(HudStyle.GOLD, 0.9 * pop), 2.5, true)
		rim = rim.lerp(HudStyle.GOLD, snappedf(pop, 0.25))     # in steps, so only a few style boxes get cached
	var rim_w := 2 if ult_open or pop > 0.0 else 1
	c.draw_style_box(HudStyle.box(HudStyle.SHADE_EDGE, 6, HudStyle.SHADE_EDGE, 0), r.grow(1.5))
	c.draw_style_box(HudStyle.box(Color(role.darkened(0.62), 0.98), 5, rim, rim_w), r)
	var tcol: Color = (HudStyle.GOLD if ult_open else HudStyle.INK).lerp(HudStyle.GOLD, pop)
	HudStyle.ctext(c, ctr + Vector2(0, 4.5 * sc), txt, int(12.0 * sc), tcol, 3)

## A downed hunter's plate: the bleed-out bar (amber, red while being finished), revive progress
## filling over it in green, a cross in place of the level, and what's happening under it. The
## moment a rival goes down a burst of rays and a "DOWN" word pop over them.
func _downed(H, c: CanvasItem, sp: Vector2, h: Hunter, frame: Rect2, s: Dictionary, role: Color) -> void:
	var stomped: bool = h.get_meta("stomped", false)
	var pulse := 0.5 + 0.5 * sin(H.m.time * 14.0)
	var bcol := HudStyle.STOMPED.lerp(Color.WHITE, 0.3 * pulse) if stomped else HudStyle.DOWNED
	var w := frame.size.x - HudStyle.PLATE_PAD * 2.0
	var x0 := frame.position.x + HudStyle.PLATE_PAD
	HudStyle.plate_frame(c, frame, Color(bcol, 0.8))
	var dmax := float(Data.MATCH["down_hp"])
	var bar_h := HudStyle.PLATE_HP_H + HudStyle.PLATE_AR_H + 1.0
	var br := Rect2(Vector2(x0, sp.y + HudStyle.PLATE_PAD), Vector2(w, bar_h))
	HudStyle.seg_bar(c, br, h.down_hp, dmax, bcol, 0.0, 0.0, 0.0, HudStyle.HP_PER_SEG)
	if h.revive > 0.0:
		var rev_w := w * clampf(h.revive, 0.0, 1.0)
		c.draw_rect(Rect2(br.position + Vector2(0, br.size.y - 4.0), Vector2(rev_w, 4.0)), HudStyle.REVIVE)
	var pop := float(s["lvl_pop"]) / LVL_POP_T
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), h.lvl, role, pop)
	var name_col := Color(role.lerp(Color.WHITE, 0.4), 0.9)
	HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), h.pname, HudStyle.PLATE_NAME_FS, name_col)
	var revs: Array = h.get_meta("revivers", [])
	var line := "DOWN"
	var lcol := bcol
	if stomped:
		var sts: Array = h.get_meta("stompers", [])
		line = "STOMPED  ·  %s" % (sts[0] as Hunter).pname if not sts.is_empty() else "STOMPED"
	elif h.revive > 0.0 and not revs.is_empty():
		line = "%s reviving  %d%%" % [(revs[0] as Hunter).pname, int(h.revive * 100.0)]
		lcol = HudStyle.REVIVE
	HudStyle.ctext(c, Vector2(sp.x, frame.end.y + 13.0), line, 11, lcol, 3)
	if H.m.player == null or h.team != H.m.player.team:
		_burst(c, sp + Vector2(0, -26), float(s["burst"]), bcol)      # (a teammate's fall stays quiet: MateAlerts)
	shown[h.nid] = {"segs": HudStyle.seg_count(dmax), "armor": false, "shield": false, "downed": true,
		"word": line, "chip": 0.0, "lvl": h.lvl, "lvl_pop": float(s["lvl_pop"])}

## The knock burst: rays flung outward from a ring, and the word popping in big then settling.
static func _burst(c: CanvasItem, at: Vector2, t: float, col: Color) -> void:
	if t <= 0.0:
		return
	var k := 1.0 - t / BURST_T          # 0 -> 1 over the burst
	var a := clampf(t / (BURST_T * 0.35), 0.0, 1.0)
	var ez := 1.0 - pow(1.0 - minf(1.0, k * 3.0), 3.0)
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * float(i) / 12.0 + 0.13
		var d := Vector2(cos(ang), sin(ang) * 0.75)
		var r0 := 10.0 + 26.0 * ez
		pts.append(at + d * r0)
		pts.append(at + d * (r0 + 8.0 + 6.0 * float(i % 2)))
	c.draw_multiline(pts, Color(col, a), 3.0)
	c.draw_arc(at, 8.0 + 20.0 * ez, 0, TAU, 28, Color(Color.WHITE, 0.6 * a), 2.0, true)
	var sc := 1.0 + 0.6 * (1.0 - minf(1.0, k * 5.0))
	HudStyle.ctext(c, at + Vector2(0, 8.0 * sc), "DOWN", int(22.0 * sc), Color(Color.WHITE.lerp(col, 0.35), a), 6)
