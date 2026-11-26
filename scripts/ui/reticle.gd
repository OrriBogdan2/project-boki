class_name Reticle
extends RefCounted
## The aiming reticle at the cursor, in the player's own style (Settings > Gameplay > Reticle): shape,
## size, colour, opacity and a dark outline. The default is each Hunter's own small look (ReticleLooks, else a
## thin ring broken into four arcs) with a centre dot; it opens with weapon bloom, and on a hit it flashes. With
## the "hunter" colour (the default) the look, the dot and the aim arcs take the Hunter's own accent (Arch.color).
## ReticleHud draws it first each frame; the aim states (ammo ring, charge arcs, hit tick and the AimKit
## cursor states on their own layer) draw on top of it. Every number is in content/rules/tuning.json "reticle".
## One instance per HUD also owns the hit tick's state (`new(match)`, `tick`): see below.

## Shape id -> its name in Settings.
const SHAPES := [
	["default", "Hunter's own"],
	["dot", "Dot"],
	["circle", "Small circle"],
	["cross", "Cross"],
	["circle_dot", "Circle and dot"],
]
## Colour id -> [its name in Settings, the colour]. "hunter" is the Hunter's accent on the look, dot and arcs
## (draw's `accent`; the pale colour here is for a plain ring); "yellow" is the high-visibility one.
const COLORS := {
	"hunter": ["Hunter colour", Color("f4f1e6")],
	"white": ["White", Color("f4f1e6")],
	"yellow": ["High-vis yellow", Color("e4ff1f")],
	"cyan": ["Cyan", Color("4fe3ff")],
	"pink": ["Pink", Color("ff5cd1")],
	"green": ["Green", Color("63ff7f")],
	"red": ["Red", Color("ff4a3d")],
}
const TUNING_PATH := "res://content/rules/tuning.json"
static var _tune: Dictionary = {}

var m: Match
var tick_t := 0.0  # s left on the hit tick showing (ReticleHud draws it)
var tick_knock := false  # the hit knocked a Hunter down: the strong tick
var tick_crit := false  # it was a crit (gold)
var tick_armor := false  # it landed on armour (pale)
var ticks := 0  # ticks raised (read by --hit-marker-check)
var dealt_at := -9.0  # match time your last hit (or your Boki's) landed


## Listens on the shared damage path (CombatBus.hit_landed), so every weapon and ability raises it.
func _init(match_node: Match = null) -> void:
	m = match_node
	if m:
		CombatBus.hit_landed.connect(_on_hit)


## `dealt_at` notes any hit you or your Boki land on a foe (the message lane's fight budget); the tick
## itself shows only for hits you land yourself. Misses never reach here; zone (damage-over-time) ticks,
## teammates' hits and anything else raise nothing.
func _on_hit(by: Node, target: Node, amount: float, tags: Array) -> void:
	var credit: Node = (by as Kin).owner_h if by is Kin else by
	if credit == null or credit != m.player or tags.has("zone"):
		return
	if not (target is Hunter or target is Kin or target is Mob) or (target as Ent).team == m.player.team:
		return
	dealt_at = m.time
	if by != m.player:
		return
	var e := target as Ent
	# (a remote body's hp drops on its owner's game: this hit knocks it if it covers what's left)
	raise(target is Hunter and not (target as Hunter).downed and e.hp <= (amount if e.remote else 0.0))


## Starts one tick (`knock`: the strong one). The match then says what kind of hit it was (`flavour`).
func raise(knock: bool) -> void:
	tick_knock = knock
	tick_crit = false
	tick_armor = false
	tick_t = t("hit_knock_s") if knock else t("hit_s")
	ticks += 1


## The hit that raised the tick was a crit and/or on armour (Match.on_damage, on_armor_break). Never starts a tick.
func flavour(crit: bool, armor: bool) -> void:
	tick_crit = tick_crit or crit
	tick_armor = tick_armor or armor


func tick(delta: float) -> void:
	tick_t = maxf(0.0, tick_t - delta)


## 1 -> 0 over the tick showing (0 when none).
func tick_k() -> float:
	return clampf(tick_t / t("hit_knock_s" if tick_knock else "hit_s"), 0.0, 1.0)


