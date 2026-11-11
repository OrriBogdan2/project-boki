extends RefCounted
## --boki-wisp-check: every species builds a Boki wisp (BokiWispLook) without errors, plain and shiny. Each is
## one mesh on the one shared material, its features are known parts (ears always, a tail tip when it has
## one), it wears its own colours (the shiny palette when it shimmers) with its glow on the rim, and the idle
## bounce moves and squashes it. The Model Room's ten (tests/kin_gallery.gd WISP_ROOM) all build and stay
## under the particle budget. Prints PASS/FAIL.

const Gallery := preload("res://tests/kin_gallery.gd")
const PARTICLE_BUDGET := 300   # sparkles alive for ten wisps (DECISIONS 2026-11-09)

const COLOUR_STEP := 1.0 / 255.0   # vertex colours are stored 8 bits a channel

var bad := 0

func run(main: Node) -> void:
	for id in Data.KIN:
		_species(String(id), {})
		_species(String(id), {"shimmer": true})
	_room()
	print("BOKIWISP %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("BOKIWISP FAIL ", what)
		bad += 1

func _species(id: String, rec: Dictionary) -> void:
	var tag := id + (" shiny" if rec.get("shimmer", false) else "")
	var feats := BokiWispLook.features(id)
	ok(BokiWispLook.EARS.has(feats[0]) and BokiWispLook.TAILS.has(feats[1]), "%s features known %s" % [tag, feats])
	var w := BokiWispLook.build(id, rec)
	var body := w.get_node_or_null("Body") as MeshInstance3D
	var trail := w.get_node_or_null("Trail") as CPUParticles3D
	ok(body != null and trail != null, tag + " has a body and a trail")
	if body == null or trail == null:
		w.free()
		return
	ok(body.mesh.get_surface_count() == 1, tag + " is one mesh")
	ok(body.material_override == BokiWispLook.material(), tag + " uses the shared material")
	var cols: PackedColorArray = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var own := Shiny.col(id, rec, "color")
	ok(Array(cols).any(func(c: Color): return _same(c, own)), tag + " wears its body colour")
	var rim: Color = body.get_instance_shader_parameter("rim_col")
	ok(rim.is_equal_approx(Shiny.col(id, rec, "glow")), tag + " rims in its glow colour")
	BokiWispLook.pose(w, 0.5 / BokiWispLook.HOP_HZ - float(w.get_meta("phase")) / BokiWispLook.HOP_HZ)
	ok(body.position.y > BokiWispLook.HOP_HEIGHT * 0.9, tag + " hops up")
	ok(trail.position == body.position, tag + " trail follows the hop")
	BokiWispLook.pose(w, -float(w.get_meta("phase")) / BokiWispLook.HOP_HZ)
	ok(body.scale.y < 1.0, tag + " squashes as it lands")
	w.free()

## Equal to within a step of the 8-bit vertex colour.
func _same(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) <= COLOUR_STEP

func _room() -> void:
	var sparkles := 0
	for id in Gallery.WISP_ROOM:
		if not Data.KIN.has(id):
			print("BOKIWISP note: %s is not in this build" % id)
			continue
		var w := BokiWispLook.build(String(id), {})
		sparkles += (w.get_node("Trail") as CPUParticles3D).amount
		w.free()
	ok(Gallery.WISP_ROOM.size() == 10, "the Model Room shows ten")
	var ten := BokiWispLook.TRAIL_AMOUNT * Gallery.WISP_ROOM.size()
	ok(ten < PARTICLE_BUDGET, "ten wisps make %d sparkles, under %d" % [ten, PARTICLE_BUDGET])
	print("BOKIWISP room: %d sparkles for the ones in this build, %d for ten" % [sparkles, ten])
