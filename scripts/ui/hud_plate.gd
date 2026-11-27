class_name HudPlate
extends RefCounted
## Overhead plates (one per hunter): the name, the run level on a coin, health in
## fixed-size segments with armour as a thin strip under it and shields as a pale fill past the end
## of health, a chip that holds then drains after a hit, a white flash on the frame when struck, an
## armour-break crack, the status row to the right, and a downed plate with a
## knock burst. Hud owns one of these (hud.plates) and calls draw() / draw_self() per hunter; the
## same chip tracker feeds the mob and boss bars and the squad list (chip_of), and the same status row
## (row, draw_row) sits under monster bars.
## Each plate sits on its own canvas item (Item), moved to the anchor every frame and redrawn only when what it
## shows changed (its key), so a still plate costs a position and a key compare instead of ~40 draw commands.
## Look and sizes: HudStyle. Layout around the anchor `sp` (the point over the head):
##   name .......................... sp.y - 7
##   frame (armour + health) ....... sp.y .. sp.y + PAD*2 + HP_H + 1 + AR_H
##   status row (others) ........... right of the frame, on its vertical centre (row, draw_row)
##   loadout icon row (others) ..... sp.y + HudStyle.PLATE_ICON_ROW, over the name: left free here

const CHIP_HOLD := 0.4  # s the lost chunk stays after the last hit
const CHIP_DRAIN := 1.6  # of the bar per second once it drains (plus an ease-out)
const FLASH_T := 0.14  # s the frame flashes white when struck
const ARMOR_FLASH_T := 0.2  # s the armour strip flashes white after it loses some
const PAIN_T := 1.2  # s a hunter's portrait wears its hurt face after a hit
const CHEER_T := 2.5  # s it wears its excited face after a kill
const BREAK_T := 0.45  # s of the armour-break crack
const TIMER_MIN := 0.5  # s: a status with less left shows no seconds (per-frame holds sit under it)
const BURST_T := 1.1  # s of the knock burst over someone who just went down
const LVL_POP_T := 0.7  # s of the pulse on a plate's level badge when that hunter levels up
const PRUNE_T := 5.0  # s unseen before a hunter's plate state is dropped
const KEY_STEP := 0.2  # a flash or pulse repaints its plate in steps this big (of its 0..1)
const FRAC_STEP := 0.004  # a bar's fraction that must change to repaint: under a pixel of the widest bar
const HP_STEP := 0.5  # health, armour and shield points that must change to repaint
const ROW_MAX := 4  # icons a status row shows at most; the lowest in the order wait
const ROW_R := 8.0  # px radius of a status icon's disc (reads at 1280x720 at the match camera)
const ROW_RING_W := 2.5  # px width of the ring round it that empties with the time left
const ROW_STEP := 2.0 * (ROW_R + ROW_RING_W) + 1.0  # px between two icons' centres
const RING_REFRESH := 0.15  # s the time left must jump up to restart a ring (a re-applied status, not net jitter)
const RING_LAPSE := 0.25  # s a status may go undrawn before its ring starts over when it is seen again
const STOPS := ["status_stunned", "status_rooted", "status_grounded"]  # what stops them: ahead of your marks
## A kit mark's icon -> the plain status it stands in for (Vex's Daze, Cinder's Ablaze): only the mark shows.
const RING_KEY := 0.04  # a status ring repaints its plate in steps this big (of its 0..1)
const MARK_FOR := {"mark_daze": "status_dazed", "fireball": "status_burning"}
const PLATE_OFFSET := 2.35  # m over the feet where a plate sits unless the archetype sets its own
const CLEAR_M := 0.85  # m: anchor over the model's top: the frame's 25 px (1080p) hang + ~11 px of air (~44 px per m up)

## nid -> {chip, hold, frac, armor, flash, brk, down, burst, seen, tot (the status row's ring clocks)}
var st := {}
var now := 0.0
var _prune_at := 0.0
## What the last draw showed for each nid (checks and tools read this): {segs, armor, shield,
## downed, row (the status row's items), chip}
var shown := {}
var _items := {}  # nid -> Item
var _layer: Node2D  # the items' parent, right under Hud.c


