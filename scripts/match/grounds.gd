class_name Grounds
extends RefCounted
## The Training Grounds' stations (the --arena map's "grounds" block, content/maps/arena.json).
## Pedestals on the sky perches let you try every Hunter, Boki, glove/armor/boot and belt item, and spawn
## a sparring bot of any Hunter; a ring on the floor takes you to the duel room. Walk up, press interact.
## Cheap by design: every pedestal shares one mesh and a few materials, a label only shows when you are close,
## and nothing here runs per-pedestal physics.

const ACT_R := 1.5            # [m] how close you stand to use a pedestal
const SHOW_R := 6.5           # [m] a pedestal's name is drawn inside this
const FALL_Y := -12.0         # [m] below this you fell off the map: back to the start (the abyss kills at -17)
const KIND_COL := {
	"arch": "ffb454", "kin": "8fe3c8", "gear": "c9a0ff", "item": "ff8a7a", "bot": "ff6a6a", "clear": "9aa0b4",
	"duel": "ffb0a0"}

static var _ped_mesh: CylinderMesh = null
static var _mats := {}

var a: Arena
var m: Match
var stations: Array = []       # {kind, id, at: Vector3 (the pedestal), c: Vector3 (its perch's middle), label: Label3D}
var near_i := -1
var _belt_turn := 0            # which belt slot a full belt gives up next
var prompt: Label = null
var _layer: CanvasLayer = null

## The map's "grounds" block ({} when this isn't the Training Grounds).
static func data() -> Dictionary:
	return World.load_layout("arena").get("grounds", {})

static func v3(p: Array, y := 0.0) -> Vector3:
	return Vector3(float(p[0]), y, float(p[1]))

## The ids a station kind offers, in pedestal order.
static func ids_for(kind: String) -> Array:
	match kind:
		"arch": return Arch.ids()
		"kin": return KinLib.kin_ids()
		"gear": return _gear_ids()
		"item": return UtilityBelt.stock_ids()
		"bot": return Arch.ids() + ["clear"]
	return []

## Gloves first (actives, then passives), then armor, then boots.
static func _gear_ids() -> Array:
	var out: Array = []
	for slot in Gear.SLOTS.size():
		out.append_array(Gear.ids_for(slot))
	return out

static func name_of(kind: String, id: String) -> String:
	match kind:
		"arch": return Arch.name_of(id)
		"kin": return String(Data.KIN.get(id, {}).get("name", id))
		"gear": return String(Gear.ALL.get(id, {}).get("name", id))
		"item": return UtilityBelt.name_of(id)
		"bot": return "Clear bots" if id == "clear" else "Bot: " + Arch.name_of(id)
	return id

static func color_of(kind: String, id: String) -> Color:
	match kind:
		"arch", "bot":
			if id != "clear": return Arch.color(id)
		"item": return UtilityBelt.col_of(id)
	return Color(String(KIND_COL.get(kind if id != "clear" else "clear", "ffffff")))

func _init(arena: Arena) -> void:
	a = arena
	m = arena.m

func build() -> void:
	var g := data()
	if g.is_empty():
		return
	for st in g.get("stations", []):
		_ring(String(st["kind"]), v3(st["at"]), float(st["ring"]))
	if g.has("duel"):
		_duel(v3(g["duel"]))
	_layer = CanvasLayer.new()
	_layer.layer = 20
	prompt = Label.new()
	prompt.position = Vector2(0, 150)
	prompt.size = Vector2(1280, 30)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.visible = false
	_layer.add_child(prompt)
	m.add_child(_layer)

## One ring of pedestals round a perch's middle, one per id of the kind.
func _ring(kind: String, c: Vector3, r: float) -> void:
	var ids := ids_for(kind)
	var n := ids.size()
	for i in n:
		var ang := -PI / 2.0 + TAU * float(i) / float(n)
		var p := c + Vector3(cos(ang), 0, sin(ang)) * r
		p.y = m.world.ground_at(p.x, p.z)
		_pedestal(kind, String(ids[i]), p, c)

func _mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mats.has(key):
		var sm := StandardMaterial3D.new()
		sm.albedo_color = col.darkened(0.15)
		sm.emission_enabled = true
		sm.emission = col
		sm.emission_energy_multiplier = 0.9
		_mats[key] = sm
	return _mats[key]

