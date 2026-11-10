extends CanvasLayer
## In-match interface, drawn every frame: health, ability bar, kin card, timer, minimap, kill feed,
## kin speech bubbles, callout pings, interaction prompts, crosshair and the scoreboard.

var m: Match
var c: Control
var panels: HudPanels
var cursor: Control
var big: Font = preload("res://fonts/LilitaOne-Regular.ttf")
var body: Font = preload("res://fonts/Rubik.ttf")
var hit_t := 0.0
var plates := HudPlate.new()     # overhead plates' chip, flash, armour-break and knock state
var hit_crit := false
var hurt_t := 0.0
var msgs := MsgLane.new()      # every short message on screen: toasts, level-ups, hints
var minimap: ImageTexture
var map_paint: Texture2D = null   # the painted map (MapPaint), when it's ready

## The map picture to draw, and its pixels per tile (for regions given in tiles).
func map_tex() -> Texture2D:
	return map_paint if map_paint else minimap

func map_region(tiles: Rect2) -> Rect2:
	var t := map_tex()
	var k := Vector2(float(t.get_width()) / m.world.w, float(t.get_height()) / m.world.h)
	return Rect2(tiles.position * k, tiles.size * k)
var kit_t0 := 0.0

const INK := Color("f3eee2")
const MUTED := Color("a9b0bf")
const PANEL := Color(0.06, 0.07, 0.1, 0.72)
const EDGE := Color(1, 1, 1, 0.08)
const GOOD := Color("8fe0a0")
const BAD := Color("ff6a5a")
const GOLD := Color("f2c84a")

func setup(match_node: Match) -> void:
	m = match_node
	layer = 5
	Record.hide_in_cinema(self)      # recording mode with the HUD hidden
	panels = HudPanels.make(self)       # the fixed panels, under c, redrawn 20 times a second
	add_child(panels)
	c = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.draw.connect(_draw_all)
	add_child(msgs)
	abyss_fx = ABYSS_FX.new()      # (movefeel) the abyss closing in: under the HUD, local player only
	add_child(abyss_fx)
	# the pointer over the item windows: drawn above them (the crosshair lives under them on `c`,
	# and the system cursor stays hidden in a match, so without this you can't see where you click)
	cursor = Control.new()
	cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.z_index = 100
	add_child(cursor)
	cursor.draw.connect(_draw_pointer)
	RankClick.attach(self)      # the gold + on a rankable slot takes a click
	await _build_minimap()
	# the painted map (smooth coasts, shading, paths) replaces the tile texture once it's baked
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	await m._slice()      # under the loading screen: a frame now and then (never waits otherwise)
	MapPaint.request(self, m.world, func(t: Texture2D): map_paint = t)
	await m._slice()
	full_map = FullMap.new(self, m)

# ------------------------------------------------------------------ the full map (M)
var full_map: FullMap

func map_open() -> bool:
	return full_map != null and full_map.is_open

## Expeditions only: the tutorial, training and the duel room keep their own screens.
func map_allowed() -> bool:
	return not (m.opts.get("tutorial", false) or m.opts.get("training", false) or m.opts.get("duel", false))

func open_map(by_plan := false) -> void:
	if map_allowed() and full_map:
		full_map.open(by_plan)

func close_map() -> void:
	if full_map:
		full_map.close()

func _unhandled_input(event: InputEvent) -> void:
	if full_map and full_map.input(event):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if full_map and full_map.is_open and full_map.auto and not (m.skydrop and m.skydrop.planning):
		full_map.close()      # the ship's off: the planning map steps aside
	_tick_wheel()
	hit_t = maxf(0.0, hit_t - delta)
	_hud_tick(delta)
	plates.tick(delta)
	panels.tick(delta)
	flash_t = maxf(0.0, flash_t - delta * 4.0)
	hurt_t = maxf(0.0, hurt_t - delta)
	_place_msgs()
	_clear_under_toasts(delta)
	c.queue_redraw()
	cursor.queue_redraw()

var hit_armor := false

func hitmarker(crit: bool, armor := false) -> void:
	hit_t = 0.14
	hit_crit = crit
	hit_armor = armor

var flash_t := 0.0
var flash_col := Color.WHITE
## A full-screen flash for big moments.
func flash(col: Color, strength := 0.35) -> void:
	flash_col = Color(col, strength)
	flash_t = 1.0

func hurt_flash(d: float) -> void:
	hurt_t = clampf(0.25 + d / 60.0, 0.25, 0.6)

## The message lane sits under the ally alerts (they take its first rows), or in the tutorial's own
## lane while that runs (Tutorial holds it while its banner is up).
func _place_msgs() -> void:
	msgs.visible = not map_open()
	msgs.reserved = alerts.size()
	msgs.top = 84.0 + alerts_h
	if m.tut: TutorialHud.place_msgs(msgs, c.size)

## The lairs' name boards in the world (Label3D over each gate) fade back while a message prints over
## them, so two lines of text never overlap on screen; they come back as it goes.
func _clear_under_toasts(delta: float) -> void:
	if m == null or m.lairs == null or m.cam == null:
		return
	var rects := msgs.rects()
	for L in m.lairs.list:
		var lnodes = L.get("nodes")
		var lbl = lnodes.get("label") if lnodes is Dictionary else null
		if lbl is Label3D and is_instance_valid(lbl):
			MsgLane.yield_label(lbl, m.cam, rects, delta)

## A message in the lane (MsgLane).
func toast(text: String, col: Color) -> void:
	msgs.push(text, col)

## A first-time hint, in the lane for longer (Match._tip says each once).
func tip(text: String) -> void:
	if not Record.clean():
		msgs.push(text, TIP_COL, MsgLane.NORMAL, TIP_LIFE)
const TIP_COL := Color("f3e6c8")
const TIP_LIFE := 6.0      # s a hint stays up

func _build_minimap() -> void:
	var w := m.world
	var img := Image.create(w.w, w.h, false, Image.FORMAT_RGBA8)
	for z in w.h:
		await m._slice()
		for x in w.w:
			var i := w.idx(x, z)
			var col := Color(0, 0, 0, 0)
			if w.kind[i] == World.T_GROUND:
				col = Color(w._bio(i)["top"]).lightened(0.12 + 0.08 * mini(w.level[i], 4))
				if w.level[i] >= 8: col = col.lightened(0.35)      # a high perch: brighter, and marked
				# authored maps: grabbable rims pale, sheer cliffs dark, so the map shows where you can climb
				if w.sheer.has(i): col = Color("6a6488")
				elif w.lip.has(i): col = Color("e6d6ae")
			elif w.kind[i] == World.T_BLOCK:
				col = Color(w.biome["top2"]).darkened(0.2)
			img.set_pixel(x, z, col)
	minimap = ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ drawing helpers
## Panel styles are made once per look and reused (the HUD draws dozens of panels every frame).
var _boxes := {}
func _box(col: Color, rad: int, border: Color, bw: int, aa := false) -> StyleBoxFlat:
	var key := [col, rad, border, bw, aa]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		if _boxes.size() > 512: _boxes.clear()
		sb = StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(rad)
		if bw > 0:
			sb.border_color = border
			sb.set_border_width_all(bw)
		sb.anti_aliasing = aa
		_boxes[key] = sb
	return sb

func _panel(r: Rect2, col := PANEL, rad := 10) -> void:
	SafeArea.note(r)
	c.draw_style_box(_box(col, rad, EDGE, 1, true), r)

func _bar(r: Rect2, frac: float, col: Color, back := Color(0, 0, 0, 0.45)) -> void:
	c.draw_rect(r, back)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)

func _text(p: Vector2, s: String, size := 15, col := INK, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font if font else body
	if align == HORIZONTAL_ALIGNMENT_LEFT and width < 0.0:
		TextCache.draw(c, f, p, s, size, col, 4)       # shaped once, kept while the text stays the same (item 94)
		return
	c.draw_string_outline(f, p, s, align, width, size, 4, Color(0, 0, 0, 0.55))
	c.draw_string(f, p, s, align, width, size, col)

func _ctext(p: Vector2, s: String, size := 15, col := INK, font: Font = null) -> void:
	var f := font if font else body
	var w := TextCache.width(f, s, size)
	_text(Vector2(p.x - w * 0.5, p.y), s, size, col, f)

func _arc(center: Vector2, radius: float, frac: float, col: Color, width := 3.0) -> void:
	if frac <= 0.0: return
	c.draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * clampf(frac, 0.0, 1.0), 40, col, width, true)

func _fmt(t: float) -> String:
	t = maxf(0.0, t)
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

# ------------------------------------------------------------------ frame
var hover_spots: Array = []     # [rect, id] for things on the HUD you can point at
var hover_id := ""
var hover_t := 0.0

func _draw_all() -> void:
	var sz := c.size
	var p := m.player
	if m.tut and m.tut.intro:
		TutorialHud.draw(self, sz)      # the intro card alone: the rest of the HUD waits
		return
	_draw_world_labels()
	_draw_bubbles()
	_draw_pings(sz)
	if hurt_t > 0.0:
		var a := hurt_t * 0.9
		for i in 6:
			var inset := i * 14.0
			c.draw_rect(Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0), Color(0.8, 0.1, 0.08, a * (0.12 - i * 0.018)), false, 14.0)
	# abyss danger [footage]: sinking below island level darkens the screen from the edges with a cold
	# tint, more the closer you get to the kill depth and the emptier your glider; near the bottom it
	# pulses red with a quickening heartbeat. It fades away as you climb back up or catch an updraft.
	# (movefeel) measured against the real point of no return (Hunter.abyss_kill_y, via AbyssFx.danger)
	# instead of a guess 14m down, and much stronger: the screen shader drains, darkens and reddens the
	# picture and closes a vignette in; here the rings, the heartbeat, a low rumble and a pulsing
	# warning near the end
	var want_a: float = ABYSS_FX.danger(p) if p == m.player else 0.0
	if want_a <= 0.02:
		abyss_cued = false
	if want_a <= 0.7:
		abyss_warned = false
	abyss_a = lerpf(abyss_a, want_a, 1.0 - exp(-10.0 * get_process_delta_time()))
	if abyss_fx:
		abyss_fx.show_danger(abyss_a, pow(0.5 + 0.5 * sin(abyss_pulse * TAU), 3.0) if abyss_a > 0.005 else 0.0)
	if abyss_a > 0.005:
		var red := clampf((abyss_a - 0.55) / 0.45, 0.0, 1.0)     # (AbyssFx: ~0.55 just under the lip, 1 at the end)
		var rate := 1.6 + red * 3.4
		abyss_pulse += get_process_delta_time() * rate
		var pulse := pow(0.5 + 0.5 * sin(abyss_pulse * TAU), 3.0)
		# (the magenta wash itself is AbyssFx's shader) near the end, crimson edges beat with the heart
		var ek := clampf((abyss_a - 0.75) / 0.25, 0.0, 1.0)
		for i in 6:
			var inset := i * minf(sz.x, sz.y) * 0.03
			var a := ek * (0.22 - float(i) * 0.035) * (0.6 + 0.4 * pulse)
			if a <= 0.0: break
			c.draw_rect(Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0), Color(0.45, 0.02, 0.18, a), false, minf(sz.x, sz.y) * 0.035)
		# (owner) an audio cue: a falling whoosh as the tint starts, a warning when it turns deep red
		if p == m.player and abyss_a > 0.08 and not abyss_cued:
			abyss_cued = true
			Sfx.play("whoosh", null, -6.0, 0.0, 0.55)
		if p == m.player and abyss_a > 0.85 and not abyss_warned:
			abyss_warned = true
			Sfx.play("warn", null, -4.0, 0.0, 0.8)
		if abyss_a > 0.1 and p == m.player:
			var beat := int(floor(abyss_pulse))
			if beat != abyss_beat:
				abyss_beat = beat
				Sfx.play("thump", null, -12.0 + abyss_a * 14.0, 0.0, 0.7 + red * 0.15)
				if red > 0.3 and beat % 2 == 0:
					Sfx.play("boom", null, -24.0 + red * 10.0, 0.0, 0.35)     # a low rumble under the heartbeat
		if abyss_a > 0.8 and p == m.player:
			# the point of no return is close: say so, pulsing, in the middle of the screen
			var wk := clampf((abyss_a - 0.8) / 0.15, 0.0, 1.0)
			var txt := "HOLD GLIDE TO LIFT" if p.glide_fuel > 0.001 and not p.gliding else ("CLIMB OUT" if p.glide_fuel > 0.001 else "HOLD GLIDE: HALF LIFT, IT BURNS")
			_ctext(Vector2(sz.x * 0.5, sz.y * 0.36), txt, 26, Color(1.0, 0.25 + 0.35 * pulse, 0.2, 0.55 + 0.45 * wk * (0.5 + 0.5 * pulse)), big)
	if p and not p.downed and not p.out and p.hp < p.max_hp * 0.35:
		var pulse := 0.5 + 0.5 * sin(m.time * 6.0)
		for i in 5:
			var inset := i * 16.0
			c.draw_rect(Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0), Color(0.75, 0.05, 0.05, (0.09 - i * 0.016) * (0.6 + pulse * 0.4)), false, 16.0)
	if flash_t > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(flash_col, flash_col.a * flash_t * (0.3 if Settings.get_v("reduce_flashes") else 1.0)))
	if p and (p.out or p.downed) and m.killcam_text != "":
		_ctext(Vector2(sz.x * 0.5, maxf(sz.y * 0.22, msgs.bottom() + 30.0)), m.killcam_text, 22, Color("ff9a8a"), big)
	if p and not m.duel:
		_draw_alerts(sz, p)
	else:
		alerts_h = 0.0
	for dk in BokiHud.squad_downed(m):
		BokiHud.downed_arrow(self, dk, sz)
	if p and not p.out and not p.extracted:
		_draw_overhead(p)
		_draw_glider_heat(p)
	if p:
		_draw_hurt_dirs(sz)
		if not p.riding:
			_draw_kit(sz, p)
		elif not map_open():
			_draw_ship_prompt(sz)
		if p.dropping and not map_open():
			_draw_drop_prompt(sz, p)
		if not p.riding and not map_open():
			_draw_squad_pings(p)
		if not p.riding:
			_draw_prompt(sz, p)
			if m.lairs and not p.out and not map_open():
				_draw_lair_dial(sz, p)
			if not map_open() and not mouse_on_panel(): _draw_crosshair(p)
		if p.downed:
			_draw_downed(sz, p)
		elif p.out and not p.gone and not m.result.get("ending", false):
			_draw_dead(sz, p)
	if Input.is_action_pressed("scores"):
		_draw_scores(sz)
	if wheel_open:
		_draw_wheel()
	if p and not p.out and not p.extracted and not map_open():
		_draw_hover_tip(sz, p)
		if hover_id == "":
			_draw_world_hover(sz, p)
	if map_open():
		full_map.draw(sz)
	elif m.skydrop and m.skydrop.planning and p:
		# the planning map was closed: a reminder of the countdown, and how to get it back
		_ctext(Vector2(sz.x * 0.5, 40), "The ship sets off in %ds  ·  %s opens the map" % [int(ceil(m.skydrop.plan_t)), Settings.key_cap("map")], 18, GOLD, big)

func _draw_world_labels() -> void:
	var cam := m.cam
	LabelCull.begin()        # (item 94: anything off screen or far away isn't laid out)
	ReviveHud.world_labels(self)       # deathboxes and revive beacons
	BondHud.draw(self)       # whoever carries your Boki: an arrow to them; and the Tracked chip if that is you
	# the tutorial's marker: a pin over what to go to, or an arrow at the screen edge, with the distance
	if m.tut and m.tut.target != Vector3.INF and m.player and not m.player.out:
		_draw_waypoint(m.tut.target, m.tut.label, Color("8fe3c8").lerp(Color.WHITE, 0.6 if m.tut.flash_t > 0.0 and int(Time.get_ticks_msec() / 150.0) % 2 == 0 else 0.0))
	_draw_exit_labels()
	_draw_lair_labels()
	_draw_truce_marks()
	_draw_wisp_rings()
	for h in m.hunters:
		if h == m.player or h.out or h.extracted or not h.model or not (h.model.visible or HunterWisp.hides(h)) or h.unseen:
			continue
		if cam.is_position_behind(h.position):
			continue
		var sp := LabelCull.at(self, _head(h, HudPlate.plate_offset(h)))
		if not sp.is_finite():
			continue
		LabelCull.mark(h)
		_nameplate(sp, h)
		if not h.downed: GripOverhead.draw(self, sp, h)      # their two gloves and Boki type, under the plate
		BokiHud.form_overhead(self, sp, h)
	if m.player and not m.player.out and m.player.model and not cam.is_position_behind(m.player.position):
		var own_head := m.player.position + Vector3(0, HudPlate.plate_offset(m.player), 0)
		BokiHud.form_overhead(self, cam.unproject_position(own_head), m.player)
	# someone basing to a teammate: a ring filling round them, and a marker on where they'll appear
	for h in m.hunters:
		if h.base_t <= 0.0 or h.out or (h.unseen and h != m.player) or cam.is_position_behind(h.position):
			continue
		var bsp: Vector2 = cam.unproject_position(h.position + Vector3(0, 0.2, 0))
		var bf: float = 1.0 - h.base_t / Hunter.BASE_TIME
		c.draw_arc(bsp, 26.0, 0, TAU, 40, Color(0.56, 0.89, 0.78, 0.25), 3.0, true)
		_arc(bsp, 26.0, bf, Color("8fe3c8"), 4.0)
		_ctext(bsp + Vector2(0, 44), "BASING  %.1f" % h.base_t, 12, Color("8fe3c8"), big)
		var to: Hunter = h.base_to
		if to and is_instance_valid(to) and not cam.is_position_behind(to.position):
			var tsp := cam.unproject_position(to.position + Vector3(0, 3.0, 0))
			_ctext(tsp, "%s incoming" % h.pname.substr(0, 10), 12, Color("8fe3c8"), big)
			c.draw_arc(cam.unproject_position(to.position + Vector3(0, 0.1, 0)), 22.0, 0, TAU, 32, Color(0.56, 0.89, 0.78, 0.4 + 0.3 * sin(m.time * 8.0)), 2.0, true)
	for mb in m.mobs:
		if mb.dead or not mb.visible or cam.is_position_behind(mb.position):
			continue
		var hy := 1.4
		if mb is Blight: hy = 3.0 if mb.mkind == "bl_warden" else 1.1
		if mb is Boss: hy = 4.8 if mb.mkind == "colossus" else 3.4
		elif mb.mkind == "ward": hy = 3.0
		elif mb.mkind == "brute": hy = 2.4
		elif mb.mkind == "warden": hy = 3.4
		var sp := LabelCull.at(self, mb.position + Vector3(0, hy, 0))
		if not sp.is_finite():
			continue
		LabelCull.mark(mb)
		if mb.stagger_t > 0.0:
			_ctext(sp + Vector2(0, -12), "STAGGERED", 18, Color("fff27a"), big)
		elif mb.stag_open > 0.0:
			var a := 0.75 + 0.25 * sin(m.time * 12.0)
			_ctext(sp + Vector2(0, -12), "STAGGERABLE", 17, Color(0.85, 0.6, 1.0, a), big)
		# compact bar; rare and mutated monsters (mb.rarity, mb.mutations) wear a tinted frame and
		# little icons for their mutations, and always show their bar
		var rare: bool = int(mb.rarity) > 0 or not mb.mutations.is_empty()
		if mb is Boss:
			if not (mb as Boss).dormant and m.lairs.boss_for(m.player) != mb:
				_ctext(sp + Vector2(0, -26), String(mb.md["name"]), 15, Lairs.color_of((mb as Boss).lair), big)
				_bar(Rect2(sp + Vector2(-50, -18), Vector2(100, 7)), clampf(mb.hp / mb.max_hp, 0.0, 1.0), Color("ff6a5a"))
			continue
		if mb.hp < mb.max_hp or rare:
			var bw := 64.0 if mb.mkind in ["brute", "warden"] else 48.0
			var br := Rect2(sp + Vector2(-bw * 0.5, 0), Vector2(bw, 6))
			var bfrac := clampf(mb.hp / mb.max_hp, 0.0, 1.0)
			if rare:
				var rc: Color = Data.RARITY[clampi(int(mb.rarity), 0, Data.RARITY.size() - 1)]["color"]
				_rounded(br.grow(3.0), Color(0, 0, 0, 0), 5, rc, 2)
				var mx: float = sp.x - mb.mutations.size() * 7.0 + 7.0
				for mu in mb.mutations:
					c.draw_circle(Vector2(mx, sp.y - 8), 6.0, Color(0.03, 0.03, 0.05, 0.85))
					Icons.draw(c, String(mu.get("icon", "burst")) if mu is Dictionary else String(mu), Vector2(mx, sp.y - 8), 3.6, rc)
					mx += 14.0
			var ct := _chip_of(mb, bfrac)
			_bar(br, bfrac, Color("e0b0ff") if mb.stagger_t > 0.0 else Color("ff8a6a"))
			if ct > bfrac:
				c.draw_rect(Rect2(br.position + Vector2(bw * bfrac, 0), Vector2(bw * (ct - bfrac), 6)), Color(1.0, 0.95, 0.88, 0.8))
			_status_row(sp + Vector2(0, 16), mb)
	# gear and tunings on the ground: name and rarity when you're close enough to care. Tags that would overlap one
	# already drawn this frame step up above it, so a few drops side by side stay readable.
	var pp: Vector3 = m.player.pos if m.player else cam.focus
	var tags: Array = []
	for wp in m.wpicks:
		var wpos: Vector3 = wp["pos"]
		if Vector2(wpos.x - pp.x, wpos.z - pp.z).length() > 7.0 or cam.is_position_behind(wpos):
			continue
		var r: Dictionary = Data.RARITY[clampi(int(wp["rar"]), 0, Data.RARITY.size() - 1)]
		var sp := cam.unproject_position(wpos + Vector3(0, 1.45, 0))
		var is_gear: bool = wp.has("gear") and Gear.ALL.has(String(wp["gear"]))
		var is_tune: bool = wp.has("tune") and Data.PERKS.has(String(wp["tune"]))
		var it := {} if (is_gear or is_tune) else Pack.ground_item(wp)
		var nm := String(Loot.name_of(Pack.ground_item(wp))) if is_gear else (String(Data.PERKS[String(wp["tune"])]["name"]) if is_tune else Loot.name_of(it))
		var tw := TextCache.width(big, nm, 16) + 10.0
		var tag := Rect2(sp + Vector2(-tw * 0.5, -16.0), Vector2(tw, 32.0 if (is_gear or is_tune) else 20.0))
		for tries in 4:
			var bumped := false
			for o in tags:
				if (o as Rect2).intersects(tag):
					bumped = true
					tag.position.y = (o as Rect2).position.y - tag.size.y - 2.0
			if not bumped:
				break
		sp.y += tag.position.y - (sp.y - 16.0)
		tags.append(tag)
		if is_gear:
			# a piece of gear: its name, rarity and which slot it goes in
			_ctext(sp, nm, 15, r["color"], big)
			_ctext(sp + Vector2(0, 14), Gear.slot_name(String(wp["gear"])) + ((" · %s / %s" % [Gloves.key_cap(0), Gloves.key_cap(1)]) if Gear.active(String(wp["gear"])) else ""), 11, Color(INK, 0.75))
		elif is_tune:
			var pd: Dictionary = Data.PERKS[String(wp["tune"])]
			_ctext(sp, nm, 15, pd["col"], big)
			_ctext(sp + Vector2(0, 14), "weapon upgrade · walk over it", 11, Color(INK, 0.75))
		else:
			_ctext(sp, nm, 16, Loot.col_of(it), big)
	for k in m.kins:
		if k.dead or not k.visible or k.state == "shoulder" or cam.is_position_behind(k.position):
			continue
		var sp := LabelCull.at(self, k.position + Vector3(0, 1.05, 0))
		if not sp.is_finite():
			continue
		LabelCull.mark(k)
		if k.is_wild():
			if k.state == "dazed":
				CaptureHud.dazed_label(self, k, sp)       # knocked out: how to scan it, and the scan filling
			else:
				_ctext(sp + Vector2(0, -10), "Wild %s" % Data.KIN[k.species]["name"], 16, Color("bfe9ff"), big)
				_bar(Rect2(sp + Vector2(-24, -2), Vector2(48, 5)), k.hp / k.max_hp, Color("bfe9ff"))
		elif k.state == "downed" and k.owner_h and m.player and k.team == m.player.team:
			BokiHud.downed_label(self, k, sp)
		elif k.hp < k.max_hp:
			_bar(Rect2(sp + Vector2(-22, 0), Vector2(44, 5)), k.hp / k.max_hp, SideColor.of(m, k))
			c.draw_rect(Rect2(sp + Vector2(-22, 0), Vector2(44 * k.hp / k.max_hp, 5)), Color(KinRegen.MOTE_COL, KinRegen.pulse(k, m.time)))

