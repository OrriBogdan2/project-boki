extends CanvasLayer
## The screen between home and an expedition: the tier's sky with islands drifting past and the
## skyship crossing, the tier name, what you're heading into, a tip, and a spinner with the stage
## being worked on over a progress bar. The match builds in short slices between frames (see
## Match._slice and World._slice), so the spinner keeps turning the whole way.

signal shown

const TIPS := [
	"Hold Space in the air to glide. You can open your glider off any booster too.",
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
	"Falling all the way into the abyss is death. Glide (hold Space) below the edge to catch an updraft back up, or touch the cliff to climb onto it.",
	"A teammate is down? Stand on their wisp to bring them back. Stand on an enemy's to stomp it, or hold F to finish them.",
	"Dash through a shot at the last moment and you take nothing.",
	"Shrines on the islands give a short power-up. Stand by one and hold F.",
	"The Blight hunts by noise and light. Gunfire, blasts, opened chests and dashing draw it in; sneaking doesn't.",
	"A Watcher's light sweeps the ground. Stay in it and it shrieks, and the Blight nearby comes running. Crouch to stay out of its reach.",
	"The Blight starts weak and grows the longer your squad is out, the deeper you go, and at night.",
]
## A line of the world's story shown under the tip (our own words; the canon is briefs/LORE_MASKS.md).
const LORE := [
	"Everyone born since the Sundering is born without a face. We call ourselves the Empty.",
	"A Mask holds the soul of a Hunter who stood against the Wyrm. Wear one and you remember what a self feels like.",
	"The Tyrant never aged, and never forgot the hoard. Under the Crown, it was always the Wyrm.",
	"The Blight is the Wyrm's blood. It sours stone, grass and sky, and it follows whoever is loudest.",
	"A thief once reached the Wyrmheart. Whatever she wished for, the whole land is still paying for it.",
	"People once dug up Masks to smash them. Now they dig for the same relics to be whole again.",
	"Skyfolk, beasts and humans all lost their faces alike. The sky doesn't ask who you were.",
	"One wish waits in the Wyrmheart: remake the world, or rule it. Every Hunter wants it. So does the Wyrm.",
	"Not every Mask has a face. Some are a compass, a jar, a pair of skates, and they remember just as much.",
	"Bring home what you carry. Out here, only what reaches the farm is truly yours.",
]
## What's being worked on, set by whoever builds the match (Main.show_screen, Match): shown by the spinner.
const STAGES := {"map": "Building the map", "spawn": "Spawning", "graphics": "Preparing graphics", "ready": "Ready"}

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
var islands: Array = []  # [x (0..1), y (0..1), size, depth, seed]
var stars: Array = []
var sky_tex: GradientTexture2D
var shade_tex: GradientTexture2D
var puff: GradientTexture2D
var _glass_at := {}      # fade step -> the tip card's glass box
var stage_label := "Building the map"
var spin_draws := 0      # frames the spinner has drawn (--load-check: one per frame means it never stalled)

func _grad(cols: Array, offs: Array, radial := false) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols); g.offsets = PackedFloat32Array(offs)
	var gt := GradientTexture2D.new()
	gt.gradient = g; gt.width = 128; gt.height = 128
	if radial:
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	else:
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
	var tips: Array = TIPS if opts.get("blight", true) else Array(TIPS).filter(func(x): return not String(x).contains("Blight"))
	tip = tips[randi() % tips.size()]
	lore = LORE[randi() % LORE.size()]
	var r := RandomNumberGenerator.new(); r.seed = hash(title) + tier
	for i in 9:
		islands.append([float(i) / 9.0 + r.randf_range(-0.04, 0.04), r.randf_range(0.14, 0.62), r.randf_range(0.7, 1.3), r.randf_range(0.2, 1.0), r.randi()])
	islands.sort_custom(func(a, b): return a[3] < b[3])
	for i in 90:
		stars.append(Vector3(r.randf(), r.randf() * 0.7, r.randf()))
	var sky: Color = T["sky"]
	var cl: Array = T["clouds"]
	sky_tex = _grad([sky.darkened(0.3), sky.lerp(cl[1], 0.35), (cl[1] as Color).lerp(sky, 0.1)], [0.0, 0.6, 1.0])
	shade_tex = _grad([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.8)], [0.0, 0.55, 1.0])
	puff = _grad([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)], [0.0, 0.45, 1.0], true)
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.draw.connect(_draw)
	add_child(c)

