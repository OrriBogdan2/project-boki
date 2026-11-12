class_name GardenCues
extends RefCounted
## The garden minigames' world cues, in the Void & Masks palette (briefs/UI_STYLE.md): one cheap glowing mesh
## set per game, made when the game starts and freed when it ends (no particles, no textures).
##   DashCue    three cheer marks that light as your Boki reaches them, and the finish line
##   ShoveCue   a push meter over the stump, filling toward the stronger Boki
##   SeekCue    a faint scent trail from the hidden scent toward each hunter
##   VolleyCue  a ring where the seed lands, and a flash when your spike is called
##   EchoCue    Echo Steps: a stone lights on its beat, a ring keeps the beat you answer, a hit or miss flashes
##   TellCue    Tumble: the rival's tell as an icon over its head, as sure as the tell is likely to be true
##   BatonCue   Relay Cup: a glowing baton over each team's runner that bursts at every hand-off
##   PopCue     Show Ring: each round's score pops over the Boki as the judges give it
## Each cue is fed the live game state by its game's tick and has a `clear()`. The last four share the small
## pools below and take the Boki's type colour. --garden-cue-shots takes the pictures, --garden-games-clip the
## clips, --garden-games-vfx-check times them.

const TEAL := Color("3fe0d0")        # neon edge, first side
const MAGENTA := Color("ff3fd0")     # neon edge, second side and the spike
const VOID := Color("2a1c40")        # an unlit cue
const BRIGHT := 0.9                  # alpha of a lit cue
const DIM := 0.55                    # alpha of an unlit cue
const MISS := Color("6a6478")        # a missed beat or a fumbled pass: dull, so a hit stands out
const LIFT := 1.7                    # m over a Boki's feet a cue floats: above its emote (1.25 m)

## The Boki's type colour (the Field Book's), for the cues that belong to one Boki.
static func type_colour(rec: Dictionary) -> Color:
	return DexView.type_col(DexView.type_of(String(rec.get("species", ""))))