func _draw_bubbles() -> void:
	if m.tut and m.tut.card_up():
		return        # (one voice at a time: the tutorial banner is up)
	var cam := m.cam
	for b in m.bubbles:
		if not is_instance_valid(b["ent"]):
			continue
		var k: Kin = b["ent"]
		if k.dead:
			continue
		var at := k.bubble_at()
		if cam.is_position_behind(at):
			continue
		var sp := cam.unproject_position(at)
		# (off screen: skip. Far-off points project to tens of thousands of pixels, where the tail's small
		# triangle loses its area to float rounding and errors "triangulation failed" every frame)
		if not (is_finite(sp.x) and is_finite(sp.y)) or not c.get_viewport_rect().grow(240.0).has_point(sp):
			continue
		var a := clampf((float(b.get("life", 2.6)) - b["t"]) * 3.0, 0.0, 1.0) * clampf(b["t"] * 8.0, 0.0, 1.0)
		var s: String = b["text"]
		var tw := body.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, BokiSpeech.MATCH_PX).x
		var r := Rect2(sp + Vector2(-tw * 0.5 - 12, -44), Vector2(tw + 24, 30))
		var mine: bool = k.owner_h == m.player
		var col := Color(0.98, 0.96, 0.9, 0.95 * a) if mine else Color(0.2, 0.22, 0.3, 0.85 * a)
		var sb := StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(12)
		c.draw_style_box(sb, r)
		c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-7, -15), sp + Vector2(7, -15), sp + Vector2(0, -6)]), col)
		c.draw_string(body, r.position + Vector2(12, 20), s, HORIZONTAL_ALIGNMENT_LEFT, -1, BokiSpeech.MATCH_PX, Color(0.1, 0.09, 0.12, a) if mine else Color(INK, a))

func _draw_pings(sz: Vector2) -> void:
	var cam := m.cam
	for p in m.pings:
		if p.has("by") or p.has("kin"):
			continue        # squad pings and Boki callouts get a waypoint instead (see _draw_squad_pings)
		var a := clampf(4.0 - p["t"], 0.0, 1.0)
		var col := Color(p["col"], a)
		var at: Vector3 = p["pos"] + Vector3(0, 1.0, 0)
		var on := cam.on_screen(at)
		if on:
			var sp := cam.unproject_position(at)
			var pulse := 1.0 + sin(p["t"] * 8.0) * 0.15
			c.draw_arc(sp, 14 * pulse, 0, TAU, 24, col, 3.0, true)
			c.draw_circle(sp, 4, col)
		else:
			var center := sz * 0.5
			var sp := cam.unproject_position(at)
			if cam.is_position_behind(at):
				sp = center - (sp - center)
			var d := (sp - center).normalized()
			var edge := center + d * minf(sz.x * 0.46 / maxf(absf(d.x), 0.001), sz.y * 0.44 / maxf(absf(d.y), 0.001))
			var n := Vector2(-d.y, d.x)
			c.draw_colored_polygon(PackedVector2Array([edge + d * 14, edge - d * 8 + n * 10, edge - d * 8 - n * 10]), col)

func _draw_top(sz: Vector2) -> void:
	if m.duel:
		_draw_duel(sz)
		return
	if m.opts.get("arena", false):
		return        # the Arena draws its own key line and meter (scripts/match/arena.gd)
	if m.opts.get("training", false):
		if Record.clean():
			return      # (recording: no training banner or checklist)
		var rr := Rect2(Vector2(sz.x * 0.5 - 220, 12), Vector2(440, 54))
		_panel(rr, Color(0.06, 0.07, 0.1, 0.88), 12)
		_ctext(Vector2(sz.x * 0.5, 34), "TRAINING AREA", 12, Color("8fe3c8"))
		_ctext(Vector2(sz.x * 0.5, 56), "Nothing can hurt you here  ·  Esc to leave", 15, INK)
		# the checklist: only what's left (up to six), with a count; H folds it away
		var all_rows: Array = m.train_rows()
		var left: Array = all_rows.filter(func(t): return not m.train.has(t[0]))
		var n_done := all_rows.size() - left.size()
		if guide_hidden:
			var pill := Rect2(Vector2(sz.x - 196, 16), Vector2(180, 30))
			_panel(pill, Color(0.06, 0.07, 0.1, 0.8), 10)
			_text(pill.position + Vector2(12, 20), "Guide %d/%d  ·  H to show" % [n_done, all_rows.size()], 13, MUTED)
			return
		var shown: Array = left.slice(0, 6)
		var box := Rect2(Vector2(sz.x - 346, 16), Vector2(330, 58 + maxi(1, shown.size()) * 24))
		_panel(box, Color(0.06, 0.07, 0.1, 0.82), 12)
		_text(box.position + Vector2(14, 24), "Try everything", 15, GOLD, big)
		_text(box.position + Vector2(box.size.x - 120, 24), "%d / %d done" % [n_done, all_rows.size()], 12, MUTED)
		if shown.is_empty():
			_text(box.position + Vector2(14, 50), "All done. Try the duel room!", 13, GOOD)
		for i in shown.size():
			var t: Array = shown[i]
			var key := ("[%s]  " % Settings.key_cap(t[2])) if t[2] != "" else ""
			if t[0] == "move": key = "[%s%s%s%s]  " % [Settings.key_cap("up"), Settings.key_cap("left"), Settings.key_cap("down"), Settings.key_cap("right")]
			_text(box.position + Vector2(14, 50 + i * 24), ("→  " if i == 0 else "○  ") + key + String(t[1]), 13, GOLD if i == 0 else INK)
		_text(box.position + Vector2(14, box.size.y - 10), "H hides the guide and your kit", 11, Color(MUTED, 0.8))
		return
	if m.tut:
		TutorialHud.draw(self, sz)
		return
	# top right, as in Supervive: squads left, your kills, your knocks, your gems
	var teams := {}
	for h in m.hunters:
		if not h.out and not h.extracted: teams[h.team] = true
	var cells := [["paw", str(teams.size()), INK], ["knock", str(m.player.kills if m.player else 0), Color("ff9a8a")],
		["burst", str(m.player.knocks if m.player else 0), Color("ffd27a")], ["gem", str(m.player.gems if m.player else 0), GOLD]]
	var cw := 58.0
	var cr := Rect2(Vector2(sz.x - 18 - cw * cells.size(), 18), Vector2(cw * cells.size(), 34))
	_rounded(cr, Color(0.04, 0.05, 0.08, 0.86), 8)
	for i in cells.size():
		var cx := cr.position.x + cw * i
		Icons.draw(c, String(cells[i][0]), Vector2(cx + 17, cr.position.y + 17), 7.0, Color(cells[i][2], 0.85))
		_text(Vector2(cx + 28, cr.position.y + 23), String(cells[i][1]), 15, cells[i][2], big)
		if i > 0: c.draw_line(Vector2(cx, cr.position.y + 7), Vector2(cx, cr.end.y - 7), Color(1, 1, 1, 0.1), 1.0)
	feed_top = cr.end.y + 10.0

## The duel room: what you're up against at the top, and your numbers on the right.
func _draw_duel(sz: Vector2) -> void:
	var d: Duel = m.duel
	var rr := Rect2(Vector2(sz.x * 0.5 - 260, 12), Vector2(520, 58))
	_panel(rr, Color(0.06, 0.07, 0.1, 0.88), 12)
	_ctext(Vector2(sz.x * 0.5, 32), "DUEL ROOM  ·  ROUND %d" % d.round_n, 12, Color("ff9a8a"))
	_ctext(Vector2(sz.x * 0.5, 56), "%s bot  ·  %s class  ·  %s  ·  %s  ·  %s" % [d.pick_text("diff"), d.pick_text("cls"), d.pick_text("weapon"), d.pick_text("glove") if d.glove != "" else "no glove", d.pick_text("mode")], 15, INK)
	if guide_hidden or Record.clean():
		return
	var st: Dictionary = d.stats
	var shots := maxi(1, int(st["shots"]))
	var rows := [
		["Damage dealt", "%d" % int(st["dealt"]), GOOD],
		["Damage taken", "%d" % int(st["taken"]), Color("ff8a7a")],
		["Shots landed", "%d / %d  (%d%%)" % [int(st["hits"]), int(st["shots"]), int(round(100.0 * int(st["hits"]) / shots)) if int(st["shots"]) > 0 else 0], INK],
		["Shots dodged", "%d / %d" % [int(st["dodged"]), int(st["bot_shots"])], Color("9af0ff")],
		["Knocks", "%d  -  %d" % [int(st["knocks"]), int(st["knocked"])], GOLD],
	]
	var box := Rect2(Vector2(sz.x - 286, 16), Vector2(270, 40 + rows.size() * 24 + 28))
	_panel(box, Color(0.06, 0.07, 0.1, 0.82), 12)
	_text(box.position + Vector2(14, 24), "Your numbers", 15, GOLD, big)
	for i in rows.size():
		var y := box.position.y + 50 + i * 24
		_text(Vector2(box.position.x + 14, y), String(rows[i][0]), 13, MUTED)
		_text(Vector2(box.position.x + 140, y), String(rows[i][1]), 14, rows[i][2], big)
	var keys_at := Vector2(box.position.x + 14, box.end.y - 12)
	_text(keys_at, "B bot setup  ·  Backspace reset  ·  G hide", 11, Color(MUTED, 0.85))

var feed_top := 18.0
## The kill feed under the counters: each line a banner plate, red when it's about an enemy squad's
## loss you caused, blue for your own side, gold for everything else.
func _draw_feed(sz: Vector2) -> void:
	var y := feed_top
	var mine: Array = []
	if m.player:
		for h in m.hunters:
			if h.team == m.player.team: mine.append(h.pname)
	for f in m.feed:
		var a := clampf(6.0 - f["t"], 0.0, 1.0)
		var s: String = f["text"]
		var w := big.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var ours := false; var first := ""
		for nm in mine:
			var at := s.find(String(nm))
			if at >= 0 and (first == "" or at < s.find(first)): first = String(nm)
		ours = first != "" and s.begins_with(first)
		var col := Color("5fb6ff") if ours else (Color("ff6a5a") if first != "" else GOLD)
		var br := Rect2(Vector2(sz.x - 18 - w - 26, y), Vector2(w + 26, 24))
		_rounded(br, Color(0.04, 0.05, 0.08, 0.82 * a), 6)
		c.draw_rect(Rect2(br.position, Vector2(4, br.size.y)), Color(col, a))
		_text(br.position + Vector2(14, 17), s, 13, Color(INK, a), big)
		y += 28

func _draw_minimap(sz: Vector2) -> void:
	var riding: bool = m.player != null and (m.player.riding or m.player.dropping)
	var s := minf(340.0, sz.y * 0.44) if riding else 196.0      # (the big drop map leaves room under it for the squad)
	var r := Rect2(Vector2(18, 18), Vector2(s, s))
	mm_bottom = r.end.y
	SafeArea.note(r)
	var w := m.world
	var inner := Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 16))
	if riding:
		mm_circ = Vector3.ZERO
		_panel(r, Color(0.05, 0.06, 0.09, 0.78), 12)
	else:
		# on the ground the map is a disc, as in Supervive, with a rim and a north tick
		inner = Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10))
		mm_circ = Vector3(r.get_center().x, r.get_center().y, inner.size.x * 0.5)
		c.draw_circle(r.get_center(), s * 0.5 + 2.0, Color(0.02, 0.02, 0.04, 0.9))
		c.draw_circle(r.get_center(), inner.size.x * 0.5, Color(0.07, 0.07, 0.14, 0.92))
	# riding in or dropping: the whole map. On the ground: a close view that follows you.
	var view := Rect2(Vector2.ZERO, Vector2(w.w, w.h))
	if not riding and m.player:
		var R := 34.0
		view = Rect2(Vector2(m.player.pos.x, m.player.pos.z) - Vector2(R, R), Vector2(R, R) * 2.0)
	var k := inner.size.x / view.size.x
	var to_map := func(p3: Vector3) -> Vector2:
		return inner.position + (Vector2(p3.x, p3.z) - view.position) * k
	var on_map := func(v: Vector2, pad := 0.0) -> bool:
		return _mm_has(inner, v, pad)
	var tex_view := view.intersection(Rect2(Vector2.ZERO, Vector2(w.w, w.h)))
	if mm_circ.z > 0.0:
		# the map texture drawn into a disc: a fan of points round the rim, each with its map UV
		var pts := PackedVector2Array(); var uvs := PackedVector2Array()
		var tsz := Vector2(w.w, w.h)
		var ctr := Vector2(mm_circ.x, mm_circ.y)
		for i in 56:
			var a := TAU * i / 56.0
			var sp := ctr + Vector2(cos(a), sin(a)) * mm_circ.z
			pts.append(sp)
			uvs.append((view.position + (sp - inner.position) / k) / tsz)
		c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, map_tex())
	elif tex_view.size.x > 0.0 and tex_view.size.y > 0.0:
		var dest := Rect2(inner.position + (tex_view.position - view.position) * k, tex_view.size * k)
		c.draw_texture_rect_region(map_tex(), dest, map_region(tex_view))
	_draw_map_labels(w, inner, view, k, riding)
	if m.skytrain:
		_draw_map_train(inner, view, k)
	# your view cone, faintly
	if m.player and not riding:
		var pp: Vector2 = to_map.call(m.player.pos)
		var ad: Vector2 = m.player.aim_dir()
		var a0 := atan2(ad.y, ad.x)
		var pts := PackedVector2Array([pp])
		for i in 13:
			var a := a0 - 0.93 + 1.86 * i / 12.0
			var e := pp + Vector2(cos(a), sin(a)) * m.view_range() * k
			pts.append(Vector2(clampf(e.x, inner.position.x, inner.end.x), clampf(e.y, inner.position.y, inner.end.y)))
		c.draw_colored_polygon(pts, Color(1, 1, 1, 0.07))
	if m.exits:
		for x in m.exits.list:
			var pv: Vector2 = to_map.call(x.get("berth", x["pos"]))
			var busy: bool = String(x["state"]) in ["called", "boarding", "charging", "open"]
			if not on_map.call(pv, 4.0):
				# off the map: an arrow for the loud ones (a called skiff, a charging uplink, an open lift)
				if busy and x["kind"] != "hatch": _edge_arrow(inner, inner.get_center(), pv, Exits.color_of(x))
				continue
			_draw_exit_icon(pv, x, 1.0 if not riding else 0.8)
	if m.lairs:
		_draw_map_lairs(inner, to_map, on_map, riding)
	ReviveHud.minimap(self, inner, to_map, on_map)
	if m.spawn_plan and full_map and m.player:
		# this match's spawns your squad knows are there (vaults from the start; the rest once scouted)
		for cnd in m.spawn_plan.cands:
			if m.spawn_plan.state_for(cnd, m.player.team) != "active":
				continue
			var cpv: Vector2 = to_map.call(cnd["pos"])
			if on_map.call(cpv, 5.0):
				var cdef: Dictionary = m.spawn_plan.cats.get(cnd["cat"], {})
				full_map.marker(c, String(cdef.get("shape", "star")), cpv, 4.5 if riding else 4.0, cdef.get("col", Color.WHITE), "active")
	if not m.ship.is_empty() and not m.ship.get("gone", false):
		var sa: Vector2 = to_map.call(m.ship["a"]); var sb: Vector2 = to_map.call(m.ship["b"])
		c.draw_line(sa, sb, Color(1, 1, 1, 0.35), 2.0, true)
		c.draw_circle(to_map.call(m.ship_pos()), 5.0, GOLD)
	if m.rolling:
		# the other drop waves' skyships (amber), and hunters with a bounty on them (seen by everyone)
		for ws in m.ships:
			if ws.get("gone", false) or ws.get("node") == null:
				continue
			var wp: Vector2 = to_map.call(m.ship_pos_of(ws))
			if on_map.call(wp, 3.0):
				var wa: Vector2 = to_map.call(ws["a"]); var wb: Vector2 = to_map.call(ws["b"])
				c.draw_line(wa, wb, Color(1.0, 0.72, 0.35, 0.3), 1.5, true)
				c.draw_circle(wp, 4.5, Color("ffb64a"))
			else:
				_edge_arrow(inner, inner.get_center(), wp, Color("ffb64a"))
		for h in m.hunters:
			if m.player and h.team == m.player.team or not h.has_meta("bounty") or h.out or h.extracted:
				continue
			var bp: Vector2 = to_map.call(h.pos)
			if on_map.call(bp, 3.0): bounty_marker(c, bp, 0.85)
			else: _edge_arrow(inner, inner.get_center(), bp, Color("ffb64a"))
	if m.tut and m.tut.target != Vector3.INF:
		var tv: Vector2 = to_map.call(m.tut.target)
		if on_map.call(tv, 4.0): c.draw_arc(tv, 6.0, 0, TAU, 16, Color("8fe3c8"), 2.5, true)
		else: _edge_arrow(inner, inner.get_center(), tv, Color("8fe3c8"))
	for pg in m.pings:
		if pg.has("team") and m.player and int(pg["team"]) != m.player.team:
			continue        # another squad's ping
		var pv: Vector2 = to_map.call(pg["pos"])
		if on_map.call(pv):
			if pg.has("by") or pg.has("kin"):
				# a squad ping: a little pin in the pinger's colour
				c.draw_colored_polygon(PackedVector2Array([pv, pv + Vector2(-4, -7), pv + Vector2(4, -7)]), pg["col"])
				c.draw_circle(pv + Vector2(0, -9), 5.0, Color(0, 0, 0, 0.6))
				c.draw_circle(pv + Vector2(0, -9), 4.0, pg["col"])
			else:
				c.draw_circle(pv, 4.0, pg["col"])
		else: _edge_arrow(inner, inner.get_center(), pv, pg["col"])
	# sound pings: rings that ripple out where you heard gunfire or a blast you can't see
	for sp in m.sound_pings:
		var age := m.time - float(sp["t"])
		if age > 1.6: continue
		var pv: Vector2 = to_map.call(sp["pos"])
		var boom: bool = sp["kind"] == "boom" or sp["kind"] == "shriek"
		var col := Color("ff9a5a") if boom else Color("ff5a5a")
		if sp["kind"] in ["blight", "shriek"]: col = Color("ff6a2a")      # the Blight: ember
		var a := clampf(1.0 - age / 1.6, 0.0, 1.0)
		if on_map.call(pv):
			c.draw_arc(pv, 3.0 + age * (12.0 if boom else 8.0), 0, TAU, 20, Color(col, a), 2.0, true)
			c.draw_circle(pv, 2.5, Color(col, a))
		else:
			_edge_arrow(inner, inner.get_center(), pv, Color(col, a))
	# truce partners you can see (white), and anyone who just broke a truce (red, seen by all)
	if m.truce and m.player:
		for h in m.hunters:
			if h.team == m.player.team or h.out or h.extracted or h.riding:
				continue
			var tv: Vector2 = to_map.call(h.pos)
			if m.truce.is_marked(h):
				var ph := fmod(m.time * 1.5, 1.0)
				if on_map.call(tv, 3.0):
					c.draw_circle(tv, 4.0, BAD)
					c.draw_arc(tv, 5.0 + ph * 8.0, 0, TAU, 20, Color(BAD, 1.0 - ph), 2.0, true)
				else: _edge_arrow(inner, inner.get_center(), tv, BAD)
			elif m.truce.allied(m.player.team, h.team) and not h.unseen and on_map.call(tv, 3.0):
				c.draw_circle(tv, 4.5, Color(0, 0, 0, 0.6))
				c.draw_circle(tv, 3.5, Color("f4f1e6"))
	# your squad, with an arrow for anyone off the edge (a dead teammate shows at their deathbox)
	for h in m.hunters:
		if m.player == null or h.team != m.player.team:
			continue
		var mst := _mate_state(h) if h != m.player else ["ALIVE", INK, h.pos, ""]
		if mst[2] == Vector3.INF or h.out or (h == m.player and h.extracted):      # (a fallen mate: their box)
			continue
		var pv: Vector2 = to_map.call(mst[2])
		var col: Color = INK if h == m.player else mst[1]
		if not on_map.call(pv, 3.0):
			_edge_arrow(inner, inner.get_center(), pv, col)
			continue
		if h == m.player:
			var d: Vector2 = h.aim_dir()
			var side := Vector2(-d.y, d.x)
			c.draw_colored_polygon(PackedVector2Array([pv + d * 8.0, pv - d * 4.0 + side * 5.0, pv - d * 2.0, pv - d * 4.0 - side * 5.0]), col)
		else:
			c.draw_circle(pv, 4.5, Color(0, 0, 0, 0.6))
			c.draw_circle(pv, 3.5, col)
			_ctext(pv + Vector2(0, -7), h.pname.substr(0, 1), 11, col, big)
	for dk in BokiHud.squad_downed(m):
		var dv: Vector2 = to_map.call(dk.position)
		if on_map.call(dv, 3.0):
			BokiHud.map_dot(c, dv, dk, 5.0, m.time)
		else:
			_edge_arrow(inner, inner.get_center(), dv, Color(dk.sp.get("glow", dk.sp["color"])))

	if mm_circ.z > 0.0:
		var ctr := Vector2(mm_circ.x, mm_circ.y)
		c.draw_arc(ctr, mm_circ.z + 1.0, 0, TAU, 72, Color(0.85, 0.8, 1.0, 0.55), 2.5, true)
		c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -mm_circ.z - 7), ctr + Vector2(5, -mm_circ.z + 1), ctr + Vector2(-5, -mm_circ.z + 1)]), Color("ffd27a"))
	_draw_clock_bar(sz, r)

## Under the minimap, like Supervive's day bar: the match clock, what the exits are doing, your run
## level, and a thin bar for how far through the match you are.
func _draw_clock_bar(sz: Vector2, mm: Rect2) -> void:
	if m.duel or m.opts.get("training", false) or m.opts.get("tutorial", false):
		return
	var r := Rect2(Vector2(mm.position.x, mm.end.y + 8), Vector2(maxf(mm.size.x, 196.0), 30))
	mm_bottom = r.end.y
	var left := m.length - m.time
	var phase := ""; var pc := MUTED
	var xl: Array = m.exits.clock_line() if m.exits else ["", MUTED]
	if left < 30.0 and (m.exits == null or m.exits.active_for(m.player.team if m.player else -9).is_empty()): phase = "ISLANDS FALLING"; pc = BAD
	else: phase = String(xl[0]); pc = xl[1]
	_rounded(r, Color(0.04, 0.05, 0.08, 0.86), 8)
	_text(r.position + Vector2(10, 20), _fmt(left), 16, BAD if left < 30.0 else INK, big)
	var pw := big.get_string_size(phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2(r.get_center().x - pw * 0.5 + 6, r.position.y + 19), phase, 11, pc, big)
	if m.player:
		var lt := "LV %d" % m.player.lvl
		_text(Vector2(r.end.x - 10 - big.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, r.position.y + 19), lt, 12, Color("ffd27a"), big)
	var prog := clampf(m.time / maxf(1.0, m.length), 0.0, 1.0)
	c.draw_rect(Rect2(Vector2(r.position.x + 6, r.end.y - 5), Vector2(r.size.x - 12, 2)), Color(1, 1, 1, 0.12))
	c.draw_rect(Rect2(Vector2(r.position.x + 6, r.end.y - 5), Vector2((r.size.x - 12) * prog, 2)), BAD if left < 30.0 else Color("b9a6ff"))
	# the raid condition (RaidLook), and how far you see under it
	var rr := Rect2(Vector2(r.position.x, r.end.y + 4), Vector2(r.size.x, 20))
	mm_bottom = rr.end.y
	var rcol: Color = RaidLook.COLORS.get(m.raid, INK)
	_rounded(rr, Color(0.04, 0.05, 0.08, 0.7), 6)
	c.draw_circle(rr.position + Vector2(11, 10), 4.0, rcol)
	_text(rr.position + Vector2(21, 14), String(RaidLook.NAMES.get(m.raid, m.raid)).to_upper(), 10, rcol, big)
	if m.sight_k < 0.99:
		var st := "SIGHT %d%%" % int(round(m.sight_k * 100.0))
		_text(Vector2(rr.end.x - 8 - big.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, rr.position.y + 14), st, 10, MUTED, big)
	if m.rolling:
		SessionRow.draw(self, Rect2(Vector2(r.position.x, rr.end.y + 4), Vector2(r.size.x, 42)))

## A bounty mark: an amber target with a pulse (on the maps and over a hunter's nameplate).
func bounty_marker(cv: Control, p: Vector2, k := 1.0) -> void:
	var amber := Color("ffb64a")
	var ph := fmod(m.time * 1.2, 1.0)
	cv.draw_arc(p, (6.0 + ph * 7.0) * k, 0, TAU, 20, Color(amber, 1.0 - ph), 2.0, true)
	cv.draw_circle(p, 6.5 * k, Color(0, 0, 0, 0.65))
	cv.draw_arc(p, 5.0 * k, 0, TAU, 18, amber, 2.0, true)
	cv.draw_circle(p, 2.0 * k, amber)
	for i in 4:
		var a := PI * 0.5 * i
		cv.draw_line(p + Vector2(cos(a), sin(a)) * 3.5 * k, p + Vector2(cos(a), sin(a)) * 8.0 * k, amber, 1.5, true)

var mm_circ := Vector3.ZERO    # the round minimap: centre x, y and radius (0 while it's the square overview)
func _mm_has(inner: Rect2, v: Vector2, pad := 0.0) -> bool:
	if mm_circ.z > 0.0:
		return v.distance_to(Vector2(mm_circ.x, mm_circ.y)) <= mm_circ.z - pad
	return inner.grow(-pad).has_point(v)

