class_name GardenCues
extends RefCounted
## The garden minigames' world cues, in the Void & Masks palette (briefs/UI_STYLE.md): one cheap glowing mesh
## set per game, made when the game starts and freed when it ends (no particles, no textures).
##   DashCue    three cheer marks that light as your Boki reaches them, and the finish line
##   ShoveCue   a push meter over the stump, filling toward the stronger Boki
##   SeekCue    a faint scent trail from the hidden scent toward each hunter
##   VolleyCue  a ring where the seed lands, and a flash when your spike is called
## Each cue is fed the live game state by its game's tick and has a `clear()`. --garden-cue-shots takes the pictures.

const TEAL := Color("3fe0d0")        # neon edge, first side
const MAGENTA := Color("ff3fd0")     # neon edge, second side and the spike
const VOID := Color("2a1c40")        # an unlit cue
const BRIGHT := 0.9                  # alpha of a lit cue
const DIM := 0.3                     # alpha of an unlit cue

## An unlit, additive, see-through material: it reads as a glow on any ground.
static func glow(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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
		GardenCues.piece(root, GardenCues.box(Vector3(track_w, 0.03, LINE_DEPTH)),
				GardenCues.glow(Color.WHITE, BRIGHT), finish + Vector3(0, 0.07, 0))

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
		GardenCues.piece(root, track, GardenCues.glow(GardenCues.VOID, 0.55), Vector3.ZERO)
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
	const DOT_R := 0.1                  # m
	const DRIFT := 0.5                  # trail lengths per s the dots move out
	const MAX_ALPHA := 0.6              # the trail of a perfect nose

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
			dot.scale = Vector3.ONE * (1.0 - 0.7 * u)
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
