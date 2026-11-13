extends CanvasLayer
## The screen between home and an expedition: your Hunter's splash, the map name over one mode line,
## your squad, a spinner with the stage being worked on over one progress bar, and one tip. The bar
## follows the real load stages (the build, then the shader warm-up) and only ever moves forward. The
## match builds in short slices between frames (see Match._slice and World._slice), so the spinner keeps
## turning the whole way.

signal shown

const TIPS := [
	"Press Space again in the air (or Mouse 5) and hold to glide. You can open your glider off any booster too.",
	"Hits don't knock you out of a glide, but they drain your glider twice as fast. Run it dry and you're spiked: you drop like a stone.",
	"Knocked off an edge? Touch the island's side and you float back up onto it.",
	"Exits open partway through. Stand inside one to fly home with everything you carry.",
	"Your Boki key (or middle mouse) sends your Boki out. It stuns what it hits; press again to call it back.",
	"Left and right click both belong to your weapon: every weapon has its own right-click ability. Try them in Training.",
	"You only see what's in front of you. Rivals behind you or past a wall stay hidden, and so do you.",
	"Tall grass hides you from anyone outside it. Shooting gives you away for a moment.",
	"Sneak (Ctrl): you move slower and quieter, and you see further.",
	"Get knocked into a wall and you're stunned. Do it to them first.",
	"Shots go exactly where you aim. Fast guns sway in the same small pattern every time, and firing slows your step.",
	"Jump at a wall in the air to kick off it. Light hunters get two kicks.",
	"One hit breaks a crate, pot or barrel. A red powder keg lights a fuse, then blows: get clear.",
	"Weapons you find out here are stronger than your own, but only for this expedition.",
	"Health and armor don't come back on their own. 1 drinks a tonic, 2 repairs your armor with a kit. You take more damage while you do either.",
	"Fight alongside your Boki to fill the bond meter, then your Fuse key calls its bond ultimate.",
	"Every Boki has a different ability, and it uses it by itself. Q fires the active glove you found out here.",
	"Your Boki stuns or roots a foe? Shoot it right away for a combo.",
	"In a squad, B bases you to the teammate nearest your cursor: 3s standing still, broken by any hit, and you arrive weakened for 3s.",
	"Gloves drop from chests, vaults and bosses. One active glove (Q) and one passive glove at a time; a new one replaces the old.",
	"Go down for good and the Boki you brought are left behind. Old Pell's Black Market sells back the ones nobody claims.",
	"A rival took your Boki? You'll sense it when they're nearby. Take it back.",
	"Knock a wild Boki out, then hold the use key beside it to scan it. Your box holds three capsules.",
	"Jump off the skyship over an island nobody else picked. Space opens your glider early for a longer, slower last stretch.",
	"Falling all the way into the abyss is death. Glide (press Space again in the air, or Mouse 5, and hold) below the edge to catch an updraft back up, or touch the cliff to climb onto it.",
	"A teammate is down? Stand on their wisp to bring them back. Stand on an enemy's to stomp it, or hold F to finish them.",
	"Dash through a shot at the last moment and you take nothing.",
	"Shrines on the islands give a short power-up. Stand by one and hold F.",
	"The Blight hunts by noise and light. Gunfire, blasts, opened chests and dashing draw it in; sneaking doesn't.",
	"A Watcher's light sweeps the ground. Stay in it and it shrieks, and the Blight nearby comes running. Crouch to stay out of its reach.",
	"The Blight starts weak and grows the longer your squad is out, the deeper you go, and at night.",
]
## What's being worked on, set by whoever builds the match (Main.show_screen, Match): shown by the spinner.
const STAGES := {"map": "Building the map", "spawn": "Spawning", "graphics": "Preparing graphics", "ready": "Ready"}
const FADE_IN_T := 0.15     # s the screen takes to fade in before the build starts
const FADE_OUT_T := 0.2     # s it takes to fade out when there is no ink to cover it
const COVER_T := 0.1        # s the ink takes to cover it once the match is ready
const REVEAL_T := 0.2       # s the ink takes to sweep off the match (the match is already running)
const MARGIN_FRAC := 0.05   # the screen's edge margin as a fraction of its height
const TITLE_FRAC := 0.055   # the map name's size as a fraction of the screen height
const FACE_FRAC := 0.09     # a squad portrait's side as a fraction of the screen height
const TIP_W := 900.0        # px, the widest the tip runs before it wraps
const SHADE := Color(0.05, 0.035, 0.08)    # the dark the splash fades into under the text