## How high over this hunter's feet their plate sits: the archetype's optional `plate_offset` (in its
## content/archetypes JSON, so taller and shorter heroes clear their own heads), else PLATE_OFFSET.
static func plate_offset(h: Hunter) -> float:
	return float(Arch.def(h.arch).get("plate_offset", PLATE_OFFSET))


## `base` m over the feet (before the match's Hunter size, as Hud._head takes it), raised so the plate hangs clear over
## h's tallest point: back props and horns grow with the drawn size, the plate's size on screen does not.
static func up(h: Hunter, base: float) -> float:
	return up_of(h.arch, h.vis_k, base)


## up() for hunter archetype `arch` drawn at model scale `vis_k`.
static func up_of(arch: String, vis_k: float, base: float) -> float:
	return maxf(base, (Arch.top_h(arch) * vis_k + CLEAR_M) / CamRig.match_hunter_scale)


## A rival you can see but who is hiding (crouched, or in tall grass or smoke) shows no plate or hover card: you see a
## body, not who it is or how hurt. Teammates, the downed and the revealed (Hunter.reveal_t) always show.
static func hidden(m: Match, h: Hunter) -> bool:
	if m.player == null or h.team == m.player.team or h.downed:
		return false
	if m.has_meta("pitch_no_foe_plates"):  # the pitch-reel recorder films fights with no text over the foe
		return true
	if h.reveal_t > 0.0:
		return false
	return h.crouch or m.world.in_bush(h.pos.x, h.pos.z) or m.in_smoke(h.pos)


## Advances the clock (Hud._process), hides plates not placed last frame and forgets hunters not drawn for a while.
func tick(dt: float) -> void:
	now += dt
	var last := Engine.get_process_frames() - 1
	for it: Item in _items.values():
		if it.seen < last and it.visible:
			it.visible = false  # (not placed last frame: off screen, hidden or gone)
	if now >= _prune_at:
		_prune_at = now + PRUNE_T
		for k in st.keys():
			if now - float(st[k]["seen"]) > PRUNE_T:
				st.erase(k)
				shown.erase(k)
		for k in _items.keys():
			if now - (_items[k] as Item).seen_at > PRUNE_T:
				(_items[k] as Item).queue_free()
				_items.erase(k)


func _state(e: Ent) -> Dictionary:
	var s: Dictionary = st.get(e.nid, {})
	if s.is_empty():
		s = {
			"chip": 1.0,
			"hold": 0.0,
			"frac": -1.0,
			"armor": -1.0,
			"flash": 0.0,
			"aflash": 0.0,
			"pain": 0.0,
			"cheer": 0.0,
			"kills": -1,
			"brk": 0.0,
			"down": false,
			"burst": 0.0,
			"lvl": -1,
			"lvl_pop": 0.0,
			"seen": now
		}
		st[e.nid] = s
	return s


## The trailing fraction behind `frac` for this entity: it holds CHIP_HOLD after the last drop,
## then drains toward frac; a heal pulls it up at once.
func chip_of(e: Ent, frac: float, dt: float) -> float:
	var s := _state(e)
	if float(s.get("at", -1.0)) == now and now > 0.0:
		return float(s["chip"])  # asked twice in one frame: the squad list and the plate
	s["at"] = now
	s["seen"] = now
	var was := float(s["frac"])
	if was >= 0.0 and frac < was - 0.0005:
		s["hold"] = CHIP_HOLD
		s["flash"] = FLASH_T
		s["pain"] = PAIN_T
	elif was < 0.0:
		s["chip"] = frac
	s["frac"] = frac
	s["hold"] = maxf(0.0, float(s["hold"]) - dt)
	s["flash"] = maxf(0.0, float(s["flash"]) - dt)
	s["pain"] = maxf(0.0, float(s["pain"]) - dt)
	var hunter := e as Hunter
	if hunter:
		if int(s["kills"]) >= 0 and hunter.kills > int(s["kills"]):
			s["cheer"] = CHEER_T
		s["kills"] = hunter.kills
	s["cheer"] = maxf(0.0, float(s["cheer"]) - dt)
	var ch := maxf(float(s["chip"]), frac)
	if float(s["hold"]) <= 0.0:
		var gap := ch - frac
		ch = maxf(frac, ch - dt * (CHIP_DRAIN * 0.5 + gap * 6.0))
	s["chip"] = ch
	return ch


