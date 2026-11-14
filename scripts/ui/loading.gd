extends CanvasLayer
## The screen between home and an expedition: your Hunter's painted splash under the tier's sky tint,
## the tier name, the map, what you're heading into, a tip, and a spinner with the stage being worked
## on over a progress bar. The bar follows the real load stages (the build, then the shader warm-up)
## and only ever moves forward. The match builds in short slices between frames (see Match._slice and
## World._slice), so the spinner keeps turning the whole way.

signal shown

## A line of the world's story shown under the tip (our own words; the canon is briefs/LORE_MASKS.md).
const LORE := [
	"Everyone born since the Hollowing is born without a face. We call ourselves the Empty.",
	"A Mask holds the soul of a Hunter who stood against the Wyrm. Wear one and you remember what a self feels like.",
	"Malgrave the Beloved never aged, and never forgot her vault. Under the Crown, it was always the Wyrm.",
	"The Blight is the Wyrm's blood. It sours stone, grass and sky, and it follows whoever is loudest.",
	"A thief once reached the Wyrmheart. Whatever she wished for, the whole land is still paying for it.",
	"People once dug up Masks to smash them. Now they dig for the same relics to be whole again.",
	"Skyfolk, beasts and humans all lost their faces alike. The sky doesn't ask who you were.",
	"One wish waits in the Wyrmheart: remake the world, or rule it. Every Hunter wants it. So does the Wyrm.",
	"Not every Mask has a face. Some are a compass, a jar, a pair of skates, and they remember just as much.",
	"Bring home what you carry. Out here, only what reaches the farm is truly yours.",
]
## What's being worked on, set by whoever builds the match (Main.show_screen, Match): shown by the spinner.
const FADE_IN_T := 0.15     # s the screen takes to fade in before the build starts
const FADE_OUT_T := 0.2     # s it takes to fade out when there is no ink to cover it
const COVER_T := 0.1        # s the ink takes to cover it once the match is ready
const REVEAL_T := 0.2       # s the ink takes to sweep off the match (the match is already running)
const STAGES := {"map": "Building the map", "spawn": "Spawning", "graphics": "Preparing graphics", "ready": "Ready"}

const SKY_TINT := 0.45     # how much of the tier's sky gradient lies over the splash (0..1)
const BAR_MIN_SPEED := 0.9  # bar share per second, at least, so it never sits still while the load works
const BAR_CATCH_UP := 6.0   # the bar closes this many times its gap per second (eases out into each stage)

var c: Control
var t := 0.0
var prog := 0.0          # what the bar shows
var want := 0.0          # where the bar is heading
var fade := 0.0
var leaving := false
var tier := 0
var T: Dictionary
var title := ""
var sub := ""
var mode_line := ""
var raid := ""           # the raid condition this expedition rolled ("" when it doesn't roll one)
var tip := ""
var lore := ""
var map_name := ""       # the map this expedition is on ("" when unknown)
var party: Array = []    # your squad, [{name, arch, you}] (Prematch.squad_of)
var arch := ""           # the Hunter whose splash fills the screen
var splash_path := ""    # that splash's file ("" when the Hunter has none)
var splash: Texture2D
var sky_tex: GradientTexture2D
var shade_tex: GradientTexture2D
var _glass_at := {}      # fade step -> the tip card's glass box
var stage_label := "Building the map"
var spin_draws := 0      # frames the spinner has drawn (--load-check: one per frame means it never stalled)

func _grad(cols: Array, offs: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols); g.offsets = PackedFloat32Array(offs)
	var gt := GradientTexture2D.new()
	gt.gradient = g; gt.width = 128; gt.height = 128
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	return gt

func setup(opts: Dictionary) -> void:
	layer = 45
	tier = clampi(int(opts.get("tier", 0)), 0, Data.TIERS.size() - 1)
	T = Data.TIERS[tier]
	if opts.get("tutorial", false):
		title = "First Expedition"; sub = "A short, safe trip with %s to learn the ropes. No rivals out here yet." % String(Save.active_kin().get("name", "your Boki"))
	elif opts.get("training", false):
		title = "Training Grounds"; sub = "Dummies, ledges and boosters. No danger here."
	else:
		title = String(T["name"]); sub = String(T["desc"])
		var teams := int(opts.get("teams", 6)); var squad := int(opts.get("squad", 1))
		# solo lobbies count hunters ("Solo · 20 squads" read oddly), squad lobbies count squads
		var count := ("%d hunters" % teams) if squad <= 1 else ("%d squads" % teams)
		mode_line = "%s  •  %s  •  skyship drop" % [["Solo", "Duos", "Trios"][clampi(squad - 1, 0, 2)], count]
		if opts.has("net"): mode_line = "Online  •  " + mode_line
		if opts.get("rolling", false): mode_line = "%s  •  rolling 30-minute session  •  join in progress" % ["Solo", "Duos", "Trios"][clampi(squad - 1, 0, 2)]
		raid = RaidLook.pick(opts, int(opts.get("seed", 0)))
		var map_id := String(opts.get("map", World.layout_for_tier(tier)))
		if opts.get("rolling", false):
			map_id = WideLayout.MAP
		map_name = String(World.load_layout(map_id).get("name", ""))
		party = Prematch.squad_of(opts, String(opts.get("arch", Arch.of_save())))
	tip = TipPick.for_loading(opts.get("blight", true))
	lore = LORE[randi() % LORE.size()]
	arch = String(opts.get("arch", Arch.of_save()))
	splash_path = Portraits.art_path(arch, true)
	if splash_path != "":
		splash = load(splash_path)
	var sky: Color = T["sky"]
	var cl: Array = T["clouds"]
	sky_tex = _grad([sky.darkened(0.3), sky.lerp(cl[1], 0.35), (cl[1] as Color).lerp(sky, 0.1)], [0.0, 0.6, 1.0])
	shade_tex = _grad([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.8)], [0.0, 0.55, 1.0])
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.draw.connect(_draw)
	add_child(c)

