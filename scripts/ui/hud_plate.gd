class_name HudPlate
extends RefCounted
## Overhead plates (one per hunter), in the leaning look of the owner's 11-12 reference: the name or a
## status word, the run level on a badge at the frame's lower left, health in a handful of segments
## with armour as a thin strip over it and shields as a strip under it, a chip that holds then drains
## after a hit, a white flash on the frame when struck, an armour-break crack, status tiles at the
## right end, and a downed plate with a knock burst. Hidden while the viewer is aboard the skyship.
## Hud owns one of these (hud.plates) and calls draw() / draw_self() per hunter; the
## same chip tracker feeds the mob and boss bars and the squad list (chip_of).
## Look and sizes: HudStyle. Layout around the anchor `sp` (the point over the head):
##   name / status word ............ sp.y - 7
##   frame (armour, health, shield) . sp.y .. sp.y + HudStyle.plate_h(), leaning HudStyle.LEAN_K
##   status tiles .................. right of the frame, top level with it
##   loadout icon row (others) ..... sp.y + HudStyle.PLATE_ICON_ROW and down: left free here

const CHIP_HOLD := 0.4         # s the lost chunk stays after the last hit
const CHIP_DRAIN := 1.6        # of the bar per second once it drains (plus an ease-out)
const FLASH_T := 0.14          # s the frame flashes white when struck
const BREAK_T := 0.45          # s of the armour-break crack
const BURST_T := 1.1           # s of the knock burst over someone who just went down
const LVL_POP_T := 0.7        # s of the pulse on a plate's level badge when that hunter levels up
const PRUNE_T := 5.0           # s unseen before a hunter's plate state is dropped
const PLATE_OFFSET := 2.35     # m over the feet where a plate sits unless the archetype sets its own

## nid -> {chip, hold, frac, armor, flash, brk, down, burst, seen}
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

## Status tiles in a row of leaning tiles, the first with its top-left at `at`; a status with time
## left shows it under its tile.
static func icon_row(c: CanvasItem, at: Vector2, icons: Array) -> void:
	var w := HudStyle.PLATE_TILE_W
	var h := HudStyle.PLATE_TILE_H
	var x := at.x
	for ic in icons:
		var pts := HudStyle.slant_pts(Vector2(x, at.y), w, h)
		c.draw_colored_polygon(pts, HudStyle.SHADE)
		pts.append(pts[0])
		c.draw_polyline(pts, Color(ic[1], 0.8), 1.0)
		var mid := Vector2(x + (w - HudStyle.LEAN_K * h) * 0.5, at.y + h * 0.5)
		Icons.draw(c, String(ic[0]), mid, w * 0.33, ic[1])
		if float(ic[3]) > 0.0:
			var under := Vector2(mid.x - HudStyle.LEAN_K * h * 0.5, at.y + h + 9.0)
			HudStyle.ctext(c, under, "%.1f" % float(ic[3]), 10, ic[1])
		x += w + 2.0

## Shield as a fraction of max health (what the bar draws past the end of health).
static func shield_frac(h: Hunter) -> float:
	return clampf(h.shield / maxf(1.0, h.max_hp), 0.0, 1.0)

## Another hunter's plate. `show_name`: Hud's rule (allies always; rivals near, hovered or down).
func draw(H, sp: Vector2, h: Hunter, show_name: bool) -> void:
	if not sp.is_finite() or absf(sp.x) > 20000.0 or absf(sp.y) > 20000.0 or (H.m.player != null and H.m.player.riding):
		return
	sp = sp.round()
	var c: CanvasItem = H.c
	var dt: float = H.get_process_delta_time()
	var role := HudStyle.role_col(H.m.player, h)
	var s := _watch(h, dt)
	var f := _frame_at(sp, HudStyle.PLATE_W)
	if h.downed:
		_downed(H, c, sp, h, f, s, role)
		return
	var frac := clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
	var ch := chip_of(h, frac, dt)
	var has_ar := _bars(c, f, HudStyle.PLATE_W, h, role, H.m.time, ch, s)
	var sts := statuses(h)
	var worded := _worded(sts)
	var word := "" if worded.is_empty() else String(worded[2])
	if word != "":
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), word, 12, worded[1])
	elif show_name:
		var name_col := Color(role.lerp(Color.WHITE, 0.55), 0.95)
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), h.pname, HudStyle.PLATE_NAME_FS, name_col)
	_tiles(c, f, HudStyle.PLATE_W, sts)
	if h.ak and h.ak.tell != "":
		_resource_tell(c, H.m.time, Vector2(f.x + HudStyle.PLATE_W + HudStyle.PLATE_PAD * 2.0 + 5.0, f.y - 3.0), h)
	_shown(h, has_ar, word, ch, s)

