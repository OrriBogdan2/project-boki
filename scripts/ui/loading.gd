extends CanvasLayer
## The screen between home and an expedition: your Hunter's painted splash, full screen and unwashed, with
## a soft shade at the top and bottom edges for the text. Your squad sits top left; the tier name, the
## map, what you're heading into, a tip and the stage being worked on (a spinner over a progress bar)
## stack up the bottom left, so the picture's centre stays clear. The bar follows the real load stages (the build, then the shader warm-up)
## and only ever moves forward. The match builds in short slices between frames (see Match._slice and
## World._slice), so the spinner keeps turning the whole way.

signal shown

const TIPS := [
	"Press {jump} again in the air and hold to glide. You can open your glider off any booster too.",
	"Hits don't knock you out of a glide, but they drain your glider twice as fast. Run it dry and you're spiked: you drop like a stone.",
	"Knocked off an edge? Touch the island's side and you float back up onto it.",
	"Exits open partway through. Stand inside one to fly home with everything you carry.",
	"{throw} sends your Boki out. It stuns what it hits; press again to call it back.",
	"Your attack and your ability keys both belong to your weapon: every weapon has its own ability. Try them in Training.",
	"You only see what's in front of you. Rivals behind you or past a wall stay hidden, and so do you.",
	"Tall grass hides you from anyone outside it. Shooting gives you away for a moment.",
	"Sneak ({crouch}): you move slower and quieter, and you see further.",
	"Get knocked into a wall and you're stunned. Do it to them first.",
	"Shots go exactly where you aim. Fast guns sway in the same small pattern every time, and firing slows your step.",
	"Jump at a wall in the air to kick off it. Light hunters get two kicks.",
	"One hit breaks a crate, pot or barrel. A red powder keg lights a fuse, then blows: get clear.",
	"Weapons you find out here are stronger than your own, but only for this expedition.",
	"Health and armor don't come back on their own. {util1} drinks a tonic, {util2} repairs your armor with a kit. You take more damage while you do either.",
	"Fight alongside your Boki to fill the bond meter, then your Fuse key calls its bond ultimate.",
	"Every Boki has a different ability, and it uses it by itself. {gear1} fires the active glove you found out here.",
	"Your Boki stuns or roots a foe? Shoot it right away for a combo.",
	"In a squad, {base} bases you to the teammate nearest your cursor: 3s standing still, broken by any hit, and you arrive weakened for 3s.",
	"Gloves drop from chests, vaults and bosses. One active glove ({gear1}) and one passive glove at a time; a new one replaces the old.",
	"Go down for good and the Boki you brought are left behind. Old Pell's Black Market sells back the ones nobody claims.",
	"A rival took your Boki? You'll sense it when they're nearby. Take it back.",
	"Knock a wild Boki out, then hold the use key beside it to scan it. Your box holds three capsules.",
	"Jump off the skyship over an island nobody else picked. {jump} opens your glider early for a longer, slower last stretch.",
	"Falling all the way into the abyss is death. Glide (press {jump} again in the air and hold) below the edge to catch an updraft back up, or touch the cliff to climb onto it.",
	"A teammate is down? Stand on their wisp to bring them back. Stand on an enemy's to stomp it, or hold {interact} to finish them.",
	"Dash through a shot at the last moment and you take nothing.",
	"Shrines on the islands give a short power-up. Stand by one and hold {interact}.",
	"The Blight hunts by noise and light. Gunfire, blasts, opened chests and dashing draw it in; sneaking doesn't.",
	"A Watcher's light sweeps the ground. Stay in it and it shrieks, and the Blight nearby comes running. Crouch to stay out of its reach.",
	"The Blight starts weak and grows the longer your squad is out, the deeper you go, and at night.",
]
## What's being worked on, set by whoever builds the match (Main.show_screen, Match): shown by the spinner.
const FADE_IN_T := 0.15  # s the screen takes to fade in before the build starts
const FADE_OUT_T := 0.2  # s it takes to fade out when there is no ink to cover it
const COVER_T := 0.1  # s the ink takes to cover it once the match is ready
const REVEAL_T := 0.2  # s the ink takes to sweep off the match (the match is already running)
const STAGES := {"map": "Building the map", "spawn": "Spawning", "graphics": "Preparing graphics", "ready": "Ready"}

