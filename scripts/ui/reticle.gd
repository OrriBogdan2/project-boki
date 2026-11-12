class_name Reticle
extends RefCounted
## The aiming reticle at the cursor, in the player's own style (Settings > Gameplay > Reticle): shape,
## size, colour, opacity and a dark outline. The default is a small thin ring broken into four arcs,
## with a centre dot. The HUD draws it first; the aim states (ammo ring, charge arcs, the hit tick and the
## AimKit cursor states on their own layer) always draw on top of it.
## One instance per HUD also owns the hit tick (`new(match)`, `tick`, `draw_tick`): see below.

## Shape id -> its name in Settings.
const SHAPES := [
	["default", "Default"], ["dot", "Dot"], ["circle", "Small circle"], ["cross", "Cross"],
	["circle_dot", "Circle and dot"],
]
## Colour id -> [its name in Settings, the colour]. "yellow" is the high-visibility one.
const COLORS := {
	"white": ["White", Color("f4f1e6")],
	"yellow": ["High-vis yellow", Color("e4ff1f")],
	"cyan": ["Cyan", Color("4fe3ff")],
	"pink": ["Pink", Color("ff5cd1")],
	"green": ["Green", Color("63ff7f")],
	"red": ["Red", Color("ff4a3d")],
}
const RING_R := 6.0        # px at size 1: the ring's radius (the old cross reached 13 px out)
const DOT_R := 1.4         # px at size 1: the centre dot
const LINE_W := 1.4        # px at size 1: ring and cross stroke
const CROSS_LEN := 5.0     # px at size 1: each arm of the cross
const CROSS_GAP := 3.0     # px at size 1: the cross's open centre
const EDGE_W := 1.2        # px: the outline's width on each side of a stroke
const EDGE_A := 0.6        # the outline's opacity (times the reticle's own)
const ARC_GAP := 0.32      # rad: each of the default ring's four breaks
## The HUD's aim states round the reticle (px from the cursor), kept tight so the whole reads small:
const CHARGE_R := 13.0     # a charge, warm-up, spin-up or reload arc
const AMMO_R := 16.0       # the ammo left, a thin arc below
const RES_R := 22.0        # the archetype resource, an arc above
## The hit tick: your own landed hit snaps four short strokes out of the reticle in your Hunter's colour
## (AimKit.hero_col, the colour of its ability aim); a hit that knocks a Hunter down draws them longer
## and heavier with a ring. The hero-ref footage shows no reticle confirm, so the look is ours.
const TICK_S := 0.09       # s a normal tick shows
const KNOCK_S := 0.12      # s the knock tick shows (the cap for any tick)
const TICK_IN := 7.0       # px from the cursor where each stroke starts
const TICK_LEN := 6.0      # px a normal stroke reaches past TICK_IN at its start, half that as it ends
const KNOCK_LEN := 10.0    # px the same for a knock
const DIAG := [Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]

var m: Match
var tick_t := 0.0          # s left on the tick showing
var tick_knock := false
var ticks := 0             # ticks raised (read by --hit-marker-check)

## Listens on the shared damage path (CombatBus.hit_landed), so every weapon and ability raises it.
func _init(match_node: Match = null) -> void:
	m = match_node
	if m:
		CombatBus.hit_landed.connect(_on_hit)

## Only hits you land yourself on a foe's Hunter, Boki or a monster. Misses never reach here; zone
## (damage-over-time) ticks, your Boki's and teammates' hits and anything else raise nothing.
func _on_hit(by: Node, target: Node, amount: float, tags: Array) -> void:
	if by == null or by != m.player or tags.has("zone"):
		return
	if not (target is Hunter or target is Kin or target is Mob) or (target as Ent).team == m.player.team:
		return
	var e := target as Ent
	# (a remote body's hp drops on its owner's game: this hit knocks it if it covers what's left)
	tick_knock = target is Hunter and not (target as Hunter).downed and e.hp <= (amount if e.remote else 0.0)
	tick_t = KNOCK_S if tick_knock else TICK_S
	ticks += 1

func tick(delta: float) -> void:
	tick_t = maxf(0.0, tick_t - delta)

## The tick round the reticle at `at`, dark-edged so it reads over bright effects.
func draw_tick(c: CanvasItem, at: Vector2) -> void:
	if tick_t <= 0.0:
		return
	var k := tick_t / (KNOCK_S if tick_knock else TICK_S)
	var col := AimKit.hero_col(m.player)
	var reach := TICK_IN + (KNOCK_LEN if tick_knock else TICK_LEN) * (0.5 + 0.5 * k)
	var w := 3.0 if tick_knock else 2.0
	var a := minf(1.0, k * 2.5)
	for d in DIAG:
		c.draw_line(at + d * TICK_IN, at + d * reach, Color(0.05, 0.03, 0.08, 0.6 * a), w + 2.0)
		c.draw_line(at + d * TICK_IN, at + d * reach, Color(col, a), w)
	if tick_knock:
		c.draw_arc(at, reach + 3.0, 0.0, TAU, 28, Color(col.lerp(Color.WHITE, 0.5), a), 2.0, true)

## The style in effect: {shape, k (size factor), col (with the opacity), outline}.
static func style() -> Dictionary:
	var col_id := String(Settings.get_v("reticle_col"))
	var col: Color = (COLORS.get(col_id, COLORS["white"]) as Array)[1]
	col.a = clampf(float(Settings.get_v("reticle_alpha")), 0.1, 1.0)
	return {
		"shape": String(Settings.get_v("reticle_shape")),
		"k": clampf(float(Settings.get_v("reticle_size")), 0.5, 2.0),
		"col": col,
		"outline": bool(Settings.get_v("reticle_outline")),
	}

## Draws the reticle at `at` on `c`. `spread` (px) opens the ring or cross with weapon bloom.
static func draw(c: CanvasItem, at: Vector2, spread := 0.0) -> void:
	var st := style()
	var k := float(st["k"])
	var col: Color = st["col"]
	var shape := String(st["shape"])
	var ring := RING_R * k + spread
	var has_dot := shape in ["default", "dot", "circle_dot"]
	var dot := DOT_R * k * (1.6 if shape == "dot" else 1.0)
	if bool(st["outline"]):
		var edge := Color(0, 0, 0, EDGE_A * col.a)
		_shape(c, at, shape, ring, k, edge, LINE_W * k + EDGE_W * 2.0)
		if has_dot:
			c.draw_circle(at, dot + EDGE_W, edge)
	_shape(c, at, shape, ring, k, col, LINE_W * k)
	if has_dot:
		c.draw_circle(at, dot, col)

## The strokes of a shape (no dot): a broken ring, a full ring or a cross.
static func _shape(c: CanvasItem, at: Vector2, shape: String, ring: float, k: float, col: Color, width: float) -> void:
	match shape:
		"default":
			for i in 4:
				var a0 := PI * 0.5 * i + ARC_GAP * 0.5
				c.draw_arc(at, ring, a0, a0 + PI * 0.5 - ARC_GAP, 8, col, width, true)
		"circle", "circle_dot":
			c.draw_arc(at, ring, 0.0, TAU, 28, col, width, true)
		"cross":
			var gap := CROSS_GAP * k + (ring - RING_R * k)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				c.draw_line(at + d * gap, at + d * (gap + CROSS_LEN * k), col, width, true)