## A world marker: a bobbing pin and label over the spot, or (when it's off screen or behind the
## camera) a big arrow at the screen edge pointing the way. Both show how far it is.
func _draw_waypoint(at: Vector3, label: String, col: Color) -> void:
	var cam := m.cam
	var sz := c.size
	var dist := int(round(Vector2(at.x - m.player.pos.x, at.z - m.player.pos.z).length()))
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 4.0
	var tp := cam.unproject_position(at + Vector3(0, 2.6, 0))
	var behind := cam.is_position_behind(at)
	var on := not behind and Rect2(Vector2(40, 110), sz - Vector2(80, 230)).has_point(tp)
	if on:
		var p := tp + Vector2(0, bob)
		c.draw_circle(p, 24.0, Color(0, 0, 0, 0.5))
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -20), p + Vector2(16, 0), p + Vector2(0, 20), p + Vector2(-16, 0)]), col)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 27), p + Vector2(12, 27), p + Vector2(0, 46)]), col)
		_ctext(p + Vector2(0, 70), "%s  ·  %dm" % [label, dist], 22, col, big)
		# a ring on the ground under it
		if not behind:
			var gp := cam.unproject_position(at + Vector3(0, 0.05, 0))
			c.draw_arc(gp, 28.0 + bob, 0, TAU, 28, Color(col, 0.85), 4.0, true)
	else:
		var ctr := sz * 0.5
		var d := (tp - ctr).normalized() if not behind else (ctr - tp).normalized()
		if d.length() < 0.1: d = Vector2.UP
		# kept inside the play area: under the tutorial banner, above the pill and the ability bar
		var ctr2 := Vector2(sz.x * 0.5, sz.y * 0.47)
		ctr = ctr2
		var hx := sz.x * 0.5 - 70.0; var hy := sz.y * 0.24
		var t := minf(hx / maxf(0.001, absf(d.x)), hy / maxf(0.001, absf(d.y)))
		var edge := ctr + d * t + d * bob * 0.5
		var perp := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([edge + d * 44.0, edge - d * 12.0 + perp * 28.0, edge - d * 12.0 - perp * 28.0]), Color(0, 0, 0, 0.5))
		c.draw_colored_polygon(PackedVector2Array([edge + d * 38.0, edge - d * 9.0 + perp * 23.0, edge - d * 9.0 - perp * 23.0]), col)
		_ctext(edge - d * 62.0, "%s  %dm" % [label, dist], 22, col, big)

## An exit on the minimap: a little boat for a skiff dock, a diamond for a rift hatch, an outpost's banner
## post (OutpostGlyph). Bright when it's usable, grey when not; a pulsing ring while it's going.
func _draw_exit_icon(pv: Vector2, x: Dictionary, k := 1.0) -> void:
	var col: Color = Exits.color_of(x)
	var usable: bool = m.exits.live(x)
	var st := String(x["state"])
	if not usable: col = Color(0.55, 0.58, 0.64, 0.7)
	var dark := Color(0, 0, 0, 0.7)
	match String(x["kind"]):
		"dock":
			var hull := PackedVector2Array([pv + Vector2(-6, 1) * k, pv + Vector2(6, 1) * k, pv + Vector2(4, 5) * k, pv + Vector2(-4, 5) * k])
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(-7, 0) * k, pv + Vector2(7, 0) * k, pv + Vector2(5, 6) * k, pv + Vector2(-5, 6) * k]), dark)
			c.draw_colored_polygon(hull, col)
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -7) * k, pv + Vector2(5, 0) * k, pv + Vector2(0, 0) * k]), col)
			c.draw_line(pv + Vector2(0, -7) * k, pv + Vector2(0, 1) * k, dark, 1.5)
			if st == "closed":
				c.draw_line(pv + Vector2(-6, -6) * k, pv + Vector2(6, 6) * k, Color(BAD, 0.8), 2.0)
		"hatch":
			var dm := PackedVector2Array([pv + Vector2(0, -5) * k, pv + Vector2(5, 0) * k, pv + Vector2(0, 5) * k, pv + Vector2(-5, 0) * k])
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -6.5) * k, pv + Vector2(6.5, 0) * k, pv + Vector2(0, 6.5) * k, pv + Vector2(-6.5, 0) * k]), dark)
			c.draw_colored_polygon(dm, col if st == "open" or (m.player and m.player.rift_keys > 0) else Color(col, 0.55))
			c.draw_circle(pv, 1.6 * k, dark)
		"outpost":
			var held := OutpostLook.held(x)
			var flag: Color = Data.TEAM_COLORS[int(x["team"]) % Data.TEAM_COLORS.size()] if held else Color(0.55, 0.58, 0.64, 0.9)
			OutpostGlyph.draw(c, pv, k, col, flag, OutpostLook.lit_of(x))
			if st == "charging":
				_arc(pv, 11.0 * k, float(x["prog"]), col, 2.0)
	if st in ["called", "boarding", "charging", "open", "unlocking"]:
		var ph := fmod(m.time * 1.2, 1.0)
		c.draw_arc(pv, (8.0 + ph * 8.0) * k, 0, TAU, 24, Color(col, 0.8 * (1.0 - ph)), 2.0, true)

## Over each exit nearby: its name and what it's doing. Your squad's own exit (a skiff you called, an
## uplink you're charging) gets a waypoint from anywhere on the map.
func _draw_exit_labels() -> void:
	if m.exits == null or m.player == null or m.player.out or m.player.extracted:
		return
	var cam := m.cam
	var p: Hunter = m.player
	var mine: Dictionary = m.exits.active_for(p.team)
	for x in m.exits.list:
		var at: Vector3 = x["pos"]
		var col: Color = Exits.color_of(x)
		var d := p.flat_dist(at)
		var st := String(x["state"])
		var line := ""
		match String(x["kind"]):
			"dock":
				match st:
					"called": line = "Skiff inbound  %s" % _fmt(x["t"])
					"boarding": line = "BOARDING  %ds" % int(ceil(x["t"]))
					"gone": line = "Skiff away"
					"closed": line = "Closed"
					_: line = "Call skiff" if m.exits.callable(x) else ("Opens %s" % _fmt(float(x["open_at"]) - m.time) if m.time < float(x["open_at"]) else "")
			"hatch":
				match st:
					"unlocking": line = "OPENING  %ds" % int(ceil(float(x["t"])))
					"open": line = "OPEN  ·  %d/%d left" % [int(x["uses"]), Exits.HATCH_USES]
					_: line = "Sealed  ·  you have a key" if p.rift_keys > 0 else "Sealed  ·  needs a Rift Key"
			"outpost":
				match st:
					"charging": line = "Uplink %d%%%s" % [int(x["prog"] * 100.0), "  ·  contested" if x["contested"] else ("  ·  draining %s" % _fmt(m.exits.drain_left(x)) if x.get("draining", false) else "")]
					"fizzling": line = "Shutting off"
					"open": line = "LIFT OPEN  %ds" % int(ceil(x["t"]))
					"spent": line = "Cooling down"
					_: line = "Start uplink" if m.exits.startable(x) else ("Online in %s" % _fmt(float(x["open_at"]) - m.time))
		var reach := 26.0 if x["kind"] == "hatch" else 44.0
		if st in ["boarding", "open", "unlocking"]: reach = 70.0
		var prompted: bool = not m.interact.is_empty() and is_same(m.interact.get("x"), x)     # the prompt already says it
		if d < reach and not cam.is_position_behind(at) and not prompted:
			var lp := cam.unproject_position(at + Vector3(0, 3.4 if x["kind"] != "hatch" else 1.6, 0))
			_ctext(lp, String(x["name"]), 13, col, big)
			if line != "":
				_ctext(lp + Vector2(0, 17), line, 12 if st not in ["boarding", "open", "unlocking"] else 16, INK if st not in ["boarding", "open", "unlocking"] else col, big)
		if is_same(x, mine) and d > 7.0 and not m.opts.get("tutorial", false):
			var tgt: Vector3 = x.get("berth", at)
			_draw_waypoint(tgt, "Skiff" if x["kind"] == "dock" else ("Hatch" if x["kind"] == "hatch" else ("Lift" if st == "open" else "Uplink")), col)

## A small arrow on the minimap's edge pointing at something off the map.
func _edge_arrow(inner: Rect2, from: Vector2, to: Vector2, col: Color) -> void:
	var d := (to - from)
	if d.length() < 0.1: return
	d = d.normalized()
	var hx := inner.size.x * 0.5 - 6.0; var hy := inner.size.y * 0.5 - 6.0
	var t := minf(hx / maxf(0.001, absf(d.x)), hy / maxf(0.001, absf(d.y)))
	if mm_circ.z > 0.0:
		from = Vector2(mm_circ.x, mm_circ.y); t = mm_circ.z - 7.0
	var p := from + d * t
	var side := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([p + d * 5.0, p - d * 3.0 + side * 4.0, p - d * 3.0 - side * 4.0]), col)

## On narrow windows the ability bar takes the whole bottom row and the player card sits above it.
func _narrow(sz: Vector2) -> bool:
	return sz.x < 1080.0

## ------------------------------------------------------------------ combat HUD
## Bottom centre: armor and health over the ability row. Bottom left: your kin. Bottom right: your
## weapon and what you're carrying. Left: your squad. Hits on you show which way they came from.
const ARMOR_COL := Color("dfe9f7")      # armor kits and repairs (the armour strip itself: HudStyle / armor_col)
const HP_LOW := Color("ff6a5a")
var armor_lerp := 1.0
var ready_was := {}        # slot id -> was it ready last frame, for the "ready" flash
var ready_flash := {}      # slot id -> time left on its flash
var slot_text := {}        # slot id -> the countdown it shows now (HudSlot; checks read it)
var slot_fx := {}          # slot id -> {kind: "cast"|"deny", t}: a pop when a press lands, a red shake when it can't

## A press on an ability slot: "cast" pops it, "deny" (on cooldown, not ready) shakes it red; "reset" (it just came back) swells it with a ring.
func ability_feedback(id: String, kind: String) -> void:
	slot_fx[id] = {"kind": kind, "t": 0.0}
var hurt_dirs: Array = []  # {ang, t}

func hurt_from(at: Vector3) -> void:
	var p := m.player
	if p == null:
		return
	var d := Vector2(at.x - p.pos.x, at.z - p.pos.z)
	if d.length() < 0.3:
		return
	hurt_dirs.append({"ang": atan2(d.y, d.x), "t": 0.0})
	if hurt_dirs.size() > 6: hurt_dirs.pop_front()

## A less urgent message: it waits behind the others, and goes if it waits too long.
func toast_small(text: String, col: Color) -> void:
	msgs.push(text, col, MsgLane.LOW)

func _rounded(r: Rect2, col: Color, rad := 10, border := Color(0, 0, 0, 0), bw := 0) -> void:
	SafeArea.note(r)
	c.draw_style_box(_box(col, rad, border, bw, true), r)

## The key label under a slot (HudStyle.key_pill).
func _keycap(center: Vector2, key: String, col: Color) -> void:
	HudStyle.key_pill(c, center, key, col)

## One ability slot (HudSlot draws it; BokiHud's slots come through here too).
func _ab_slot(id: String, rect: Rect2, icon: String, key: String, col: Color, cd_frac: float, cd_secs: float, ready: bool, charges := -1, max_ch := 0, label := "") -> void:
	var on := ready and not AirLimits.drop_locked(m.player)      # greyed through the opening drop
	HudSlot.ab_slot(self, id, rect, icon, key, col, cd_frac, cd_secs, on, charges, max_ch, label)

var guide_hidden := false
var abyss_pulse := 0.0
var abyss_beat := -1
var glider_hit_t := 0.0
var glider_hit_amt := 0.0

## A hit drained your glider: flash the meter and show how much went.
func glider_hit(amount: float) -> void:
	glider_hit_amt = (glider_hit_amt if glider_hit_t > 0.0 else 0.0) + amount
	glider_hit_t = 0.5
var _h_down := false

func _hud_tick(delta: float) -> void:
	_track_mates(m.player, delta)
	_loot_tick(delta)
	glider_hit_t = maxf(0.0, glider_hit_t - delta)
	# H folds the training guide (G is send / recall your kin) and the kit panel away (and back)
	var hd := Input.is_physical_key_pressed(KEY_H)
	if hd and not _h_down and (m.opts.get("training", false) or m.opts.get("duel", false)):
		guide_hidden = not guide_hidden
	_h_down = hd
	HudSlot.decay(self, delta)
	for h in hurt_dirs.duplicate():
		h["t"] = float(h["t"]) + delta
		if float(h["t"]) > 1.2: hurt_dirs.erase(h)

## The bottom-left cluster (HudVitals draws the portrait and bars; the ability row sits under them).
const HUD_PORTRAIT := Vector2(112, 132)
func _hud_origin(sz: Vector2) -> Vector2:
	return Vector2(18, sz.y - 18 - HUD_PORTRAIT.y)

var lvl_pop := 0.0
var lvl_seen := -1
## A level just went up (Hunter.gain_xp): the badge pops and the lane names what improved (the
## weapon's step on even levels, which also get a gold wash).
func level_up(lv: int, info := {}) -> void:
	lvl_pop = 0.35      # every level: the badge flashes (the growth itself is quiet, LevelGrowth)
	var line := "LEVEL %d  ·  +1 skill point" % lv
	if lv % 2 == 0:
		flash(Color("ffd27a"), 0.16)
		if not info.is_empty(): line = "LEVEL %d  ·  %s" % [lv, info["name"]]
	msgs.push(line, Color("ffd27a"), MsgLane.HIGH)

## The archetype resource under the health bar, with its name and tells (ARCHETYPES §3.2).
func _draw_res_bar(x0: float, y: float, w: float, p: Hunter) -> void:
	var k: ArchKit = p.ak
	var rc := k.res_col()
	var f := k.res_frac()
	var rd := k.res_def()
	_text(Vector2(x0, y + 9), String(rd.get("name", "")).to_upper(), 10, Color(rc, 0.9), big)
	var bx := x0 + 78.0
	var bw := w - 78.0 - 40.0
	if String(rd.get("kind", "")) in ["count", "on_targets"]:
		var n := int(rd.get("max", 3))
		var have := int(round(f * n))
		for i in n:
			var cr := Rect2(Vector2(bx + i * (bw / n), y + 2), Vector2(bw / n - 3.0, 7))
			_rounded(cr, rc if i < have else Color(1, 1, 1, 0.12), 3)
	else:
		_bar(Rect2(Vector2(bx, y + 2), Vector2(bw, 7)), f, rc)
		if String(rd.get("id", "")) == "heat":
			var ov := float(rd.get("over", 70.0)) / float(rd.get("max", 100.0))
			c.draw_rect(Rect2(Vector2(bx + bw * ov, y), Vector2(2, 11)), Color(1, 1, 1, 0.6))
	var txt := k.res_text()
	# right-aligned to the health bar's end: just after the bar it ran into the R slot's "UNLOCK" at level 6
	var tw := big.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2(maxf(bx + bw + 6, x0 + w - tw), y + 10), txt, 11, rc if k.tell == "full" else INK, big)
	if k.tell == "full":
		var pulse := 0.5 + 0.5 * sin(m.time * 8.0)
		_rounded(Rect2(Vector2(bx - 2, y), Vector2(bw + 4, 11)), Color(0, 0, 0, 0), 4, Color(rc, 0.4 + 0.5 * pulse), 2)

## Glider heat as a ring floating beside the glider, as in Supervive: it fills as you glide (faster
## when you're hit or lifting out of the abyss), drains on the ground, and pulses red when
## overheated, when the next hit will spike you.
func _draw_glider_heat(p: Hunter) -> void:
	if p.dropping or p.downed or p.riding:
		return
	var heat := 1.0 - p.glide_fuel
	if not p.gliding and heat < 0.01:
		return
	var at := _head(p, 2.25 * float(p.cdat["scale"]))
	if m.cam.is_position_behind(at):
		return
	var cpt := m.cam.unproject_position(at) + Vector2(58, -6)
	var hot := heat >= 0.999
	var gcol := Color("ffd27a").lerp(Color("ff5a3a"), clampf(heat * 1.2 - 0.2, 0.0, 1.0))
	if hot: gcol = gcol.lerp(Color.WHITE, 0.35 + 0.35 * sin(m.time * 14.0))
	var a := 1.0 if p.gliding else 0.6
	# a hit just drained it (2x): the ring flashes red and shows the chunk it lost
	if glider_hit_t > 0.0:
		var hk := glider_hit_t / 0.5
		c.draw_arc(cpt, 19.0, 0.0, TAU, 32, Color(1.0, 0.25, 0.2, 0.8 * hk), 3.0, true)
		_ctext(cpt + Vector2(0, -24), "-%d%%" % int(round(glider_hit_amt * 100.0)), 13, Color(1.0, 0.45, 0.35, hk), big)
	c.draw_circle(cpt, 15.0, Color(0.03, 0.03, 0.05, 0.75 * a))
	c.draw_arc(cpt, 11.0, 0.0, TAU, 32, Color(1, 1, 1, 0.14 * a), 4.0, true)
	if heat > 0.005:
		c.draw_arc(cpt, 11.0, -PI * 0.5, -PI * 0.5 + TAU * heat, 40, Color(gcol, a), 4.0, true)
	# a little wing in the middle
	var wcol := Color(gcol if hot else Color(1, 1, 1, 0.8), a)
	c.draw_polyline(PackedVector2Array([cpt + Vector2(-6, 2), cpt + Vector2(0, -3), cpt + Vector2(6, 2)]), wcol, 2.0, true)
	if hot:
		c.draw_arc(cpt, 17.0 + 2.0 * sin(m.time * 14.0), 0.0, TAU, 32, Color(1.0, 0.3, 0.2, 0.6), 2.0, true)

## The ability row under the bars: right click, Shift dash, E kin, R bond ultimate (gloves: GripHud). Every
## one starts the run locked; rank pips sit above each, a gold border means a point can unlock it
## (just press its key), and a gold + means Alt + its key will rank it up.
func _draw_abilities(sz: Vector2, p: Hunter) -> void:
	if p.ak:
		_draw_arch_abilities(sz, p)
		return
	var o := _hud_origin(sz)
	var s := 50.0
	var gap := 10.0
	var x := o.x + HUD_PORTRAIT.x + 16.0
	var y := o.y + 66.0
	var k: Kin = p.kin
	var util: AbilityDef = p.runner.def_of("utility") if p.runner else null
	# right click: the weapon's ability
	var sr := Rect2(Vector2(x, y), Vector2(s, s))
	if util:
		_skill_slot("sec", "sec", sr, util.icon, Settings.key_cap("secondary"), util.color, p.runner.cd_frac("utility"), p.runner.cd_left("utility") if not p.runner.is_ready("utility") else 0.0, p.runner.is_ready("utility"), p.runner.charges("utility") if util.charges > 1 else -1, util.charges if util.charges > 1 else 0)
	x += s + gap
	# Shift: your dash
	DashSlot.row_slot(self, Rect2(Vector2(x, y), Vector2(s, s)), p)
	x += s + gap
	# E: your kin's ability
	var er := Rect2(Vector2(x, y), Vector2(s, s))
	if k:
		var kd: AbilitySpec = k.runner.def_of("k1")
		if kd:
			var rdy: bool = k.runner.is_ready("k1") and k.ready_to_fight()
			_skill_slot("kin", "k1", er, KinText.icon(kd), Settings.key_cap("signature"), KinText.color(kd), k.runner.cd_frac("k1"), k.runner.cd_left("k1") if not k.runner.is_ready("k1") else 0.0, rdy)
			if not k.ready_to_fight() and int(p.slot_lv["kin"]) > 0:
				_rounded(er, Color(0, 0, 0, 0.45), 10)
	BokiHud.aug_mark(self, p, er, "e")
	x += s + gap
	# C and G (the Merge sits on the right: GripHud)
	x = BokiHud.cg_slots(self, p, x, y, s)
	# B (base to a teammate) as a small badge at the end of the row (the gloves sit on the right: GripHud)
	if m.hunters.any(func(oh): return oh != p and oh.team == p.team):
		var brr := Rect2(Vector2(x, y + s - 34.0), Vector2(34, 34))
		_ab_slot("base", brr, "swap", Settings.key_cap("base"), Color("8fe3c8"), p.base_cd / Hunter.BASE_CD if p.base_cd > 0.0 else 0.0, p.base_cd, p.base_cd <= 0.0 and p.base_t <= 0.0)

## The archetype row: RMB, Shift dash, E utility, X the hero's ultimate (locked until level 6), then the
## kin's own ability (C) and send/recall (G) as small badges. The Merge is the Boki box on the right (GripHud).
func _draw_arch_abilities(sz: Vector2, p: Hunter) -> void:
	var o := _hud_origin(sz)
	var s := 50.0
	var gap := 10.0
	var x := o.x + HUD_PORTRAIT.x + 16.0
	var y := o.y + 74.0
	var k: Kin = p.kin
	var info := p.slot_info("sec")
	var sr := Rect2(Vector2(x, y), Vector2(s, s))
	_skill_slot("sec", "sec", sr, String(info["icon"]), Settings.key_cap("secondary"), info["col"], float(info["cd"]) / maxf(0.01, float(info["cd_max"])) if float(info["cd"]) > 0.0 else 0.0, float(info["cd"]), bool(info["ready"]), int(info["charges"]) if int(info["max_charges"]) > 1 else -1, int(info["max_charges"]) if int(info["max_charges"]) > 1 else 0)
	if info.get("full", false) and int(p.slot_lv["sec"]) > 0:
		# the resource-full variant is ready (Cash In, Called Shot, Shield Slam...): a gold dot
		c.draw_circle(sr.position + Vector2(s - 6, 6), 5.0 + sin(m.time * 8.0), Color("ffd23f"))
	if float(info.get("hold", -1.0)) >= 0.0:
		# a merged form's RMB hold: the fill ring, bright once it is full
		c.draw_arc(sr.get_center(), s * 0.5 + 4.0, -PI / 2, -PI / 2 + TAU * clampf(float(info["hold"]), 0.0, 1.0), 32, Color(info["col"], 1.0 if info.get("full", false) else 0.8), 3.0, true)
	if p.ak and p.ak.rmb_down and p.ak.rmb_t > 0.05:
		var hfull: float = p.ak.rmb_charge_full() if p.ak.rmb_charge_full() > float(p.ak.rmb_def().get("hold", 0.3)) else float(p.ak.rmb_def().get("hold", 0.3))
		var hk := clampf(p.ak.rmb_t / maxf(0.05, hfull), 0.0, 1.0)
		c.draw_arc(sr.get_center(), s * 0.5 + 4.0, -PI / 2, -PI / 2 + TAU * hk, 32, Color(info["col"], 0.9), 3.0, true)
	BokiHud.aug_mark(self, p, sr, "rmb")
	x += s + gap
	var di := p.slot_info("dash")
	DashSlot.row_slot(self, Rect2(Vector2(x, y), Vector2(s, s)), p)
	if di.get("full", false):
		# the payoff lives on the dash (the Thief's Primed shot into 3 Marks): the same gold dot
		c.draw_circle(Vector2(x, y) + Vector2(s - 6, 6), 5.0 + sin(m.time * 8.0), Color("ffd23f"))
	BokiHud.aug_mark(self, p, Rect2(Vector2(x, y), Vector2(s, s)), "dash")
	x += s + gap
	var ei := p.slot_info("k1")
	var er := Rect2(Vector2(x, y), Vector2(s, s))
	_skill_slot("kin", "k1", er, String(ei["icon"]), Settings.key_cap("signature"), ei["col"], float(ei["cd"]) / maxf(0.01, float(ei["cd_max"])) if float(ei["cd"]) > 0.0 and float(ei.get("up", 0.0)) <= 0.0 else 0.0, float(ei["cd"]) if float(ei.get("up", 0.0)) <= 0.0 else 0.0, bool(ei["ready"]))
	if ei.get("full", false):
		# the payoff lives on E (the Mage's Flashpoint): the same gold dot as the right click's
		c.draw_circle(er.position + Vector2(s - 6, 6), 5.0 + sin(m.time * 8.0), Color("ffd23f"))
	if float(ei.get("up", 0.0)) > 0.0:
		c.draw_arc(er.get_center(), s * 0.5 + 4.0, -PI / 2, -PI / 2 + TAU * clampf(float(ei["up"]) / maxf(0.1, float(p.ak.e_def().get("time", 5.0))), 0.0, 1.0), 32, Color(ei["col"], 0.9), 3.0, true)
	x += s + gap
	# X: the hero's own ultimate (the Merge sits on the right: GripHud)
	x = HunterUltTile.draw(self, p, x, y, s, gap)
	# C: the Boki's own ability, G: throw / recall (hold: hold the spot or follow)
	x = BokiHud.cg_slots(self, p, x, y, s)
	if m.hunters.any(func(oh): return oh != p and oh.team == p.team):
		var brr := Rect2(Vector2(x, y + s - 34.0), Vector2(34, 34))
		_ab_slot("base", brr, "swap", Settings.key_cap("base"), Color("8fe3c8"), p.base_cd / Hunter.BASE_CD if p.base_cd > 0.0 else 0.0, p.base_cd, p.base_cd <= 0.0 and p.base_t <= 0.0)

## What the R slot says about its lock: "LV 6" until then, "UNLOCK" with a point to spend on it,
## "" once it's unlocked.
func r_lock_text(p: Hunter) -> String:
	if int(p.slot_lv.get("ult", 0)) > 0:
		return ""
	if p.can_level("ult"):
		return "UNLOCK"
	if p.lvl >= int(Hunter.ULT_AT[0]):
		return "NEXT POINT"
	return "LV %d" % int(Hunter.ULT_AT[0])