func _process(delta: float) -> void:
	t += delta
	if leaving:
		fade = maxf(0.0, fade - delta * 2.2)
		if fade <= 0.0:
			queue_free()
	else:
		var was := fade
		fade = minf(1.0, fade + delta * 3.5)
		if was < 1.0 and fade >= 1.0:
			shown.emit()
	prog = move_toward(prog, want, delta * maxf(0.9, (want - prog) * 6.0))
	c.queue_redraw()

## Move the bar to a stage (0..1) and wait until it gets there.
func step(frac: float) -> void:
	want = maxf(want, frac)
	while prog < want - 0.01 and is_inside_tree():
		await get_tree().process_frame

func finish() -> void:
	await step(1.0)
	var hold := 0.35
	while hold > 0.0 and is_inside_tree():
		hold -= get_process_delta_time()
		await get_tree().process_frame
	# gone before the map shows: fading this out over the planning map blended the two for half a
	# second, so the screen's ink sweeps over first, this goes, and the ink sweeps off the map
	var sf: ScreenFade = Game.main.get("fade") if Game.main else null
	if sf and is_inside_tree() and not sf.covered:
		await sf.cover(0.22)
		queue_free()
		sf.reveal(0.4)
		return
	leaving = true

## Names the stage under the spinner (a key of STAGES).
func set_stage(key: String) -> void:
	stage_label = String(STAGES.get(key, key))

func _draw() -> void:
	var sz := c.size
	var a := fade
	var sky: Color = T["sky"]
	var cl: Array = T["clouds"]
	var biome: Dictionary = T["biome"]
	# sky: dark at the top, the tier's cloud colour near the horizon
	c.draw_texture_rect(sky_tex, Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, a))
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * 1.7 + s.z * 30.0)
		c.draw_circle(Vector2(s.x * sz.x, s.y * sz.y), 1.0 + s.z, Color(1, 1, 1, a * (0.15 + 0.35 * tw) * (1.0 - s.y)))
	# far cloud bank
	for i in 16:
		var x := fposmod(i * 130.0 - t * 8.0, sz.x + 400.0) - 200.0
		var r := 150.0 + (i % 3) * 40.0
		c.draw_texture_rect(puff, Rect2(Vector2(x, sz.y * 0.8 + sin(i * 1.3) * 30.0) - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), false, Color((cl[1] as Color).lightened(0.12), a * 0.6))
	# islands drifting past, nearer ones bigger and faster
	for isl in islands:
		var d: float = isl[3]
		var x := fposmod(float(isl[0]) * (sz.x + 400.0) - t * 22.0 * d, sz.x + 400.0) - 200.0
		var y: float = float(isl[1]) * sz.y + sin(t * 0.8 + float(isl[4] % 100)) * 6.0
		_island(Vector2(x, y), float(isl[2]) * (70.0 + 170.0 * d), d, biome, a, int(isl[4]))
	# the skyship sailing across
	var sx := fposmod(t * 70.0 + sz.x * 0.35, sz.x + 500.0) - 250.0
	_ship(Vector2(sx, sz.y * 0.2 + sin(t * 1.3) * 5.0), a)
	# near cloud wisps over the bottom
	for i in 12:
		var x := fposmod(i * 170.0 - t * 30.0, sz.x + 500.0) - 250.0
		c.draw_texture_rect(puff, Rect2(Vector2(x - 200, sz.y - 90.0 + sin(i * 2.1) * 25.0), Vector2(400, 220)), false, Color((cl[1] as Color).lightened(0.25), a * 0.5))
	# a soft shade behind the text
	c.draw_texture_rect(shade_tex, Rect2(0, sz.y * 0.42, sz.x, sz.y * 0.58), false, Color(1, 1, 1, a))
	# text
	var cx := sz.x * 0.5
	var base := sz.y * 0.47
	var kick := "GETTING READY"
	if mode_line != "":
		kick = "EXPEDITION  ·  " + map_name.to_upper() if map_name != "" else "EXPEDITION"
	_text(Vector2(cx, base), kick, UI.caps, 15, Color(UI.GOLD, a), 3)
	_text(Vector2(cx, base + 62), title, UI.big, 58, Color(UI.INK, a))
	_wrap(Vector2(cx, base + 96), sub, 17, minf(620.0, sz.x - 60.0), Color(UI.MUTED, a))
	if mode_line != "":
		_text(Vector2(cx, base + 176), mode_line, UI.semi, 15, Color(UI.TEAL, a))
	if raid != "":
		# the raid condition, shown before you drop
		var rc: Color = RaidLook.COLORS.get(raid, UI.INK)
		_text(Vector2(cx, base + 204), "CONDITIONS  ·  " + String(RaidLook.NAMES.get(raid, raid)).to_upper(), UI.caps, 13, Color(rc, a), 2)
		_wrap(Vector2(cx, base + 210), String(RaidLook.BLURBS.get(raid, "")), 14, minf(560.0, sz.x - 60.0), Color(UI.MUTED, a * 0.9))
	# progress
	var tw_ := minf(660.0, sz.x - 60.0)
	var lines := UI.body.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_CENTER, tw_ - 40.0, 15, 3).y
	var lore_h := UI.body.get_multiline_string_size(lore, HORIZONTAL_ALIGNMENT_CENTER, tw_ - 40.0, 14, 3).y + 12.0
	var card := Rect2(cx - tw_ * 0.5, sz.y - 24.0 - (40.0 + lines + lore_h), tw_, 40.0 + lines + lore_h)
	var bw := minf(480.0, sz.x - 80.0)
	var br := Rect2(cx - bw * 0.5, card.position.y - 30.0, bw, 6)
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
		var g := UI.frame(Color(0.05, 0.045, 0.07, alpha * 0.72), 14, Color(1, 1, 1, alpha * 0.07), 1, 0.0, 0.0, alpha * 0.04)
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