## An archetype's resource tell, readable from the other side: a glow at half, bright and quick at full.
static func _resource_tell(c: CanvasItem, time: float, at: Vector2, h: Hunter) -> void:
	var rc: Color = h.ak.res_col()
	var full: bool = h.ak.tell == "full"
	var tk := 0.5 + 0.5 * sin(time * (8.0 if full else 3.0))
	if full:
		c.draw_circle(at, 3.0 + 1.5 * tk, Color(rc, 0.5 + 0.4 * tk))
	else:
		c.draw_circle(at, 3.0, Color(rc, 0.45))

## Your own plate over your head: the same frame in your colour, a touch narrower (the vitals
## bottom-left carry the number). Hud skips it while you ride the skyship.
func draw_self(H, sp: Vector2, p: Hunter) -> void:
	var c: CanvasItem = H.c
	var dt: float = H.get_process_delta_time()
	var s := _watch(p, dt)
	var f := _frame_at(sp, HudStyle.PLATE_W_SELF)
	var ch := chip_of(p, clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0), dt)
	var has_ar := _bars(c, f, HudStyle.PLATE_W_SELF, p, HudStyle.SELF, H.m.time, ch, s)
	var sts := statuses(p)
	var worded := _worded(sts)
	var word := "" if worded.is_empty() else String(worded[2])
	if word != "":
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), word, 12, worded[1])
	_tiles(c, f, HudStyle.PLATE_W_SELF, sts)
	_shown(p, has_ar, word, ch, s)

## The worst status that has a word for the slot over the plate: [icon, colour, word, left], or [].
static func _worded(sts: Array) -> Array:
	for x in sts:
		if String(x[2]) != "":
			return x
	return []

## Top-left of the plate's leaning frame for a bar `w` wide, centred on the anchor `sp`.
static func _frame_at(sp: Vector2, w: float) -> Vector2:
	var pad := HudStyle.PLATE_PAD
	return Vector2(sp.x - (w + pad * 2.0 - HudStyle.LEAN_K * HudStyle.plate_h()) * 0.5, sp.y)

## Top-left of a bar row `yo` px below the frame's top: it follows the lean.
static func _row(f: Vector2, yo: float) -> Vector2:
	return Vector2(f.x + HudStyle.PLATE_PAD - HudStyle.LEAN_K * yo, f.y + yo)

## The frame and its three rows for a living hunter; returns whether the armour strip is drawn.
func _bars(c: CanvasItem, f: Vector2, w: float, h: Hunter, role: Color, time: float, chip: float,
		s: Dictionary) -> bool:
	var fl := flash_of(h)
	HudStyle.plate_frame(c, f, w, Color(role, 0.55), fl)
	var pad := HudStyle.PLATE_PAD
	var hp_y := pad + HudStyle.PLATE_AR_H + 1.0
	var frac := clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
	var hp_at := _row(f, hp_y)
	HudStyle.slant_bar(c, hp_at, w, HudStyle.PLATE_HP_H, h.hp, h.max_hp, HudStyle.hp_fill(role, frac, time),
		h.max_hp / float(segs(h.max_hp)), chip)
	if fl > 0.0:
		HudStyle.slant(c, hp_at, w, HudStyle.PLATE_HP_H, Color(1, 1, 1, 0.33 * fl))
	if h.shield > 0.0:
		var sh_at := _row(f, hp_y + HudStyle.PLATE_HP_H + 1.0)
		HudStyle.slant(c, sh_at, w * shield_frac(h), HudStyle.PLATE_SH_H, HudStyle.SHIELD_BAR)
	_badge(c, f, h, role, s)
	return _armor(c, h, _row(f, pad), w, s)