func flash_of(e: Ent) -> float:
	return clampf(float(_state(e)["flash"]) / FLASH_T, 0.0, 1.0)


## The portrait face this hunter wears: "hurt" for a moment after a hit or while nearly down, "excited"
## for a moment after a kill, else "" (neutral).
func mood_of(e: Ent, low: float) -> String:
	var s := _state(e)
	if float(s["pain"]) > 0.0 or low > 0.5:
		return "hurt"
	return "excited" if float(s["cheer"]) > 0.0 else ""


## 1 as the armour strip loses some (a hit on the shell), fading to 0 over ARMOR_FLASH_T.
func armor_flash_of(e: Ent) -> float:
	return clampf(float(_state(e)["aflash"]) / ARMOR_FLASH_T, 0.0, 1.0)


## Watches armour and the downed state for the crack and the knock burst.
func _watch(h: Hunter, dt: float) -> Dictionary:
	var s := _state(h)
	var ar := h.armor
	if float(s["armor"]) > 0.5 and ar <= 0.5 and h.max_armor > 0.5:
		s["brk"] = BREAK_T
	if ar < float(s["armor"]) - 0.01:
		s["aflash"] = ARMOR_FLASH_T
	s["aflash"] = maxf(0.0, float(s["aflash"]) - dt)
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
	var hunter := e as Hunter
	var held := hunter != null and hunter.ak != null and hunter.ak.holds_still()  # her own hold, not a root
	if e.stun_t > 0.0:
		out.append(["status_stunned", BodyTell.STUN_COL, "STUNNED", e.stun_t])
	if e.root_t > 0.0 and not held:
		out.append(["status_rooted", BodyTell.ROOT_COL, "ROOTED", e.root_t])
	if KitStatus.grounded(e):
		out.append(["status_grounded", KitStatus.GROUND_COL, "GROUNDED", KitStatus.grounded_left(e)])
	if KitStatus.rattled(e):
		out.append(["status_dazed", KitStatus.RATTLE_COL, "DAZED", KitStatus.rattled_left(e)])
	if e.slow_t > 0.0:
		out.append(["status_slowed", BodyTell.SLOW_COL, "SLOWED", e.slow_t])
	if e.burn_t > 0.0:
		out.append(["status_burning", Color("ff9a5a"), "BURNING", -1.0])
	if hunter and hunter.weak_t > 0.0:
		out.append(["status_weakened", Color("ffb36a"), "WEAKENED", hunter.weak_t])
	if hunter and hunter.shield > 0.0:
		out.append(["status_shielded", Color("d8ecff"), "", -1.0])
	if e.guard_t > 0.0:
		out.append(["status_guarded", Color("f2e6cf"), "", -1.0])
	return out


## The status row `viewer` sees on `e`, at most ROW_MAX, each {icon, col, left, total, n}: what stops them (stun,
## root, Ground), then the combo state their attackers put on them (ArchKit.combo_read for the viewer and then each
## squadmate; the Boki setups the viewer made), then the rest of `sts` (statuses(e)). A mark takes the place of the
## plain status it stands in for (MARK_FOR). A status's ring runs over the longest time left seen since it went on.
func row(viewer: Hunter, e: Ent, sts: Array) -> Array:
	var marks: Array = []
	if viewer:
		for o in (viewer.m as Match).hunters:
			if o != e and o.ak and (o == viewer or (o.team == viewer.team and not o.out)):
				var d: Dictionary = o.ak.combo_read(e)
				if not d.is_empty():
					marks.append(
						{
							"icon": d["icon"],
							"col": o.ak.res_col(),
							"left": float(d["left"]),
							"total": float(d["total"]),
							"n": int(d["n"])
						}
					)
		for id in e.marks:  # a combo setup this hunter or its Boki put on them (Combos)
			var setup: Dictionary = e.marks[id]
			var left := float(setup["until"]) - float(viewer.m.time)
			if setup["owner"] == viewer and left > 0.0:
				marks.append(
					{"icon": "bond", "col": HudStyle.GOLD, "left": left, "total": float(setup["window"]), "n": 0}
				)
	if sts.is_empty() and marks.is_empty():
		return []
	var s := _state(e)
	s["seen"] = now
	var tot: Dictionary = s.get("tot", {})  # icon -> Vector3(ring total, time left, plate clock) last drawn
	s["tot"] = tot
	var out: Array = []
	for stops in [true, false]:
		for x in sts:
			var replaced := marks.any(func(mk): return MARK_FOR.get(mk["icon"], "") == x[0])
			if (x[0] in STOPS) == stops and not replaced:
				out.append(_status_item(x, tot))
		if stops:
			out.append_array(marks)
	out.resize(mini(out.size(), ROW_MAX))
	return out