func _island(p: Vector2, w: float, d: float, biome: Dictionary, a: float, sd: int) -> void:
	var r := RandomNumberGenerator.new(); r.seed = sd
	var shade := lerpf(0.45, 0.0, d)   # far islands fade into the sky
	var topc: Color = (biome["top"] as Color).darkened(shade)
	var sidec: Color = (biome["side"] as Color).darkened(shade)
	var deepc: Color = (biome["deep"] as Color).darkened(shade)
	var h := w * 0.28
	# the rocky underside, a jagged point
	var under := PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(w * 0.5, 0)])
	var n := 6
	for i in n + 1:
		var f := 1.0 - float(i) / n
		var depth := h * (1.0 + 1.6 * sin(PI * f)) * r.randf_range(0.75, 1.1)
		under.append(p + Vector2(-w * 0.5 + w * f, depth))
	c.draw_colored_polygon(under, Color(deepc, a))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(w * 0.5, 0), p + Vector2(w * 0.46, h * 0.7), p + Vector2(-w * 0.46, h * 0.7)]), Color(sidec, a))
	# grass top as a flat ellipse
	var top := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		top.append(p + Vector2(cos(ang) * w * 0.5, sin(ang) * h * 0.45))
	c.draw_colored_polygon(top, Color(topc, a))
	# a couple of trees
	for i in r.randi_range(1, 3):
		var tp := p + Vector2(r.randf_range(-w * 0.3, w * 0.3), r.randf_range(-h * 0.2, h * 0.05))
		var ts := w * r.randf_range(0.06, 0.1)
		c.draw_rect(Rect2(tp + Vector2(-ts * 0.12, -ts * 0.6), Vector2(ts * 0.24, ts * 0.6)), Color(sidec.darkened(0.2), a))
		c.draw_circle(tp + Vector2(0, -ts * 0.9), ts * 0.55, Color((biome["leaf"] as Color).darkened(shade), a))

func _ship(p: Vector2, a: float) -> void:
	var bal := PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		bal.append(p + Vector2(cos(ang) * 58.0, sin(ang) * 26.0))
	c.draw_colored_polygon(bal, Color(Color("f2e6cf"), a))
	for k in [-24.0, 0.0, 24.0]:
		var hh := 26.0 * sqrt(maxf(0.0, 1.0 - pow(k / 58.0, 2)))
		c.draw_line(p + Vector2(k, -hh), p + Vector2(k, hh), Color(Color("d9604a"), a), 5.0)
	for x in [-30.0, 30.0]:
		c.draw_line(p + Vector2(x, 20), p + Vector2(x * 0.7, 46), Color(Color("4e3424"), a), 1.5)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-36, 44), p + Vector2(36, 44), p + Vector2(28, 58), p + Vector2(-30, 58)]), Color(Color("7a5236"), a))
	var spin := t * 18.0
	c.draw_line(p + Vector2(-40, 50) + Vector2(0, cos(spin) * 9), p + Vector2(-40, 50) - Vector2(0, cos(spin) * 9), Color(Color("e0b84a"), a), 3.0)

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