## One ability in the row, aware of run levels (HudSlot.skill_slot).
func _skill_slot(slot: String, id: String, r: Rect2, icon: String, key: String, col: Color, cdf: float, cds: float, ready: bool, ch := -1, mx := 0) -> void:
	HudSlot.skill_slot(self, slot, id, r, icon, key, col, cdf, cds, ready and not AirLimits.drop_locked(m.player), ch, mx)

## Your kin, perched on the top corner of your portrait: its face, a health ring and its state.
func _draw_kin_card(sz: Vector2, p: Hunter) -> void:
	var k: Kin = p.kin
	if k == null:
		return
	var o := _hud_origin(sz)
	var kc: Color = Data.KIN[k.species]["color"]
	var glow: Color = Data.KIN[k.species].get("glow", kc)
	var rr := 20.0
	var ring := Vector2(rr + 4.0, rr + 4.0)
	var pc := SafeArea.keep(Rect2(o + Vector2(6, 6) - ring, ring * 2.0), sz).get_center()      # (the corner of the portrait, kept on screen)
	SafeArea.note(Rect2(pc - ring, ring * 2.0))
	c.draw_circle(pc, rr + 4, Color(0.03, 0.03, 0.05, 0.95))
	c.draw_arc(pc, rr + 1.5, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
	c.draw_arc(pc, rr + 1.5, -PI / 2, -PI / 2 + TAU * clampf(k.hp / k.max_hp, 0.0, 1.0), 40, kc, 3.0, true)
	c.draw_circle(pc, rr - 2, Color(glow, 0.25))
	c.draw_circle(pc, rr - 4, kc)
	c.draw_circle(pc + Vector2(-6, -2), 2.8, Color.BLACK)
	c.draw_circle(pc + Vector2(6, -2), 2.8, Color.BLACK)
	if k.state == "downed":
		c.draw_circle(pc, rr - 4, Color(0, 0, 0, 0.55))
		_ctext(pc + Vector2(0, 5), str(int(ceil(k.down_t))), 14, INK, big)
	hover_spots.append([Rect2(pc - Vector2(rr, rr), Vector2(rr, rr) * 2.0), "kin"])
	BokiHud.rest_card(self, k, pc, rr)
	var st := ""
	match k.state:
		"shoulder":
			st = ({"mount": "riding", "perch": "perched"}.get(k.carry_style(), "on shoulder") if k.cmd == "return" else "carried") if k.settle >= 1.0 else "settling"
			if not k.giant.is_empty(): st = "GIANT"
			elif k.carry_style() == "mount" and p.gliding: st = "curled up"
		"flying", "flying_home": st = "in the air"
		"active": st = "fighting" if k.target else String(KinFollow.NAMES.get(k.cmd, "Follow")).to_lower()
		"returning": st = "coming back"
		"downed": st = "down"
		"reviving": st = "reviving you!"
		"fused": st = "merged"
	if k.state in ["active", "downed", "reviving", "fused", "returning"] or not k.giant.is_empty():
		var tw := big.get_string_size(st.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var sr := SafeArea.keep(Rect2(pc + Vector2(-tw * 0.5 - 5, rr + 3), Vector2(tw + 10, 14)), sz)
		_rounded(sr, Color(0.03, 0.03, 0.05, 0.9), 6)
		_ctext(sr.get_center() + Vector2(0, 3.5), st.to_upper(), 9, Color(kc.lerp(INK, 0.3), 0.95), big)

## Bottom right, as in Supervive: your consumables and kin throw as small slots with counts, your
## loot counter, and the weapon card with ammo underneath.
func _draw_weapon(sz: Vector2, p: Hunter) -> void:
	var w := 270.0
	var r := Rect2(Vector2(sz.x - w - 18, sz.y - 18 - 62), Vector2(w, 62))
	var rc: Color = Loot.ELEMENTS[p.welem]["col"] if p.welem != "" else Color("e6dccb")
	_rounded(r, Color(0.04, 0.05, 0.08, 0.88), 12, Color(rc, 0.45), 1)
	hover_spots.append([r, "weapon"])
	BokiHud.aug_mark(self, p, Rect2(r.position + Vector2(6, 4), Vector2(18, 18)), "lmb")
	c.draw_rect(Rect2(r.position + Vector2(0, 10), Vector2(3, r.size.y - 20)), rc)
	Icons.draw(c, p.wid, r.position + Vector2(40, 34), 26.0, Color(rc, 0.9))
	var wn := String(p.wpn["name"]).to_upper()
	_text(r.position + Vector2(78, 22), wn, 12 if wn.length() <= 20 else 10, rc, big)
	if p.welem != "":
		# the element's colour: what it does to whatever you hit is in the hover
		var ec: Color = Loot.ELEMENTS[p.welem]["col"]
		c.draw_circle(r.position + Vector2(w - 16, 18), 5.0, ec)
		c.draw_arc(r.position + Vector2(w - 16, 18), 8.0, 0, TAU, 20, Color(ec, 0.5), 2.0)
	var mag := int(p.wpn["mag"])
	var ammo_col := INK if p.ammo > mag * 0.25 else HP_LOW
	if p.wpn.get("melee", false):
		_text(r.position + Vector2(78, 48), "MELEE", 18, rc, big)
		var cn: int = (p.wpn.get("combo_dmg", p.wpn.get("combo", [1.0])) as Array).size()
		var live := m.time - p.swing_at <= float(p.wpn["rate"]) + float(p.wpn.get("combo_reset", 0.6))
		for ci in cn:
			var on := live and (p.combo_i % cn) > ci
			c.draw_circle(r.position + Vector2(160 + ci * 16, 42), 5.0 if ci == cn - 1 else 3.5, rc if on else Color(1, 1, 1, 0.2))
	elif not p.wpn.get("ammo", true):
		pass                       # no ammo (Data.weapon_stats): no count to show
	elif p.reload_t > 0.0:
		_text(r.position + Vector2(78, 46), "RELOADING", 16, Color("ffe7a8"), big)
		_bar(Rect2(r.position + Vector2(78, 52), Vector2(170, 4)), 1.0 - p.reload_t / float(p.wpn["reload"]), Color("ffe7a8"))
	else:
		_text(r.position + Vector2(78, 52), str(p.ammo), 28, ammo_col, big)
		var aw := big.get_string_size(str(p.ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_text(r.position + Vector2(84 + aw, 52), "/ %d" % mag, 14, MUTED, big)
	# the row of small slots above the weapon card
	var s := 44.0; var gap := 8.0
	var y := r.position.y - s - 22.0
	var x := r.end.x - s
	var k: Kin = p.kin
	# 1 2 3: the utility belt (tonic, armor kit and gadgets: BeltHud); Q V C: the gloves and the Boki (GripHud)
	x = BeltHud.draw(self, p, x, y)
	GripHud.draw(self, p, r)
	# C: throw / recall your kin
	if k:
		var kc: Color = Data.KIN[k.species]["color"]
		var out_now: bool = k.state in ["active", "flying", "returning"]
		var can_throw: bool = (k.state == "shoulder" and k.throw_cd <= 0.0) or out_now
		_ab_slot("throw", Rect2(Vector2(x, y), Vector2(s, s)), "recall" if out_now else "throw", Settings.key_cap("throw"), kc, k.throw_cd / 1.0 if k.throw_cd > 0.0 else 0.0, k.throw_cd, can_throw)
		x -= s + gap
	# what you're carrying home, as a counter
	var seeds := 0
	for sd in p.seeds: seeds += int(p.seeds[sd])
	# (inside the weapon card on the right: the slot row above is full with the four-slot belt)
	var gx := r.end.x - 112.0
	var cy := r.position.y + 6.0
	Icons.draw(c, "gem", Vector2(gx + 8, cy + s - 10), 7.0, GOLD)
	_text(Vector2(gx + 20, cy + s - 4), "%d" % p.gems, 18, GOLD if p.gems > 0 else MUTED, big)
	_text(Vector2(gx + 2, cy + 14), "%d seeds · %s" % [seeds, CaptureHud.box_text(p)], 10, CaptureHud.box_col(p, MUTED), big)
	if not m.opts.get("training", false):
		# the backpack: slots used (red when full); the key opens it
		var full := p.pack.size() >= p.pack_cap
		var pcol := Color("ffb0a0") if full else (INK if p.pack.size() > 0 else MUTED)
		var gw := big.get_string_size("%d" % p.gems, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var px := gx + 30.0 + gw
		Icons.draw(c, "satchel", Vector2(px + 8, cy + s - 10), 8.0, pcol)
		_text(Vector2(px + 20, cy + s - 4), "%d/%d" % [p.pack.size(), p.pack_cap], 14, pcol, big)
		var pw := big.get_string_size("%d/%d" % [p.pack.size(), p.pack_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		hover_spots.append([Rect2(Vector2(px, cy + s - 22), Vector2(24 + pw, 24)), "pack"])

## Your squadmates down the left side.
## A teammate's state, for the squad frames, markers and arrows: [label, colour, where to point,
## timer text]. Alive, a downed wisp, dead (with the soul window at their deathbox), gone, or out.
func _mate_state(h: Hunter) -> Array:
	if h.extracted:
		return ["EXTRACTED", Color("8fe3c8"), Vector3.INF, ""]
	if h.out:
		var b: Dictionary = Life.box_of(m, h)
		if h.gone or b.is_empty():
			return ["DEAD", Color("8a8f9e"), Vector3.INF, ""]
		var left := float(b.get("soul_until", 0.0)) - m.time
		if left > 0.0:
			return ["DEATHBOX", Color("ff6a5a"), b.get("pos", h.pos), "%d:%02d" % [int(left) / 60, int(left) % 60]]
		return ["DEAD", Color("8a8f9e"), b.get("pos", h.pos), ""]
	if h.downed:
		return ["WISP", Color("ffb36a"), h.pos, ""]
	return ["ALIVE", GOOD, h.pos, ""]

## Rendered portraits for hunters with no painted art, one per hunter (and a greyed copy for the fallen).
var portraits := {}       # nid -> SubViewport
var portraits_grey := {}  # nid -> ImageTexture

func portrait(h: Hunter) -> Texture2D:
	var pkey := "%s|%s|%s" % [h.arch, h.cls, h.wid]
	if portraits.has(h.nid) and String((portraits[h.nid] as Node).get_meta("pkey", pkey)) != pkey:
		# a new archetype or weapon (the Arena's 2-7 swap): the portrait follows
		(portraits[h.nid] as Node).queue_free()
		portraits.erase(h.nid); portraits_grey.erase(h.nid)
	if not portraits.has(h.nid):
		var look: Dictionary = Unmasked.mask_look() if h.ctrl == "local" else h.bot_look
		var vp := Portraits.make(h.cls, Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()], h.wid, look, h.arch)
		vp.set_meta("pkey", pkey)
		add_child(vp)
		portraits[h.nid] = vp
	return (portraits[h.nid] as SubViewport).get_texture()

func portrait_grey(h: Hunter) -> Texture2D:
	if not portraits_grey.has(h.nid):
		var g := Portraits.grey(portrait(h))
		if g == null:
			return portrait(h)
		portraits_grey[h.nid] = g
	return portraits_grey[h.nid]

## A hunter's framed portrait (Portraits): its Warden's painted face, or its rendered model when it has
## none. state: "" alive, "down", "dead", "out". Alive, a hit flashes it and low health drains it.
func _draw_portrait(r: Rect2, h: Hunter, state: String, border: Color) -> void:
	var ak := Portraits.arch_of(h)
	var fallback: Texture2D = null
	if not Portraits.has_art(ak):
		fallback = portrait_grey(h) if state == "dead" else portrait(h)
	var hurt := plates.flash_of(h) if state == "" else 0.0
	var low := clampf((0.3 - h.hp / maxf(1.0, h.max_hp)) / 0.3, 0.0, 1.0) if state == "" else 0.0
	Portraits.draw(c, r, ak, fallback, border, state, hurt, low, m.time)

## Seconds a wisp has left at the normal bleed rate.
func _bleed_left(h: Hunter) -> float:
	return h.down_hp / (Data.MATCH["down_hp"] / Life.R["bleed_out"])

var mm_bottom := 226.0    # where the minimap ends (it grows while you ride in)

## Your squad, stacked under the minimap: portrait, name, armor over segmented health, status icons.
## A knocked teammate pulses red with their bleed-out timer; a dead one is greyed with an X and the
## time left to bring them back from their deathbox; one who got out wears a check mark.
func _draw_squad(sz: Vector2, p: Hunter) -> void:
	var y := mm_bottom + 10.0
	var w := 210.0
	for h in m.hunters:
		if h == p or h.team != p.team:
			continue
		var st := _mate_state(h)
		var lbl := String(st[0])
		var r := Rect2(Vector2(16, y), Vector2(w, 60))
		var down := lbl == "WISP"
		var pulse := 0.5 + 0.5 * sin(m.time * 8.0)
		_rounded(r, Color(0.05, 0.06, 0.09, 0.84), 10, Color(st[1], 0.35 + (0.5 * pulse if down else 0.0)), 2 if down else 1)
		var pr := Rect2(r.position + Vector2(6, 6), Vector2(48, 48))
		var pst := ""
		match lbl:
			"WISP": pst = "down"
			"DEATHBOX", "DEAD": pst = "dead"
			"EXTRACTED": pst = "out"
		_draw_portrait(pr, h, pst, SideColor.of(m, h))
		var tx := pr.end.x + 8.0
		var tw := r.end.x - 8.0 - tx
		_text(Vector2(tx, r.position.y + 19), h.pname.substr(0, 13), 14, INK if lbl == "ALIVE" else Color(INK, 0.7), big)
		if m.skydrop and (h.riding or h.dropping):
			# on the way in: who leads the drop, who follows, who's gone solo
			var tag := "LEAD" if m.skydrop.is_lead(h) else ("SOLO" if h.drop_solo else "")
			if tag != "":
				_text(Vector2(tx + big.get_string_size(h.pname.substr(0, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 6, r.position.y + 18), tag, 10, GOLD if tag == "LEAD" else Color("8fd8ff"), big)
		# how far, on the right of the name row
		var at: Vector3 = st[2]
		if at != Vector3.INF and lbl != "DEAD":
			var dist_txt := "%dm" % int(round(Vector2(at.x - p.pos.x, at.z - p.pos.z).length()))
			_text(Vector2(r.end.x - 8 - body.get_string_size(dist_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, r.position.y + 18), dist_txt, 11, MUTED, body)
		match lbl:
			"ALIVE":
				var frac := clampf(h.hp / h.max_hp, 0.0, 1.0)
				HudStyle.seg_bar(c, Rect2(Vector2(tx, r.position.y + 29), Vector2(tw, 8)), h.hp, h.max_hp, HudStyle.hp_fill(HudStyle.ALLY, frac, m.time), _chip_of(h, frac), HudPlate.shield_frac(h), plates.flash_of(h))
				if h.max_armor > 0.5:
					HudStyle.strip(c, Rect2(Vector2(tx, r.position.y + 38), Vector2(tw, 3)), h.armor / h.max_armor, h.armor_col())
				if _has_status(h):
					_status_row(Vector2(tx + tw * 0.5, r.position.y + 52), h)
			"WISP":
				var left := _bleed_left(h)
				var stp: bool = h.get_meta("stomped", false)
				_bar(Rect2(Vector2(tx, r.position.y + 28), Vector2(tw, 6)), h.down_hp / Data.MATCH["down_hp"], (Color("ff2a1a") if stp else Color("ff6a4a")).lerp(Color.WHITE, (0.5 if stp else 0.25) * pulse))
				_text(Vector2(tx, r.position.y + 51), ("STOMPED  %ds" if stp else "KNOCKED  %ds") % int(ceil(left)), 13, Color("ff4a3a") if stp else Color("ff8a6a"), big)
				if h.revive > 0.0:
					_arc(Vector2(r.end.x - 16, r.position.y + 46), 8, h.revive, GOOD, 3.0)
			"DEATHBOX":
				_text(Vector2(tx, r.position.y + 37), "DEAD", 13, Color("ff6a5a"), big)
				_text(Vector2(tx, r.position.y + 53), "Deathbox  %s" % String(st[3]), 12, Color("ffb0a0"))
			"EXTRACTED":
				_text(Vector2(tx, r.position.y + 42), "EXTRACTED", 13, Color("8fe3c8"), big)
			_:
				_text(Vector2(tx, r.position.y + 42), "ELIMINATED", 13, MUTED, big)
		y += 66
	_draw_squad_markers(sz, p)

func _has_status(e: Ent) -> bool:
	return e.stun_t > 0.0 or e.root_t > 0.0 or e.slow_t > 0.0 or e.burn_t > 0.0 or e.guard_t > 0.0 \
		or (e is Hunter and ((e as Hunter).shield > 0.0 or (e as Hunter).weak_t > 0.0))

## Ally alerts, top centre under the timer. A teammate getting knocked gets a big card (their face,
## name, bleed-out countdown, and how far and which way); it turns green if they're picked up, red if
## they're lost, then fades. Smaller cards for a teammate eliminated or revived from their deathbox.
var mate_last := {}       # nid -> last squad state label
var alerts: Array = []    # {h, kind, t}

func _track_mates(p: Hunter, delta: float) -> void:
	for a in alerts.duplicate():
		a["t"] = float(a["t"]) + delta
		var life := 999.0 if a["kind"] == "knocked" else 2.6
		if float(a["t"]) > life or (a["kind"] == "knocked" and not is_instance_valid(a["h"])) or (a["kind"] == "knocked" and not (a["h"] as Hunter).downed and float(a["t"]) > 1.0):
			alerts.erase(a)
	if p == null:
		return
	for h in m.hunters:
		if h == p or h.team != p.team:
			continue
		var now := String(_mate_state(h)[0])
		var was := String(mate_last.get(h.nid, now))
		mate_last[h.nid] = now
		if now == was:
			continue
		var card = null
		for a in alerts:
			if a["h"] == h and a["kind"] == "knocked":
				card = a
		if now == "WISP":
			if card == null:
				alerts.append({"h": h, "kind": "knocked", "t": 0.0})
			Sfx.play("warn", null, -4.0, 0.0, 0.8)
		elif was == "WISP" and now == "ALIVE":
			if card: card["kind"] = "revived"; card["t"] = 0.0
			else: alerts.append({"h": h, "kind": "revived", "t": 0.0})
			Sfx.play("revive", null, -6.0)
		elif (now == "DEATHBOX" or now == "DEAD") and was in ["WISP", "ALIVE"]:
			if card: card["kind"] = "eliminated"; card["t"] = 0.0
			else: alerts.append({"h": h, "kind": "eliminated", "t": 0.0, "small": true})
			Sfx.play("warn", null, -8.0, 0.0, 0.6)
		elif was == "DEATHBOX" and now == "ALIVE":
			alerts.append({"h": h, "kind": "revived", "t": 0.0, "small": true})
			Sfx.play("revive", null, -6.0)
		elif was == "DEATHBOX" and now == "DEAD":
			alerts.append({"h": h, "kind": "lost", "t": 0.0, "small": true})
	while alerts.size() > 3:
		alerts.pop_front()

var alerts_h := 0.0       # how much room the alerts take (the message lane sits below them)

func _draw_alerts(sz: Vector2, p: Hunter) -> void:
	var y := 82.0
	alerts_h = 0.0
	for a in alerts:
		var h: Hunter = a["h"]
		var kind := String(a["kind"])
		var t := float(a["t"])
		var fade := 1.0 if kind == "knocked" else clampf((2.6 - t) / 0.6, 0.0, 1.0)
		var pop := clampf(t / 0.15, 0.0, 1.0)
		var small: bool = a.get("small", false)
		var w := 300.0 if not small else 236.0
		var hh := 70.0 if not small else 44.0
		var r := Rect2(Vector2(sz.x * 0.5 - w * 0.5, y + (1.0 - pop) * -10.0), Vector2(w, hh))
		var col := Color("ff5a3a")
		var title := "ALLY KNOCKED"
		match kind:
			"revived": col = GOOD; title = "ALLY REVIVED"
			"eliminated": col = BAD; title = "ALLY ELIMINATED"
			"lost": col = MUTED; title = "WISP LOST"
		var pulse := 0.5 + 0.5 * sin(m.time * 8.0) if kind == "knocked" else 0.0
		_rounded(r, Color(0.06, 0.03, 0.04, 0.9 * fade), 10, Color(col, (0.6 + 0.4 * pulse) * fade), 2)
		var ps := hh - 12.0
		var pr := Rect2(r.position + Vector2(6, 6), Vector2(ps, ps))
		var pst := "down" if kind == "knocked" else ("dead" if kind in ["eliminated", "lost"] else "")
		if fade > 0.05:
			_draw_portrait(pr, h, pst, col)
		var tx := pr.end.x + 10.0
		if small:
			_text(Vector2(tx, r.position.y + 19), title, 12, Color(col, fade), big)
			_text(Vector2(tx, r.position.y + 36), h.pname.substr(0, 16), 14, Color(INK, fade), big)
		else:
			_text(Vector2(tx, r.position.y + 21), title, 13, Color(col, fade), big)
			_text(Vector2(tx, r.position.y + 42), h.pname.substr(0, 16), 17, Color(INK, fade), big)
			if kind == "knocked":
				_text(Vector2(tx, r.position.y + 61), "%ds to revive" % int(ceil(_bleed_left(h))), 12, Color("ffb0a0"))
				# which way, and how far
				var dv := Vector2(h.pos.x - p.pos.x, h.pos.z - p.pos.z)
				var ctr := Vector2(r.end.x - 34, r.position.y + 30)
				var ang := _screen_dir(dv)
				var tip := ctr + Vector2.from_angle(ang) * 13.0
				var side := Vector2.from_angle(ang + PI * 0.5) * 7.0
				var back := ctr - Vector2.from_angle(ang) * 6.0
				c.draw_circle(ctr, 17.0, Color(0, 0, 0, 0.35))
				c.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), col)
				_ctext(Vector2(ctr.x, r.position.y + 63), "%dm" % int(round(dv.length())), 12, INK, big)
			else:
				_text(Vector2(tx, r.position.y + 61), "Back on their feet" if kind == "revived" else "Get to their deathbox", 12, Color(MUTED, fade))
		y += hh + 8.0
		alerts_h += hh + 8.0

## A ground direction as a screen angle, using the camera's view.
func _screen_dir(dv: Vector2) -> float:
	var cam := m.cam
	if cam == null or m.player == null:
		return dv.angle()
	var a := cam.unproject_position(m.player.position)
	var b := cam.unproject_position(m.player.position + Vector3(dv.x, 0, dv.y).normalized() * 3.0)
	return (b - a).angle()

func _chip_of(e: Ent, frac: float) -> float:
	return plates.chip_of(e, frac, get_process_delta_time())

## Who sees a rival's name on their plate (HudPlate draws it).
const NP_NAME_NEAR := 9.0       # a rival this close shows their name
const NP_HOVER_PX := 46.0       # ... or the mouse within this of their plate

## Does this hunter's plate show their name? Allies always; rivals when hovered or close, or down.
func _np_show_name(sp: Vector2, h: Hunter) -> bool:
	if m.player == null or h.team == m.player.team or h.downed:
		return true
	if m.player.flat_dist(h) < NP_NAME_NEAR:
		return true
	return c.get_local_mouse_position().distance_to(sp) < NP_HOVER_PX

func _nameplate(sp: Vector2, h: Hunter) -> void:
	if not sp.is_finite():
		return
	plates.draw(self, sp, h, _np_show_name(sp, h))
	if m.rolling and h.has_meta("bounty"):
		# a bounty: a target over the plate and what knocking them is worth
		bounty_marker(c, Vector2(sp.x, sp.y - 34), 1.15)
		_ctext(Vector2(sp.x, sp.y - 48), "BOUNTY  ·  LV %d" % h.lvl, 11, Color("ffb64a"), big)
	if not h.downed:
		_draw_marks(Vector2(sp.x, sp.y - 28), h)

## A Thief's Marks over their target's head: pips, and a pulsing purse at 3 (both sides see them).
func _draw_marks(at: Vector2, e: Ent) -> void:
	if not e.has_meta("marks"):
		return
	var best := 0
	for k in (e.get_meta("marks") as Dictionary):
		var mk: Array = e.get_meta("marks")[k]
		if float(mk[1]) > 0.0: best = maxi(best, int(mk[0]))
	if best <= 0:
		return
	var gold := Color("ffd23f")
	for i in 3:
		var pc := at + Vector2((i - 1) * 11.0, 0)
		c.draw_circle(pc, 4.6, Color(0, 0, 0, 0.6))
		c.draw_circle(pc, 3.6, gold if i < best else Color(1, 1, 1, 0.2))
	if best >= 3:
		var pulse := 0.5 + 0.5 * sin(m.time * 9.0)
		c.draw_circle(at + Vector2(0, -12), 7.0 + pulse * 2.0, Color(gold, 0.85))
		_ctext(at + Vector2(0, -8), "$", 11, Color(0.15, 0.1, 0.0), big)

## Little icons for what's happening to someone: stunned, rooted, slowed, burning, shielded, braced.
func _status_row(at: Vector2, e: Ent) -> void:
	var icons: Array = HudPlate.statuses(e)
	var x := at.x - icons.size() * 8.0 + 8.0
	for ic in icons:
		c.draw_circle(Vector2(x, at.y), 7.0, Color(0.03, 0.03, 0.05, 0.85))
		Icons.draw(c, String(ic[0]), Vector2(x, at.y), 4.2, ic[1])
		if float(ic[3]) > 0.0:
			_ctext(Vector2(x, at.y + 17), "%.1f" % float(ic[3]), 10, ic[1], big)
		x += 16.0

## Teammates you can't see on screen get an arrow at the screen edge (with distance, coloured by
## how they're doing; a dead teammate's deathbox in their squad colour while their soul can still be saved).
func _draw_squad_markers(sz: Vector2, p: Hunter) -> void:
	var cam := m.cam
	var inner := Rect2(Vector2(70, 90), sz - Vector2(140, 220))
	for h in m.hunters:
		if h == p or h.team != p.team:
			continue
		var st := _mate_state(h)
		var at: Vector3 = st[2]
		if at == Vector3.INF:
			continue
		var col: Color = st[1]
		var wp := at + Vector3(0, 2.4, 0)
		var dist := int(round(Vector2(at.x - p.pos.x, at.z - p.pos.z).length()))
		var behind := cam.is_position_behind(wp)
		var sp := cam.unproject_position(wp)
		if not behind and inner.has_point(sp):
			continue          # on screen: their own label (or their box's, ReviveHud) says it
		if String(st[0]) == "DEATHBOX":
			col = m.mate_col(h)
		var ctr := sz * 0.5
		var d := (sp - ctr) * (-1.0 if behind else 1.0)
		if d.length() < 1.0: continue
		d = d.normalized()
		var t := minf(inner.size.x * 0.5 / maxf(0.001, absf(d.x)), inner.size.y * 0.5 / maxf(0.001, absf(d.y)))
		var e := ctr + d * t
		var side := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([e + d * 16.0, e - d * 6.0 + side * 11.0, e - d * 6.0 - side * 11.0]), col)
		var lbl := "%s %dm" % [h.pname.substr(0, 10), dist]
		if String(st[0]) == "WISP": lbl = "%s DOWN %dm" % [h.pname.substr(0, 10), dist]
		elif String(st[0]) == "DEATHBOX": lbl = "%s's box %s" % [h.pname.substr(0, 10), st[3]]
		_ctext(e - d * 26.0 + Vector2(0, 5), lbl, 13, col, big)

## Red arcs around the middle of the screen pointing at whoever just hit you.
func _draw_hurt_dirs(sz: Vector2) -> void:
	var ctr := sz * 0.5
	for h in hurt_dirs:
		var a := clampf(1.0 - float(h["t"]) / 1.2, 0.0, 1.0)
		var ang: float = h["ang"]
		var rad := minf(sz.x, sz.y) * 0.22
		c.draw_arc(ctr, rad, ang - 0.32, ang + 0.32, 18, Color(1.0, 0.25, 0.2, 0.75 * a), 7.0, true)
		var tip := ctr + Vector2(cos(ang), sin(ang)) * (rad + 12.0)
		var nrm := Vector2(-sin(ang), cos(ang))
		c.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(cos(ang), sin(ang)) * 12.0 + nrm * 9.0, tip - Vector2(cos(ang), sin(ang)) * 12.0 - nrm * 9.0]), Color(1.0, 0.25, 0.2, 0.8 * a))

## Aboard the skyship: when to jump.
func _draw_ship_prompt(sz: Vector2) -> void:
	var left := maxf(0.0, float(m.ship.get("ride", 0.0)) - m.time)
	var w := 460.0
	var cam := m.cam
	# where you'd come down if you jumped now: a ring on the ground under the ship
	var sp: Vector3 = m.ship_pos()
	if not m.world.is_void(sp.x, sp.z):
		var g := Vector3(sp.x, m.world.ground_at(sp.x, sp.z), sp.z)
		var gp := cam.unproject_position(g)
		var top := cam.unproject_position(sp)
		var dash := 0.0
		var L := gp.distance_to(top)
		while dash < L:
			c.draw_line(top.lerp(gp, dash / L), top.lerp(gp, minf(1.0, (dash + 6.0) / L)), Color(1, 0.85, 0.4, 0.55), 2.0)
			dash += 12.0
		var pul := 1.0 + sin(m.time * 5.0) * 0.08
		c.draw_arc(gp, 22.0 * pul, 0, TAU, 40, GOLD, 3.0, true)
		c.draw_arc(gp, 8.0, 0, TAU, 20, Color(GOLD, 0.6), 2.0, true)
	var p: Hunter = m.player
	var dr: DropSquad = m.skydrop
	var lead: Hunter = dr.leader(p.team) if dr else null
	var i_lead := lead == p
	var waits: bool = dr != null and dr.waits(p)
	var squad := m.hunters.filter(func(x): return x.team == p.team).size() > 1
	var rr := Rect2(Vector2(sz.x * 0.5 - w * 0.5, 92), Vector2(w, 122 if squad else 92))
	_panel(rr, Color(0.06, 0.07, 0.1, 0.88), 14)
	if dr and dr.planning:
		_ctext(Vector2(sz.x * 0.5, rr.position.y + 36), "Plan your drop", 26, GOLD, big)
	elif waits:
		_ctext(Vector2(sz.x * 0.5, rr.position.y + 36), "%s leads the drop" % lead.pname, 26, GOLD, big)
	else:
		_ctext(Vector2(sz.x * 0.5, rr.position.y + 36), "Press %s to jump" % Settings.key_cap("jump"), 26, GOLD, big)
	var sub := "Pick your spot on the map. Everyone left aboard drops in %ds" % int(ceil(left))
	if dr and dr.planning: sub = "The ship sets off in %ds  ·  %s opens the map to ping a spot" % [int(ceil(dr.plan_t)), Settings.key_cap("map")]
	elif waits: sub = "You'll jump together and glide in behind them. %ds left aboard" % int(ceil(left))
	elif i_lead and squad: sub = "Your squad jumps with you. %ds left aboard" % int(ceil(left))
	_ctext(Vector2(sz.x * 0.5, rr.position.y + 62), sub, 14, INK)
	_bar(Rect2(Vector2(rr.position.x + 20, rr.position.y + 76), Vector2(w - 40, 4)), clampf(m.time / maxf(1.0, float(m.ship.get("ride", 1.0))), 0.0, 1.0), GOLD)
	if squad:
		# the keys for the drop, as keycaps
		var keys: Array = []
		if i_lead: keys = [["jump", "Jump"], ["pass_lead", "Pass lead"], ["map", "Map"]]
		elif waits: keys = [["separate", "Separate"], ["map", "Map"]]
		else: keys = [["jump", "Jump"], ["map", "Map"]]
		_key_row(Vector2(sz.x * 0.5, rr.position.y + 104), keys)

## A centred row of keycap prompts: [[action, label], ...].
func _key_row(center: Vector2, keys: Array) -> void:
	var parts: Array = []
	var tot := 0.0
	for kk in keys:
		var cap := Settings.key_cap(String(kk[0]))
		var cw := maxf(26.0, big.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
		var lw := body.get_string_size(String(kk[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		parts.append([cap, cw, String(kk[1]), lw])
		tot += cw + 6.0 + lw + 22.0
	var x := center.x - (tot - 22.0) * 0.5
	for pt in parts:
		var kr := Rect2(Vector2(x, center.y - 12), Vector2(pt[1], 24))
		_rounded(kr, Color(1, 1, 1, 0.12), 5, Color(1, 1, 1, 0.35), 1)
		_ctext(kr.get_center() + Vector2(0, 5), pt[0], 13, INK, big)
		_text(Vector2(kr.end.x + 6, center.y + 5), pt[2], 13, INK)
		x = kr.end.x + 6 + float(pt[3]) + 22.0

## On the way down: who leads, and what you can do about it.
func _draw_drop_prompt(sz: Vector2, p: Hunter) -> void:
	var dr: DropSquad = m.skydrop
	if dr == null or m.hunters.filter(func(x): return x.team == p.team).size() < 2:
		return
	var y := 96.0
	if dr.is_lead(p):
		var n := m.hunters.filter(func(x): return x.drop_follow == p).size()
		_ctext(Vector2(sz.x * 0.5, y), "Leading the drop" + ("  ·  %d following" % n if n > 0 else ""), 18, GOLD, big)
		if n > 0: _key_row(Vector2(sz.x * 0.5, y + 24), [["pass_lead", "Pass lead"]])
	elif p.drop_follow != null:
		_ctext(Vector2(sz.x * 0.5, y), "Following %s" % p.drop_follow.pname, 18, GOLD, big)
		_key_row(Vector2(sz.x * 0.5, y + 24), [["separate", "Separate"]])
	elif p.drop_solo:
		_ctext(Vector2(sz.x * 0.5, y), "Dropping solo", 16, Color("8fd8ff"), big)

## Squad pings out in the world: a marker over each with how far it is.
func _draw_squad_pings(p: Hunter) -> void:
	for pg in m.pings:
		if not pg.has("by") or int(pg.get("team", -1)) != p.team:
			continue
		var a := clampf(float(pg.get("life", 4.0)) - float(pg["t"]), 0.0, 1.0)
		_draw_waypoint(pg["pos"], PingInput.label(pg, p), Color(pg["col"], a))
	# a Boki's callout: a marker with what it spotted, fading after a few seconds
	for pg in m.pings:
		if not pg.has("kin") or int(pg.get("team", -1)) != p.team or m.tut != null:
			continue      # (the tutorial has one marker: no Boki callout pins)
		var kk: Kin = pg["kin"] if is_instance_valid(pg["kin"]) else null
		var a2 := clampf(float(pg.get("life", 5.0)) - float(pg["t"]), 0.0, 1.0) * clampf(float(pg["t"]) * 6.0, 0.0, 1.0)
		var who := String(kk.rec.get("name", "Boki")) if kk and kk.owner_h != p else ""
		var lbl2 := String(pg.get("label", ""))
		_draw_waypoint(pg["pos"], ("%s: %s" % [who, lbl2]) if who != "" else lbl2, Color(pg["col"], a2))

## For the first seconds of every match: what each of your buttons does.
func _draw_kit(sz: Vector2, p: Hunter) -> void:
	if not Settings.get_v("tips") or Record.clean() or m.opts.get("tutorial", false) or p.out or guide_hidden:
		return
	var show_t := 14.0 if not m.opts.get("training", false) else 1e9
	var t := m.time - kit_t0
	if p.dropping or p.riding:
		# shown once you land, not over the drop map
		kit_t0 = m.time
		return
	if t > show_t:
		return
	var a := clampf(show_t - t, 0.0, 1.0)
	var lines: Array = []
	var util: AbilityDef = p.runner.def_of("utility") if p.runner and p.ak == null else null
	if util:
		lines.append([Settings.key_cap("secondary"), util.display_name, util.desc, util.color])
	if p.ak:
		# the archetype's kit (right click, E, R) and the Boki's own ability on C; before, this listed
		# the old kin kit (E as the Boki's ability, R as the merge) for every hunter
		var ak: ArchKit = p.ak
		var rv: Dictionary = ak.rmb_def().get("variants", {})
		var rdesc := "Tap: %s" % String(rv.get("tap", "")) if rv.has("tap") else ""
		if rv.has("hold"): rdesc += "  Hold: %s" % String(rv["hold"])
		lines.append([Settings.key_cap("secondary"), String(ak.rmb_def().get("name", "Right click")), rdesc, ak.col_of(ak.rmb_def())])
		lines.append([Settings.key_cap("signature"), String(ak.e_def().get("name", "E")), String(ak.e_def().get("desc", "")), ak.col_of(ak.e_def())])
		lines.append([Settings.key_caps("hunter_ult"), String(ak.r_def().get("name", "Ultimate")) + ("" if p.lvl >= int(Hunter.ULT_AT[0]) else "  (level %d)" % int(Hunter.ULT_AT[0])), String(ak.r_def().get("desc", "")), ak.col_of(ak.r_def())])
	if p.kin and p.ak:
		var k: Kin = p.kin
		var kcol: Color = Data.KIN[k.species]["color"]
		var kd1: AbilitySpec = k.runner.def_of("k1")
		if kd1: lines.append(["Auto", kd1.display_name + " (" + String(k.rec.get("name", "your Boki")) + ")", KinText.ability(k.effective("k1")), KinText.color(kd1)])
		lines.append([Settings.key_cap("throw"), "Orders for " + String(k.rec.get("name", "your Boki")), "Tap: Sic at the cursor (it staggers what it lands on), or call it back when it is away. Hold and flick: Chase, Guard, Return, Follow.", kcol])
	elif p.kin:
		var k: Kin = p.kin
		var kcol: Color = Data.KIN[k.species]["color"]
		var kd1: AbilitySpec = k.runner.def_of("k1")
		if kd1: lines.append([Settings.key_cap("signature"), kd1.display_name, KinText.ability(k.effective("k1")), KinText.color(kd1)])
		var ud := KinMerge.def_for(k)
		if ud: lines.append([Settings.key_caps("ultimate"), ud.display_name + " (Fusion)", " ".join(KinText.merge(ud, k.carry_style() == "mount")) + " Fusion: needs a full bond meter. Unlocks at level %d." % int(Hunter.ULT_AT[0]), GOLD])
		lines.append([Settings.key_cap("throw"), "Orders for " + String(k.rec.get("name", "your Boki")), "Tap: Sic at the cursor (it staggers what it lands on), or call it back when it is away. Hold and flick: Chase, Guard, Return, Follow.", kcol])
	var dsi := p.slot_info("dash")
	lines.append([Settings.key_cap("dash"), String(dsi["name"]), String(dsi["desc"]), dsi["col"]])
	lines.append_array(GripHud.kit_lines(p))
	var w := 356.0
	# each row: the key and name, then the description wrapped to the panel
	var hs: Array = []
	var total := 34.0
	for l in lines:
		var dh := body.get_multiline_string_size(String(l[2]), HORIZONTAL_ALIGNMENT_LEFT, w - 28, 12).y
		hs.append(26.0 + dh + 8.0)
		total += 26.0 + dh + 8.0
	var bottom := sz.y - 176.0
	var compact := false
	if not m.opts.get("training", false) and total > bottom - 230.0:
		# too tall to sit under the kill feed: names only
		compact = true
		hs = []
		for l in lines: hs.append(28.0)
		total = 34.0 + 28.0 * lines.size() + 4.0
	var box := Rect2(Vector2(sz.x - w - 16, bottom - total), Vector2(w, total))
	if m.opts.get("training", false):
		# in training it stays up, so it lives on the left under the minimap, clear of the checklist;
		# on a short screen it drops the descriptions rather than run into your kin card
		box.position = Vector2(16, 240)
		if total > sz.y - 240 - 196:
			compact = true
			hs = []
			for l in lines: hs.append(28.0)
			total = 34.0 + 28.0 * lines.size() + 4.0
		box.size.y = total
	_panel(box, Color(0.06, 0.07, 0.1, 0.82 * a), 12)
	_text(box.position + Vector2(14, 22), "Your kit", 14, Color(GOLD, a), big)
	var y := box.position.y + 34
	for i in lines.size():
		var l: Array = lines[i]
		var kw := big.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var ks := StyleBoxFlat.new(); ks.bg_color = Color(l[3], a); ks.set_corner_radius_all(5)
		c.draw_style_box(ks, Rect2(Vector2(box.position.x + 14, y), Vector2(kw + 12, 20)))
		c.draw_string(big, Vector2(box.position.x + 20, y + 15), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.07, 0.06, 0.08, a))
		_text(Vector2(box.position.x + 34 + kw, y + 15), l[1], 14, Color(INK, a))
		if not compact:
			c.draw_multiline_string(body, Vector2(box.position.x + 14, y + 38), String(l[2]), HORIZONTAL_ALIGNMENT_LEFT, w - 28, 12, -1, Color(MUTED, a))
		y += float(hs[i])

## Perks you've picked up this run: a row of little badges over your health bar, with stacks.
func _draw_perks(sz: Vector2, p: Hunter) -> void:
	if p.perks.is_empty():
		return
	var seen: Array = []
	for pk in p.perks:
		if not seen.has(pk): seen.append(pk)
	var bs := 26.0
	var x := sz.x * 0.5 - (seen.size() * (bs + 6.0)) * 0.5
	var y := sz.y - 50.0
	for pk in seen:
		var pd: Dictionary = Data.PERKS[pk]
		var r := Rect2(Vector2(x, y), Vector2(bs, bs))
		hover_spots.append([r, "perk:" + String(pk)])
		_rounded(r, Color(0.05, 0.06, 0.09, 0.9), 7, Color(pd["col"], 0.8), 1)
		Icons.draw(c, String(pd["icon"]), r.get_center(), bs * 0.3, pd["col"])
		var n := p.perk_n(pk)
		if n > 1:
			_text(r.position + Vector2(bs - 7, bs + 1), str(n), 11, INK, big)
		x += bs + 6.0

func _draw_prompt(sz: Vector2, p: Hunter) -> void:
	var it := m.interact
	var y := TutorialHud.prompt_y(self, sz)
	if not it.is_empty():
		var prog := 0.0
		match it["kind"]:
			"revive": prog = it["ent"].revive
			"finish": prog = p.finish_t / Life.R["stomp_commit"]
			"stomping": prog = float(p.stomp.get("t", 0.0)) / Life.R["stomp_time"]
			"boxrev": prog = p.box_t / BoxRevive.time_for(it["box"]["owner"])
			"loot": prog = p.box_t / Life.R["loot_time"]
			"catch": prog = CaptureHud.progress(p)
			"chest": prog = it["chest"]["prog"]
			"exit": prog = float(it["x"]["hold"].get(p.nid, 0.0)) / float(it["need"]) if it.has("need") else 0.0
			"lair": prog = float(it["rune"]["prog"]) if it.has("rune") else 0.0
		var s: String = it["label"]
		var w := body.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_panel(Rect2(Vector2(sz.x * 0.5 - w * 0.5 - 16, y - 22), Vector2(w + 32, 32)))
		_ctext(Vector2(sz.x * 0.5, y), s, 16, it.get("col", GOLD))
		if prog > 0.0:
			_bar(Rect2(Vector2(sz.x * 0.5 - w * 0.5 - 16, y + 12), Vector2(w + 32, 4)), prog, GOLD)
	var st: Dictionary = m.exits.status_for(p) if m.exits else {}
	if not st.is_empty():
		_ctext(Vector2(sz.x * 0.5, sz.y * 0.2), String(st["text"]), 24, st["col"], big)
		_bar(Rect2(Vector2(sz.x * 0.5 - 140, sz.y * 0.2 + 12), Vector2(280, 8)), clampf(float(st["prog"]), 0.0, 1.0), st["col"])

func _draw_crosshair(p: Hunter) -> void:
	var mp := c.get_local_mouse_position()
	# the reticle (the player's style) opens with per-shot bloom and the minigun's spread
	var spread := p.recoil * 4.0 + p.wbloom * 1.2
	if p.wpn.has("tighten_from_deg") and p.spin > 0.0:
		spread += lerpf(12.0, 0.0, clampf(p.spun_t / float(p.wpn.get("tighten_time", 1.5)), 0.0, 1.0))
	Reticle.draw(c, mp, spread)
	if p.ak and p.ak.has_meter():
		# the archetype resource as an arc hugging the crosshair
		var rf := p.ak.res_frac()
		var rc := p.ak.res_col()
		c.draw_arc(mp, Reticle.RES_R, PI * 1.62, PI * 1.62 + PI * 0.76, 24, Color(0, 0, 0, 0.35), 3.0, true)
		if rf > 0.0:
			c.draw_arc(mp, Reticle.RES_R, PI * 1.62, PI * 1.62 + PI * 0.76 * rf, 24, Color(rc, 0.95 if p.ak.tell == "full" else 0.7), 3.0 if p.ak.tell == "full" else 2.0, true)
		# the payoff is armed (DEADEYE, FLASHPOINT, CALLED SHOT, SLAM): a pulsing word under the arc
		var rl := p.ak.ready_label()
		if rl != "":
			var pk := 0.5 + 0.5 * sin(m.time * 9.0)
			_ctext(mp + Vector2(0, Reticle.RES_R + 16.0), rl, 13, Color(rc.lightened(0.2), 0.75 + 0.25 * pk), big)
	# aiming at a truce partner: a reminder before you break it
	if m.truce and not m.truce.pacts.is_empty():
		var ph: Hunter = m.truce.partner_at(p.inp["aim"], p.team)
		if ph and not ph.unseen:
			_flag(mp + Vector2(-58, 30), 0.7, Color("f4f1e6"))
			_ctext(mp + Vector2(6, 36), "Truce with %s  ·  shooting breaks it" % ph.pname, 13, Color("f4f1e6"), big)
	var ck := p.charge_k()
	if ck > 0.0:
		# a sword's charge: fills, then flashes when it's ready to release
		var full := ck >= 1.0
		_arc(mp, Reticle.CHARGE_R, ck, Color("fff3b0") if not full or int(m.time * 10.0) % 2 == 0 else Color.WHITE, 4.0 if full else 3.0)
	elif p.warm_t > 0.0:
		_arc(mp, Reticle.CHARGE_R, 1.0 - p.warm_t / maxf(0.01, float(p.wpn.get("warmup", 0.6))), p.wpn["color"], 3.0)
	elif p.wpn.has("spin_up") and p.spin > 0.0 and p.spin < 1.0:
		_arc(mp, Reticle.CHARGE_R, p.spin, Color("ffb34d"), 3.0)
	elif p.wpn.get("melee", false):
		pass
	elif p.reload_t > 0.0:
		_arc(mp, Reticle.CHARGE_R, 1.0 - p.reload_t / float(p.wpn["reload"]), Color("ffe7a8"), 3.0)
	else:
		# ammo left, as a thin ring that empties as you fire
		var af := float(p.ammo) / maxf(1.0, float(p.wpn["mag"]))
		c.draw_arc(mp, Reticle.AMMO_R, PI * 0.62, PI * 0.62 + PI * 0.76, 24, Color(0, 0, 0, 0.35), 3.0, true)
		c.draw_arc(mp, Reticle.AMMO_R, PI * 0.62, PI * 0.62 + PI * 0.76 * af, 24, Color(1, 1, 1, 0.75) if af > 0.25 else Color(HP_LOW, 0.9), 2.0, true)
	if hit_t > 0.0:
		var hc := Color("ffd23f") if hit_crit else Color.WHITE
		if hit_armor: hc = ARMOR_COL if not hit_crit else Color("cfefff")
		# a sharp X that snaps out and settles: bigger and bolder on crits, dark-edged so it reads
		# over bright effects
		var k := hit_t / 0.14
		var s := (11.0 if not hit_crit else 15.0) + (1.0 - k) * 3.0 + k * k * 4.0
		var w := 3.0 if not hit_crit else 4.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			c.draw_line(mp + d * 5.0, mp + d * s, Color(0.05, 0.03, 0.08, 0.65 * minf(1.0, k * 2.0)), w + 2.0)
			c.draw_line(mp + d * 5.0, mp + d * s, Color(hc, minf(1.0, k * 2.5)), w)

func _draw_downed(sz: Vector2, p: Hunter) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.3, 0.02, 0.02, 0.18))
	_ctext(Vector2(sz.x * 0.5, sz.y * 0.32), "You're down", 34, BAD, big)
	var left := p.down_hp / Data.MATCH["down_hp"] * Life.R["bleed_out"]
	var who := "You're a wisp: %ds left. A teammate or your Boki standing on you brings you back. Enemies can stomp or execute you." % int(ceil(left))
	if p.kin and p.kin.state == "downed":
		who = "You're a wisp: %ds left, and your Boki is down. Only a teammate standing on you can bring you back." % int(ceil(left))
	var stomped: bool = p.get_meta("stomped", false)
	if stomped:
		var sts: Array = p.get_meta("stompers", [])
		who = "%s is on you! You're pinned and draining %.1fx faster. Drift away!" % [(sts[0] as Hunter).pname if not sts.is_empty() else "An enemy", Life.R["stomp_mult"]]
		_edge_pulse(sz, Color(1.0, 0.1, 0.05), 0.35 + 0.3 * (0.5 + 0.5 * sin(m.time * 9.0)))
	_ctext(Vector2(sz.x * 0.5, sz.y * 0.32 + 28), who, 16, Color("ff7a6a") if stomped else INK)
	_bar(Rect2(Vector2(sz.x * 0.5 - 140, sz.y * 0.32 + 44), Vector2(280, 8)), p.down_hp / Data.MATCH["down_hp"], Color("ff2a1a").lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(m.time * 14.0))) if stomped else BAD)
	if p.revive > 0.0:
		_bar(Rect2(Vector2(sz.x * 0.5 - 140, sz.y * 0.32 + 58), Vector2(280, 8)), p.revive, GOOD)
		var revs: Array = p.get_meta("revivers", [])
		if not revs.is_empty():
			_ctext(Vector2(sz.x * 0.5, sz.y * 0.32 + 84), "%s is reviving you  %d%%" % [(revs[0] as Hunter).pname, int(p.revive * 100.0)], 15, GOOD, big)

## Dead, but your team's still in it.
func _draw_dead(sz: Vector2, p: Hunter) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.03, 0.08, 0.25))
	var y0 := sz.y * 0.62
	var b := Life.box_of(m, p)
	var lines: Array = []
	# your Boki left on the map, still there for anyone to scan (the game's hook: say it plainly)
	var left_line := ""
	for L in m.player_lost:
		var lk = L.get("kin")
		var kn := String((L.get("rec", {}) as Dictionary).get("name", "Your Boki"))
		if lk != null and is_instance_valid(lk) and not (lk as Kin).dead and KinLoss.guarding(lk):
			left_line = "%s is guarding your box: get revived and run into it, or a rival can scan it" % kn
	if left_line != "":
		y0 = sz.y * 0.58
		_ctext(Vector2(sz.x * 0.5, y0 - 64), left_line, 20, GOLD, big)
	if not b.is_empty() and Life.soul_here(m, b):
		lines.append("A teammate can bring you back at your deathbox: %ds left." % int(ceil(float(b["soul_until"]) - m.time)))
	lines.append("Or at any revive beacon (the green pillars), with nothing you carried." if m.beacons.any(func(x): return not x["used"]) else "No revive beacons left.")
	var mate := m.spectating()
	if mate:
		lines.append("Watching %s." % mate.pname)
	lines.append("%s to open the menu and leave." % Settings.key_cap("menu"))
	_panel(Rect2(Vector2(sz.x * 0.5 - 300, y0 - 44), Vector2(600, 62 + lines.size() * 22)))
	_ctext(Vector2(sz.x * 0.5, y0), "You're dead", 30, BAD, big)
	for i in lines.size():
		_ctext(Vector2(sz.x * 0.5, y0 + 28 + i * 22), lines[i], 16, INK if i < 2 else MUTED)

