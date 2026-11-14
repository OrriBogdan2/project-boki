class_name WardenMood
extends RefCounted
## A construct's little life (ART-1, Breaker): a face drawn on glass that changes with what he is doing, and a
## hanging companion that reacts. Cosmetic only; nothing here touches the kit. Data: warden_anim/<art>.json "mood":
##   "kmoves": kit move -> mood; "downed", "hit", "emote", "default": moods; "hit_t": s a hit's mood lasts
##   "companion": the bone it wiggles and shivers; "lure": the material tag of its glow; "flare_kmoves": its moves
##   "faces": {material tag: {mood: atlas cell}}: faces drawn on an atlas (the glb's `eyes-mood_<tag>` texture)
##   in place of the glass, one per companion; "blink_cell" is the cell of a blink
## Moods: calm, happy, angry, determined, sad (+ sleepy, shy, cry for atlas faces).
## A kit calls poke(model, "shiver") for a blocked hit, and sets the root
## meta FLARE while its big moment runs.

const IDS := {"calm": 0, "happy": 1, "angry": 2, "determined": 3, "sad": 4, "sleepy": 5, "shy": 6, "cry": 7}
const FACE_SHADER := preload("res://shaders/warden_mood.gdshader")
const ATLAS_SHADER := preload("res://shaders/warden_mood_atlas.gdshader")
const POKE := "mood_poke"     # root meta: the time left of a shiver
const FLARE := "lure_flare"   # root meta: bool, the lure burns bright
const FADE := 7.0             # 1/s: one mood into the next
const SHIVER_T := 0.45        # s
const SHIVER_HZ := 26.0
const SHIVER_RAD := 0.3
const WIGGLE_HZ := 3.2
const WIGGLE_RAD := 0.34
const SWAY_HZ := 0.5
const SWAY_RAD := 0.08
const BLINK_EVERY := 3.7      # s
const BLINK_T := 0.13
const LURE_REST := 1.0        # x its glow: small, so it never reads as a pickup or a shot
const LURE_FLARE := 4.0
const FLARE_M := 0.7          # m, the flare's glow on the neutral model

var root: Node3D
var skel: Skeleton3D
var d: Dictionary
var face: ShaderMaterial
var atlas: Array = []         # [ShaderMaterial, {mood id: cell}] per atlas face
var lure: Array = []          # the lure's materials
var lure_base := 1.0
var lure_k := 0.0
var puff: MeshInstance3D      # the flare's glow
var bone := -1
var rest := Quaternion.IDENTITY
var cur := 0
var was := 0
var k := 1.0
var t := 0.0

static func poke(model: Node3D, _what := "shiver") -> void:
	if model:
		model.set_meta(POKE, SHIVER_T)

## The moods of this model, or null when its art has none.
static func make(model: Node3D, glb: Node3D, sk: Skeleton3D, art_name: String) -> WardenMood:
	var dd: Dictionary = WardenClips.data(art_name).get("mood", {})
	if dd.is_empty():
		return null
	var m := WardenMood.new()
	m.root = model
	m.skel = sk
	m.d = dd
	m._setup(glb)
	return m

func _setup(glb: Node3D) -> void:
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			var nm := String(src.resource_name) if src else ""
			var tag := nm.trim_prefix("eyes-mood_")
			if nm.begins_with("eyes-mood_") and d.get("faces", {}).has(tag) and src is BaseMaterial3D:
				var am := ShaderMaterial.new()
				am.shader = ATLAS_SHADER
				am.set_shader_parameter("atlas", (src as BaseMaterial3D).albedo_texture)
				am.set_shader_parameter("blink_cell", int(d.get("blink_cell", -1)))
				atlas.append([am, d["faces"][tag]])
				(mi as MeshInstance3D).set_surface_override_material(si, am)
			elif nm.begins_with("eyes-mood"):
				face = ShaderMaterial.new()
				face.shader = FACE_SHADER
				(mi as MeshInstance3D).set_surface_override_material(si, face)
			elif nm.begins_with("glow-" + String(d.get("lure", "lure"))):
				var over := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
				if over:
					lure.append(over)
					lure_base = float(over.get_shader_parameter("glow"))
	_flare_glow(glb)
	bone = WardenSkeleton.find(skel, String(d.get("companion", "")))
	if bone >= 0:
		rest = skel.get_bone_rest(bone).basis.get_rotation_quaternion()

