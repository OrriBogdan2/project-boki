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
	if not (m.tut and m.tut.intro):
		var sz := size
		hud._draw_top(sz)
		if p and m.lairs:
			hud._draw_boss_bar(sz, p)        # (these two push the feed down: before it)
			hud._draw_lair_victory(sz, p)
		hud._draw_feed(sz)
		hud._draw_minimap(sz)
		if p and not p.out and not p.extracted:
			HudVitals.draw(hud, sz, p)
			hud._draw_abilities(sz, p)
			hud._draw_weapon(sz, p)
			GearPanel.draw(hud, sz, p)
			hud._draw_kin_card(sz, p)
			hud._draw_squad(sz, p)
			TeamBoki.draw(hud, p)
			hud._draw_perks(sz, p)
	hud.c = main_canvas
	used_us += Time.get_ticks_usec() - t0