func _draw_scores(sz: Vector2) -> void:
	var r := Rect2(Vector2(sz.x * 0.5 - 300, sz.y * 0.18), Vector2(600, 40 + m.hunters.size() * 28))
	_panel(r, Color(0.05, 0.06, 0.09, 0.9), 14)
	_text(r.position + Vector2(20, 30), "Hunter", 14, MUTED); _text(r.position + Vector2(260, 30), "Boki", 14, MUTED)
	_text(r.position + Vector2(380, 30), "Knocks", 14, MUTED); _text(r.position + Vector2(450, 30), "Damage", 14, MUTED); _text(r.position + Vector2(530, 30), "State", 14, MUTED)
	var hs := m.hunters.duplicate()
	hs.sort_custom(func(a, b): return a.team < b.team)
	var y := r.position.y + 58
	for h in hs:
		var tc: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
		c.draw_rect(Rect2(Vector2(r.position.x + 12, y - 14), Vector2(4, 18)), tc)
		_text(Vector2(r.position.x + 22, y), HeroTitle.of_hunter(h), 15, INK if h != m.player else GOLD)
		if h.kin: _text(Vector2(r.position.x + 260, y), Data.KIN[h.kin.species]["name"], 14, Data.KIN[h.kin.species]["color"])
		_text(Vector2(r.position.x + 392, y), str(h.knocks), 15)
		_text(Vector2(r.position.x + 456, y), str(int(h.dmg_done)), 15)
		var st := "Out" if h.out else ("Extracted" if h.extracted else ("Down" if h.downed else "Alive"))
		_text(Vector2(r.position.x + 530, y), st, 14, BAD if h.out else (Color("8fe3c8") if h.extracted else INK))
		y += 28