func _status_item(x: Array, tot: Dictionary) -> Dictionary:
	var left := float(x[3])
	return {"icon": x[0], "col": x[1], "left": left, "total": _ring_total(tot, String(x[0]), left), "n": 0}


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


## What a repaint of a status row hangs on: each icon, its colour, its stack count and its ring in RING_KEY steps.
static func _row_key(items: Array) -> Array:
	var out := []
	for it in items:
		var left := float(it["left"])
		var ring := -1.0 if left < 0.0 else snappedf(left / maxf(0.05, float(it["total"])), RING_KEY)
		out.append([it["icon"], it["col"], it["n"], ring])
	return out


## Draws a status row (from row()) from `at`, its left end at the vertical centre, or centred on `at`.
static func draw_row(c: CanvasItem, at: Vector2, items: Array, centred := false) -> void:
	var left_end := at.x - (items.size() * ROW_STEP - 1.0) * 0.5 if centred else at.x
	var x := left_end + ROW_R + ROW_RING_W
	for it in items:
		_row_icon(c, Vector2(x, at.y), it)
		x += ROW_STEP


## One status: its icon on a dark disc, a ring in its colour emptying with the time left (whole and faint with no
## clock), and the stack count at the lower right.
static func _row_icon(c: CanvasItem, at: Vector2, it: Dictionary) -> void:
	var col: Color = it["col"]
	var ring_r := ROW_R + ROW_RING_W * 0.5
	c.draw_circle(at, ROW_R + ROW_RING_W + 1.0, HudStyle.SHADE)
	var left := float(it["left"])
	if left < 0.0:
		c.draw_arc(at, ring_r, 0.0, TAU, 24, Color(col, 0.45), ROW_RING_W, true)
	else:
		var frac := clampf(left / maxf(0.05, float(it["total"])), 0.0, 1.0)
		c.draw_arc(at, ring_r, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, col, ROW_RING_W, true)
	Icons.draw(c, String(it["icon"]), at, ROW_R * 0.6, col)
	if int(it["n"]) > 0:
		HudStyle.ctext(c, at + Vector2(ROW_R, ROW_R + 2.0), str(it["n"]), 10, HudStyle.INK, 3)


## Does a status icon show its seconds left under it? Not with no time, nor under TIMER_MIN: a zone or hold
## that tops its timer up every frame would sit at a stray "0.2", and a real countdown that low reads nothing.
static func shows_time(secs: float) -> bool:
	return secs >= TIMER_MIN


## Shield as a fraction of max health (what the bar draws past the end of health).
static func shield_frac(h: Hunter) -> float:
	return clampf(h.shield / maxf(1.0, h.max_hp), 0.0, 1.0)


## A 0..1 pulse of `rate` rad/s, in KEY_STEP steps.
static func _wave(time: float, rate: float) -> float:
	return snappedf(0.5 + 0.5 * sin(time * rate), KEY_STEP)