func _process(delta: float) -> void:
	t += delta
	if leaving:
		fade = maxf(0.0, fade - delta / FADE_OUT_T)
		if fade <= 0.0:
			queue_free()
	else:
		var was := fade
		fade = minf(1.0, fade + delta / FADE_IN_T)
		if was < 1.0 and fade >= 1.0:
			shown.emit()
	prog = move_toward(prog, want, delta * maxf(BAR_MIN_SPEED, (want - prog) * BAR_CATCH_UP))
	c.queue_redraw()

## A real load stage reached (0..1 of the whole load): the bar's target only ever moves forward, so a
## stage reporting less than an earlier one changes nothing.
func advance(frac: float) -> void:
	want = maxf(want, clampf(frac, 0.0, 1.0))

## Move the bar to a stage (0..1) and wait until it gets there.
func step(frac: float) -> void:
	advance(frac)
	while prog < want - 0.01 and is_inside_tree():
		await get_tree().process_frame

## The match is built and drawn: the bar fills at once and the screen goes, with nothing to wait out
## (playtest 11-09: players were held on a full bar). The ink covers it, then sweeps off the match.
func finish() -> void:
	want = 1.0
	prog = 1.0
	# gone before the map shows: fading this out over the planning map blended the two, so the
	# screen's ink sweeps over first, this goes, and the ink sweeps off the map
	var sf: ScreenFade = Game.main.get("fade") if Game.main else null
	if sf and is_inside_tree() and not sf.covered:
		await sf.cover(COVER_T)
		queue_free()
		sf.reveal(REVEAL_T)
		return
	leaving = true

## Names the stage under the spinner (a key of STAGES).
func set_stage(key: String) -> void:
	stage_label = String(STAGES.get(key, key))

func _draw() -> void:
	var sz := c.size
	var a := fade
	# the Hunter's splash filling the screen (its framing point stays in view), the tier's sky tinted over it
	if splash:
		c.draw_texture_rect_region(splash, Rect2(Vector2.ZERO, sz), Portraits.region(arch, splash_path, splash.get_size(), sz), Color(1, 1, 1, a))
	c.draw_texture_rect(sky_tex, Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, a * (SKY_TINT if splash else 1.0)))
	# a soft shade behind the text
	c.draw_texture_rect(shade_tex, Rect2(0, sz.y * 0.42, sz.x, sz.y * 0.58), false, Color(1, 1, 1, a))
	# progress and the tip card sit at the bottom; the text block above them moves up when it would reach the bar
	var cx := sz.x * 0.5
	var tw_ := minf(660.0, sz.x - 60.0)
	var lines := UI.body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_CENTER, tw_ - 40.0, 15, 3).y
	var lore_h := UI.body.get_multiline_string_size(lore, HORIZONTAL_ALIGNMENT_CENTER, tw_ - 40.0, 14, 3).y + 12.0
	var card := Rect2(cx - tw_ * 0.5, sz.y - 24.0 - (40.0 + lines + lore_h), tw_, 40.0 + lines + lore_h)
	var bw := minf(480.0, sz.x - 80.0)
	var br := Rect2(cx - bw * 0.5, card.position.y - 30.0, bw, 6)
	# text: the block's height from its first line, so a short window lifts it clear of the bar
	var tw_w := minf(620.0, sz.x - 60.0)
	var blurb := String(RaidLook.BLURBS.get(raid, "")) if raid != "" else ""
	var blurb_w := minf(560.0, sz.x - 60.0)
	var block := 96.0 + UI.body.get_multiline_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, tw_w, 17, 3).y
	if mode_line != "":
		block = maxf(block, 182.0)
	if raid != "":
		block = 214.0 + UI.body.get_multiline_string_size(blurb, HORIZONTAL_ALIGNMENT_CENTER, blurb_w, 14, 3).y
	var base := minf(sz.y * 0.47, br.position.y - 44.0 - block)
	var kick := "GETTING READY"
	if mode_line != "":
		kick = "EXPEDITION  ·  " + map_name.to_upper() if map_name != "" else "EXPEDITION"
	_text(Vector2(cx, base), kick, UI.caps, 15, Color(UI.GOLD, a), 3)
	_text(Vector2(cx, base + 62), title, UI.big, 58, Color(UI.INK, a))
	_wrap(Vector2(cx, base + 96), sub, 17, tw_w, Color(UI.MUTED, a))
	if mode_line != "":
		_text(Vector2(cx, base + 176), mode_line, UI.semi, 15, Color(UI.TEAL, a))
	if raid != "":
		# the raid condition, shown before you drop
		var rc: Color = RaidLook.COLORS.get(raid, UI.INK)
		_text(Vector2(cx, base + 204), "CONDITIONS  ·  " + String(RaidLook.NAMES.get(raid, raid)).to_upper(), UI.caps, 13, Color(rc, a), 2)
		_wrap(Vector2(cx, base + 210), blurb, 14, blurb_w, Color(UI.MUTED, a * 0.9))
	var af := snappedf(a, 0.1)
	UI.draw_bar(c, br, prog if prog > 0.01 else 0.0, Color(UI.ACCENT, af), Color(1, 1, 1, af * 0.12), 3)
	_spinner(Vector2(br.position.x + 7.0, br.position.y - 15.0), a)
	_text(Vector2(br.position.x + 22.0, br.position.y - 10), stage_label + "…", UI.semi, 13, Color(UI.INK, a * 0.8), 0, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(br.end.x, br.position.y - 10), "%d%%" % int(prog * 100.0), UI.semi, 13, Color(UI.INK, a * 0.55), 0, HORIZONTAL_ALIGNMENT_RIGHT)
	# the tip, on a glass card with a small accent tag
	c.draw_style_box(_glass(af), card)
	_text(Vector2(cx, card.position.y + 22), "TIP", UI.caps, 11, Color(UI.ACCENT, a), 2)
	_wrap(Vector2(cx, card.position.y + 26), tip, 15, tw_ - 40.0, Color(UI.INK, a * 0.85))
	_wrap(Vector2(cx, card.position.y + 30.0 + lines), lore, 14, tw_ - 40.0, Color(UI.TEAL, a * 0.75))
	_squad_row(Vector2(cx, sz.y * 0.1), a)