## The reticle's numbers (tuning.json "reticle"), read once.
static func tune() -> Dictionary:
	if _tune.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
		_tune = (parsed as Dictionary).get("reticle", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	return _tune


## One tuning number.
static func t(key: String) -> float:
	return float(tune()[key])


## One tuning colour (a hex string).
static func tc(key: String) -> Color:
	return Color(String(tune()[key]))


## The accent for the dot and the aim arcs of a Hunter: its own colour for the "hunter" setting, else the chosen colour.
static func accent(arch_id: String) -> Color:
	if Settings.get_v("reticle_col") == "hunter":
		return Arch.color(arch_id)
	return style()["col"] as Color


## The swatch colour of a colour id in Settings; "hunter" shows the colour of the Hunter you play.
static func swatch(id: String) -> Color:
	return Arch.color(String(Save.d.get("arch", ""))) if id == "hunter" else COLORS[id][1]


## A Hunter's own look id (content/archetypes/<id>.json "reticle"), or "" for the plain broken ring.
static func look_of(arch_id: String) -> String:
	return String(Arch.def(arch_id).get("reticle", ""))


## The style in effect: {shape, k (size factor), col (with the opacity), outline, hunter (the accent colour mode)}.
static func style() -> Dictionary:
	var col_id := String(Settings.get_v("reticle_col"))
	var col: Color = (COLORS.get(col_id, COLORS["white"]) as Array)[1]
	col.a = clampf(float(Settings.get_v("reticle_alpha")), 0.1, 1.0)
	return {
		"shape": String(Settings.get_v("reticle_shape")),
		"k": clampf(float(Settings.get_v("reticle_size")), 0.5, 2.0),
		"col": col,
		"outline": bool(Settings.get_v("reticle_outline")),
		"hunter": col_id == "hunter",
	}


## Draws the reticle at `at` on `c`. `spread` (px) opens the ring or cross with weapon bloom; `accent` is the
## Hunter's colour (used when the colour setting is "hunter"); `flash` (alpha = strength) tints the ring on a hit;
## `look` is the Hunter's own look (ReticleLooks), drawn for the "default" shape. With the "hunter" colour the
## strokes take the accent too, lifted so a dark colour still reads on dark ground.
static func draw(
	c: CanvasItem, at: Vector2, spread := 0.0, accent := Color.WHITE, flash := Color(0, 0, 0, 0), look := ""
) -> void:
	var st := style()
	var k := float(st["k"])
	var col: Color = st["col"]
	var dot_col := Color(accent, col.a) if st["hunter"] else col
	var shape := String(st["shape"])
	if shape == "default" and ReticleLooks.has(look):
		shape = look
		if st["hunter"]:
			col = Color(accent.lightened(t("look_lift")), col.a)
	var ring := t("ring_r") * k + minf(spread, t("spread_max"))
	var has_dot := shape not in ["circle", "cross"]
	var dot := t("dot_r") * k * (1.6 if shape == "dot" else 1.0)
	var line_w := t("line_w") * k
	if bool(st["outline"]):
		var edge := Color(0, 0, 0, t("edge_a") * col.a)
		_shape(c, at, shape, ring, k, edge, line_w + t("edge_w") * 2.0)
		if has_dot:
			c.draw_circle(at, dot + t("edge_w"), edge)
	_shape(c, at, shape, ring, k, col.lerp(Color(flash, col.a), flash.a), line_w)
	if has_dot:
		c.draw_circle(at, dot * (1.0 + flash.a * 0.6), dot_col)


## An arc of the reticle's aim states (ammo, resource, charge) from angle `from` to `to`: only the part drawn,
## over a thin dark edge when the outline is on. No dark track runs on past it, so an empty gauge draws nothing
## (a full-length track read as a second, shadow ring round the reticle).
static func arc(c: CanvasItem, at: Vector2, r: float, from: float, to: float, col: Color, width: float) -> void:
	if bool(style()["outline"]):
		c.draw_arc(at, r, from, to, 32, Color(0, 0, 0, t("edge_a") * col.a), width + t("edge_w") * 2.0, true)
	c.draw_arc(at, r, from, to, 32, col, width, true)


## The strokes of a shape (no dot): a broken ring, a full ring, a cross or a Hunter's look.
static func _shape(c: CanvasItem, at: Vector2, shape: String, ring: float, k: float, col: Color, width: float) -> void:
	if ReticleLooks.has(shape):
		ReticleLooks.strokes(c, at, shape, ring, k, col, width)
		return
	match shape:
		"default":
			var gap := t("arc_gap_rad")
			for i in 4:
				var a0 := PI * 0.5 * i + gap * 0.5
				c.draw_arc(at, ring, a0, a0 + PI * 0.5 - gap, 8, col, width, true)
		"circle", "circle_dot":
			c.draw_arc(at, ring, 0.0, TAU, 28, col, width, true)
		"cross":
			var open := t("cross_gap") * k + (ring - t("ring_r") * k)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				c.draw_line(at + d * open, at + d * (open + t("cross_len") * k), col, width, true)
