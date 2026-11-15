class_name MoveDrills
extends Node
## The Training Area's movement drills (the Drills button on Practice's bar): five short runs, one banner
## line each, pass or fail, and the best pass time saved per drill in Save.d["drills"]. The match tutorial
## no longer teaches movement (DECISIONS 2026-11-08), so this is where it gets practised.
##   gates:  dash through three hoops
##   glide:  tap jump, let go, press jump again and hold it (never held from the take-off) to glide
##   dive:   glide down onto the target mat and dive (crouch) onto it
##   wall:   kick up a four-terrace wall (a plain jump and mantle only reach three)
##   mantle: jump at a two-terrace ledge and climb it
## Each drill builds its props on the island's flat ground (hoops and mat as in the farm's training yard,
## terraces as raised tiles plus a block to see them), moves you to its start and puts it all back after.
## The button starts the run; pressed again during it, it skips to the next drill.

const NAME := "MoveDrills"
enum State { OFF, RUN, RESULT }
const IDS := ["gates", "glide", "dive", "wall", "mantle"]
const LIMIT_S := 14.0  # s a drill lasts before it fails
const RESULT_S := 2.2  # s the pass or fail line stays up
const TILE := 1.0  # m
const GATE_SPACING := 3.2  # m between hoops (one dash is 3.6 m)
const GATE_FIRST := 2.5  # m from the start to the first hoop
const GATE_R := 0.95  # m: a dash this close to a hoop's centre goes through it
const GATE_RING_R := 0.9  # m: the hoop's drawn size
const GLIDE_GOAL := 4.0  # m flown with the glider open
const DIVE_HEIGHT := 12.0  # m above the ground the dive drill starts
const DIVE_DISTANCE := 8.0  # m to the mat
const DIVE_R := 1.6  # m: a landing this close to the mat's centre counts
const WALL_TERRACES := 4  # a plain jump and mantle reach three (docs/decisions/0007)
const MANTLE_TERRACES := 2
const RUN_UP := 5  # tiles of flat ground before a wall
## Tiles of flat ground a drill's row needs.
const TILES := {"gates": 10, "glide": 10, "dive": 10, "wall": 8, "mantle": 8}
const COURSE_W := 3  # tiles wide
const GOLD := Color("f2c84a")
const MINT := Color("8fe3c8")
const RED := Color("ff9a8a")

var m: Match
var state := State.OFF
var step := -1  # index into IDS
var t := 0.0  # s into the current drill
var result_t := 0.0
var passed := {}  # id -> true, this run
var origin := Vector3.INF  # where you stood when the run began
var start := Vector3.ZERO  # the drill's start spot
var target := Vector3.ZERO  # the mat (dive) or the wall face's foot (wall, mantle)
var gates: Array = []  # hoop centres still to go through, in order
var _raised := {}  # tile index -> its old level
var _props: Node3D = null
var _flags := {}  # what the current drill has seen you do
var _glide_from := Vector3.ZERO
var _jump_let_go := false
var _was_air := false
var _label: Label = null


## Adds the drills to the Training Area (Practice.attach calls this); other practice areas get none.
static func attach(p: Practice) -> MoveDrills:
	if not p.m.opts.get("practice", false) or p.m.arena == null or p.m.duel != null:
		return null
	var d := MoveDrills.new()
	d.name = NAME
	d.m = p.m
	p.add_child(d)
	d._build_banner()
	return d


func _build_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_label = UI.label("", 20, UI.INK, UI.semi)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_label.offset_top = 60.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)


## The bar's Drills button: starts the run, or skips to the next drill during one.
func press() -> void:
	if state == State.OFF:
		passed.clear()
		origin = m.player.pos
		_begin(0)
	else:
		_finish_drill(false, "Skipped")


func _process(dt: float) -> void:
	if m.paused or m.over:
		return
	tick(dt)


## One simulation step of the run (the match's player has just moved).
func tick(dt: float) -> void:
	if state == State.OFF:
		return
	if state == State.RESULT:
		result_t -= dt
		if result_t <= 0.0:
			_begin(step + 1)
		return
	t += dt
	var P := m.player
	match IDS[step]:
		"gates":
			_tick_gates(P)
		"glide":
			_tick_glide(P)
		"dive":
			_tick_dive(P)
		"wall":
			_tick_climb(P, true)
		"mantle":
			_tick_climb(P, false)
	if state == State.RUN and t >= LIMIT_S:
		_finish_drill(false, "Out of time")


