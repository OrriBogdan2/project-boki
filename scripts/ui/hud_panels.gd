class_name HudPanels
extends Control
## The HUD's fixed panels (top bar, boss bar, kill feed, minimap, vitals, ability and weapon slots, gear, Boki card,
## squad, perks) on their own canvas under the Hud's, redrawn REDRAW_HZ times a second instead of every
## frame: item 94, they cost 6-11 ms a frame on the owner's PC (the canvas keeps its last drawing in
## between). Everything that moves with the world or the mouse (labels, crosshair, prompts, hit flashes)
## stays on Hud.c, redrawn every frame. While this draws, Hud.c points at this canvas, so the panel
## code (and the HudVitals / GearPanel / BeltHud helpers) draw here unchanged.

const REDRAW_HZ := 20.0      # panel redraws per second
var hud: Node
var _t := 0.0
var used_us := 0             # microseconds spent drawing since tooling last read it (--perf-probe, --perf-bench)
static var draws := 0        # panel redraws so far; RankMarks keeps a "+" only while the latest one drew it

static func make(h: Node) -> HudPanels:
	var p := HudPanels.new()
	p.hud = h
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS      # (the painted minimap, as on Hud.c)
	p.draw.connect(p._draw_panels)
	return p

## Called from Hud._process every frame. At least MIN_FRAMES frames apart too, so a slow machine (where
## every frame is over 50 ms) still saves two draws in three.
const MIN_FRAMES := 3
var _frames := 0
func tick(delta: float) -> void:
	_t -= delta
	_frames += 1
	if _t <= 0.0 and _frames >= MIN_FRAMES:
		_t = 1.0 / REDRAW_HZ
		_frames = 0
		queue_redraw()

func _draw_panels() -> void:
	var t0 := Time.get_ticks_usec()
	draws += 1
	var main_canvas: Control = hud.c
	hud.c = self
	hud.hover_spots.clear()
	var m: Match = hud.m
	var p: Hunter = m.player
	if DropHud.aboard(p):
		hud._draw_minimap(size)      # aboard the rocket: the map and nothing else (DropHud)
	elif not (m.tut and m.tut.intro):
		var sz := size
<<<<<<< HEAD
		SafeArea.begin("top")
		if HudReveal.on(m, "counters"):
			hud._draw_top(sz)
=======
		HudScale.pass_start()
		HudScale.begin(hud, "top", sz)
		hud._draw_top(sz)
>>>>>>> c556bb8a67 (HUD size: Settings hud_scale 80-130% scales each HUD group about its anchor inside the safe area)
		if p and m.lairs:
			HudScale.begin(hud, "boss", sz)
			hud._draw_boss_bar(sz, p)        # (these two push the feed down: before it)
			hud._draw_lair_victory(sz, p)
<<<<<<< HEAD
		SafeArea.begin("feed")
		if HudReveal.on(m, "feed"):
			hud._draw_feed(sz)
		SafeArea.begin("minimap")
=======
		HudScale.begin(hud, "feed", sz)
		hud._draw_feed(sz)
		HudScale.begin(hud, "minimap", sz)
>>>>>>> c556bb8a67 (HUD size: Settings hud_scale 80-130% scales each HUD group about its anchor inside the safe area)
		hud._draw_minimap(sz)
		if p and not p.out and not p.extracted:
			HudScale.begin(hud, "vitals", sz)
			HudVitals.draw(hud, sz, p)
			HudScale.begin(hud, "abilities", sz)
			hud._draw_abilities(sz, p)
			HudScale.begin(hud, "weapon", sz)
			hud._draw_weapon(sz, p)
<<<<<<< HEAD
			if HudReveal.on(m, "gear"):
				SafeArea.begin("gear")
				GearPanel.draw(hud, sz, p)
			SafeArea.begin("kin")
			hud._draw_kin_card(sz, p)
			if HudReveal.on(m, "squad"):
				SafeArea.begin("squad")
				SquadFrames.draw(hud, sz, p)
				TeamBoki.draw(hud, p)
			if HudReveal.on(m, "perks"):
				SafeArea.begin("perks")
				hud._draw_perks(sz, p)
		else:
			m.spectate.draw(hud, sz)
=======
			HudScale.begin(hud, "gear", sz)
			GearPanel.draw(hud, sz, p)
			HudScale.begin(hud, "kin", sz)
			hud._draw_kin_card(sz, p)
			HudScale.begin(hud, "squad", sz)
			hud._draw_squad(sz, p)
			TeamBoki.draw(hud, p)
			HudScale.begin(hud, "perks", sz)
			hud._draw_perks(sz, p)
	HudScale.close(hud)
>>>>>>> c556bb8a67 (HUD size: Settings hud_scale 80-130% scales each HUD group about its anchor inside the safe area)
	SafeArea.begin("")
	HudScale.pass_end()
	hud.c = main_canvas
	used_us += Time.get_ticks_usec() - t0