## The flare past the lure's own white: a soft additive puff that opens on its anchor, off at rest so the small lure
## never reads as a pickup.
func _flare_glow(glb: Node3D) -> void:
	var at := glb.find_child("anchor_lure", true, false) as Node3D
	if at == null:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.55, 1.0, 0.9, 0.9)
	m.albedo_texture = WardenFx._puff()
	puff = WardenFx._bloom_quad(m, FLARE_M, Vector3.ZERO)
	puff.visible = false
	# (on the root, following the anchor: nothing that walks the .glb's meshes sees it)
	root.add_child(puff)
	var follow := RemoteTransform3D.new()
	follow.update_scale = false
	follow.update_rotation = false
	at.add_child(follow)
	follow.remote_path = follow.get_path_to(puff)

func _want(s: Dictionary) -> String:
	if bool(s.get("downed", false)) or bool(s.get("dead", false)):
		return String(d.get("downed", "sad"))
	if String(s.get("emote", "")) != "":
		return String(d.get("emote", "happy"))
	var moves: Dictionary = d.get("kmoves", {})
	var km := String(s.get("kmove", ""))
	if moves.has(km):
		return String(moves[km])
	if float(s.get("hit_t", 99.0)) < float(d.get("hit_t", 1.2)):
		return String(d.get("hit", "angry"))
	return String(d.get("default", "calm"))

## The atlas cell of mood id `id` in a face's map (a mood it has no cell for shows its calm one).
func _cell(map: Dictionary, id: int) -> int:
	return int(map.get(IDS.find_key(id), map.get("calm", 0)))

func step(dt: float) -> void:
	t += dt
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	var km := String(s.get("kmove", ""))
	var want := int(IDS.get(_want(s), 0))
	if want != cur:
		was = cur
		cur = want
		k = 0.0
	k = minf(1.0, k + FADE * dt)
	if face:
		face.set_shader_parameter("from_mood", was)
		face.set_shader_parameter("to_mood", cur)
		face.set_shader_parameter("k", k)
		var b := fmod(t, BLINK_EVERY)
		face.set_shader_parameter("blink", 1.0 if b < BLINK_T else 0.0)
	for a in atlas:
		var m := a[0] as ShaderMaterial
		m.set_shader_parameter("from_cell", _cell(a[1], was))
		m.set_shader_parameter("to_cell", _cell(a[1], cur))
		m.set_shader_parameter("k", k)
		m.set_shader_parameter("blink", 1.0 if fmod(t, BLINK_EVERY) < BLINK_T else 0.0)
	var left := float(root.get_meta(POKE, 0.0))
	if left > 0.0:
		root.set_meta(POKE, maxf(0.0, left - dt))
	if bone >= 0:
		var yaw := SWAY_RAD * sin(t * TAU * SWAY_HZ)
		if cur == 1:
			yaw += WIGGLE_RAD * sin(t * TAU * WIGGLE_HZ) * k
		var roll := SHIVER_RAD * sin(t * TAU * SHIVER_HZ) * left / SHIVER_T
		skel.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.FORWARD, roll))
	var flare: bool = bool(root.get_meta(FLARE, false)) or km in d.get("flare_kmoves", [])
	lure_k = move_toward(lure_k, 1.0 if flare else 0.0, 4.0 * dt)
	for m in lure:
		(m as ShaderMaterial).set_shader_parameter("glow", lure_base * lerpf(LURE_REST, LURE_FLARE, lure_k))
	if puff:
		puff.visible = lure_k > 0.01
		puff.scale = Vector3.ONE * lure_k