var abyss_cued := false
var abyss_warned := false
var abyss_a := 0.0
const ABYSS_FX := preload("res://scripts/match/abyss_fx.gd")
var abyss_fx: CanvasLayer = null


## A point `up` metres above a hunter's feet, following the body's lean toward the camera
## (CamRig.char_lean), so bars and names stay just over the head.
func _head(h: Node3D, up: float) -> Vector3:
	return h.position + (m.cam.char_lean() * Vector3(0, up, 0) if m.cam else Vector3(0, up, 0))

## Health right above your hunter, where your eyes already are.
func _draw_overhead(p: Hunter) -> void:
	var cam := m.cam
	var at := _head(p, 2.7 * float(p.cdat["scale"]))
	if cam.is_position_behind(at) or p.downed or p.riding:
		return
	var sp := cam.unproject_position(at)
	var vr: Rect2 = cam.get_viewport().get_visible_rect().grow(200.0)
	if not sp.is_finite() or not vr.has_point(sp):
		return      # off screen, or a degenerate camera (headless, mid-teleport): huge/NaN coords can't triangulate
	sp = sp.round()     # whole pixels: the bars and pips don't shimmer as the camera glides
	var w := HudStyle.PLATE_W_SELF
	plates.draw_self(self, sp, p)
	# high up: a small readout of how far above the ground you are
	var alt := m.player_altitude() if p == m.player else 0.0
	if alt > 6.0 and not p.grounded:
		_ctext(sp + Vector2(-w * 0.5 - 30, 8), "%dm" % int(round(alt)), 13, Color("bfe6ff"), big)
		c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-w * 0.5 - 30, -10), sp + Vector2(-w * 0.5 - 35, -3), sp + Vector2(-w * 0.5 - 25, -3)]), Color("bfe6ff"))
	if p.reload_t > 0.0:
		# reloading: a filling ring beside your head, and the word under your bars
		var rf := 1.0 - p.reload_t / float(p.wpn["reload"])
		var rc := sp + Vector2(w * 0.5 + 16, 4)
		c.draw_circle(rc, 11.0, Color(0.04, 0.04, 0.06, 0.75))
		c.draw_arc(rc, 8.0, 0, TAU, 24, Color(1, 1, 1, 0.15), 3.0, true)
		_arc(rc, 8.0, rf, Color("ffe7a8"), 3.0)
		_ctext(sp + Vector2(0, 33), "RELOADING", 11, Color("ffe7a8"), big)
	if p.drink_t > 0.0:
		var df := 1.0 - p.drink_t / Hunter.DRINK_TIME
		var dc := sp + Vector2(-w * 0.5 - 16, 4)
		c.draw_circle(dc, 11.0, Color(0.04, 0.04, 0.06, 0.75))
		_arc(dc, 8.0, df, Color("8ff0a0"), 3.0)
		_ctext(sp + Vector2(0, 33 if p.reload_t <= 0.0 else 46), "DRINKING", 11, Color("8ff0a0"), big)
	if p.kit_t > 0.0:
		var kf := 1.0 - p.kit_t / Hunter.KIT_TIME
		var kc := sp + Vector2(-w * 0.5 - 16, 4)
		c.draw_circle(kc, 11.0, Color(0.04, 0.04, 0.06, 0.75))
		_arc(kc, 8.0, kf, ARMOR_COL, 3.0)
		_ctext(sp + Vector2(0, 33 if p.reload_t <= 0.0 else 46), "REPAIRING", 11, ARMOR_COL, big)

# ------------------------------------------------------------------ hover tips
## Point at anything on the bottom bar (abilities, health, weapon, kin) to see what it is.
func _draw_hover_tip(sz: Vector2, p: Hunter) -> void:
	var mp := c.get_local_mouse_position()
	var hit: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hover="):      # test hook: point at a HUD element
			for hs in hover_spots:
				if hs[1] == arg.substr(8): mp = (hs[0] as Rect2).get_center()
	for hs in hover_spots:
		if (hs[0] as Rect2).has_point(mp):
			hit = hs
	var id: String = hit[1] if hit.size() > 0 else ""
	if id != hover_id:
		hover_id = id
		hover_t = 0.0
	hover_t += get_process_delta_time()
	if id == "" or hover_t < 0.25:
		return
	var lines := _tip_lines(id, p)
	if lines.is_empty():
		return
	# [title, colour] then rows of [text, colour, size]
	var head: Array = lines[0]
	var w := 340.0
	var h := 40.0
	for i in range(1, lines.size()):
		h += _wrapped_h(String(lines[i][0]), w - 28, int(lines[i][2])) + 4.0
	var anchor: Rect2 = hit[0]
	var pos := HudTip.place(anchor, Vector2(w, h), sz)      # above if it fits, else beside; always on screen, never over the slot
	var a := clampf((hover_t - 0.25) / 0.12, 0.0, 1.0)
	var box := Rect2(pos, Vector2(w, h))
	_rounded(box, Color(0.05, 0.06, 0.09, 0.95 * a), 12, Color(head[1], 0.6 * a), 2)
	_text(pos + Vector2(14, 26), String(head[0]), 17, Color(head[1], a), big)
	var y := pos.y + 40
	for i in range(1, lines.size()):
		var ln: Array = lines[i]
		var fs := int(ln[2])
		var hh := _wrapped_h(String(ln[0]), w - 28, fs)
		c.draw_multiline_string(body, Vector2(pos.x + 14, y + fs), String(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, w - 28, fs, -1, Color(ln[1], a))
		y += hh + 4.0

func _wrapped_h(txt: String, w: float, fs: int) -> float:
	return body.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y

func _secs(x: float) -> String:
	return ("%ds" % int(x)) if absf(x - round(x)) < 0.05 else ("%.1fs" % x)

## Hover text for an archetype's slots (and the kin's own ability on C, send/recall on G).
func _arch_tip(id: String, p: Hunter) -> Array:
	var out: Array = []
	var k: Kin = p.kin
	match id:
		"kin_ab":
			if k == null or k.runner.def_of("k1") == null: return []
			var kd: AbilitySpec = k.runner.def_of("k1")
			out.append([kd.display_name, KinText.color(kd)])
			out.append(["%s's own ability  ·  it casts it by itself" % k.rec.get("name", "Boki"), MUTED, 12])
			out.append([KinText.ability(k.effective("k1")), INK, 14])
			out.append(["Cooldown %s%s" % [_secs(kd.cooldown), ("  ·  ready in %s" % _secs(k.runner.cd_left("k1"))) if not k.runner.is_ready("k1") else "  ·  ready"], MUTED, 13])
			return out
		"throw":
			if k == null: return []
			out.append(["Send / recall", Color("cfe8ff")])
			out.append(["%s  ·  tap: Sic %s at the cursor, or Call it back when it is away (it hits what it passes). Hold: Chase, Guard, Return or Follow. A downed Boki stays where it fell: run into it to bring it back." % [Settings.key_cap("throw"), k.rec.get("name", "your Boki")], INK, 13])
			return out
	var si := p.slot_info(id)
	var r_name := "Ultimate (%s)" % Settings.key_cap("hunter_ult")
	var slot_names := {"sec": "Right click", "k1": "Utility (E)", "r": r_name, "dash": "Dash"}
	var slot_name: String = slot_names[id]
	var key: String = {"sec": "secondary", "k1": "signature", "r": "hunter_ult", "dash": "dash"}[id]
	out.append([String(si["name"]), si["col"]])
	out.append(["%s %s  ·  %s  ·  %s" % [Arch.name_of(p.arch), slot_name, Settings.key_cap(key), p.rank_text({"sec": "sec", "k1": "k1", "r": "r", "dash": "dash"}[id])], MUTED, 12])
	out.append([String(si["desc"]), INK, 13])
	# what the next rank does, concretely (rank 2 when you're rank 1), then rank 3's special after it
	var sk: String = {"sec": "sec", "k1": "kin", "r": "ult", "dash": "dash"}[id]
	var nr := Arch.next_ranks(p.arch, sk, int(p.slot_lv.get(sk, 0)))
	for i in nr.size():
		out.append(["%s%s: %s" % ["Next  ·  " if i == 0 else "", String(nr[i][0]), String(nr[i][1])], Color(si["col"], 0.95 if i == 0 else 0.7), 12])
	if id == "r":
		out.append(["Unlocks at level %d, rank 2 at %d. " % [int(Hunter.ULT_AT[0]), int(Hunter.ULT_AT[1])], MUTED, 12])
	if id == "sec":
		var rd := p.ak.res_def()
		out.append(["Passive: %s" % String(p.ak.d["passive"]["desc"]), Color(Color(String(rd.get("col", "#ffffff"))), 0.9), 12])
	out.append(["Cooldown %s%s" % [_secs(float(si["cd_max"])), ("  ·  ready in %s" % _secs(float(si["cd"]))) if float(si["cd"]) > 0.0 else "  ·  ready"], MUTED, 13])
	return out

func _tip_lines(id: String, p: Hunter) -> Array:
	var hc: Color = p.accent()
	var out: Array = []
	if id.begins_with("perk:"):
		var pd: Dictionary = Data.PERKS.get(id.substr(5), {})
		if not pd.is_empty():
			var n := p.perk_n(id.substr(5))
			out.append([String(pd["name"]) + ("  x%d" % n if n > 1 else ""), pd["col"]])
			out.append([String(pd["desc"]), INK])
			out.append(["Found this expedition. Gone when it ends.", MUTED])
		return out
	if id.begins_with("gslot:"):
		return GearPanel.tip(p, int(id.substr(6)))
	if p.ak and id in ["sec", "k1", "r", "dash", "kin_ab", "throw"]:
		return _arch_tip(id, p)
	match id:
		"sec" when p.runner and p.runner.def_of("utility") != null:
			var u: AbilityDef = p.runner.def_of("utility")
			out.append([u.display_name, u.color])
			out.append(["Weapon utility (%s)  ·  %s" % [String(p.wpn.get("name", "")), Settings.key_cap("secondary")], MUTED, 12])
			out.append([u.desc, INK, 14])
			out.append(["Cooldown %s%s" % [_secs(u.cooldown), ("  ·  ready in %s" % _secs(p.runner.cd_left("utility"))) if not p.runner.is_ready("utility") else "  ·  ready"], MUTED, 13])
		"k1", "k2":
			var k: Kin = p.kin
			if k == null: return []
			var kd: AbilitySpec = k.runner.def_of(id)
			if kd == null: return []
			out.append([kd.display_name, KinText.color(kd)])
			out.append(["%s's ability  ·  %s" % [k.rec.get("name", "Boki"), "its own" if p.ak or id != "k1" else Settings.key_cap("signature")], MUTED, 12])
			out.append([KinText.ability(k.effective(id)), INK, 14])
			var where := "Your Boki casts it; while it rides with you, you do." if kd.from == "kin" else "Works on you wherever your Boki is."
			out.append(["Cooldown %s%s. %s" % [_secs(kd.cooldown / maxf(0.1, k.runner.rate)), ("  ·  ready in %s" % _secs(k.runner.cd_left(id))) if not k.runner.is_ready(id) else "  ·  ready", where], MUTED, 13])
			if id == "k1" and kd.cue != null:
				out.append(["Your Boki can also use it on its own (turn that on in Settings).", Color(KinText.color(kd), 0.85), 12])
			var ka: AbilitySpec = k.runner.def_of("k2")
			if id == "k1" and ka:
				out.append(["%s: %s. %s" % [ka.display_name, KinText.when(ka), KinText.ability(k.effective("k2"))], KinText.color(ka), 12])
		"r":
			var ud := KinMerge.def_for(p.kin) if p.kin else null
			if ud == null: return []
			var giant: bool = (p.kin as Kin).carry_style() == "mount"
			out.append([ud.display_name, GOLD])
			out.append(["Fusion  ·  %s  ·  %s" % [Settings.key_caps("ultimate"), "your mount grows giant" if giant else "you take its colour and power"], MUTED, 12])
			for ln in KinText.merge(ud, giant):
				out.append([String(ln), INK, 13])
			out.append(["Unlocks at level %d with a full meter. The bond fills as your Boki lands hits, as you hit what it marked, and on combos. Boki out? It comes back to you first. No Boki: a weak surge. Then %ss before it can go again." % [int(Hunter.ULT_AT[0]), KinText.n(KinParts.MERGE_SPENT_TIME)], GOLD, 12])
		"swap":
			var b: Kin = p.kin2
			if b == null: return []
			out.append(["Swap to %s" % b.rec.get("name", "your other Boki"), Data.KIN[b.species]["color"]])
			out.append(["Second Boki  ·  %s" % Settings.key_cap("swap_kin"), MUTED, 12])
			var names := []
			for sl in ["k1", "k2"]:
				var bd: AbilitySpec = b.runner.def_of(sl)
				if bd: names.append(bd.display_name)
			var bu := KinMerge.def_for(b)
			out.append(["Brings out %s: %s, and %s as its bond ultimate. The Boki you swap out rests and heals." % [Data.KIN[b.species]["name"], " and ".join(names), bu.display_name if bu else "its ultimate"], INK, 14])
		"kin":
			var k: Kin = p.kin
			if k == null: return []
			var ai := k.brain
			out.append([Data.kin_title(String(k.rec.get("name", "")), String(Data.KIN[k.species]["name"])), Data.KIN[k.species]["color"]])
			out.append(["Level %d  ·  %d / %d health  ·  trust %d" % [int(k.rec.get("level", 1)), int(ceil(k.hp)), int(k.max_hp), int(k.trust)], MUTED, 12])
			var traits := []
			if ai.aggression > 0.6: traits.append("aggressive: chases foes far")
			if ai.loyalty > 0.65: traits.append("loyal: stays by you and goes after whoever hurts you")
			if ai.caution > 0.55: traits.append("cautious: backs off when hurt")
			if traits.is_empty(): traits.append("steady: a bit of everything")
			out.append(["In a fight it's " + "; ".join(traits) + ".", INK, 14])
			if k.ks:
				out.append([KinText.carry(k.ks), KinRules.cat_color("sustain"), 13])
				var ob := KinText.owner_bonus(p.kin_bonus)
				if ob != "":
					out.append(["Owner bonus for the run: " + ob, GOLD, 13])
		"gear0", "gear1": out = GripHud.tip(p, int(id.substr(4)))
		"x": out = HunterUltTile.tip(p)
		"throw": return BokiHud.order_tip(self, p)
		"dash":
			var dd: AbilityDef = p.dodge_def
			out.append([dd.display_name if dd else "Dash", dd.color if dd else Color("bfe6ff")])
			out.append(["Dodge  ·  %s" % Settings.key_cap("dash"), MUTED, 12])
			out.append([dd.desc if dd else "A quick burst the way you're moving.", INK, 14])
			out.append(["%d of %d charges. One comes back every %s." % [int(floor(p.dashes)), int(p.max_dashes()), _secs(p.dash_regen())], MUTED, 13])
		"util1", "util2", "util3", "util4": out = BeltHud.tip(p, int(id.substr(4)) - 1)
		"armor_level": out = ArmorHud.tip(p)
		"base":
			out.append(["Base to a teammate", Color("8fe3c8")])
			out.append(["Squads  ·  %s" % Settings.key_cap("base"), MUTED, 12])
			out.append(["A 3s channel to the teammate nearest your cursor. Stand still: moving, attacking or any damage interrupts it. You arrive weakened for 3s: half damage, and your crowd control, healing and shields are halved.", INK, 14])
			out.append(["Cooldown %ds%s" % [int(Hunter.BASE_CD), ("  ·  ready in %ds" % int(ceil(p.base_cd))) if p.base_cd > 0.0 else "  ·  ready"], MUTED, 13])
		"pack":
			var pack_tip := Backpacks.tip(p)
			out.append(pack_tip[0])
			out.append(["Open  ·  %s" % Settings.key_cap("inventory"), MUTED, 12])
			out.append(pack_tip[1])
		"weapon":
			var wp: Dictionary = p.wpn
			out.append([wp["name"], Color("e6dccb")])
			out.append(["Your signature weapon  ·  reloads by itself when empty", MUTED, 12])
			var ups := WeaponUps.summary(p)
			if ups != "":
				out.append([ups, GOOD, 13])
			var rate := 1.0 / maxf(0.01, float(wp["rate"]))
			out.append(["%.0f damage a shot  ·  %.1f shots a second  ·  about %d damage a second" % [float(wp["dmg"]), rate, int(float(wp["dmg"]) * rate)], INK, 14])
			out.append(["Magazine %d  ·  reload %s  ·  range %d tiles" % [int(wp["mag"]), _secs(float(wp["reload"])), int(float(wp.get("range", 10.0)))], MUTED, 13])
			out.append(["It's the one weapon you carry; level-ups, chests and tunings on the ground make it stronger.", MUTED, 12])
		"vitals":
			out.append([Arch.label(p.arch), hc])
			out.append(["Speed %.1f  ·  %s" % [p.base_speed, String(p.cdat.get("desc", ""))], MUTED, 12])
			out.append(["Health %d / %d   ·   Armor %d / %d" % [int(ceil(p.hp)), int(p.max_hp), int(ceil(p.armor)), int(p.max_armor)], INK, 14])
			out.append(["Level %d  ·  %s" % [p.lvl, LevelGrowth.tip(p)], GOLD, 13])
			out.append(["Armor takes 20% off every hit until it wears out. Neither armor nor health comes back on its own: use armor kits and tonics.", MUTED, 13])
			if p.lives < 50:
				out.append(["Lives left: %d" % p.lives, Color("ff7a8a"), 13])
	var rk := p.rank_text(id)
	if rk != "" and not out.is_empty():
		out.append([rk, GOLD, 12])
	return out

## Point the cursor at a monster, a kin or another hunter to see what it is.
## A rival kin's kit in one or two lines: its ability names and what each does, so you learn the
## counters by looking (the kin's species always means the same kit).
## Read from its parts (KinText), coloured by effect category: damage, control, sustain, utility.
func _kit_lines(lines: Array, k: Kin) -> void:
	if k == null or k.runner == null:
		return
	for slot in ["k1", "k2"]:
		var d: AbilitySpec = k.runner.def_of(slot)
		if d == null: continue
		var tag := "E" if slot == "k1" else "auto"
		lines.append(["%s  %s: %s" % [tag, d.display_name, KinText.ability(k.effective(slot))], KinText.color(d).lightened(0.2)])
	var ms := KinMerge.def_for(k)
	if ms:
		var ml: Array = KinText.merge(ms, k.carry_style() == "mount")
		var first := String(ml[0]) if not ml.is_empty() else ""
		lines.append(["%s  %s: %s" % [Settings.key_cap("ultimate"), ms.display_name, first], Color(GOLD, 0.95)])
	if k.ks:
		lines.append([KinText.carry(k.ks), Color(KinRules.cat_color("sustain"), 0.9)])

var _wh_mp := Vector2.ZERO
var _wh_still := 0.0
func _draw_world_hover(sz: Vector2, p: Hunter) -> void:
	var mp := c.get_local_mouse_position()
	var cam := m.cam
	# only once the cursor rests a moment and you aren't fighting: in a fight you aim at things all the
	# time and a card popped up over every target (and never while recording)
	if mp.distance_to(_wh_mp) > 6.0 or Input.is_action_pressed("fire") or Input.is_action_pressed("secondary"):
		_wh_still = 0.0
	_wh_mp = mp
	_wh_still += get_process_delta_time()
	var testing := "--hover-rival" in OS.get_cmdline_user_args() or "--hover" in OS.get_cmdline_user_args()
	if (Record.clean() or _wh_still < 0.4) and not testing:
		return
	if "--hover-rival" in OS.get_cmdline_user_args():
		# test hook: point at the nearest rival hunter (or their kin, with --hover-rival-kin)
		var nb: Ent = null; var nd := 1e9
		for e0 in (m.kins if "--hover-rival-kin" in OS.get_cmdline_user_args() else m.hunters):
			if e0 != p and e0.team != p.team and not e0.dead and e0.visible and p.flat_dist(e0) < nd and not (e0 is Kin and (e0 as Kin).state == "shoulder"):
				nd = p.flat_dist(e0); nb = e0
		if nb and not cam.is_position_behind((nb as Node3D).position):
			mp = cam.unproject_position((nb as Node3D).position + Vector3(0, 0.7, 0))
	var best: Ent = null; var bd := 46.0
	var cands: Array = []
	for mb in m.mobs:
		if not mb.dead and mb.visible: cands.append(mb)
	for k in m.kins:
		if not k.dead and k.visible and k.state != "shoulder": cands.append(k)
	for h in m.hunters:
		if h != p and not h.out and not h.extracted and not h.unseen and h.visible: cands.append(h)
	for e in cands:
		var ep: Vector3 = (e as Node3D).position + Vector3(0, 0.7, 0)
		if cam.is_position_behind(ep):
			continue
		var d := cam.unproject_position(ep).distance_to(mp)
		if d < bd: bd = d; best = e
	if best == null:
		return
	var lines: Array = []
	if best is Mob:
		var mb: Mob = best
		var md: Dictionary = mb.md
		lines.append([String(md["name"]), Color(md["color"]).lightened(0.35)])
		lines.append(["Monster  ·  %d / %d health" % [int(ceil(mb.hp)), int(mb.max_hp)], MUTED])
		var how := {"lunge": "Lunges at whoever is closest.", "spit": "Spits from range: keep moving.", "slam": "Winds up a ground slam: step out of the circle.",
			"fuse": "Rolls in and blows up. Shoot it before it reaches you.", "volley": "Fires a spread of bolts down a line.", "none": "Runs from you. Tame it before it escapes."}
		if mb is Blight:
			# the Blight: what it does, and how strong it is right now
			var bl: Blight = mb
			lines[1] = ["The Blight  ·  %d / %d health  ·  %s" % [int(ceil(mb.hp)), int(round(mb.max_hp)), "stirring" if bl.lvl < 0.35 else ("hunting" if bl.lvl < 0.8 else "ravenous")], MUTED]
			how = {"lunge": "Hunts by noise and light. Fast, fragile, comes in packs later on.", "spit": "Sweeps a light. Stay in it and it shrieks, and the Blight nearby comes."}
		lines.append([String(how.get(String(md["attack"]), "Dangerous up close.")), INK])
		if md.get("stag", false):
			lines.append(["Staggerable: hit it with an ability while the purple ring shows.", Color(0.85, 0.6, 1.0)])
		lines.append(["Drops %d gem%s." % [int(md["gems"]), "" if int(md["gems"]) == 1 else "s"], GOLD])
	elif best is Kin:
		var k: Kin = best
		var sp: Dictionary = Data.KIN[k.species]
		var nm := String(k.rec.get("name", sp["name"]))
		lines.append([("%s (lost)" % nm if k.lost_from != "" else "Wild %s" % sp["name"]) if k.is_wild() else nm, sp["color"]])
		lines.append(["%s type  ·  level %d  ·  %d / %d health" % [String(sp["type"]).capitalize(), int(k.rec.get("level", 1)), int(ceil(k.hp)), int(k.max_hp)], MUTED])
		if k.is_wild():
			if k.state == "dazed":
				lines.append(["Knocked out. Hold %s next to it to scan it." % Settings.key_cap("interact"), GOLD])
			else:
				lines.append(["Knock its health down to knock it out, then hold %s beside it to scan it." % Settings.key_cap("interact"), INK])
			if k.rec.get("shimmer", false):
				lines.append(["A shimmering one. Rare.", INK])
			for mid in Mutations.of(k.rec):
				lines.append(["%s: %s (%s)" % [Mutations.name_of(mid), String(Mutations.info(mid).get("desc", "")), Mutations.perk_text(mid)], INK])
			if k.lost_from != "":
				lines.append(["Guarding where %s fell. Scan it and whoever gets out with it keeps it; its owner can pick it up if revived." % ("you" if k.lost_from == "you" else k.lost_from), GOLD if k.lost_from == "you" else MUTED])
		elif k.owner_h == p:
			var a1: AbilitySpec = k.runner.def_of("k1")
			var uses := ("it uses %s itself" if p.ak else Settings.key_cap("signature") + " uses %s") % (a1.display_name if a1 else "its ability")
			lines.append(["Yours. %s sends it out, %s." % [Settings.key_cap("throw"), uses], INK])
		elif k.lost_from == "you" and k.lost_uid != "":
			lines.append(["Your lost Boki! Held by %s. Take it back." % (k.owner_h.pname if k.owner_h else "a rival"), GOLD])
		else:
			lines.append(["%s's Boki." % (k.owner_h.pname if k.owner_h else "A rival hunter"), BAD])
			_kit_lines(lines, k)
	elif best is Hunter:
		var h: Hunter = best
		var ally: bool = h.team == p.team
		lines.append([h.pname, GOOD if ally else Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]])
		lines.append(["%s  ·  %s  ·  %s" % [Arch.label(h.arch), String(h.wpn.get("name", "")), "teammate" if ally else "rival"], MUTED])
		lines.append(["Health %d / %d   ·   Armor %d / %d (%s)" % [int(ceil(h.hp)), int(h.max_hp), int(ceil(h.armor)), int(h.max_armor), String(Hunter.ARMOR_TIERS[h.armor_tier][0])], INK])
		if not ally:
			# know your opponent: their right click, dodge, glove and kin, so you can play around them
			var util: AbilityDef = h.runner.def_of("utility") if h.runner else null
			if util: lines.append(["%s: %s" % [Settings.key_cap("secondary"), util.display_name], Color(util.color).lightened(0.2)])
			if h.dodge_def: lines.append(["Dodge: %s" % h.dodge_def.display_name, Color("bfe6ff")])
			if not (h.gear[0] as Dictionary).is_empty() and Gear.ALL.has(String(h.gear[0]["id"])):
				lines.append(["Glove: %s" % String(Gear.ALL[String(h.gear[0]["id"])]["name"]), Gear.ALL[String(h.gear[0]["id"])]["col"]])
			if h.kin and not (h.kin as Kin).dead:
				lines.append(["Boki: " + Data.kin_title(String((h.kin as Kin).rec.get("name", "")), String(Data.KIN[(h.kin as Kin).species]["name"])), Data.KIN[(h.kin as Kin).species]["color"]])
				_kit_lines(lines, h.kin)
		if h.downed:
			lines.append(["Down. %s" % ("Hold %s next to them to revive." % Settings.key_cap("interact") if ally else "Finish them before they're revived."), BAD if not ally else GOOD])
	var w := 300.0
	var h2 := 36.0
	for i in range(1, lines.size()):
		h2 += _wrapped_h(String(lines[i][0]), w - 24, 13) + 3.0
	var pos := mp + Vector2(22, 18)
	if pos.x + w > sz.x - 8: pos.x = mp.x - w - 22
	if pos.y + h2 > sz.y - 160: pos.y = mp.y - h2 - 18
	var box := Rect2(pos, Vector2(w, h2))
	_rounded(box, Color(0.05, 0.06, 0.09, 0.9), 10, Color(lines[0][1], 0.5), 2)
	_text(pos + Vector2(12, 24), String(lines[0][0]), 16, lines[0][1], big)
	var y := pos.y + 34
	for i in range(1, lines.size()):
		var hh := _wrapped_h(String(lines[i][0]), w - 24, 13)
		c.draw_multiline_string(body, Vector2(pos.x + 12, y + 13), String(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, -1, lines[i][1])
		y += hh + 3.0

## The sky train on the minimap: its loop as a dashed amber line (fainter where it runs under a
## bridge), and the train itself, the engine marked red so you can see which way it's coming.
var _train_line := PackedVector2Array()
var _train_low: Array = []
func _draw_map_train(inner: Rect2, view: Rect2, k: float) -> void:
	var st: SkyTrain = m.skytrain
	if _train_line.is_empty():
		var s := 0.0
		while s < st.loop_len:
			var p := m.world.train_at(s)
			_train_line.append(Vector2(p.x, p.z)); _train_low.append(p.y < -1.0)
			s += 1.5
	var n := _train_line.size()
	for i in n:
		if i % 2 == 1:
			continue
		var a := inner.position + (_train_line[i] - view.position) * k
		var b := inner.position + (_train_line[(i + 1) % n] - view.position) * k
		if not (_mm_has(inner, a) and _mm_has(inner, b)):
			continue
		c.draw_line(a, b, Color(1.0, 0.72, 0.35, 0.35 if _train_low[i] else 0.8), 2.0, true)
	var cars: Array = st.car_positions()
	for ci in range(cars.size() - 1, -1, -1):
		var pv: Vector2 = inner.position + ((cars[ci] as Vector2) - view.position) * k
		if not _mm_has(inner, pv, 3.0):
			continue
		c.draw_circle(pv, 4.0 if ci == 0 else 3.2, Color(0, 0, 0, 0.6))
		c.draw_circle(pv, 3.0 if ci == 0 else 2.3, Color("ff5a3a") if ci == 0 else Color("ffcf7a"))

var _regions_of: World = null
var _regions := {}
func _region_names(w: World) -> Dictionary:
	if _regions_of != w:
		_regions_of = w
		_regions = {}
		for isl in w.islands: _regions[String(isl.get("name", ""))] = true
	return _regions

## Place names on the minimap (authored maps). Riding in or dropping you see the whole map with every
## point of interest and chokepoint named; on the ground, the names of places near you.
func _draw_map_labels(w: World, inner: Rect2, view: Rect2, k: float, overview: bool) -> void:
	if w.labels.is_empty():
		return
	for lb in w.labels:
		var p3: Vector3 = lb["pos"]
		var pv := inner.position + (Vector2(p3.x, p3.z) - view.position) * k
		if not _mm_has(inner, pv, 6.0):
			continue
		var nm := String(lb["name"])
		if String(lb["kind"]) == "perch":
			# a high perch: an up-arrow with its height, so you know it takes vertical tech
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -8), pv + Vector2(6, 3), pv + Vector2(-6, 3)]), Color(0, 0, 0, 0.6))
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -6), pv + Vector2(4.5, 2), pv + Vector2(-4.5, 2)]), Color("9af0ff"))
			if overview:
				_ctext(pv + Vector2(0, 15), "%dm" % int(round(float(lb.get("height", 0.0)))), 10, Color("c8f6ff"))
			continue
		if String(lb["kind"]) == "lair":
			if overview:
				_ctext(pv + Vector2(0, 18), nm, 11, Color("ffe2b0"), big)
			continue
		if String(lb["kind"]) == "rail":
			# a train stop: a small amber square, named in the overview
			c.draw_rect(Rect2(pv - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(pv - Vector2(3, 3), Vector2(6, 6)), Color("ffcf7a"))
			continue      # (unnamed here: stop, road and perch names piled on top of each other at this size; the full map names them)
		if String(lb["kind"]) == "choke":
			# a chokepoint: a small orange diamond, named in the overview
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -5), pv + Vector2(5, 0), pv + Vector2(0, 5), pv + Vector2(-5, 0)]), Color(0, 0, 0, 0.55))
			c.draw_colored_polygon(PackedVector2Array([pv + Vector2(0, -3.5), pv + Vector2(3.5, 0), pv + Vector2(0, 3.5), pv + Vector2(-3.5, 0)]), Color("ffb36a"))
		else:
			if overview and not _region_names(w).has(nm):
				continue      # (the whole map at this size: region names only, as the full map does)
			var col := Color("ffd2f0") if String(lb.get("role", "")) == "heart" else INK
			_ctext(pv + Vector2(0, 4), nm, 13 if overview else 11, col, big)

