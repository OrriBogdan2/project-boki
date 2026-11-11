class_name WardenBlink
extends Node3D
## A Hero blinks in a close-up (hero select, the Model Room, the relic put-on). The appeal3 eyes are painted on the
## skin atlas and no mesh rides the lid bones, so a lid is a Decal: a skin-coloured lid with a dark lash edge projected
## onto each painted eye, riding the head, shown only while a blink runs. Data: warden_anim/<art>.json "blink":
## "eyes" [[x, y, z], ...] each eye's middle on the face, "size" [w, h] an eye, in the model's bind space (m, the face
## looks along -Z); "skin" the lid's colour. Every EVERY s (random) it looks for the camera: within
## WardenGlb.FAR_HIDE_D of the head the lids come down for SHUT_T s, now and then twice; past it (the match camera)
## they never do. Asleep between blinks: a Timer wakes it, so a far camera costs no per-frame work and no draw.
## Cosmetic: its own RNG, nothing synced.

const EVERY := Vector2(2.0, 6.0)   # s between blinks, at random
const DOWN_T := 0.04               # s the lids take to close
const HOLD_T := 0.04               # s they stay shut
const UP_T := 0.07                 # s they take to open
const SHUT_T := DOWN_T + HOLD_T + UP_T
const GAP_T := 0.12                # s open between the two of a double blink
const TWICE := 0.2                 # share of blinks that come as a double
const DEPTH := 0.03                # m: how deep a lid projects into the face (no further: the nose, the hair)
const LASH := Color(0.1, 0.06, 0.07)
const LASH_W := 0.22               # share of the lid's height its lash edge takes
const TEX := Vector2i(64, 32)      # px, the lid's texture
const FACING := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)   # a lid's decal frame in bind space

static var _tex: ImageTexture

var skel: Skeleton3D
var head := -1
var unbind := Transform3D.IDENTITY # the head's bind pose, undone: bind space -> the head's current pose
var eye_size := Vector2.ZERO       # m, one eye
var lids: Array = []               # a Decal per eye
var eyes: Array = []               # each eye's middle, bind space (m)
var shut_k := 0.0                  # 0 open .. 1 closed, the last pose
var left := 0                      # blinks still to come in this run
var t := 0.0                       # s into the current blink
var timer := Timer.new()
var rng := RandomNumberGenerator.new()

## The blink of this model, added under its skeleton; null when its art has no eyes in its data.
static func make(sk: Skeleton3D, art_name: String) -> WardenBlink:
	var cfg: Dictionary = WardenClips.data(art_name).get("blink", {})
	if cfg.is_empty():
		return null
	var b := WardenBlink.new()
	b.name = "Blink"
	b.skel = sk
	b.head = WardenSkeleton.find(sk, "head")
	b.unbind = sk.get_bone_global_rest(b.head).affine_inverse()
	b.eye_size = Vector2(float(cfg["size"][0]), float(cfg["size"][1]))
	for e in cfg["eyes"]:
		b.eyes.append(Vector3(float(e[0]), float(e[1]), float(e[2])))
		var d := Decal.new()
		d.texture_albedo = _lid_tex()
		d.modulate = Color(String(cfg["skin"]))
		d.upper_fade = 0.0
		d.lower_fade = 0.3
		d.visible = false
		b.lids.append(d)
		b.add_child(d)
	b.rng.randomize()
	sk.add_child(b)
	return b

## The lid: white (the decal's modulate makes it skin), its bottom rim the lash edge, soft all round.
static func _lid_tex() -> ImageTexture:
	if _tex:
		return _tex
	var img := Image.create(TEX.x, TEX.y, false, Image.FORMAT_RGBA8)
	for y in TEX.y:
		for x in TEX.x:
			var p := Vector2((x + 0.5) / TEX.x * 2.0 - 1.0, (y + 0.5) / TEX.y * 2.0 - 1.0)
			var r := p.length()
			var a := clampf((1.0 - r) / 0.12, 0.0, 1.0)
			# (a Decal's texture runs up its +Z, here the face's up: row 0 is the bottom rim, on the lower lashes)
			var lash := p.y < 0.0 and r > 1.0 - LASH_W * 2.0
			img.set_pixel(x, y, Color(LASH if lash else Color.WHITE, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex

func _ready() -> void:
	set_process(false)
	timer.one_shot = true
	timer.timeout.connect(_due)
	add_child(timer)
	_arm()

func _arm() -> void:
	timer.start(rng.randf_range(EVERY.x, EVERY.y))

## The timer: a blink when the camera is close, else back to sleep.
func _due() -> void:
	if near():
		start(2 if rng.randf() < TWICE else 1)
	else:
		_arm()

## True when the camera is within the far-camera distance of the head (and the model is shown).
func near() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or head < 0 or not skel.is_visible_in_tree():
		return false
	var at := skel.global_transform * skel.get_bone_global_pose(head).origin
	return cam.global_position.distance_to(at) < WardenGlb.FAR_HIDE_D

func start(times: int) -> void:
	left = times
	t = 0.0
	set_process(true)

## How shut the lids are `at` s into a blink: 0 open, 1 closed.
static func shut(at: float) -> float:
	if at < DOWN_T:
		return at / DOWN_T
	if at < DOWN_T + HOLD_T:
		return 1.0
	return clampf(1.0 - (at - DOWN_T - HOLD_T) / UP_T, 0.0, 1.0)

func _process(dt: float) -> void:
	t += dt
	if left > 1 and t >= SHUT_T + GAP_T:
		left -= 1
		t -= SHUT_T + GAP_T
	if t < SHUT_T:
		pose(shut(t))
	elif left <= 1:
		left = 0
		pose(0.0)
		set_process(false)
		_arm()

## The lids k of the way down: each hangs from the top of its eye, k of the eye's height, on the head's current pose.
func pose(k: float) -> void:
	shut_k = k
	var on_head := skel.get_bone_global_pose(head) * unbind
	for i in lids.size():
		var d := lids[i] as Decal
		d.visible = k > 0.0
		if not d.visible:
			continue
		var top: Vector3 = eyes[i] + Vector3(0.0, eye_size.y * 0.5, 0.0)
		# (a Decal projects along its -Y: here into the face, +Z)
		d.transform = on_head * Transform3D(FACING, top - Vector3(0.0, eye_size.y * k * 0.5, 0.0))
		d.size = Vector3(eye_size.x, DEPTH, eye_size.y * k)
