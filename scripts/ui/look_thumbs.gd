class_name LookThumbs
extends SubViewport
## Little pictures of you wearing each choice, for the look locker's tiles. One offscreen stage (its own world, a key
## and a rim light, a clear background) builds the model with the choice on, takes one picture and moves on, one
## choice per frame so a tab fills in without a hitch. The model comes from the locker's own maker, so any model
## works. Pictures are kept by look and framing: a choice you have already seen comes back at once. With no renderer
## (headless runs) it takes no pictures and the tiles keep just their names.
##
##   var thumbs := LookThumbs.create(func(lk, parent): return make_posed_model_under(parent, lk))
##   thumbs.want(trial_look, "head", texture_rect)

const PX := Vector2i(184, 168)              # px: one picture (shown at about half size, so it stays crisp)
## Each framing: [camera, the point it looks at, field of view (deg), the model's turn (rad)], from the model's feet.
const FRAMES := {"head": [Vector3(0, 1.55, 0.9), Vector3(0, 1.5, 0), 34.0, 0.25],
	"bust": [Vector3(0, 1.35, 1.6), Vector3(0, 1.2, 0), 36.0, 0.45],
	"body": [Vector3(0, 1.05, 3.4), Vector3(0, 0.92, 0), 36.0, 0.4]}
const CACHE_MAX := 160                      # pictures kept before the oldest are dropped

var _make: Callable                         # (look, parent) -> the model, built and posed under parent
var _queue: Array = []                      # [look, framing, TextureRect, slot], oldest first
var _cache := {}
var _last := {}                             # a tile's slot -> its latest picture, shown while its new one is taken
var _cam: Camera3D
var _busy := false


static func create(make: Callable) -> LookThumbs:
	var t := LookThumbs.new()
	t._make = make
	t.size = PX
	t.own_world_3d = true
	t.transparent_bg = true
	t.msaa_3d = Viewport.MSAA_4X
	t.render_target_update_mode = SubViewport.UPDATE_DISABLED
	t._cam = Camera3D.new()
	t.add_child(t._cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8cdf0")
	env.environment.ambient_light_energy = 0.55
	t.add_child(env)
	t._light(Vector3(-1.4, 2.6, 2.4), Color("ffe6cc"), 1.4)
	t._light(Vector3(1.2, 2.2, -2.0), Color("bfe4ff"), 1.1)
	return t


## Whether pictures can be taken here (there is a renderer).
static func can_shoot() -> bool:
	return DisplayServer.get_name() != "headless"


## Puts the picture of `lk` in this framing ("head", "bust", "body") on `into`: at once if it is kept, else soon,
## showing the last picture taken for the same `slot` (a tile's choice) meanwhile so a pick never blanks the tiles.
func want(lk: Dictionary, framing: String, into: TextureRect, slot: String) -> void:
	var key := [lk, framing].hash()
	if _cache.has(key):
		into.texture = _cache[key]
		return
	into.texture = _last.get(slot)
	if can_shoot():
		_queue.append([lk.duplicate(true), framing, into, slot])


## Forgets the pictures still waiting (the tab changed; their tiles are gone).
func drop_queue() -> void:
	_queue.clear()


func _process(_delta: float) -> void:
	if not _busy and not _queue.is_empty():
		_shoot()


func _shoot() -> void:
	var job: Array = _queue.pop_front()
	if not is_instance_valid(job[2]):      # its tile is gone
		return
	var into: TextureRect = job[2]
	var key := [job[0], job[1]].hash()
	if _cache.has(key):
		into.texture = _cache[key]
		return
	_busy = true
	var fr: Array = FRAMES[String(job[1])]
	var m: Node3D = _make.call(job[0], self)
	m.rotation.y = PI - float(fr[3])
	_cam.fov = float(fr[2])
	_cam.position = fr[0]
	_cam.look_at(fr[1])
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	m.queue_free()
	_busy = false
	if img == null or img.is_empty():
		return
	if _cache.size() >= CACHE_MAX:
		_cache.erase(_cache.keys()[0])
	_cache[key] = ImageTexture.create_from_image(img)
	_last[String(job[3])] = _cache[key]
	if is_instance_valid(into):
		into.texture = _cache[key]


func _light(at: Vector3, col: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.transform = Transform3D(Basis.looking_at(-at), Vector3.ZERO)
	add_child(l)