## The level badge on the frame's lower-left corner.
static func _badge(c: CanvasItem, f: Vector2, h: Hunter, role: Color, s: Dictionary) -> void:
	var corner := Vector2(f.x - HudStyle.LEAN_K * HudStyle.plate_h() + 2.0, f.y + HudStyle.plate_h() - 1.0)
	level_badge(c, corner, h.lvl, role, float(s["lvl_pop"]) / LVL_POP_T)

## Status tiles at the frame's right end (top level with it).
static func _tiles(c: CanvasItem, f: Vector2, w: float, sts: Array) -> void:
	if not sts.is_empty():
		icon_row(c, Vector2(f.x + w + HudStyle.PLATE_PAD * 2.0 + 2.0, f.y), sts)

## What the last draw showed for this hunter (`shown`).
func _shown(h: Hunter, has_ar: bool, word: String, chip: float, s: Dictionary) -> void:
	shown[h.nid] = {"segs": segs(h.max_hp), "armor": has_ar, "shield": h.shield > 0.0, "downed": false,
		"word": word, "chip": chip, "lvl": h.lvl, "lvl_pop": float(s["lvl_pop"])}

## Segments on a plate's health bar: one per 25 health, at most PLATE_MAX_SEGS.
static func segs(max_hp: float) -> int:
	return mini(HudStyle.seg_count(max_hp), HudStyle.PLATE_MAX_SEGS)

## The armour strip over health: the tier's colour, an empty track once broken (it can come
## back), and a white crack that flies apart the moment it breaks. `at` is its top-left, `w` its
## length. Returns whether it's drawn.
func _armor(c: CanvasItem, h: Hunter, at: Vector2, w: float, s: Dictionary) -> bool:
	if h.max_armor <= 0.5:
		return false
	var ah := HudStyle.PLATE_AR_H
	var col: Color = h.armor_col() if h.armor_tier > 0 or h.armor > 0.5 else HudStyle.ARMOR
	HudStyle.slant(c, at, w, ah, Color(col.darkened(0.75), 0.85))
	HudStyle.slant(c, at, w * clampf(h.armor / h.max_armor, 0.0, 1.0), ah, col)
	var b := float(s["brk"]) / BREAK_T
	if b > 0.0:
		var k := 1.0 - b
		var r := Rect2(at, Vector2(w, ah))
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
func _downed(H, c: CanvasItem, sp: Vector2, h: Hunter, f: Vector2, s: Dictionary, role: Color) -> void:
	var stomped: bool = h.get_meta("stomped", false)
	var pulse := 0.5 + 0.5 * sin(H.m.time * 14.0)
	var bcol := HudStyle.STOMPED.lerp(Color.WHITE, 0.3 * pulse) if stomped else HudStyle.DOWNED
	var w := HudStyle.PLATE_W
	var pad := HudStyle.PLATE_PAD
	var bar_h := HudStyle.plate_h() - pad * 2.0
	HudStyle.plate_frame(c, f, w, Color(bcol, 0.8))
	var br := _row(f, pad)
	var dmax := float(Data.MATCH["down_hp"])
	HudStyle.slant_bar(c, br, w, bar_h, h.down_hp, dmax, bcol, HudStyle.HP_PER_SEG)
	if h.revive > 0.0:
		var rev_at := br + Vector2(-HudStyle.LEAN_K * (bar_h - 4.0), bar_h - 4.0)
		HudStyle.slant(c, rev_at, w * clampf(h.revive, 0.0, 1.0), 4.0, HudStyle.REVIVE)
	_badge(c, f, h, role, s)
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
	HudStyle.ctext(c, Vector2(sp.x, sp.y + HudStyle.plate_h() + 13.0), line, 11, lcol, 3)
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