const SHADE_BOTTOM := 0.55  # share of the screen height the bottom shade covers
const SHADE_TOP := 0.25  # share of the screen height the top shade covers
const SHADE_LEFT := 0.6  # share of the screen width the left shade covers (the text sits on it)
const SHADE_ALPHA := 0.75  # black at the very bottom edge (the top and left edges use less)
const MARGIN_SHARE := 0.05  # of the screen width: the margin text and bar keep from the edges
const MARGIN_MIN := 32.0  # px
const MARGIN_MAX := 96.0  # px
const TIP_W := 720.0  # px, the tip line length
const TEXT_W := 640.0  # px, the title block's wrap width
const SQUAD_PX := 72.0  # px, a squad portrait
const SQUAD_GAP := 22.0  # px between squad portraits
const BAR_MIN_SPEED := 0.9  # bar share per second, at least, so it never sits still while the load works
const BAR_CATCH_UP := 6.0  # the bar closes this many times its gap per second (eases out into each stage)

var c: Control
var t := 0.0
var prog := 0.0  # what the bar shows
var want := 0.0  # where the bar is heading
var fade := 0.0
var leaving := false
var tier := 0
var T: Dictionary
var title := ""
var sub := ""
var mode_line := ""
var raid := ""  # the raid condition this expedition rolled ("" when it doesn't roll one)
var tip := ""
var map_name := ""  # the map this expedition is on ("" when unknown)
var party: Array = []  # your squad, [{name, arch, you}] (Prematch.squad_of)
var arch := ""  # the Hunter whose splash fills the screen
var splash_path := ""  # that splash's file ("" when the Hunter has none)
var splash: Texture2D
var shade_bottom: GradientTexture2D
var shade_top: GradientTexture2D
var shade_left: GradientTexture2D
var stage_label := "Building the map"
var spin_draws := 0  # frames the spinner has drawn (--load-check: one per frame means it never stalled)


func _grad(cols: Array, offs: Array, across := false) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 128
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0) if across else Vector2(0, 1)
	return gt


func setup(opts: Dictionary) -> void:
	layer = 45
	tier = clampi(int(opts.get("tier", 0)), 0, Data.TIERS.size() - 1)
	T = Data.TIERS[tier]
	if opts.get("tutorial", false):
		title = "First Expedition"
		sub = (
			"A short, safe trip with %s to learn the ropes. No rivals out here yet."
			% String(Save.active_kin().get("name", "your Boki"))
		)
	elif opts.get("training", false):
		title = "Training Grounds"
		sub = "Dummies, ledges and boosters. No danger here."
	else:
		title = String(T["name"])
		sub = String(T["desc"])
		var teams := int(opts.get("teams", 6))
		var squad := int(opts.get("squad", 1))
		# solo lobbies count hunters ("Solo · 20 squads" read oddly), squad lobbies count squads
		var count := ("%d hunters" % teams) if squad <= 1 else ("%d squads" % teams)
		mode_line = "%s  •  %s  •  skyship drop" % [["Solo", "Duos", "Trios"][clampi(squad - 1, 0, 2)], count]
		if opts.has("net"):
			mode_line = "Online  •  " + mode_line
		if opts.get("rolling", false):
			mode_line = (
				"%s  •  rolling 30-minute session  •  join in progress"
				% ["Solo", "Duos", "Trios"][clampi(squad - 1, 0, 2)]
			)
		raid = RaidLook.pick(opts, int(opts.get("seed", 0)))
		var map_id := String(opts.get("map", World.layout_for_tier(tier)))
		if opts.get("rolling", false):
			map_id = WideLayout.MAP
		map_name = String(World.load_layout(map_id).get("name", ""))
		party = Prematch.squad_of(opts, String(opts.get("arch", Arch.of_save())))
	var tips: Array = (
		TIPS if opts.get("blight", true) else Array(TIPS).filter(func(x): return not String(x).contains("Blight"))
	)
	tip = Settings.fill_keys(tips[randi() % tips.size()])
	arch = String(opts.get("arch", Arch.of_save()))
	splash_path = Portraits.art_path(arch, true)
	if splash_path != "":
		splash = load(splash_path)
	shade_bottom = _grad([Color(0, 0, 0, 0), Color(0, 0, 0, SHADE_ALPHA)], [0.0, 1.0])
	shade_top = _grad([Color(0, 0, 0, SHADE_ALPHA * 0.5), Color(0, 0, 0, 0)], [0.0, 1.0])
	shade_left = _grad([Color(0, 0, 0, SHADE_ALPHA * 0.6), Color(0, 0, 0, 0)], [0.0, 1.0], true)
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