## The item for `nid`, shown and moved to `sp` (whole pixels). Repainted by the caller when its key changed.
func _place(h_v, nid, sp: Vector2) -> Item:
	if _layer == null or not is_instance_valid(_layer):
		_layer = Node2D.new()
		h_v.add_child(_layer)
		h_v.move_child(_layer, h_v.c.get_index())  # (under Hud.c: its crosshair, tips and numbers stay on top)
	var it: Item = _items.get(nid)
	if it == null:
		it = Item.new()
		it.draw.connect(_paint.bind(it))
		_layer.add_child(it)
		_items[nid] = it
	it.seen = Engine.get_process_frames()
	it.seen_at = now
	it.position = sp
	if not it.visible:
		it.visible = true
	return it


func _paint(it: Item) -> void:
	TextCache.world = true  # plates hang on the world over each head: their text keeps its design size
	var a: Dictionary = it.args
	if not is_instance_valid(a["h"]):
		return
	if a["self"]:
		_paint_self(it, a)
	elif (a["h"] as Hunter).downed:
		_downed(it, a)
	else:
		_paint_plate(it, a)
	TextCache.world = false


## Another hunter's plate. `show_name`: Hud's rule (allies always; rivals near, hovered or down).
func draw(h_v, sp: Vector2, h: Hunter, show_name: bool) -> void:
	SafeArea.note_as("plate", Rect2(sp - LabelClash.PLATE, LabelClash.PLATE * 2.0))
	if not sp.is_finite() or absf(sp.x) > 20000.0 or absf(sp.y) > 20000.0:
		return
	var dt: float = h_v.get_process_delta_time()
	var time: float = h_v.m.time
	var role := HudStyle.role_col(h_v.m.player, h)
	var s := _watch(h, dt)
	var frac := clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
	var ch := 0.0 if h.downed else chip_of(h, frac, dt)
	var items := [] if h.downed else row(h_v.m.player, h, statuses(h))
	var tell: bool = h.ak != null and h.ak.tell != ""
	var beat := 0.0  # a pulse (downed plate, resource tell, low health) in KEY_STEP steps
	if h.downed:
		beat = _wave(time, 14.0)
	elif tell:
		beat = _wave(time, 8.0 if h.ak.tell == "full" else 3.0)
	elif frac < 0.3:
		beat = _wave(time, 9.0)
	var key := [
		h.downed,
		role,
		h.lvl,
		h.pname,
		h.clan_tag,
		show_name,
		_row_key(items),
		snappedf(h.hp, HP_STEP),
		h.max_hp,
		snappedf(h.armor, HP_STEP),
		h.max_armor,
		h.armor_tier,
		snappedf(h.shield, HP_STEP),
		snappedf(ch, FRAC_STEP),
		snappedf(flash_of(h), KEY_STEP),
		snappedf(armor_flash_of(h), KEY_STEP),
		s["brk"],
		s["lvl_pop"],
		LevelGap.of(h_v.m.player, h),
		beat,
		s["burst"],
		h.revive,
		h.down_hp
	]
	var it := _place(h_v, h.nid, sp.round())
	if key != it.key:
		it.key = key
		it.args = {
			"self": false, "h": h, "m": h_v.m, "role": role, "show_name": show_name, "row": items, "ch": ch, "s": s
		}
		it.queue_redraw()