# ------------------------------------------------------------------ the deathbox loot window
## Pressing interact at a deathbox opens this: everything inside, each with its icon and rarity
## colour, "upgrade" marked where it beats what you've got. Click one to take it (swapping a glove
## or weapon leaves yours in the box); press interact again, or Smart loot, to grab everything
## worth having. Walking away, going down or emptying the box closes it.
var loot_open = null          # the box Dictionary, or null
var loot_panel: PanelContainer
var loot_hold: PanelContainer   # LootHold: your backpack beside the box while a clicked thing won't fit
var loot_sig := ""

func loot_is(b: Dictionary) -> bool:
	return loot_open != null and is_same(loot_open, b)

func mouse_on_ui() -> bool:
	return wheel_open or map_open() or mouse_on_panel()

var ui_extra: Array = []      # other panels that own the mouse (the practice areas' bottom bar)

## The cursor is over one of the item windows (deathbox loot, swap, backpack) or a panel in ui_extra.
func mouse_on_panel() -> bool:
	for pn in [loot_panel, loot_hold, swap_panel, pack_panel] + ui_extra:
		if pn != null and is_instance_valid(pn) and pn.visible and not pn.is_queued_for_deletion() and pn.get_global_rect().grow(6.0).has_point(pn.get_global_mouse_position()):
			return true
	return false

## Over an item window the crosshair gives way to a pointer, drawn on top of the window.
func _draw_pointer() -> void:
	if map_open() or not mouse_on_panel():
		return
	var mp := cursor.get_local_mouse_position()
	var pts := PackedVector2Array()
	for q in [Vector2(0, 0), Vector2(0, 19), Vector2(4.6, 14.6), Vector2(8.2, 22.0), Vector2(11.2, 20.6), Vector2(7.8, 13.4), Vector2(13.6, 13.4)]:
		pts.append(mp + q * 1.3)
	var sh := PackedVector2Array()
	for q in pts: sh.append(q + Vector2(1.5, 2.0))
	cursor.draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
	cursor.draw_colored_polygon(pts, INK)
	var ring := pts.duplicate(); ring.append(pts[0])
	cursor.draw_polyline(ring, Color(0.06, 0.065, 0.1), 1.6, true)

## Makes a whole item row clickable (as well as its buttons): hovering lights it up.
func _row_click(rp: Control, cb: Callable) -> void:
	rp.mouse_filter = Control.MOUSE_FILTER_STOP
	rp.mouse_entered.connect(func(): rp.modulate = Color(1.12, 1.12, 1.12))
	rp.mouse_exited.connect(func(): rp.modulate = Color.WHITE)
	rp.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (ev as InputEventMouseButton).pressed:
			rp.accept_event()
			Sfx.play("click")
			cb.call())

func open_loot(b: Dictionary) -> void:
	loot_open = b
	loot_sig = ""
	Sfx.play("ui_open", null, -10.0)
	_build_loot()
	if loot_panel: UI.pop_in(loot_panel)

func close_loot() -> void:
	loot_open = null
	_close_hold()
	if loot_panel and is_instance_valid(loot_panel):
		loot_panel.queue_free()
	loot_panel = null

func _loot_tick(_delta: float) -> void:
	_pack_tick()
	if loot_open == null:
		return
	var p: Hunter = m.player
	var b: Dictionary = loot_open
	if p == null or p.out or p.downed or b.get("empty", true) or p.flat_dist(b["pos"]) > 2.4 or not m.boxes.has(b):
		close_loot()
		return
	# rebuild only when what's in it (or what you're holding) changes
	var sig := str(Life.box_items(m, p, b).map(func(it): return [it["name"], it["upgrade"]])) + str(p.gear) + p.wid + str(p.pack.size())
	if sig != loot_sig:
		_build_loot()

## A clicked box thing that doesn't fit: nothing moves; your backpack opens beside the box with it held.
## (Public so the screenshot tool can open it.)
func open_hold(row: Dictionary) -> void:
	_close_hold()
	if not LootFull.holdable(row):
		return
	var b: Dictionary = loot_open
	var hi := int(row["i"])
	var swap := func(mi: int): if LootFull.swap_held(m, m.player, b, hi, mi): _hold_done()
	var drop := func(mi: int): if LootFull.drop_for_held(m, m.player, b, hi, mi): _hold_done()
	loot_hold = LootHold.build(m.player, (b["pack"] as Array)[hi], swap, drop, _close_hold)
	add_child(loot_hold)
	UI.pop_in(loot_hold)
	await get_tree().process_frame
	if is_instance_valid(loot_hold) and loot_panel:
		loot_hold.position = Vector2(maxf(8.0, loot_panel.position.x - loot_hold.size.x - 12.0), loot_panel.position.y)

func _close_hold() -> void:
	if loot_hold and is_instance_valid(loot_hold):
		loot_hold.queue_free()
	loot_hold = null

func _hold_done() -> void:
	if (loot_open as Dictionary).get("empty", false):
		close_loot()
	else:
		_build_loot()

func _build_loot() -> void:
	_close_hold()
	var p: Hunter = m.player
	var b: Dictionary = loot_open
	if loot_panel and is_instance_valid(loot_panel):
		loot_panel.queue_free()
	var items: Array = Life.box_items(m, p, b)
	loot_sig = str(items.map(func(it): return [it["name"], it["upgrade"]])) + str(p.gear) + p.wid + str(p.pack.size())
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var bc: Color = Life.box_color(b)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.1, 0.95)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(bc, 0.8); sb.set_border_width_all(2); sb.border_width_top = 4
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 18
	pc.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(6); pc.add_child(v)
	var o: Hunter = b["owner"]
	var head := UI.hbox(8); v.add_child(head)
	head.add_child(Icons.Glyph.new("gem", bc, 18.0))
	var t := UI.title(("Your deathbox" if o == p else "%s's deathbox" % o.pname), 22, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_pack_chip(p))
	var cl := UI.button("✕", func(): close_loot(), 36)
	cl.flat = true
	head.add_child(cl)
	if items.is_empty():
		v.add_child(UI.label("Empty.", 14, MUTED))
	var list := UI.vbox(6)
	if items.size() > 5:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = 5 * 60.0
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(list)
		v.add_child(sc)
	else:
		v.add_child(list)
	for it in items:
		var row := UI.hbox(8)
		var rp := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(it["col"], 0.12 if it["upgrade"] else 0.06)
		rs.set_corner_radius_all(9)
		rs.border_color = Color(it["col"], 0.55 if it["upgrade"] else 0.2); rs.border_width_left = 3
		var fit := LootFull.fits(p, it, b)
		rs.content_margin_left = 8; rs.content_margin_right = 8; rs.content_margin_top = 5; rs.content_margin_bottom = 5
		rp.add_theme_stylebox_override("panel", rs)
		rp.add_child(row)
		row.add_child(Icons.Glyph.new(String(it["icon"]), it["col"], 24.0))
		var col := UI.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(String(it["name"]), 15, INK, UI.semi)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(nm)
		var sub := UI.label(String(it["sub"]), 12, MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub.clip_text = true
		sub.custom_minimum_size.x = 210
		col.add_child(sub)
		row.add_child(col)
		if it["key"] == "gear":
			var tag := UI.label("UPGRADE" if it["upgrade"] else "WORSE", 11, GOOD if it["upgrade"] else MUTED, UI.caps)
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tag)
		elif it["key"] == "pack":
			var vt := UI.label("%d" % int(it.get("value", 0)), 13, GOLD, UI.big)
			vt.tooltip_text = "Worth"
			vt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(Icons.Glyph.new("gem", Color(GOLD, 0.8), 12.0))
			row.add_child(vt)
		var itc: Dictionary = it
		var verb := "Take"
		if it["key"] == "gear": verb = "Swap"
		elif not fit: verb = "Full"
		elif it["key"] == "pack" and it.get("full", false): verb = "Swap"
		var take_it := func():
			if loot_open == null or not m.player:
				return
			if not LootFull.click(m, m.player, loot_open, itc):
				open_hold(itc)
			elif (loot_open as Dictionary).get("empty", false): close_loot()
			else: _build_loot()
		var take := UI.button(verb, take_it, 76)
		_row_click(rp, take_it)
		take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not fit:
			LootHold.mark_full(rp)
			take.tooltip_text = "No room: swap it with something of yours"
		elif it["key"] == "pack" and it.get("full", false):
			take.tooltip_text = "Swaps out the least valuable thing in your backpack"
		row.add_child(take)
		list.add_child(rp)
	var foot := UI.hbox(8); v.add_child(foot)
	var sm := UI.primary("Smart loot  (%s)" % Settings.key_cap("interact"), func():
		if loot_open != null and m.player:
			var got := LootFull.smart(m, m.player, loot_open)
			if got > 0 or (loot_open as Dictionary).get("empty", false):
				close_loot(), 200)
	foot.add_child(sm)
	var hint := UI.label("Best first: hands, then your backpack", 12, MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	pc.custom_minimum_size.x = 430
	add_child(pc)
	loot_panel = pc
	# to the right of centre, clear of your hunter and the ability bar
	await get_tree().process_frame
	if is_instance_valid(pc):
		var vs := pc.get_viewport_rect().size
		pc.position = Vector2(vs.x * 0.5 + 90.0, maxf(90.0, vs.y * 0.5 - pc.size.y * 0.5 - 40.0))

# ------------------------------------------------------------------ the backpack and the swap window
## The backpack (I): what you're carrying home, each with Equip (weapons and gloves go in your hands,
## what you held takes its slot) and Drop. The swap window opens when you pick something up with a
## full pack: click the thing to leave behind, or leave the new one where it lies.
var swap_wp = null             # the ground pick-up waiting for a slot, or null
var swap_panel: PanelContainer
var pack_panel: PanelContainer
var pack_sig := ""

func swap_open() -> bool:
	return swap_wp != null and swap_panel != null and is_instance_valid(swap_panel)

func pack_open() -> bool:
	return pack_panel != null and is_instance_valid(pack_panel)

func _pack_chip(p: Hunter) -> Control:
	var full: bool = p.pack.size() >= p.pack_cap
	var chip := UI.card(Color(Color("ffb0a0") if full else INK, 0.1), 4, 999)
	var hb := UI.hbox(5); chip.add_child(hb)
	hb.add_child(Icons.Glyph.new("satchel", Color("ffb0a0") if full else INK, 14.0))
	var l := UI.label("%d/%d" % [p.pack.size(), p.pack_cap], 13, Color("ffb0a0") if full else INK, UI.semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(l)
	chip.tooltip_text = "Backpack: weapons, gloves and treasure to carry home (%s)" % Settings.key_cap("inventory")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip

func _item_panel(title: String, col: Color, width: float) -> Array:
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.1, 0.95)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(col, 0.8); sb.set_border_width_all(2); sb.border_width_top = 4
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 18
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size.x = width
	var v := UI.vbox(6); pc.add_child(v)
	var head := UI.hbox(8); v.add_child(head)
	head.add_child(Icons.Glyph.new("satchel", col, 18.0))
	var t := UI.title(title, 22, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	return [pc, v, head]

## One item as a row: icon, name, what it does, its worth, and buttons [[text, callable, primary]].
func _item_row(it: Dictionary, buttons: Array, note := "") -> Control:
	return LootHold.item_row(it, buttons, note)

## A scrolling list inside an item window: [scroll, rows]. _fit_panel sizes it.
func _scroll_rows(v: VBoxContainer) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := UI.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	v.add_child(sc)
	return [sc, rows]

## Puts an item window on the right, between the top counters and the weapon/slots cluster at the
## bottom right, and lets its list scroll if it's too long to fit.
func _fit_panel(pc: PanelContainer, sc: ScrollContainer, rows: VBoxContainer) -> void:
	pc.position = Vector2(-10000, 0)     # out of sight until it's sized
	await get_tree().process_frame
	if not is_instance_valid(pc):
		return
	var vs := pc.get_viewport_rect().size
	var top := 64.0
	var bottom := vs.y - 172.0          # clear of the weapon card and the consumable slots
	var want := rows.get_combined_minimum_size().y
	var rest := pc.get_combined_minimum_size().y - sc.get_combined_minimum_size().y
	sc.custom_minimum_size.y = clampf(bottom - top - rest, 60.0, want)
	pc.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(pc):
		return
	pc.position = Vector2(vs.x - pc.size.x - 16.0, clampf(vs.y * 0.42 - pc.size.y * 0.5, top, maxf(top, bottom - pc.size.y)))

func open_swap(wp: Dictionary) -> void:
	close_pack()
	swap_wp = wp
	_build_swap()
	if swap_panel: UI.pop_in(swap_panel)
	Sfx.play("lock_rattle", null, -4.0)

func close_swap() -> void:
	swap_wp = null
	if swap_panel and is_instance_valid(swap_panel):
		swap_panel.queue_free()
	swap_panel = null

func _build_swap() -> void:
	if swap_panel and is_instance_valid(swap_panel):
		swap_panel.queue_free()
	var p: Hunter = m.player
	var wp: Dictionary = swap_wp
	var incoming := Pack.ground_item(wp)
	var pb := _item_panel("Backpack full", Color("ffb0a0"), 470)
	var pc: PanelContainer = pb[0]; var v: VBoxContainer = pb[1]; var head: HBoxContainer = pb[2]
	head.add_child(_pack_chip(p))
	var cl := UI.button("✕", func(): close_swap(), 36); cl.flat = true
	head.add_child(cl)
	v.add_child(UI.label("Picking up", 12, MUTED, UI.caps))
	var incoming_row := _item_row(incoming, [])
	LootHold.mark_full(incoming_row)
	v.add_child(incoming_row)
	v.add_child(UI.label("Drop one to make room", 12, MUTED, UI.caps))
	var low := Pack.lowest(p)
	var sl := _scroll_rows(v)
	for i in p.pack.size():
		var idx := i
		var it: Dictionary = p.pack[i]
		var worse := Loot.value(it) < Loot.value(incoming)
		var drop_it := func():
			if swap_wp != null and m.player:
				Pack.swap(m, m.player, idx, swap_wp)
			close_swap()
		var srow := _item_row(it, [["Drop", drop_it, worse]], "least valuable" if i == low else "")
		_row_click(srow, drop_it)
		sl[1].add_child(srow)
	var foot := UI.hbox(8); v.add_child(foot)
	foot.add_child(UI.button("Leave it  (Esc)", func(): close_swap(), 150))
	var hint := UI.label("What you drop stays on the ground", 12, MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	add_child(pc)
	swap_panel = pc
	_fit_panel(pc, sl[0], sl[1])

func toggle_pack() -> void:
	if pack_open():
		close_pack()
	else:
		close_swap()
		pack_sig = ""
		_build_pack()
		if pack_panel: UI.pop_in(pack_panel)
		Sfx.play("ui_open", null, -10.0)

func close_pack() -> void:
	if pack_panel and is_instance_valid(pack_panel):
		pack_panel.queue_free()
	pack_panel = null

func _pack_state(p: Hunter) -> String:
	return str(p.pack.map(func(it): return it.get("uid", ""))) + p.wid + p.welem + str(p.gear) + str(p.pack_cap) + str(p.caught.size())

func _build_pack() -> void:
	if pack_panel and is_instance_valid(pack_panel):
		pack_panel.queue_free()
	var p: Hunter = m.player
	pack_sig = _pack_state(p)
	var pb := _item_panel("Backpack", INK, 470)
	var pc: PanelContainer = pb[0]; var v: VBoxContainer = pb[1]; var head: HBoxContainer = pb[2]
	head.add_child(_pack_chip(p))
	var cl := UI.button("✕", func(): close_pack(), 36); cl.flat = true
	head.add_child(cl)
	v.add_child(UI.label("Wearing", 12, MUTED, UI.caps))
	for g in p.gear:
		if not (g as Dictionary).is_empty():
			v.add_child(_item_row(Loot.gear(String(g["id"]), int(g["rar"])), []))
	v.add_child(UI.label("Carrying home  ·  extract to keep it all", 12, MUTED, UI.caps))
	var sl := _scroll_rows(v)
	var rows: VBoxContainer = sl[1]
	if p.pack.is_empty():
		rows.add_child(UI.label("Nothing yet. Gear and treasure you pick up go here.", 13, MUTED))
	for i in p.pack.size():
		var idx := i
		var it: Dictionary = p.pack[i]
		var bts: Array = []
		if String(it.get("t", "")) == "gear":
			bts.append(["Wear", func(): Pack.use_from_pack(m, m.player, idx); _build_pack(), true])
		bts.append(["Drop", func(): Pack.drop_from_pack(m, m.player, idx); _build_pack()])
		rows.add_child(_item_row(it, bts))
	for k in p.pack_cap - p.pack.size():
		if k >= 3: break
		var empty := UI.card(Color(1, 1, 1, 0.03), 6, 9)
		empty.custom_minimum_size.y = 30
		empty.add_child(UI.label("empty slot", 12, Color(MUTED, 0.6)))
		rows.add_child(empty)
	CaptureHud.pack_section(self, v, p, func(): _build_pack())       # the capsules in your box, with Release
	var hint := UI.label("%s or Esc to close  ·  bigger backpacks at your armory" % Settings.key_cap("inventory"), 12, MUTED)
	v.add_child(hint)
	add_child(pc)
	pack_panel = pc
	_fit_panel(pc, sl[0], rows)

## Closes the windows when they stop making sense (you went down, walked off, or it's gone).
func _pack_tick() -> void:
	var p: Hunter = m.player
	if swap_wp != null:
		var wp: Dictionary = swap_wp
		if p == null or p.out or p.downed or not m.wpicks.has(wp) or p.flat_dist(wp["pos"]) > 3.0 or Pack.room(p):
			if p and Pack.room(p) and m.wpicks.has(wp) and p.flat_dist(wp["pos"]) <= 3.0:
				Pack.stash(m, p, wp)
			close_swap()
	if pack_open():
		if p == null or p.out or p.downed:
			close_pack()
		elif _pack_state(p) != pack_sig:
			_build_pack()

# ------------------------------------------------------------------ wisp and deathbox revive rings
## Downed Hunters and the Boki tethers (DownedMarks, BokiMarks); on top of an enemy wisp you get
## "Standing on <name>". Deathbox revives get the same ground ring.
func _ground_ring(at: Vector3, r: float, col: Color, width: float, frac := 1.0, start := -PI * 0.5) -> void:
	DownedMarks.ring(c, m.cam, at, r, col, width, frac, start)

func _draw_wisp_rings() -> void:
	var p: Hunter = m.player
	DownedMarks.draw(c, m)
	BokiMarks.draw(c, m)
	# you, standing on an enemy wisp
	if p and not p.out and p.has_meta("standing_on") and m.time - float(p.get_meta("standing_at", -9.0)) < 0.15:
		var o2 = p.get_meta("standing_on")
		if is_instance_valid(o2) and (o2 as Hunter).downed:
			var sz := c.size
			var s := "Standing on %s  ·  they drain %.1fx faster and can barely move" % [(o2 as Hunter).pname, Life.R["stomp_mult"]]
			var w := body.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_rounded(Rect2(Vector2(sz.x * 0.5 - w * 0.5 - 14, sz.y * 0.5 + 70), Vector2(w + 28, 28)), Color(0.12, 0.02, 0.02, 0.85), 8, Color(1, 0.3, 0.2, 0.7), 2)
			_ctext(Vector2(sz.x * 0.5, sz.y * 0.5 + 89), s, 15, Color("ff8a7a"))
	ReviveHud.revive_rings(self)       # deathbox revives in progress

## A soft coloured glow round the screen edges (danger to you).
func _edge_pulse(sz: Vector2, col: Color, a: float) -> void:
	var bands := 6
	for i in bands:
		var t := float(i) / bands
		var w := 70.0 * (1.0 - t)
		var cc := Color(col, a * (1.0 - t) * 0.35)
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, w)), cc)
		c.draw_rect(Rect2(Vector2(0, sz.y - w), Vector2(sz.x, w)), cc)
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, sz.y)), cc)
		c.draw_rect(Rect2(Vector2(sz.x - w, 0), Vector2(w, sz.y)), cc)