const SKY_TINT := 0.45     # how much of the tier's sky gradient lies over the splash (0..1)
const BAR_MIN_SPEED := 0.9  # bar share per second, at least, so it never sits still while the load works
const BAR_CATCH_UP := 6.0   # the bar closes this many times its gap per second (eases out into each stage)

var c: Control
var t := 0.0
var prog := 0.0          # what the bar shows
var want := 0.0          # where the bar is heading
var fade := 0.0
var leaving := false
var title := ""          # the map's name (the tutorial's and training's own names)
var mode_line := ""      # tier, squad size, count and raid condition ("" off expeditions)
var tip := ""
var party: Array = []    # your squad, [{name, arch, you}] (Prematch.squad_of)
var arch := ""           # the Hunter whose splash fills the screen
var splash_path := ""    # that splash's file ("" when the Hunter has none)
var splash: Texture2D    # your Hunter's splash art (null if it has none)
var shade_tex: GradientTexture2D
var stage_label := "Building the map"
var spin_draws := 0      # frames the spinner has drawn (--load-check: one per frame means it never stalled)

func setup(opts: Dictionary) -> void:
	layer = 45
	var tier := clampi(int(opts.get("tier", 0)), 0, Data.TIERS.size() - 1)
	var mine := String(opts.get("arch", Arch.of_save()))
	if opts.get("tutorial", false):
		title = "First Expedition"
	elif opts.get("training", false):
		title = "Training Grounds"
	else:
		var map_id := WideLayout.MAP if opts.get("rolling", false) else String(opts.get("map", World.layout_for_tier(tier)))
		title = String(World.load_layout(map_id).get("name", Data.TIERS[tier]["name"]))
		mode_line = _mode(opts, String(Data.TIERS[tier]["name"]))
		party = Prematch.squad_of(opts, mine)
	var tips: Array = TIPS if opts.get("blight", true) else Array(TIPS).filter(func(x): return not String(x).contains("Blight"))
	tip = tips[randi() % tips.size()]
	arch = mine
	splash_path = Portraits.art_path(mine, true)
	splash = load(splash_path) if splash_path != "" else null
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(SHADE, 0.0), Color(SHADE, 0.7), Color(SHADE, 0.92)])
	shade_tex = GradientTexture2D.new()
	shade_tex.gradient = g
	shade_tex.fill_to = Vector2(0, 1)
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.draw.connect(_draw)
	add_child(c)

## The mode line: tier, squad size, how many (solo lobbies count hunters, squad lobbies squads), online,
## a rolling session, and the raid condition this expedition rolled.
func _mode(opts: Dictionary, tier_name: String) -> String:
	var squad := int(opts.get("squad", 1))
	var size_word: String = ["Solo", "Duos", "Trios"][clampi(squad - 1, 0, 2)]
	var teams := int(opts.get("teams", 6))
	var parts: Array = [tier_name, size_word, ("%d hunters" % teams) if squad <= 1 else ("%d squads" % teams)]
	if opts.get("rolling", false):
		parts[2] = "rolling session"
	if opts.has("net"):
		parts.push_front("Online")
	var raid := RaidLook.pick(opts, int(opts.get("seed", 0)))
	if raid != "":
		parts.append(String(RaidLook.NAMES.get(raid, raid)))
	return "  ·  ".join(parts)

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