func _paint_plate(c: CanvasItem, a: Dictionary) -> void:
	var h: Hunter = a["h"]
	var m: Match = a["m"]
	var role: Color = a["role"]
	var s: Dictionary = a["s"]
	var sp := Vector2.ZERO
	var w := HudStyle.PLATE_W
	var x0 := sp.x - w * 0.5
	var frame := _frame_rect(x0, sp.y, w)
	var frac := clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
	var ch: float = a["ch"]
	var fl := flash_of(h)
	HudStyle.plate_frame(c, frame, Color(role, 0.55), fl)
	var ar := Rect2(Vector2(x0, sp.y + HudStyle.PLATE_PAD), Vector2(w, HudStyle.PLATE_AR_H))  # armour above health
	var hr := Rect2(Vector2(x0, ar.end.y + 1.0), Vector2(w, HudStyle.PLATE_HP_H))
	var fill := HudStyle.hp_fill(HudStyle.plate_fill(role), frac, m.time)
	HudStyle.seg_bar(c, hr, h.hp, h.max_hp, fill, ch, shield_frac(h), fl * 0.6)
	var has_ar := _armor(c, h, ar, s)
	var pop := float(s["lvl_pop"]) / LVL_POP_T
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), h.lvl, role, pop, LevelGap.of(m.player, h))
	# the name; what's being done to them is the status row beside the plate (no word; the body shows it too)
	if a["show_name"]:
		var name_col := Color(role.lerp(Color.WHITE, 0.55), 0.95)
		var nm := ClanInfo.tagged(h.pname, h.clan_tag)
		HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), nm, HudStyle.PLATE_NAME_FS, name_col)
	var items: Array = a["row"]
	draw_row(c, Vector2(frame.end.x + 3.0, frame.get_center().y), items)
	if h.ak and h.ak.tell != "":
		_resource_tell(c, m.time, Vector2(x0 + w + 5.0, frame.position.y - 3.0), h)
	shown[h.nid] = {
		"segs": HudStyle.seg_count(h.max_hp),
		"armor": has_ar,
		"shield": h.shield > 0.0,
		"downed": false,
		"row": items,
		"chip": ch,
		"lvl": h.lvl,
		"lvl_pop": float(s["lvl_pop"])
	}


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
func draw_self(h_v, sp: Vector2, p: Hunter) -> void:
	var dt: float = h_v.get_process_delta_time()
	var s := _watch(p, dt)
	var frac := clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var ch := chip_of(p, frac, dt)
	var items := row(p, p, statuses(p))
	var key := [
		snappedf(p.hp, HP_STEP),
		ceili(p.hp),
		p.max_hp,
		snappedf(p.armor, HP_STEP),
		p.max_armor,
		p.armor_tier,
		snappedf(p.shield, HP_STEP),
		p.lvl,
		snappedf(ch, FRAC_STEP),
		snappedf(flash_of(p), KEY_STEP),
		snappedf(armor_flash_of(p), KEY_STEP),
		s["brk"],
		s["lvl_pop"],
		_row_key(items),
		_wave(h_v.m.time, 9.0) if frac < 0.3 else 0.0
	]
	var it := _place(h_v, p.nid, sp)
	if key != it.key:
		it.key = key
		it.args = {"self": true, "h": p, "m": h_v.m, "ch": ch, "s": s, "row": items}
		it.queue_redraw()


