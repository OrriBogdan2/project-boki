class_name HeartRaidGates
extends RefCounted
## Heart Raid's wave gates (content/rules/heart_raid.json "gates"; principle 1, clarity): every wave comes out
## of fixed points round the Heart on the wave clock, never a random spot or time. warn_s before a wave its
## gates are marked: a ring on the ground with a countdown over it (one pooled marker per gate, built once)
## and a badge on the minimap (HeartRaidHud.minimap). Host and clients work the marks out alike from the
## wave number, so nothing new goes over the net.

const EDGE_IN := 4.0           # m: an outer gate stays at least this far inside the tide ring at its wave's time
const RING_R := 2.6            # m, the ground ring's radius
const GLYPH_Y := 4.0           # m, the countdown's height over the gate
const GLYPH_PX := 0.0016       # fixed-size glyph: share of the screen height per font pixel

var rd: HeartRaid
var marks: Array = []          # the coming (or just sent) wave's groups: {gate, at, guard, mobs}
var marked_wave := -1          # the wave index the marks are for
var _root: Node3D
var _markers := {}             # gate id -> {node, glyph, clock}

func _init(raid: HeartRaid) -> void:
	rd = raid

## Where a gate stands for a wave that comes out at wave_t (session seconds): its bearing and distance from
## the Heart, an outer gate pulled inside the tide ring the tide has then.
func spot(gate: String, wave_t: float) -> Vector3:
	var m := rd.m
	var g: Dictionary = HeartRaid.rules()["gates"][gate]
	var a := deg_to_rad(float(g["deg"]))
	var dist := float(g["m"])
	if not bool(g["guard"]):
		dist = minf(dist, Heart.ring_at(wave_t, m.heart.ways_scale) - EDGE_IN)
	var p := m.heart.site + Vector3(sin(a), 0.0, -cos(a)) * dist
	return m.world.free_spot_near(p, [], 1.0, 0.45, 6.0)

## Marks wave `i` (coming out at wave_t) once; the marks stay until the next wave is marked.
func mark(i: int, wave_t: float) -> void:
	if i == marked_wave or i >= rd.waves_n():
		return
	marked_wave = i
	marks.clear()
	for grp in HeartRaid.rules()["waves"][i]:
		var gate := String(grp["gate"])
		var g: Dictionary = HeartRaid.rules()["gates"][gate]
		marks.append({"gate": gate, "at": spot(gate, wave_t), "guard": bool(g["guard"]), "mobs": grp["mobs"]})

## The countdown to the marked wave (seconds; negative once it is out).
func left() -> float:
	return rd.next_wave_t - rd.m.sess_time()

## Shown while the marked wave is still to come: the rings and their countdowns. Cheap per tick: the glyph
## text is only set when the whole second changes.
func show_marks() -> void:
	if _root == null:
		_build()
	var s := int(ceilf(left()))
	var up := marked_wave == rd.wave and s > 0
	for gate in _markers:
		(_markers[gate]["node"] as Node3D).visible = false
	if not up:
		return
	for mk in marks:
		var mr: Dictionary = _markers[mk["gate"]]
		var n: Node3D = mr["node"]
		n.visible = true
		n.position = mk["at"]
		if int(mr["clock"]) != s:
			mr["clock"] = s
			(mr["glyph"] as Label3D).text = str(s)

func _build() -> void:
	_root = Node3D.new()
	_root.name = "RaidGates"
	rd.m.add_child(_root)
	for gate in HeartRaid.rules()["gates"]:
		if gate.begins_with("_"):
			continue
		var n := Node3D.new()
		n.visible = false
		_root.add_child(n)
		var ring := MeshInstance3D.new()
		ring.mesh = Models.flat_quad(RING_R * 2.0)
		ring.material_override = Models.ring_mat(Color(HeartRaid.COL, 0.9), 0.1)
		ring.position = Vector3(0, 0.14, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(ring)
		var glyph := Label3D.new()
		glyph.font = UI.big
		glyph.font_size = 48
		glyph.outline_size = 14
		glyph.outline_modulate = Color(0.1, 0.1, 0.14, 0.9)
		glyph.modulate = HeartRaid.COL
		glyph.pixel_size = GLYPH_PX
		glyph.fixed_size = true
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glyph.no_depth_test = true
		glyph.position = Vector3(0, GLYPH_Y, 0)
		n.add_child(glyph)
		_markers[gate] = {"node": n, "glyph": glyph, "clock": -1}