## An unlit, see-through material: plain alpha, so the violet and teal read on bright day ground too.
## `on_top` draws it over everything, for the cues that float among the Boki.
static func glow(c: Color, alpha: float, on_top := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.no_depth_test = on_top
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	return m

static func tint(m: StandardMaterial3D, c: Color, alpha: float) -> void:
	m.albedo_color = Color(c.r, c.g, c.b, alpha)

static func piece(parent: Node3D, mesh: Mesh, m: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = at
	parent.add_child(n)
	return n

static func ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 4
	return t

static func box(dims: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = dims
	return b

## The cue's own root under the home, so clear() frees all of it at once.
static func root_in(parent: Node3D, label: String) -> Node3D:
	var r := Node3D.new()
	r.name = label
	parent.add_child(r)
	return r

## The Dash: marks at the stretch boundaries (where you cheer) and the finish line at the start.
class DashCue:
	extends RefCounted
	const POST_H := 1.1                 # m, a mark's beam
	const RING_IN := 0.38               # m, a mark's ring
	const RING_OUT := 0.5
	const LINE_DEPTH := 0.16            # m, the finish line along the track
	const PULSE := 6.0                  # rad/s the next mark breathes at

	var root: Node3D
	var mats: Array = []                # per mark: the glow material
	var lit := 0                        # marks your Boki has reached
	var t := 0.0

	func _init(parent: Node3D, marks: Array, finish: Vector3, track_w: float) -> void:
		root = GardenCues.root_in(parent, "DashCue")
		for at in marks:
			var m := GardenCues.glow(GardenCues.VOID, GardenCues.DIM)
			mats.append(m)
			GardenCues.piece(root, GardenCues.ring(RING_IN, RING_OUT), m, at + Vector3(0, 0.06, 0))
			var beam := CylinderMesh.new()
			beam.top_radius = 0.03
			beam.bottom_radius = 0.05
			beam.height = POST_H
			GardenCues.piece(root, beam, m, at + Vector3(0, POST_H * 0.5, 0))
		var line := finish + Vector3(0, 0.07, 0)
		var base := GardenCues.box(Vector3(track_w, 0.03, LINE_DEPTH))
		GardenCues.piece(root, base, GardenCues.glow(GardenCues.VOID, GardenCues.BRIGHT), line)
		var stripe := GardenCues.box(Vector3(track_w, 0.03, LINE_DEPTH * 0.4))
		GardenCues.piece(root, stripe, GardenCues.glow(Color.WHITE, GardenCues.BRIGHT), line + Vector3(0, 0.01, 0))

	## `reached`: how many marks your Boki has passed; `next_open`: you can cheer at the next one now.
	func update(reached: int, next_open: bool, d: float) -> void:
		t += d
		lit = reached
		for i in mats.size():
			if i < lit:
				GardenCues.tint(mats[i], GardenCues.TEAL, GardenCues.BRIGHT)
			else:
				var up := 0.5 + 0.5 * sin(t * PULSE) if i == lit and next_open else 0.0
				GardenCues.tint(mats[i], GardenCues.VOID.lerp(GardenCues.TEAL, 0.6 * up), GardenCues.DIM + 0.3 * up)

	func clear() -> void:
		root.queue_free()

## The Stump Shove: a bar over the stump; the fill runs from the middle toward whoever is stronger.
class ShoveCue:
	extends RefCounted
	const HALF := 0.6                   # m, half the bar
	const HEIGHT := 1.25                # m over the stump's foot
	const THICK := 0.09                 # m
	const TILT := 0.3                   # rad the bar dips at full balance

	var root: Node3D
	var fill: MeshInstance3D
	var fill_mat: StandardMaterial3D
	var side := 0                       # the side the fill runs toward (0 on a level bar)
	var power := 0.0                    # 0..1: how far the fill runs

	func _init(parent: Node3D, stump_at: Vector3) -> void:
		root = GardenCues.root_in(parent, "ShoveCue")
		root.position = stump_at + Vector3(0, HEIGHT, 0)
		var track := GardenCues.box(Vector3(HALF * 2.0, THICK, THICK))
		GardenCues.piece(root, track, GardenCues.glow(GardenCues.VOID, 0.8), Vector3.ZERO)
		var middle := GardenCues.box(Vector3(0.04, THICK * 2.5, THICK * 1.4))
		GardenCues.piece(root, middle, GardenCues.glow(Color.WHITE, 0.8), Vector3.ZERO)
		fill_mat = GardenCues.glow(GardenCues.TEAL, BRIGHT)
		fill = GardenCues.piece(root, GardenCues.box(Vector3.ONE * THICK * 1.3), fill_mat, Vector3.ZERO)
		update(0.0)

	## `balance`: the bout's -1..1 (positive when the first Boki is stronger, who stands at -x).
	func update(balance: float) -> void:
		power = absf(balance)
		side = 0 if balance >= 0.0 else 1
		var toward := -signf(balance)
		fill.scale = Vector3(maxf(HALF * power / (THICK * 1.3), 0.01), 1, 1)
		fill.position.x = toward * HALF * power * 0.5
		GardenCues.tint(fill_mat, GardenCues.TEAL if side == 0 else GardenCues.MAGENTA, GardenCues.BRIGHT)
		root.rotation.z = balance * TILT

	func clear() -> void:
		root.queue_free()

## Seek: dots drift from the hidden scent toward each hunter; the better its nose, the brighter its trail.
class SeekCue:
	extends RefCounted
	const DOTS := 8                     # per hunter
	const REACH := 4.0                  # m the trail runs from the scent at most
	const DOT_R := 0.2                  # m
	const DRIFT := 0.5                  # trail lengths per s the dots move out
	const MAX_ALPHA := 0.85             # the trail of a perfect nose

	var root: Node3D
	var dots: Array = []                # per hunter: its DOTS meshes
	var mats: Array = []                # per hunter: its glow material
	var strength: Array = [0.0, 0.0]    # per hunter: the trail's alpha before the fade along it
	var shown: Array = [0, 0]           # per hunter: dots on the ground now
	var t := 0.0

	func _init(parent: Node3D) -> void:
		root = GardenCues.root_in(parent, "SeekCue")
		for i in 2:
			var m := GardenCues.glow(GardenCues.TEAL if i == 0 else GardenCues.MAGENTA, 0.0)
			mats.append(m)
			var row: Array = []
			for k in DOTS:
				var dot := CylinderMesh.new()
				dot.top_radius = DOT_R
				dot.bottom_radius = DOT_R
				dot.height = 0.01
				row.append(GardenCues.piece(root, dot, m, Vector3.ZERO))
			dots.append(row)

	## Lays hunter i's trail from the scent to it. `nose` is its chance of a right sniff (0..1);
	## `ground` maps a Vector2 to the ground height.
	func update(i: int, scent: Vector2, hunter: Vector2, nose: float, ground: Callable, d: float) -> void:
		if i == 0:
			t += d
		strength[i] = nose * MAX_ALPHA
		GardenCues.tint(mats[i], mats[i].albedo_color, strength[i])
		var span := minf(scent.distance_to(hunter), REACH)
		var dir := (hunter - scent).normalized()
		shown[i] = 0
		for k in DOTS:
			var u := fposmod(float(k) / DOTS + t * DRIFT, 1.0)
			var p := scent + dir * span * u
			var dot: MeshInstance3D = dots[i][k]
			dot.visible = span > DOT_R
			dot.position = Vector3(p.x, float(ground.call(p)) + 0.05, p.y)
			dot.scale = Vector3.ONE * (1.0 - 0.5 * u)
			if dot.visible:
				shown[i] += 1

	func clear() -> void:
		root.queue_free()

## Spark Volley: a ring where the seed will land, and a flash at the Boki whose spike you called.
class VolleyCue:
	extends RefCounted
	const RING_IN := 0.3                # m
	const RING_OUT := 0.4
	const FAR := 1.8                    # the ring's scale when the seed has just left
	const FLASH_S := 0.4                # s the spike flash lasts
	const FLASH_R := 1.2                # m the flash grows to
	const BRIGHT_RING := 0.8            # alpha of the ring at touchdown and of the flash's first frame

	var root: Node3D
	var landing: MeshInstance3D
	var landing_mat: StandardMaterial3D
	var flash: MeshInstance3D
	var flash_mat: StandardMaterial3D
	var flash_t := 0.0                  # s of flash left
	var spiked := false                 # the seed in the air is a spike

	func _init(parent: Node3D) -> void:
		root = GardenCues.root_in(parent, "VolleyCue")
		landing_mat = GardenCues.glow(GardenCues.TEAL, BRIGHT_RING)
		landing = GardenCues.piece(root, GardenCues.ring(RING_IN, RING_OUT), landing_mat, Vector3.ZERO)
		landing.visible = false
		flash_mat = GardenCues.glow(GardenCues.MAGENTA, 0.0)
		flash = GardenCues.piece(root, GardenCues.ring(0.4, 0.5), flash_mat, Vector3.ZERO)
		flash.visible = false

	## While the seed flies: `at` is the landing spot on the ground, `u` how far along the flight it is (0..1).
	func aim(at: Vector3, u: float, hard: bool) -> void:
		landing.visible = true
		spiked = hard
		landing.position = at + Vector3(0, 0.05, 0)
		landing.scale = Vector3.ONE * lerpf(FAR, 1.0, u)
		GardenCues.tint(landing_mat, GardenCues.MAGENTA if hard else GardenCues.TEAL, lerpf(0.35, BRIGHT_RING, u))

	func hide_landing() -> void:
		landing.visible = false
		spiked = false

	## Your spike was called: the flash blooms at `at`.
	func call_flash(at: Vector3) -> void:
		flash_t = FLASH_S
		flash.position = at + Vector3(0, 0.08, 0)
		flash.visible = true

	func step(d: float) -> void:
		if flash_t <= 0.0:
			return
		flash_t = maxf(0.0, flash_t - d)
		var k := 1.0 - flash_t / FLASH_S
		flash.scale = Vector3.ONE * lerpf(0.5, FLASH_R / 0.5, k)
		GardenCues.tint(flash_mat, GardenCues.MAGENTA, BRIGHT_RING * (1.0 - k))
		flash.visible = flash_t > 0.0

	func clear() -> void:
		root.queue_free()

## A few rings reused in turn, the oldest first: each grows from `from` to `to` times its size and fades out
## over its life. `spawns` counts them and `last_at`/`last_col` keep the newest, for the checks.
class Bursts:
	extends RefCounted
	var nodes: Array = []               # MeshInstance3D per ring
	var mats: Array = []                # its glow material
	var age: Array = []                 # s since it spawned
	var life: Array = []                # s it lasts (0: idle)
	var grow: Array = []                # [from, to] scale
	var tone: Array = []                # its colour, alpha at spawn
	var next := 0
	var spawns := 0
	var last_at := Vector3.ZERO
	var last_col := Color.WHITE

	func _init(root: Node3D, count: int, inner: float, outer: float) -> void:
		for i in count:
			var m := GardenCues.glow(Color.WHITE, 0.0)
			var n := GardenCues.piece(root, GardenCues.ring(inner, outer), m, Vector3.ZERO)
			n.visible = false
			nodes.append(n)
			mats.append(m)
			age.append(0.0)
			life.append(0.0)
			grow.append([1.0, 1.0])
			tone.append(Color.WHITE)

	func spawn(at: Vector3, col: Color, from: float, to: float, secs: float) -> void:
		var i := next
		next = (next + 1) % nodes.size()
		nodes[i].position = at
		nodes[i].scale = Vector3.ONE * from
		nodes[i].visible = true
		GardenCues.tint(mats[i], col, col.a)
		age[i] = 0.0
		life[i] = secs
		grow[i] = [from, to]
		tone[i] = col
		spawns += 1
		last_at = at
		last_col = col

	func step(d: float) -> void:
		for i in nodes.size():
			if life[i] <= 0.0:
				continue
			age[i] += d
			var k := minf(1.0, age[i] / life[i])
			nodes[i].scale = Vector3.ONE * lerpf(grow[i][0], grow[i][1], k)
			GardenCues.tint(mats[i], tone[i], tone[i].a * (1.0 - k))
			if k >= 1.0:
				life[i] = 0.0
				nodes[i].visible = false

## Echo Steps: the lead's stone lights on its beat in the lead's type colour; on a beat you answer a ring
## round all four stones keeps time without giving the stone away. A hit flashes bright, a miss dull and inward.
class EchoCue:
	extends RefCounted
	const BEAT_S := 0.3                 # s a beat ring lasts
	const FLASH_S := 0.45               # s a hit or miss flash lasts
	const UP := Vector3(0, 0.16, 0)     # m over a stone's foot: on its top

	var root: Node3D
	var middle := Vector3.ZERO
	var beats: Bursts                   # a stone's beat
	var pulses: Bursts                  # the beat you answer, round the stones
	var flashes: Bursts                 # hits and misses

	func _init(parent: Node3D, at: Vector3, reach: float) -> void:
		root = GardenCues.root_in(parent, "EchoCue")
		middle = at + Vector3(0, 0.05, 0)
		beats = Bursts.new(root, 4, 0.3, 0.4)
		pulses = Bursts.new(root, 2, reach - 0.06, reach)
		flashes = Bursts.new(root, 4, 0.34, 0.46)

	func beat(stone_at: Vector3, col: Color) -> void:
		beats.spawn(stone_at + UP, Color(col, GardenCues.BRIGHT), 1.0, 1.5, BEAT_S)

	func pulse(col: Color) -> void:
		pulses.spawn(middle, Color(col, GardenCues.DIM), 1.0, 1.12, BEAT_S)

	func hit(stone_at: Vector3, col: Color) -> void:
		flashes.spawn(stone_at + UP, Color(col.lightened(0.35), 1.0), 1.0, 2.4, FLASH_S)

	func miss(stone_at: Vector3) -> void:
		flashes.spawn(stone_at + UP, Color(GardenCues.MISS, GardenCues.BRIGHT), 1.8, 0.5, FLASH_S)

	func step(d: float) -> void:
		beats.step(d)
		pulses.step(d)
		flashes.step(d)

	func clear() -> void:
		root.queue_free()

## Tumble: the rival's tell over its head while the tell lasts: Rush a double chevron toward your Boki, Brace a
## shield, Dodge a hoop. A tell is only probably true, so the icon is never solid: its alpha is the chance it
## is honest and it sways more the less sure it is.
class TellCue:
	extends RefCounted
	const POP_S := 0.12                 # s the icon takes to grow in
	const SWAY := 0.5                   # rad of sway at a coin-flip tell, none at a sure one
	const SWAY_RATE := 5.0              # rad/s
	const SIZE := 1.5                   # the icon's scale: about 0.55 m across, a Boki's head

	var root: Node3D                    # faces the camera and sways
	var pivot: Node3D                   # grows the icon in
	var icons := {}                     # move -> its Node3D
	var mat: StandardMaterial3D
	var face: StandardMaterial3D        # the band across the shield
	var shown := ""                     # the move on show ("" for none)
	var sure := 0.0                     # the chance the tell on show is honest
	var t := 0.0

	func _init(parent: Node3D, col: Color) -> void:
		root = GardenCues.root_in(parent, "TellCue")
		mat = GardenCues.glow(col, 0.0, true)
		face = GardenCues.glow(Color.WHITE, 0.0, true)
		var rush := Node3D.new()
		for x in [-0.12, 0.12]:
			for y in [-1.0, 1.0]:
				var bar := GardenCues.piece(rush, GardenCues.box(Vector3(0.26, 0.07, 0.04)), mat,
						Vector3(x, y * 0.085, 0))
				bar.rotation.z = -y * 0.7
		var brace := Node3D.new()
		GardenCues.piece(brace, GardenCues.box(Vector3(0.36, 0.44, 0.04)), mat, Vector3.ZERO)
		GardenCues.piece(brace, GardenCues.box(Vector3(0.26, 0.06, 0.06)), face, Vector3(0, 0.06, 0))
		var dodge := Node3D.new()
		var hoop := GardenCues.piece(dodge, GardenCues.ring(0.16, 0.22), mat, Vector3.ZERO)
		hoop.rotation.x = PI * 0.5
		icons = {"rush": rush, "brace": brace, "dodge": dodge}
		pivot = Node3D.new()
		root.add_child(pivot)
		for m in icons:
			icons[m].visible = false
			pivot.add_child(icons[m])

	## `honest`: the chance this tell shows the rival's real move (0..1).
	func show_tell(move: String, honest: float) -> void:
		hide_tell()
		shown = move
		sure = honest
		t = 0.0
		icons[move].visible = true
		GardenCues.tint(mat, mat.albedo_color, GardenCues.BRIGHT * honest)
		GardenCues.tint(face, Color.WHITE, GardenCues.BRIGHT * honest)

	func hide_tell() -> void:
		if shown != "":
			icons[shown].visible = false
		shown = ""

	## Floats over `rival` facing the camera; Rush points toward `yours` on screen.
	func step(rival: Vector3, yours: Vector3, d: float) -> void:
		if shown == "":
			return
		t += d
		root.position = rival + Vector3(0, GardenCues.LIFT, 0)
		var cam := root.get_viewport().get_camera_3d()
		if cam != null:
			root.look_at(cam.global_position, Vector3.UP, true)
			icons["rush"].scale.x = -1.0 if cam.global_basis.x.dot(yours - rival) < 0.0 else 1.0
		root.rotate_object_local(Vector3.BACK, sin(t * SWAY_RATE) * SWAY * 2.0 * (1.0 - sure))
		pivot.scale = Vector3.ONE * SIZE * clampf(t / POP_S, 0.05, 1.0)

	func clear() -> void:
		root.queue_free()

## The Relay Cup: a glowing baton over each team's runner in the runner's type colour. At a hand-off a ring
## bursts at the Boki taking it, bright on a clean pass, dull on a fumble, and the baton blinks while it fumbles.
class BatonCue:
	extends RefCounted
	const SPIN := 2.5                   # rad/s the baton turns
	const BLINK := 14.0                 # rad/s it blinks while the runner takes it
	const BURST_S := 0.6                # s a hand-off ring lasts

	var root: Node3D
	var batons: Array = []              # per team
	var mats: Array = []
	var legs := [0, 0]                  # the leg each baton is on
	var rings: Bursts
	var t := 0.0

	func _init(parent: Node3D) -> void:
		root = GardenCues.root_in(parent, "BatonCue")
		for team in 2:
			var c := CapsuleMesh.new()
			c.radius = 0.08
			c.height = 0.6
			var m := GardenCues.glow(Color.WHITE, GardenCues.BRIGHT, true)
			mats.append(m)
			var b := GardenCues.piece(root, c, m, Vector3.ZERO)
			b.rotation.z = PI * 0.5
			batons.append(b)
		rings = Bursts.new(root, 2, 0.4, 0.5)

	## Team's baton over its runner at `at` on `leg`; `waiting` while that runner takes it; `clean` when
	## its last hand-off lost no time.
	func update(team: int, at: Vector3, leg: int, col: Color, waiting: bool, clean: bool) -> void:
		var b: MeshInstance3D = batons[team]
		b.position = at + Vector3(0, GardenCues.LIFT, 0)
		b.rotation.y = t * SPIN
		var on := not waiting or sin(t * BLINK) > 0.0
		GardenCues.tint(mats[team], col.lightened(0.25), GardenCues.BRIGHT if on else 0.2)
		if leg != legs[team]:
			legs[team] = leg
			var tone := Color(col.lightened(0.4), 1.0) if clean else Color(GardenCues.MISS, GardenCues.BRIGHT)
			rings.spawn(at + Vector3(0, 0.06, 0), tone, 0.6, 2.2 if clean else 1.2, BURST_S)

	func step(d: float) -> void:
		t += d
		rings.step(d)

	func clear() -> void:
		root.queue_free()

## Show Ring: a round's score pops over the Boki in its type colour, grows in, rises and fades.
class PopCue:
	extends RefCounted
	const LIFE := 1.8                   # s a pop shows
	const POP_S := 0.15                 # s it grows in
	const RISE := 0.6                   # m it rises over its life

	var root: Node3D
	var labels: Array = []              # Label3D pool
	var age: Array = []                 # s since it popped (negative: still waiting)
	var from: Array = []                # where it popped
	var next := 0
	var spawns := 0
	var last_text := ""

	func _init(parent: Node3D) -> void:
		root = GardenCues.root_in(parent, "PopCue")
		for i in 3:
			var l := Label3D.new()
			l.font = UI.big
			l.font_size = 56
			l.pixel_size = 0.012
			l.outline_size = 16
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.visible = false
			root.add_child(l)
			labels.append(l)
			age.append(LIFE)
			from.append(Vector3.ZERO)

	## Pops `text` over a Boki standing at `at`, `delay` s from now.
	func pop(at: Vector3, text: String, col: Color, delay := 0.0) -> void:
		var i := next
		next = (next + 1) % labels.size()
		labels[i].text = text
		labels[i].modulate = col.lightened(0.2)
		labels[i].visible = false
		age[i] = -delay
		from[i] = at + Vector3(0, GardenCues.LIFT, 0)
		spawns += 1
		last_text = text

	func step(d: float) -> void:
		for i in labels.size():
			if age[i] >= LIFE:
				continue
			age[i] += d
			var l: Label3D = labels[i]
			l.visible = age[i] >= 0.0 and age[i] < LIFE
			var k := clampf(age[i] / LIFE, 0.0, 1.0)
			l.position = from[i] + Vector3(0, RISE * k, 0)
			l.scale = Vector3.ONE * minf(1.0, maxf(age[i], 0.0) / POP_S)
			l.modulate.a = 1.0 - k * k
			l.outline_modulate.a = l.modulate.a

	func clear() -> void:
		root.queue_free()