## Bottom up: the tip, the bar with its stage and percent, then the map name and mode line on the left
## and the squad on the right, all over the splash fading to dark below.
func _draw() -> void:
	var sz := c.size
	var a := fade
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(UI.BG, a))
	if splash:
		c.draw_texture_rect_region(splash, Rect2(Vector2.ZERO, sz), Portraits.region(arch, splash_path, splash.get_size(), sz), Color(1, 1, 1, a))
	c.draw_texture_rect(shade_tex, Rect2(0, sz.y * 0.35, sz.x, sz.y * 0.65), false, Color(1, 1, 1, a))
	var m := maxf(24.0, sz.y * MARGIN_FRAC)
	var tw := minf(TIP_W, sz.x - 2.0 * m)
	var tip_h := UI.body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_CENTER, tw, 15, 2).y
	c.draw_multiline_string(UI.body, Vector2(sz.x * 0.5 - tw * 0.5, sz.y - m - tip_h + 15.0), tip,
		HORIZONTAL_ALIGNMENT_CENTER, tw, 15, 2, Color(UI.MUTED, a))
	var br := Rect2(m, sz.y - m - tip_h - 22.0, sz.x - 2.0 * m, 6)
	var af := snappedf(a, 0.1)
	UI.draw_bar(c, br, prog if prog > 0.01 else 0.0, Color(UI.ACCENT, af), Color(1, 1, 1, af * 0.12), 3)
	_spinner(Vector2(br.position.x + 7.0, br.position.y - 15.0), a)
	_text(Vector2(br.position.x + 22.0, br.position.y - 10), stage_label + "…", UI.semi, 13, Color(UI.INK, a * 0.8),
		HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(br.end.x, br.position.y - 10), "%d%%" % int(prog * 100.0), UI.semi, 13, Color(UI.INK, a * 0.55),
		HORIZONTAL_ALIGNMENT_RIGHT)
	var base := br.position.y - 44.0
	if mode_line != "":
		_text(Vector2(m, base), mode_line, UI.semi, 16, Color(UI.TEAL, a), HORIZONTAL_ALIGNMENT_LEFT)
		base -= 30.0
	_text(Vector2(m, base), title, UI.big, maxi(36, int(sz.y * TITLE_FRAC)), Color(UI.INK, a), HORIZONTAL_ALIGNMENT_LEFT)
	_squad_row(Vector2(sz.x - m, br.position.y - 62.0), clampf(sz.y * FACE_FRAC, 64.0, 100.0), a)

## Your squad's portraits with their names under them, right-aligned to `p` (the names' baseline).
func _squad_row(p: Vector2, px: float, a: float) -> void:
	var gap := 18.0
	var x := p.x - party.size() * px - (party.size() - 1) * gap
	for mate in party:
		var ak: String = mate["arch"]
		Portraits.draw(c, Rect2(x, p.y - 20.0 - px, px, px), ak, null, Color(Arch.color(ak) if Arch.exists(ak) else UI.MUTED, a))
		var col := UI.ACCENT_HI if mate["you"] else UI.INK
		_text(Vector2(x + px * 0.5, p.y), String(mate["name"]), UI.semi, 14, Color(col, a * 0.9))
		x += px + gap

## A ring with a turning arc that grows and shrinks as it goes round: moves every frame, so a
## stalled frame shows at once.
func _spinner(p: Vector2, a: float) -> void:
	spin_draws += 1
	var r := 7.0
	c.draw_arc(p, r, 0.0, TAU, 28, Color(1, 1, 1, a * 0.14), 2.5, true)
	var head := t * TAU * 1.15
	var span := lerpf(0.5, 3.6, 0.5 + 0.5 * sin(t * 2.6))
	c.draw_arc(p, r, head - span, head, 24, Color(UI.ACCENT, a), 2.5, true)

## One line of text with a soft drop shadow, centred on (or starting/ending at) `pos.x`.
func _text(pos: Vector2, s: String, f: Font, size: int, col: Color, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 900.0
	var x := pos.x - w * 0.5
	if al == HORIZONTAL_ALIGNMENT_LEFT:
		x = pos.x
	elif al == HORIZONTAL_ALIGNMENT_RIGHT:
		x = pos.x - w
	c.draw_string(f, Vector2(x + 2, pos.y + 2), s, al, w, size, Color(0, 0, 0, col.a * 0.5))
	c.draw_string(f, Vector2(x, pos.y), s, al, w, size, col)