## Where everything sits at a screen size: the squad row, the text block, the tip and the bar. Pure
## geometry (--loading-check reads it), measured from the bottom edge up so a short window lifts the text.
func layout(sz: Vector2) -> Dictionary:
	var m := clampf(sz.x * MARGIN_SHARE, MARGIN_MIN, MARGIN_MAX)
	var bar := Rect2(m, sz.y - m * 0.7, sz.x - m * 2.0, 4.0)
	var tip_w := minf(TIP_W, sz.x - m * 2.0)
	var tip_h := UI.body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, tip_w, 16, 3).y + 22.0
	var tip_box := Rect2(m, bar.position.y - 44.0 - tip_h, tip_w, tip_h)
	var text_w := minf(TEXT_W, sz.x - m * 2.0)
	var sub_h := UI.body.get_multiline_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, text_w, 17, 3).y
	var blurb_h := 0.0
	if raid != "":
		blurb_h = (
			UI
			. body
			. get_multiline_string_size(String(RaidLook.BLURBS.get(raid, "")), HORIZONTAL_ALIGNMENT_LEFT, text_w, 14, 3)
			. y
		)
	var block_h := 70.0 + sub_h
	if mode_line != "":
		block_h += 24.0
	if raid != "":
		block_h += 30.0 + blurb_h
	var block := Rect2(m, tip_box.position.y - 28.0 - block_h, text_w, block_h)
	var squad := Rect2(m, m * 0.8, 0.0, 0.0)
	if not party.is_empty():
		squad.size = Vector2(party.size() * SQUAD_PX + (party.size() - 1) * SQUAD_GAP, SQUAD_PX + 40.0)
	return {"margin": m, "bar": bar, "tip": tip_box, "block": block, "squad": squad}