# ------------------------------------------------------------------ the run
func _begin(i: int) -> void:
	_clear_props()
	if i >= IDS.size():
		_end()
		return
	step = i
	t = 0.0
	_flags.clear()
	_jump_let_go = false
	_was_air = false
	if not _build(String(IDS[i])):
		state = State.RESULT
		result_t = RESULT_S
		_say("No room for this drill here", RED)
		return
	state = State.RUN
	_say(_line(String(IDS[i])), GOLD)


func _end() -> void:
	state = State.OFF
	step = -1
	m.player.teleport(origin)
	m.player.vel = Vector3.ZERO
	_say("Drills: %d of %d passed" % [passed.size(), IDS.size()], MINT)
	m.player.inp["move"] = Vector2.ZERO


func _finish_drill(ok: bool, why: String) -> void:
	var id := String(IDS[step])
	if state == State.RESULT:
		return
	state = State.RESULT
	result_t = RESULT_S
	if ok:
		passed[id] = true
		var best := record(Save.d, id, t)
		var tail := "  new best" if best else "  (best %.1f s)" % float(Save.d["drills"][id])
		_say("%s: %.1f s%s" % [id.capitalize(), t, tail], MINT)
		Sfx.play("unlock", null, -8.0)
	else:
		_say("%s: %s" % [id.capitalize(), why], RED)


## Keeps the best (lowest) pass time for a drill. True when this one is the new best.
static func record(data: Dictionary, id: String, secs: float) -> bool:
	if typeof(data.get("drills", null)) != TYPE_DICTIONARY:
		data["drills"] = {}
	var old := float(data["drills"].get(id, INF))
	if secs >= old:
		return false
	data["drills"][id] = snappedf(secs, 0.01)
	return true


