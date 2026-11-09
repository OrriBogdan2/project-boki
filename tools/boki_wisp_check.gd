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
	_clear_sweep()
	_clear_rules()
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
	ok(Array(cols).any(func(c: Color): return _same(c, BokiWispLook.EYE_COL)), tag + " keeps its eye")
	var span := body.mesh.get_aabb().size - BokiWispLook.BASE[0][1] * 2.0
	ok(maxf(span.x, maxf(span.y, span.z)) > 0.02, tag + " sticks out past a round body (a critter, not a Hunter Wisp)")
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

## The match camera of each style (scripts/match/cam.gd): pitch deg, distance m, fov deg; the world looks north.
const CAMERAS := [[66.0, 23.0, 32.0], [57.0, 32.2, 28.0], [50.0, 23.0, 42.0]]
const SCREEN := Vector2(1920, 1080)
const HUNTER_R := 0.48          # m: a Hunter's hit circle (r 0.4 + Match.HIT_SLACK)
const AIM_LENS := [1.5, 4.0, 12.0]
const SWEEP_STEP := 3           # deg between aims in the 360 sweep
const SWING_STEPS := 8          # wisp positions along one swing
const DIMMED := BokiWispClear.MIN_ALPHA + 0.001   # an alpha that counts as dimmed right down
const AIM_PRIORITY := 2         # AimDraw's material: telegraphs draw after anything below this
const SHOULDER_Y := 1.45        # m over the feet (the wisp prototype's)

func _view(cam: Array, focus: Vector3) -> BokiWispClear.View:
	var back := Vector3(0, sin(deg_to_rad(cam[0])), cos(deg_to_rad(cam[0]))) * float(cam[1])
	var xf := Transform3D(Basis.looking_at(-back, Vector3.UP), focus + back)
	return BokiWispClear.View.new(xf, cam[2], SCREEN)

## A 360 degree sweep of the aim, for each camera style and Hunter spots over the screen: along the whole swing
## of its arc the wisp (and its trail) never touches the aim line, and never touches the cursor, your hit circle
## or your plate. The worst gaps print.
func _clear_sweep() -> void:
	var worst := {"line": INF, "cursor": INF, "hit": INF, "plate": INF}
	var faded := 0              # wisp spots over a plate, and how many of them were dimmed
	var over_plate := 0
	var w := BokiWispLook.build(String(Data.KIN.keys()[0]), {})
	for cam in CAMERAS:
		for spot in [Vector3.ZERO, Vector3(10, 0, 6), Vector3(-10, 0, -6)]:
			var view := _view(cam, Vector3.ZERO)
			var feet: Vector3 = spot
			w.set_meta("side", 1.0)
			for deg in range(0, 360, SWEEP_STEP):
				var aim := Vector2.RIGHT.rotated(deg_to_rad(deg))
				for len in AIM_LENS:
					var line := BokiWispClear.aim_line(view, feet, aim, len)
					var rects := {
						"cursor": BokiWispClear.cursor_rect(line[1]),
						"hit": BokiWispClear.ground_rect(view, feet, HUNTER_R),
						"plate": BokiWispClear.plate_rect(view, feet),
					}
					for i in SWING_STEPS:
						var t := (float(i) / SWING_STEPS - float(w.get_meta("phase"))) / BokiWispClear.SWING_HZ
						var at := BokiWispClear.place(view, feet, SHOULDER_Y, aim, len, w, t)
						worst["line"] = minf(worst["line"], BokiWispClear.line_gap(view, at, line))
						for key in rects:
							worst[key] = minf(worst[key], BokiWispClear.rect_gap(view, at, rects[key]))
						if BokiWispClear.rect_gap(view, at, rects["plate"]) < 0.0:
							over_plate += 1
							faded += 1 if BokiWispClear.alpha(view, at, line, [rects["plate"]]) <= DIMMED else 0
	w.free()
	print("BOKIWISP clear worst gaps (px, below 0 = overlap): ", worst)
	print("BOKIWISP clear over a plate %d times, dimmed %d" % [over_plate, faded])
	ok(worst["line"] >= 0.0, "the wisp never touches the aim line over a 360 sweep (worst %.1f px)" % worst["line"])
	ok(worst["cursor"] >= 0.0, "the wisp never touches the cursor (worst %.1f px)" % worst["cursor"])
	ok(worst["hit"] >= 0.0, "the wisp never touches your hit circle (worst %.1f px)" % worst["hit"])
	ok(faded == over_plate, "the wisp is dimmed whenever it is over a plate (%d of %d)" % [faded, over_plate])

## Fade, trail and draw order, and the crowd's sparkles.
func _clear_rules() -> void:
	var view := _view(CAMERAS[0], Vector3.ZERO)
	var feet := Vector3.ZERO
	var line := BokiWispClear.aim_line(view, feet, Vector2.RIGHT, 8.0)
	var no_rects: Array[Rect2] = []
	var covering := Vector3(4, 0.4, 0)               # on the line (which lies on the ground)
	ok(BokiWispClear.alpha(view, covering, line, no_rects) <= DIMMED, "over the aim line it is dimmed")
	var clear := Vector3(4, 0.4, -6)
	ok(is_equal_approx(BokiWispClear.alpha(view, clear, line, no_rects), 1.0), "in the clear it is full")
	var plates: Array[Rect2] = [BokiWispClear.plate_rect(view, Vector3(0, 0, -6))]
	ok(BokiWispClear.alpha(view, Vector3(0, 2.2, -6), line, plates) <= DIMMED, "over a teammate's plate it is dimmed")
	var w := BokiWispLook.build(String(Data.KIN.keys()[0]), {})
	var trail := w.get_node("Trail") as CPUParticles3D
	BokiWispClear.apply(w, 0.5, true, true)
	ok(trail.lifetime < BokiWispLook.TRAIL_LIFE and trail.emitting, "firing shortens the trail")
	var fade: float = (w.get_node("Body") as GeometryInstance3D).get_instance_shader_parameter("fade")
	ok(is_equal_approx(fade, 0.5), "fade reaches the body")
	BokiWispClear.apply(w, 1.0, false, false)
	ok(is_equal_approx(trail.lifetime, BokiWispLook.TRAIL_LIFE) and not trail.emitting, "trail whole, off when told")
	w.free()
	var priority := BokiWispLook.material().render_priority
	ok(priority < AIM_PRIORITY and priority < 0, "it draws before the telegraphs")
	_crowd()

## 30 Hunters in one fight: only the nearest few shed sparkles, so the live count stays under the budget.
func _crowd() -> void:
	var dists := PackedFloat32Array()
	for i in 30:
		dists.append(2.0 + 0.3 * i)
	var on := BokiWispClear.sparkly(dists)
	var count := 0
	for b in on:
		count += b
	ok(count == BokiWispClear.TRAIL_WISPS, "30 Hunters: %d wisps shed sparkles" % count)
	ok(on[0] == 1 and on[29] == 0, "the nearest sparkles, the furthest does not")
	var sparkles := count * BokiWispLook.TRAIL_AMOUNT
	ok(sparkles < PARTICLE_BUDGET, "30 Hunters make %d sparkles, under %d" % [sparkles, PARTICLE_BUDGET])
	var far := BokiWispClear.sparkly(PackedFloat32Array([BokiWispClear.TRAIL_RANGE + 1.0]))
	ok(far[0] == 0, "out of range sheds none")