func _pedestal(kind: String, id: String, p: Vector3, c: Vector3) -> void:
	if _ped_mesh == null:
		_ped_mesh = CylinderMesh.new()
		_ped_mesh.top_radius = 0.42
		_ped_mesh.bottom_radius = 0.55
		_ped_mesh.height = 0.5
		_ped_mesh.radial_segments = 12
		_ped_mesh.rings = 1
	var col := color_of(kind, id)
	var mi := MeshInstance3D.new()
	mi.mesh = _ped_mesh
	mi.material_override = _mat(col)
	mi.position = p + Vector3(0, 0.25, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	var lb := _label(name_of(kind, id), col, 1.9)
	lb.position = p + Vector3(0, 1.2, 0)
	lb.visible = false
	m.add_child(lb)
	stations.append({"kind": kind, "id": id, "at": p, "c": c, "label": lb})

func _label(text: String, col: Color, scale_k := 1.0) -> Label3D:
	var lb := Label3D.new()
	lb.text = text
	lb.font = UI.big
	lb.font_size = 32
	lb.pixel_size = 0.006 * scale_k / 1.9
	lb.outline_size = 10
	lb.modulate = col.lightened(0.35)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.render_priority = 100
	lb.outline_render_priority = 99
	return lb

## The duel ring: the old training pad, inside a walled ring east of the Training Room.
func _duel(at: Vector3) -> void:
	at.y = m.world.ground_at(at.x, at.z)
	var pad := Models.jump_pad(Color(String(KIND_COL["duel"])))
	pad.position = at
	m.add_child(pad)
	var lb := _label("DUEL ROOM\n%s to enter" % Settings.key_cap("interact"), Color(String(KIND_COL["duel"])), 2.6)
	lb.position = at + Vector3(0, 2.7, 0)
	m.add_child(lb)
	m.duel_pad = at

## Per frame (from Arena.tick): show the near pedestal's name, use it on interact, bring a faller home.
func tick() -> void:
	var P: Hunter = m.player
	if P == null or prompt == null:
		return
	if P.pos.y < FALL_Y and not P.downed:
		P.teleport(a.home)
		P.vel = Vector3.ZERO
		if m.hud: m.hud.toast_small("Back to the Training Grounds", Color("8fe3c8"))
		return
	var best := -1
	var bd := ACT_R
	for i in stations.size():
		var s: Dictionary = stations[i]
		var at: Vector3 = s["at"]
		var d := P.flat_dist(at)
		var near := d < SHOW_R and absf(P.pos.y - at.y) < 4.0
		var lb: Label3D = s["label"]
		if lb.visible != near:
			lb.visible = near
		if near and d < bd:
			bd = d
			best = i
	if best != near_i:
		near_i = best
		prompt.visible = best >= 0
		if best >= 0:
			var sd: Dictionary = stations[best]
			prompt.text = "%s   ·   %s" % [name_of(String(sd["kind"]), String(sd["id"])), Settings.key_cap("interact")]
			prompt.add_theme_color_override("font_color", color_of(String(sd["kind"]), String(sd["id"])).lightened(0.3))
	if best >= 0 and Input.is_action_just_pressed("interact") and not m.paused and not P.downed:
		use(best)

## Try a pedestal's thing.
func use(i: int) -> void:
	var s: Dictionary = stations[i]
	var id := String(s["id"])
	var P: Hunter = m.player
	match String(s["kind"]):
		"arch": a.set_arch(id)
		"kin": a.set_kin(id)
		"gear": _wear(id)
		"item": _stock(id)
		"bot": _spawn(id, s["c"])
	m.fx.ring(s["at"], 1.2, color_of(String(s["kind"]), id), 0.3)

## Fill this item's stack. The belt has four slots: when they are all taken, the next one in turn is emptied.
func _stock(id: String) -> void:
	var P: Hunter = m.player
	if UtilityBelt.room_for(P, id) <= 0 and UtilityBelt.count(P, id) <= 0:
		P.belt[_belt_turn % UtilityBelt.SLOTS] = {}
		_belt_turn += 1
	UtilityBelt.grant(P, id, UtilityBelt.room_for(P, id))

## Gloves go where Gloves.slot_for puts them; armor and boots in their own slot (Rare).
func _wear(id: String) -> void:
	var P: Hunter = m.player
	if Gear.is_glove(id):
		a.give_glove(id)
		return
	var slot := Gear.slot_of(id)
	P.gear[slot] = {"id": id, "rar": 2}
	P.refresh_gear()
	P.armor = P.max_armor

## A sparring bot of this Hunter, in the middle of the perch you are on ("clear": none).
func _spawn(id: String, c: Vector3) -> void:
	if id == "clear":
		a.bot_mode = "off"
		a._spawn_bot()
		return
	if a.bot_mode == "off":
		a.bot_mode = "fighting"
	a.bot_at = a._free_near(c)
	a.set_bot_arch(id)