## Your squad's portraits and names across the top: who you are dropping with.
func _squad_row(p: Vector2, a: float) -> void:
	if party.is_empty():
		return
	var px := 72.0
	var gap := 22.0
	var x := p.x - (party.size() * px + (party.size() - 1) * gap) * 0.5
	_text(Vector2(p.x, p.y - 14.0), "YOUR SQUAD", UI.caps, 12, Color(UI.GOLD, a), 2)
	for m in party:
		var ak: String = m["arch"]
		var r := Rect2(x, p.y, px, px)
		Portraits.draw(c, r, ak, null, Color(Arch.color(ak) if Arch.exists(ak) else UI.MUTED, a))
		_text(Vector2(x + px * 0.5, p.y + px + 20.0), String(m["name"]), UI.semi, 13, Color(UI.INK, a * 0.9))
		_text(Vector2(x + px * 0.5, p.y + px + 36.0), Arch.label(ak), UI.body, 12, Color(UI.MUTED, a * 0.9))
		x += px + gap

## The tip's glass card at a fade step (cached: drawn every frame while loading).
func _glass(alpha: float) -> UiFrame:
	if not _glass_at.has(alpha):
		var g := UI.frame(Color(UI.NIGHT, alpha * 0.72), 14, Color(1, 1, 1, alpha * 0.07), 1, 0.0, 0.0, alpha * 0.04)
		_glass_at[alpha] = g
	return _glass_at[alpha]

## A ring with a turning arc that grows and shrinks as it goes round: moves every frame, so a
## stalled frame shows at once.
func _spinner(p: Vector2, a: float) -> void:
	spin_draws += 1
	var r := 7.0
	c.draw_arc(p, r, 0.0, TAU, 28, Color(1, 1, 1, a * 0.14), 2.5, true)
	var head := t * TAU * 1.15
	var span := lerpf(0.5, 3.6, 0.5 + 0.5 * sin(t * 2.6))
	c.draw_arc(p, r, head - span, head, 24, Color(UI.ACCENT, a), 2.5, true)

func _text(pos: Vector2, s: String, f: Font, size: int, col: Color, spacing := 0, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 900.0
	var x := pos.x - w * 0.5
	if al == HORIZONTAL_ALIGNMENT_LEFT: x = pos.x
	elif al == HORIZONTAL_ALIGNMENT_RIGHT: x = pos.x - w
	if spacing > 0:
		s = " ".join(s.split(""))
	c.draw_string(f, Vector2(x + 2, pos.y + 2), s, al, w, size, Color(0, 0, 0, col.a * 0.4))
	c.draw_string(f, Vector2(x, pos.y), s, al, w, size, col)

func _wrap(pos: Vector2, s: String, size: int, w: float, col: Color) -> void:
	c.draw_multiline_string(UI.body, Vector2(pos.x - w * 0.5, pos.y + size), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, 3, col)