func _say(text: String, col: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", col)
	_label.visible = text != ""


func _line(id: String) -> String:
	var jump := Settings.key_cap("jump")
	var best := float(Save.d.get("drills", {}).get(id, 0.0))
	var tail := "   (best %.1f s)" % best if best > 0.0 else ""
	match id:
		"gates":
			return "Dash (%s) through the three hoops%s" % [Settings.key_cap("dash"), tail]
		"glide":
			return "Tap %s, let go, then press %s again and hold it: glide %d m%s" % [jump, jump, int(GLIDE_GOAL), tail]
		"dive":
			return "Hold %s to glide, then hold %s to dive onto the mat%s" % [jump, Settings.key_cap("crouch"), tail]
		"wall":
			return "Wall kick: jump at the wall, press %s on it again and again, up to the top%s" % [jump, tail]
	return "Mantle: jump at the ledge and keep pushing in to climb onto it%s" % tail


# ------------------------------------------------------------------ the drills
func _tick_gates(P: Hunter) -> void:
	if P.roll_t > 0.0 and not gates.is_empty() and P.flat_dist(gates[0]) <= GATE_R:
		gates.remove_at(0)
		Sfx.play("unlock", null, -14.0)
	if gates.is_empty():
		_finish_drill(true, "")


func _tick_glide(P: Hunter) -> void:
	if not P.grounded and not P.inp["glide"]:
		_jump_let_go = true
	if P.gliding and _glide_from == Vector3.INF:
		_glide_from = P.pos
		if not (_jump_let_go or P.inp.get("glide_btn", false)):
			_finish_drill(false, "Space held from the take-off: tap it, let go, then hold")
			return
	if P.gliding and P.flat_dist(_glide_from) >= GLIDE_GOAL:
		_finish_drill(true, "")
	elif not P.gliding:
		_glide_from = Vector3.INF


func _tick_dive(P: Hunter) -> void:
	_flags["dive"] = bool(_flags.get("dive", false)) or P.glide_dive.on
	if not P.grounded:
		_was_air = true
	elif _was_air:
		var off := P.flat_dist(target)
		if off > DIVE_R:
			_finish_drill(false, "%.1f m off the mat" % off)
		elif not _flags["dive"]:
			_finish_drill(false, "Hold %s to dive" % Settings.key_cap("crouch"))
		else:
			_finish_drill(true, "")


func _tick_climb(P: Hunter, kick: bool) -> void:
	_flags["mantle"] = bool(_flags.get("mantle", false)) or P.mantle_k() > 0.0 or not P.lfloat.is_empty()
	if kick and WallMoves.scuffs > int(_flags.get("scuffs", WallMoves.scuffs)):
		_flags["kicked"] = true
	_flags["scuffs"] = WallMoves.scuffs
	var top := float(_flags["top"])
	if P.grounded and absf(P.pos.y - top) < 0.05 and P.pos.x > target.x:
		if kick and not _flags.get("kicked", false):
			_finish_drill(false, "Climbed without a kick")
		elif not kick and not _flags.get("mantle", false):
			_finish_drill(false, "Climbed without a mantle")
		else:
			_finish_drill(true, "")


# ------------------------------------------------------------------ props
## Builds the drill's course and puts you at its start. False if the island has no room for it.
func _build(id: String) -> bool:
	var row := _find_row(TILES[id])
	if row == Vector2i(-1, -1):
		return false
	var y := m.world.ground_at(row.x + 0.5, row.y + 0.5)
	var z := row.y + 0.5
	start = Vector3(row.x + 0.5, y, z)
	_props = Node3D.new()
	add_child(_props)
	_glide_from = Vector3.INF
	gates.clear()
	match id:
		"gates":
			for k in 3:
				var c := Vector3(start.x + GATE_FIRST + k * GATE_SPACING, y, z)
				gates.append(c)
				_hoop(c)
		"dive":
			target = Vector3(start.x + DIVE_DISTANCE, y, z)
			_mat(target)
			start.y = y + DIVE_HEIGHT
		"wall", "mantle":
			var n := WALL_TERRACES if id == "wall" else MANTLE_TERRACES
			_raise(row.x + RUN_UP, row.y - 1, 3, 3, n)
			target = Vector3(row.x + RUN_UP, y, z)
			_flags["top"] = y + n * World.LEVEL
	m.player.teleport(start)
	m.player.vel = Vector3.ZERO
	m.player.face = 0.0
	return true


## The tile (x, z) a row of `len` flat, free tiles starts at, COURSE_W wide, closest to you.
func _find_row(tiles: int) -> Vector2i:
	var w := m.world
	var isl := w.island_of(origin.x, origin.z)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for z in range(1, w.h - 1):
		for x in range(1, w.w - tiles):
			if _row_free(x, z, tiles, isl):
				var d := Vector2(x + tiles * 0.5, z + 0.5).distance_to(Vector2(origin.x, origin.z))
				if d < best_d:
					best_d = d
					best = Vector2i(x, z)
	return best


func _row_free(x: int, z: int, tiles: int, isl: int) -> bool:
	var w := m.world
	var lv := int(w.level[w.idx(x, z)])
	for dz in range(-1, COURSE_W - 1):
		for dx in tiles:
			var i := w.idx(x + dx, z + dz)
			var flat: bool = w.kind[i] == World.T_GROUND and int(w.level[i]) == lv and not w.stairs.has(i)
			if w.island[i] != isl or not flat or w.edge_dist(x + dx, z + dz, 2) < 1:
				return false
	return true


func _raise(x0: int, z0: int, nx: int, nz: int, n: int) -> void:
	var w := m.world
	var base := float(w.level[w.idx(x0, z0)]) * World.LEVEL
	for z in range(z0, z0 + nz):
		for x in range(x0, x0 + nx):
			var i := w.idx(x, z)
			_raised[i] = int(w.level[i])
			w.level[i] = int(w.level[i]) + n
	var box := Models.part(
		_props,
		Models.box(nx, n * World.LEVEL, nz),
		Models.toon(Color("b4a58a")),
		Vector3(x0 + nx * 0.5, base + n * World.LEVEL * 0.5, z0 + nz * 0.5)
	)
	box.name = "Terrace"


func _hoop(c: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = GATE_RING_R - 0.06
	ring.outer_radius = GATE_RING_R
	var at := c + Vector3(0, GATE_RING_R, 0)
	var hoop := Models.part(_props, ring, Models.toon(GOLD), at, Vector3.ONE, Vector3(PI / 2, 0, PI / 2))
	hoop.name = "Hoop"


func _mat(c: Vector3) -> void:
	var red := Models.toon(Color("c9604a"))
	Models.part(_props, Models.cyl(DIVE_R, DIVE_R, 0.05, 24), Models.toon(Color("e9dcc0")), c + Vector3(0, 0.025, 0))
	Models.part(_props, Models.cyl(DIVE_R * 0.7, DIVE_R * 0.7, 0.02, 24), red, c + Vector3(0, 0.06, 0))
	var bull := Models.toon(Color("e9dcc0"), false)
	Models.part(_props, Models.cyl(DIVE_R * 0.35, DIVE_R * 0.35, 0.02, 20), bull, c + Vector3(0, 0.08, 0))


func _clear_props() -> void:
	var w := m.world
	for i in _raised:
		w.level[i] = _raised[i]
	_raised.clear()
	if _props:
		_props.queue_free()
		_props = null


func _exit_tree() -> void:
	if m and m.world:
		_clear_props()