func _draw() -> void:
	var sz := c.size
	var a := fade
	var lay := layout(sz)
	var m: float = lay["margin"]
	if splash:
		c.draw_texture_rect_region(
			splash,
			Rect2(Vector2.ZERO, sz),
			Portraits.region(arch, splash_path, splash.get_size(), sz),
			Color(1, 1, 1, a)
		)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(T["sky"] as Color, a).darkened(0.5))
	c.draw_texture_rect(
		shade_bottom, Rect2(0, sz.y * (1.0 - SHADE_BOTTOM), sz.x, sz.y * SHADE_BOTTOM), false, Color(1, 1, 1, a)
	)
	c.draw_texture_rect(shade_left, Rect2(0, 0, sz.x * SHADE_LEFT, sz.y), false, Color(1, 1, 1, a))
	c.draw_texture_rect(shade_top, Rect2(0, 0, sz.x, sz.y * SHADE_TOP), false, Color(1, 1, 1, a))
	var block: Rect2 = lay["block"]
	var left := HORIZONTAL_ALIGNMENT_LEFT
	var y := block.position.y
	var kick := "GETTING READY"
	if mode_line != "":
		kick = "EXPEDITION  ·  " + map_name.to_upper() if map_name != "" else "EXPEDITION"
	_text(Vector2(m, y + 14), kick, UI.caps, 15, Color(UI.GOLD, a), 3, left)
	_text(Vector2(m, y + 66), title, UI.big, 58, Color(UI.INK, a), 0, left)
	y += 78.0
	_wrap(Vector2(m, y), sub, 17, block.size.x, Color(UI.INK, a * 0.8))
	y += UI.body.get_multiline_string_size(sub, left, block.size.x, 17, 3).y + 8.0
	if mode_line != "":
		_text(Vector2(m, y + 12), mode_line, UI.semi, 15, Color(UI.TEAL, a), 0, left)
		y += 24.0
	if raid != "":
		var rc: Color = RaidLook.COLORS.get(raid, UI.INK)
		_text(
			Vector2(m, y + 22),
			"CONDITIONS  ·  " + String(RaidLook.NAMES.get(raid, raid)).to_upper(),
			UI.caps,
			13,
			Color(rc, a),
			2,
			left
		)
		_wrap(Vector2(m, y + 28), String(RaidLook.BLURBS.get(raid, "")), 14, block.size.x, Color(UI.INK, a * 0.75))
	var tip_box: Rect2 = lay["tip"]
	c.draw_rect(Rect2(tip_box.position, Vector2(2.0, tip_box.size.y)), Color(UI.ACCENT, a * 0.9))
	_text(Vector2(tip_box.position.x + 14.0, tip_box.position.y + 12), "TIP", UI.caps, 11, Color(UI.ACCENT, a), 2, left)
	_wrap(
		Vector2(tip_box.position.x + 14.0, tip_box.position.y + 14.0),
		tip,
		16,
		tip_box.size.x - 14.0,
		Color(UI.INK, a * 0.9)
	)
	var br: Rect2 = lay["bar"]
	var af := snappedf(a, 0.1)
	UI.draw_bar(c, br, prog if prog > 0.01 else 0.0, Color(UI.ACCENT, af), Color(1, 1, 1, af * 0.18), 2)
	_spinner(Vector2(br.position.x + 7.0, br.position.y - 17.0), a)
	_text(
		Vector2(br.position.x + 22.0, br.position.y - 12),
		stage_label + "…",
		UI.semi,
		13,
		Color(UI.INK, a * 0.85),
		0,
		left
	)
	_text(
		Vector2(br.end.x, br.position.y - 12),
		"%d%%" % int(prog * 100.0),
		UI.semi,
		13,
		Color(UI.INK, a * 0.6),
		0,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_squad_row(lay["squad"], a)


## Your squad's portraits and names, top left: who you are dropping with.
func _squad_row(r: Rect2, a: float) -> void:
	if party.is_empty():
		return
	var left := HORIZONTAL_ALIGNMENT_LEFT
	_text(Vector2(r.position.x, r.position.y - 6.0), "YOUR SQUAD", UI.caps, 12, Color(UI.GOLD, a), 2, left)
	var x := r.position.x
	for mate in party:
		var ak: String = mate["arch"]
		Portraits.draw(
			c,
			Rect2(x, r.position.y, SQUAD_PX, SQUAD_PX),
			ak,
			null,
			Color(Arch.color(ak) if Arch.exists(ak) else UI.MUTED, a)
		)
		_text(
			Vector2(x + SQUAD_PX * 0.5, r.position.y + SQUAD_PX + 20.0),
			String(mate["name"]),
			UI.semi,
			13,
			Color(UI.INK, a * 0.9)
		)
		_text(
			Vector2(x + SQUAD_PX * 0.5, r.position.y + SQUAD_PX + 36.0),
			Arch.label(ak),
			UI.body,
			12,
			Color(UI.MUTED, a * 0.9)
		)
		x += SQUAD_PX + SQUAD_GAP


## A ring with a turning arc that grows and shrinks as it goes round: moves every frame, so a
## stalled frame shows at once.
func _spinner(p: Vector2, a: float) -> void:
	spin_draws += 1
	var r := 7.0
	c.draw_arc(p, r, 0.0, TAU, 28, Color(1, 1, 1, a * 0.14), 2.5, true)
	var head := t * TAU * 1.15
	var span := lerpf(0.5, 3.6, 0.5 + 0.5 * sin(t * 2.6))
	c.draw_arc(p, r, head - span, head, 24, Color(UI.ACCENT, a), 2.5, true)


func _text(
	pos: Vector2, s: String, f: Font, size: int, col: Color, spacing := 0, al := HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	var w := 900.0
	var x := pos.x - w * 0.5
	if al == HORIZONTAL_ALIGNMENT_LEFT:
		x = pos.x
	elif al == HORIZONTAL_ALIGNMENT_RIGHT:
		x = pos.x - w
	if spacing > 0:
		s = " ".join(s.split(""))
	c.draw_string(f, Vector2(x + 2, pos.y + 2), s, al, w, size, Color(0, 0, 0, col.a * 0.55))
	c.draw_string(f, Vector2(x, pos.y), s, al, w, size, col)


func _wrap(pos: Vector2, s: String, size: int, w: float, col: Color) -> void:
	c.draw_multiline_string(
		UI.body,
		Vector2(pos.x + 1, pos.y + size + 1),
		s,
		HORIZONTAL_ALIGNMENT_LEFT,
		w,
		size,
		3,
		Color(0, 0, 0, col.a * 0.55)
	)
	c.draw_multiline_string(UI.body, Vector2(pos.x, pos.y + size), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, 3, col)