# ------------------------------------------------------------------ emotes and truces
var wheel_open := false
var wheel_at := Vector2.ZERO
var wheel_sel := -1

## Hold the emote key: a wheel opens at the cursor; point at an emote and let go to use it.
func _tick_wheel() -> void:
	var p: Hunter = m.player
	var can: bool = m.truce != null and p != null and not p.out and not p.extracted and not p.riding and not m.paused and m.duel == null
	var held := can and Input.is_action_pressed("emote")
	var n := Truce.EMOTES.size()
	if has_meta("wheel_demo"):
		# test: the wheel held open, pointing at Truce
		wheel_open = true; wheel_at = c.size * Vector2(0.72, 0.5); wheel_sel = 0
		return
	if held and not wheel_open:
		wheel_open = true
		var sz := c.size
		wheel_at = c.get_local_mouse_position().clamp(Vector2(150, 150), sz - Vector2(150, 150))
		wheel_sel = -1
		Sfx.play("click", null, -14.0, 0.02, 1.3)
	elif held:
		var d := c.get_local_mouse_position() - wheel_at
		var s := -1 if d.length() < 26.0 else int(round(fposmod(atan2(d.y, d.x) + PI / 2.0, TAU) / (TAU / n))) % n
		if s != wheel_sel and s >= 0: Sfx.play("click", null, -18.0, 0.02, 1.6)
		wheel_sel = s
	elif wheel_open:
		wheel_open = false
		if wheel_sel >= 0 and can:
			m.truce.emote(p, String(Truce.EMOTES[wheel_sel]["id"]))
		wheel_sel = -1

func _draw_wheel() -> void:
	var n := Truce.EMOTES.size()
	var R := 98.0
	c.draw_circle(wheel_at, R + 44.0, Color(0.03, 0.04, 0.07, 0.6))
	c.draw_arc(wheel_at, R + 44.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
	for i in n:
		var a := -PI / 2.0 + TAU * i / n
		var pos := wheel_at + Vector2(cos(a), sin(a)) * R
		var e: Dictionary = Truce.EMOTES[i]
		var on := i == wheel_sel
		var rr := 33.0 if on else 27.0
		c.draw_circle(pos, rr, Color(e["col"], 0.32) if on else Color(0.09, 0.1, 0.15, 0.95))
		c.draw_arc(pos, rr, 0, TAU, 28, e["col"], 3.0 if on else 1.5, true)
		if e["id"] == "truce":
			_flag(pos + Vector2(-7, -16), 0.9, e["col"])
			_ctext(pos + Vector2(0, 16), String(e["name"]), 13, e["col"], big)
		else:
			_ctext(pos + Vector2(0, 5), String(e["name"]), 14 if String(e["name"]).length() < 7 else 12, e["col"], big)
	var mid := "Emote"
	var p: Hunter = m.player
	if p and m.truce.offers.has(p.team):
		mid = "Offer from %s" % (m.truce.offers[p.team]["by"] as Hunter).pname
	_ctext(wheel_at + Vector2(0, 5), mid, 12 if mid.length() > 6 else 13, Color("f4f1e6") if mid != "Emote" else MUTED, big)

## A little white flag (k scales it), pole at p.
func _flag(p: Vector2, k: float, col: Color) -> void:
	c.draw_line(p, p + Vector2(0, 22) * k, Color(0, 0, 0, 0.6), 3.0 * k)
	c.draw_line(p, p + Vector2(0, 22) * k, Color("c9b39a"), 1.6 * k)
	var w := sin(m.time * 6.0) * 1.5
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(1, 0) * k, p + Vector2(14, 2 + w) * k, p + Vector2(13, 8 + w) * k, p + Vector2(1, 9) * k]), col)

## Over heads: emote bubbles from anyone you can see, a white flag on truce partners, and a red
## mark on whoever just broke a truce.
func _draw_truce_marks() -> void:
	if m.truce == null or m.player == null:
		return
	var cam := m.cam
	var me: Hunter = m.player
	for s in m.truce.shown:
		var h: Hunter = s["h"]
		if h.out or h.extracted or (h != me and h.team != me.team and (h.unseen or not h.visible)):
			continue
		if cam.is_position_behind(h.position):
			continue
		var e := Truce.emote_def(String(s["id"]))
		var a := clampf((Truce.BUBBLE_T - float(s["t"])) * 2.0, 0.0, 1.0) * clampf(float(s["t"]) * 8.0, 0.0, 1.0)
		var sp := cam.unproject_position(_head(h, 3.3)) + Vector2(0, -6.0 * minf(1.0, float(s["t"]) * 4.0))
		if not c.get_viewport_rect().grow(240.0).has_point(sp):
			continue     # (far off screen, e.g. someone falling away into the abyss: the bubble's triangles degenerate and spam "triangulation failed")
		var label := String(e["name"])
		var w := big.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + (40.0 if e["id"] == "truce" else 22.0)
		var r := Rect2(sp - Vector2(w * 0.5, 15), Vector2(w, 28))
		_rounded(r, Color(0.05, 0.06, 0.09, 0.88 * a), 12, Color(e["col"], 0.8 * a), 2)
		c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-6, 13), sp + Vector2(6, 13), sp + Vector2(0, 21)]), Color(0.05, 0.06, 0.09, 0.88 * a))
		if e["id"] == "truce":
			_flag(r.position + Vector2(12, 3), 0.95, Color(e["col"], a))
			_text(r.position + Vector2(30, 20), label, 15, Color(e["col"], a), big)
		else:
			_ctext(sp + Vector2(0, 5), label, 15, Color(e["col"], a), big)
	if m.truce.pacts.is_empty() and m.truce.marked.is_empty():
		return
	for h in m.hunters:
		if h.team == me.team or h.out or h.extracted or h.unseen or not h.visible or cam.is_position_behind(h.position):
			continue
		var tp := cam.unproject_position(_head(h, 2.55))
		if not c.get_viewport_rect().grow(240.0).has_point(tp):
			continue
		if m.truce.is_marked(h):
			_ctext(tp + Vector2(0, -16), "BROKE THE TRUCE", 12, BAD, big)     # (above the name, not over it)
		elif m.truce.allied(me.team, h.team):
			# a white flag beside their name plate
			_flag(tp + Vector2(-66, -12), 0.7, Color("f4f1e6"))

# ------------------------------------------------------------------ boss lairs
## A lair on the minimap: a padlock while sealed, an open gate once open, a pulsing horned skull
## while its boss is awake, a tick once cleared.
func _lair_icon(pv: Vector2, L: Dictionary, k := 1.0) -> void:
	var col: Color = Lairs.color_of(L)
	var dark := Color(0, 0, 0, 0.75)
	match String(L["state"]):
		"dormant":
			c.draw_circle(pv, 4.5 * k, dark)
			c.draw_circle(pv, 3.2 * k, Color(0.5, 0.52, 0.58, 0.8))
		"sealed":
			c.draw_rect(Rect2(pv - Vector2(6, 3) * k, Vector2(12, 10) * k).grow(1.5), dark)
			c.draw_rect(Rect2(pv - Vector2(6, 3) * k, Vector2(12, 10) * k), col)
			c.draw_arc(pv + Vector2(0, -3) * k, 4.0 * k, PI, TAU, 10, dark, 4.0 * k)
			c.draw_arc(pv + Vector2(0, -3) * k, 4.0 * k, PI, TAU, 10, col, 2.0 * k)
			c.draw_circle(pv + Vector2(0, 2) * k, 1.6 * k, dark)
		"open":
			c.draw_rect(Rect2(pv - Vector2(7, 7) * k, Vector2(14, 14) * k).grow(1.5), dark)
			c.draw_rect(Rect2(pv - Vector2(7, 7) * k, Vector2(14, 14) * k), col, false, 2.5 * k)
			c.draw_rect(Rect2(pv + Vector2(-2.5, 3) * k, Vector2(5, 5) * k), dark)
		"awake":
			var ph := fmod(m.time * 1.4, 1.0)
			c.draw_arc(pv, (9.0 + ph * 9.0) * k, 0, TAU, 24, Color(BAD, 0.85 * (1.0 - ph)), 2.0, true)
			c.draw_circle(pv, 8.0 * k, dark)
			c.draw_circle(pv, 6.5 * k, BAD)
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([pv + Vector2(4.5 * sx, -3) * k, pv + Vector2(8.5 * sx, -10) * k, pv + Vector2(2.0 * sx, -5.5) * k]), BAD)
				c.draw_circle(pv + Vector2(2.4 * sx, -0.5) * k, 1.4 * k, dark)
			c.draw_rect(Rect2(pv + Vector2(-2.5, 2.5) * k, Vector2(5, 1.6) * k), dark)
		"cleared":
			c.draw_circle(pv, 7.0 * k, dark)
			c.draw_circle(pv, 5.5 * k, Color(0.55, 0.58, 0.64, 0.9))
			c.draw_polyline(PackedVector2Array([pv + Vector2(-3, 0) * k, pv + Vector2(-0.8, 2.6) * k, pv + Vector2(3.4, -2.6) * k]), dark, 2.0 * k)

func _draw_map_lairs(inner: Rect2, to_map: Callable, on_map: Callable, overview: bool) -> void:
	for L in m.lairs.list:
		var pv: Vector2 = to_map.call(L["c"])
		# a fight you heard (or its boss falling): a big pulsing ring round the boss's icon
		var al: bool = m.player != null and m.lairs.alerted(L, m.player)
		var acol: Color = Lairs.color_of(L) if String(L.get("alert", "")) == "fight" else GOLD
		if on_map.call(pv, 6.0):
			if al:
				var ph := fmod(m.time * 1.2, 1.0)
				c.draw_arc(pv, 9.0 + ph * 16.0, 0, TAU, 28, Color(acol, 1.0 - ph), 3.0, true)
				c.draw_arc(pv, 10.0, 0, TAU, 24, Color(acol, 0.9), 2.0, true)
			_lair_icon(pv, L, (1.0 if not overview else 0.9) * (1.3 if al else 1.0))
		elif al:
			_edge_arrow(inner, inner.get_center(), pv, acol)
		elif L["state"] == "awake":
			_edge_arrow(inner, inner.get_center(), pv, BAD)
	# a dropped Rare Egg (and whoever just picked it up) shows to everyone for a few seconds
	for e in m.lairs.egg_pings:
		var at: Vector3 = e["pos"]
		if e.get("follow") != null and is_instance_valid(e["follow"]): at = (e["follow"] as Hunter).pos
		var pv: Vector2 = to_map.call(at)
		var ph := fmod(m.time * 1.8, 1.0)
		if on_map.call(pv, 4.0):
			c.draw_arc(pv, 6.0 + ph * 12.0, 0, TAU, 24, Color(GOLD, 1.0 - ph), 2.5, true)
			c.draw_set_transform(pv, 0.0, Vector2(0.8, 1.05))
			c.draw_circle(Vector2.ZERO, 6.5, Color(0, 0, 0, 0.75))
			c.draw_circle(Vector2.ZERO, 5.0, Color("ffd36a"))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_edge_arrow(inner, inner.get_center(), pv, GOLD)

## Over each lair nearby: what's going on at its gate. Someone working the dial shows a small dial
## over the lectern so everyone can see it turning; runes being lit show their fill.
func _draw_lair_labels() -> void:
	if m.lairs == null or m.player == null:
		return
	var cam := m.cam
	var p: Hunter = m.player
	for L in m.lairs.list:
		var d := p.flat_dist(L["dial"])
		var u = L["user"]
		if L["state"] == "sealed" and u != null and not is_same(u, p) and d < 40.0 and not cam.is_position_behind(L["dial"]):
			var sp := cam.unproject_position(L["dial"] + Vector3(0, 3.0, 0))
			_dial_widget(sp, 26.0, L, false)
			_ctext(sp + Vector2(0, -36), "%s is opening the gate" % (u as Hunter).pname, 13, Lairs.color_of(L), big)
		for rn in L["runes"]:
			if rn["lit"] or float(rn["prog"]) <= 0.0 or p.flat_dist(rn["pos"]) > 30.0 or cam.is_position_behind(rn["pos"]):
				continue
			var rp := cam.unproject_position(rn["pos"] + Vector3(0, 2.6, 0))
			_bar(Rect2(rp + Vector2(-34, 0), Vector2(68, 6)), float(rn["prog"]), Lairs.color_of(L))
	# a Rare Egg on the ground nearby: a marker you can follow
	for L in m.lairs.list:
		var wp = L.get("egg_wp")
		if wp != null and m.wpicks.has(wp) and p.flat_dist(wp["pos"]) < 70.0 and not p.out:
			_draw_waypoint(wp["pos"], "Rare Egg", GOLD)

## The dial: a ring with the lit arcs (gold until hit, then dim green), the needle, and pips for the
## locks. Drawn big for whoever is working it, small over the lectern for everyone else.
func _dial_widget(ctr: Vector2, rad: float, L: Dictionary, big_one: bool) -> void:
	var col: Color = Lairs.color_of(L)
	var jam := float(L["jam"]) > 0.0
	var w := maxf(3.0, rad * (0.16 if big_one else 0.2))
	c.draw_circle(ctr, rad + w * 1.4, Color(0.03, 0.03, 0.06, 0.82))
	c.draw_arc(ctr, rad, 0, TAU, 64, Color(1, 1, 1, 0.14) if not jam else Color(BAD, 0.5), w, true)
	for t in L["targets"]:
		var a := float(t["a"]); var tw := float(t["w"])
		var tc: Color = Color(GOOD, 0.55) if t["hit"] else col.lightened(0.25)
		if not t["hit"] and not jam:
			tc = tc.lerp(Color.WHITE, 0.25 + 0.25 * sin(m.time * 9.0))
		c.draw_arc(ctr, rad, a - tw * 0.5, a + tw * 0.5, 16, tc, w * (1.0 if t["hit"] else 1.35), true)
	# the needle, with a short glowing trail behind it
	var nd := float(L["needle"]); var dirn := float(L["dir"])
	for i in 6:
		var ta := nd - dirn * i * 0.06
		c.draw_line(ctr, ctr + Vector2(cos(ta), sin(ta)) * rad * 1.08, Color(1, 0.97, 0.85, 0.22 - i * 0.035), w * 0.7, true)
	var tip := ctr + Vector2(cos(nd), sin(nd)) * rad * 1.12
	c.draw_line(ctr, tip, Color(BAD, 0.95) if jam else Color("fff4d0"), w * 0.75, true)
	c.draw_circle(tip, w * 0.6, Color("fff4d0") if not jam else BAD)
	c.draw_circle(ctr, w * 0.9, col)
	# the locks: one pip each, filled once open
	var n := int(L["locks"])
	var px0 := ctr.x - (n - 1) * (rad * 0.22) * 0.5
	for i in n:
		var pp := Vector2(px0 + i * rad * 0.22, ctr.y + rad + w * 2.4)
		c.draw_circle(pp, rad * 0.07 + 1.0, Color(0, 0, 0, 0.8))
		c.draw_circle(pp, rad * 0.07, col if i < int(L["lock"]) else (Color(INK, 0.9) if i == int(L["lock"]) else Color(1, 1, 1, 0.22)))

func _draw_lair_dial(sz: Vector2, p: Hunter) -> void:
	var L: Dictionary = m.lairs.puzzle_of(p)
	if L.is_empty():
		return
	var ctr := Vector2(sz.x * 0.5 - minf(290.0, sz.x * 0.26), sz.y * 0.5 - 45.0)
	var rad := 86.0
	_dial_widget(ctr, rad, L, true)
	var col: Color = Lairs.color_of(L)
	_ctext(ctr + Vector2(0, -rad - 42), String(L["name"]).to_upper(), 15, col, big)
	_ctext(ctr + Vector2(0, -rad - 24), "LOCK %d OF %d" % [mini(int(L["lock"]) + 1, int(L["locks"])), int(L["locks"])], 13, INK, big)
	var jam := float(L["jam"]) > 0.0
	var key := Settings.key_cap("interact")
	var hint := "JAMMED" if jam else "%s  ·  CLICK  ·  (A)   to stop on a lit arc" % key
	_ctext(ctr + Vector2(0, rad + 48), hint, 14 if not jam else 18, BAD if jam else INK, big)
	var lit: int = (L["targets"] as Array).filter(func(t): return t["hit"]).size()
	_ctext(ctr + Vector2(0, rad + 68), "%d of %d arcs  ·  a miss rings the chime" % [lit, (L["targets"] as Array).size()], 12, MUTED)

## After the kill, still sealed in: the gate's clock, and the two ways out sooner.
func _draw_lair_victory(sz: Vector2, p: Hunter) -> void:
	var L: Dictionary = m.lairs.sealed_lair(p)
	if L.is_empty() or not L.get("victory", false):
		return
	var col: Color = Lairs.color_of(L)
	var w := minf(620.0, sz.x * 0.52)
	var r := Rect2(Vector2(sz.x * 0.5 - w * 0.5, 22), Vector2(w, 54))
	_rounded(r, Color(0.04, 0.04, 0.07, 0.85), 10, Color(col, 0.6), 2)
	# a padlock: you're locked in with the loot until the clock runs out (or you open it early)
	var lc := r.position + Vector2(24, 26)
	c.draw_arc(lc + Vector2(0, -5), 6.0, PI, TAU, 12, col, 2.5, true)
	_rounded(Rect2(lc + Vector2(-8, -5), Vector2(16, 13)), col, 3)
	_ctext(Vector2(sz.x * 0.5 + 8, r.position.y + 20), "VICTORY  ·  LOCKED IN  ·  gate opens in %s" % Lairs.clock(m.lairs.victory_left(L)), 15, col, big)
	var k := Settings.key_cap("interact")
	_ctext(Vector2(sz.x * 0.5 + 8, r.position.y + 37), "%s at the lever by the gate opens it now  ·  the updraft at the back carries only those who fought" % k, 11, MUTED)
	# the lock's clock draining
	var bw := r.size.x - 64.0
	var f := clampf(m.lairs.victory_left(L) / Lairs.VICTORY_T, 0.0, 1.0)
	_rounded(Rect2(Vector2(r.position.x + 48, r.end.y - 10), Vector2(bw, 4)), Color(1, 1, 1, 0.12), 2)
	_rounded(Rect2(Vector2(r.position.x + 48, r.end.y - 10), Vector2(bw * f, 4)), col, 2)
	feed_top = maxf(feed_top, r.end.y + 8.0)

## At the top of the screen while you're in a lair with its boss awake: name, phase, health with
## marks at the phase lines, and the enrage clock.
func _draw_boss_bar(sz: Vector2, p: Hunter) -> void:
	var b: Boss = m.lairs.boss_for(p)
	if b == null:
		return
	var col: Color = Lairs.color_of(b.lair)
	var w := minf(560.0, sz.x * 0.46)
	var r := Rect2(Vector2(sz.x * 0.5 - w * 0.5, 30), Vector2(w, 16))
	_rounded(Rect2(r.position - Vector2(14, 22), r.size + Vector2(28, 50)), Color(0.04, 0.04, 0.07, 0.85), 10, Color(col, 0.6), 2)
	_text(r.position + Vector2(0, -6), String(b.md["name"]).to_upper(), 15, col, big)
	var ph := "PHASE %d" % (b.phase + 1)
	_text(Vector2(r.end.x - big.get_string_size(ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, r.position.y - 6), ph, 13, INK, big)
	var frac := clampf(b.hp / b.max_hp, 0.0, 1.0)
	c.draw_rect(r, Color(0, 0, 0, 0.6))
	var ct := _chip_of(b, frac)
	if ct > frac:
		c.draw_rect(Rect2(r.position + Vector2(w * frac, 0), Vector2(w * (ct - frac), r.size.y)), Color(1.0, 0.95, 0.88, 0.8))
	var hc := Color("ff5a4a") if b.enraged else (Color("e0b0ff") if b.stagger_t > 0.0 else Color("ff8a5a"))
	c.draw_rect(Rect2(r.position, Vector2(w * frac, r.size.y)), hc)
	for mk in [0.66, 0.33]:
		c.draw_line(r.position + Vector2(w * mk, -3), r.position + Vector2(w * mk, r.size.y + 3), Color(1, 1, 1, 0.8), 2.0)
	_ctext(r.get_center() + Vector2(0, 5), "%d / %d" % [int(ceil(b.hp)), int(b.max_hp)], 12, INK, big)
	var left := float(b.md.get("enrage", 75.0)) - b.awake_t
	var et := "ENRAGED" if b.enraged else "ENRAGE IN %s" % _fmt(maxf(0.0, left))
	_ctext(Vector2(sz.x * 0.5, r.end.y + 20), et, 12, BAD if b.enraged or left < 20.0 else MUTED, big)
	var lk: Dictionary = m.lairs.sealed_lair(p)
	if not lk.is_empty():
		# sealed in with it: what it takes to get out, and when the seal gives up on its own
		_ctext(Vector2(sz.x * 0.5, r.end.y + 40), "SEALED IN  ·  DEFEAT %s  ·  %s" % [String(b.md["name"]).to_upper(), Lairs.clock(m.lairs.lock_left(lk))], 15, col, big)
	if b.invul_t > 0.0:
		_ctext(Vector2(sz.x * 0.5, r.end.y + (64 if not lk.is_empty() else 44)), "PHASE %d" % (b.phase + 1), 22, col, big)
	feed_top = maxf(feed_top, r.end.y + (54.0 if not lk.is_empty() else 34.0))