func _paint_self(c: CanvasItem, a: Dictionary) -> void:
	var p: Hunter = a["h"]
	var m: Match = a["m"]
	var s: Dictionary = a["s"]
	var sp := Vector2.ZERO
	var w := HudStyle.PLATE_W_SELF
	var x0 := sp.x - w * 0.5
	var frame := _frame_rect(x0, sp.y, w)
	var frac := clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var ch: float = a["ch"]
	var fl := flash_of(p)
	HudStyle.plate_frame(c, frame, Color(SideColor.you(), 0.5), fl)
	var ar := Rect2(Vector2(x0, sp.y + HudStyle.PLATE_PAD), Vector2(w, HudStyle.PLATE_AR_H))  # armour above health
	var hr := Rect2(Vector2(x0, ar.end.y + 1.0), Vector2(w, HudStyle.PLATE_HP_H))
	var fill := HudStyle.hp_fill(HudStyle.plate_fill(SideColor.you()), frac, m.time)
	HudStyle.seg_bar(c, hr, p.hp, p.max_hp, fill, ch, shield_frac(p), fl * 0.6)
	var has_ar := _armor(c, p, ar, s)
	HudStyle.text(c, Vector2(frame.end.x + 5.0, hr.end.y + 1.0), HudStyle.num(ceili(p.hp)), 13, Color(1, 1, 1, 0.92))
	var pop := float(s["lvl_pop"]) / LVL_POP_T
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), p.lvl, SideColor.you(), pop)
	var items: Array = a["row"]
	draw_row(c, Vector2(sp.x, frame.end.y + 18.0), items, true)
	shown[p.nid] = {
		"segs": HudStyle.seg_count(p.max_hp),
		"armor": has_ar,
		"shield": p.shield > 0.0,
		"downed": false,
		"row": items,
		"chip": ch,
		"lvl": p.lvl,
		"lvl_pop": float(s["lvl_pop"])
	}


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
	HudStyle.strip(c, r, h.armor / h.max_armor, col.lerp(Color.WHITE, armor_flash_of(h)))
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
## throws a gold ring (`pop` 1 -> 0 over LVL_POP_T). A rival's `gap` (their level minus the viewer's, LevelGap)
## of 2+ either way tints the tab and adds a triangle.
static func level_badge(c: CanvasItem, corner: Vector2, lvl: int, role: Color, pop := 0.0, gap := 0) -> void:
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
		rim = rim.lerp(HudStyle.GOLD, snappedf(pop, 0.25))  # in steps, so only a few style boxes get cached
	var rim_w := 2 if ult_open or pop > 0.0 else 1
	c.draw_style_box(HudStyle.box(HudStyle.SHADE_EDGE, 6, HudStyle.SHADE_EDGE, 0), r.grow(1.5))
	var band := LevelGap.band(gap)
	var fill := Color(role.darkened(0.62), 0.98) if band == 0 else LevelGap.tint(gap)
	c.draw_style_box(HudStyle.box(fill, 5, rim, rim_w), r)
	var tcol: Color = (HudStyle.GOLD if ult_open else HudStyle.INK).lerp(HudStyle.GOLD, pop)
	if band != 0:
		LevelGap.draw_cue(c, r, gap)
		tcol = Color(0.08, 0.05, 0.02) if band > 0 else Color.WHITE
	HudStyle.ctext(c, ctr + Vector2(0, 4.5 * sc), txt, int(12.0 * sc), tcol, 3)


## A downed hunter's plate: the bleed-out bar (amber, red while being finished), revive progress
## filling over it in green, a cross in place of the level, and what's happening under it. The
## moment a rival goes down a burst of rays pops over them.
func _downed(c: CanvasItem, a: Dictionary) -> void:
	var h: Hunter = a["h"]
	var m: Match = a["m"]
	var s: Dictionary = a["s"]
	var role: Color = a["role"]
	var sp := Vector2.ZERO
	var frame := _frame_rect(sp.x - HudStyle.PLATE_W * 0.5, sp.y, HudStyle.PLATE_W)
	var stomped: bool = h.get_meta("stomped", false)
	var pulse := 0.5 + 0.5 * sin(m.time * 14.0)
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
	level_badge(c, Vector2(frame.position.x + 2.0, frame.end.y - 1.0), h.lvl, role, pop, LevelGap.of(m.player, h))
	var name_col := Color(role.lerp(Color.WHITE, 0.4), 0.9)
	HudStyle.ctext(c, Vector2(sp.x, sp.y - 6), ClanInfo.tagged(h.pname, h.clan_tag), HudStyle.PLATE_NAME_FS, name_col)
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
	if m.player == null or h.team != m.player.team:
		_burst(c, sp + Vector2(0, -26), float(s["burst"]), bcol)  # (a teammate's fall stays quiet: MateAlerts)
	shown[h.nid] = {
		"segs": HudStyle.seg_count(dmax),
		"armor": false,
		"shield": false,
		"downed": true,
		"word": line,
		"chip": 0.0,
		"lvl": h.lvl,
		"lvl_pop": float(s["lvl_pop"])
	}


## The knock burst: rays flung outward from a ring (no word: the plate itself shows the fall).
static func _burst(c: CanvasItem, at: Vector2, t: float, col: Color) -> void:
	if t <= 0.0:
		return
	var k := 1.0 - t / BURST_T  # 0 -> 1 over the burst
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


## One plate's canvas: moved to its anchor each frame (Node2D transform), repainted by `_paint` when `key` changes.
class Item:
	extends Node2D
	var key: Array = []
	var args := {}  # what the paint needs besides the live hunter (h, role, word, chip ...)
	var seen := -1  # the process frame it was last placed
	var seen_at := 0.0  # HudPlate.now then (pruned after PRUNE_T)
