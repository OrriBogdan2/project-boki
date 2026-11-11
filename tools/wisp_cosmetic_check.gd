extends RefCounted
## --wisp-cosmetic-check: the Boki wisp's cosmetic line (BokiWispCosmetics, content/rules/boki_wisp_cosmetics.json).
## The data has the starter set (3 trails, 3 sparkle colours, 2 orbit styles beside each default). Every
## option applies: the trail sets the sparkles' life, speed, gravity and size, the sparkle option their colour
## (the Boki's own glow lifted for "own"), the orbit option the path. None of them ever changes the critter
## outline (the body mesh is vertex for vertex the same, one surface, the shared material) or the sparkle
## count, so the particle budget holds. Picks save (round trip through JSON), an unknown id falls back,
## another player's wisp wears the defaults, and a v11 save upgrades with its picks. Prints PASS/FAIL.

const STARTERS := {"trail": 3, "sparkle": 3, "orbit": 2}      # options beyond the default
const ORBIT_FRAMES := 8       # angles sampled round one lap

var bad := 0

func run(main: Node) -> void:
	var saved_look = Save.d.get("look")
	_data()
	for id in Data.KIN:
		_species(String(id))
	_saving()
	_orbits()
	if saved_look == null:
		Save.d.erase("look")
	else:
		Save.d["look"] = saved_look
	print("WISPCOSMETIC %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("WISPCOSMETIC FAIL ", what)
		bad += 1

func _data() -> void:
	for line in BokiWispCosmetics.LINES:
		var opts := BokiWispCosmetics.options(line)
		ok(opts.has(BokiWispCosmetics.default_id(line)), line + " has its default")
		ok(opts.size() - 1 >= STARTERS[line], "%s has %d starter options" % [line, STARTERS[line]])
		var names := {}
		for id in opts:
			names[opts[id]["name"]] = true
			ok(String(opts[id]["desc"]) != "", "%s %s has a description" % [line, id])
		ok(names.size() == opts.size(), line + " names are all different")

## Every trail and sparkle option on one species: applied, and the body untouched.
func _species(id: String) -> void:
	var plain := BokiWispLook.build(id)
	var base_verts := _verts(plain)
	var glow := Shiny.col(id, {}, "glow")
	for line in ["trail", "sparkle"]:
		for opt in BokiWispCosmetics.options(line):
			var worn := BokiWispCosmetics.worn(null)
			worn[line] = BokiWispCosmetics.options(line)[opt]
			var w := BokiWispLook.build(id, {}, worn)
			var tag := "%s %s %s" % [id, line, opt]
			_outline(w, base_verts, tag)
			var p := w.get_node("Trail") as CPUParticles3D
			ok(p.amount == BokiWispLook.TRAIL_AMOUNT, tag + " keeps the sparkle count")
			if line == "trail":
				var t: Dictionary = worn["trail"]
				var g: Array = t["gravity"]
				var life_ok := is_equal_approx(p.lifetime, t["life"])
				var motion_ok := life_ok and is_equal_approx(p.initial_velocity_max, t["speed"])
				ok(motion_ok, tag + " sets life and speed")
				var size_ok := is_equal_approx(p.scale_amount_max, t["size"][1])
				ok(p.gravity.is_equal_approx(Vector3(g[0], g[1], g[2])) and size_ok, tag + " sets gravity and size")
			else:
				var spec := String(worn["sparkle"]["color"])
				var want := glow.lightened(BokiWispLook.TRAIL_LIGHTEN) if spec == "own" else Color(spec)
				ok(p.color.is_equal_approx(want), tag + " tints the sparkles")
			w.free()
	plain.free()

func _verts(w: Node3D) -> PackedVector3Array:
	return ((w.get_node("Body") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func _outline(w: Node3D, base_verts: PackedVector3Array, tag: String) -> void:
	var body := w.get_node("Body") as MeshInstance3D
	var shared: bool = body.material_override == BokiWispLook.material()
	ok(body.mesh.get_surface_count() == 1 and shared, tag + " body: one surface, shared material")
	ok(_verts(w) == base_verts, tag + " leaves the critter outline as it was")

func _saving() -> void:
	Save.d.erase("look")
	ok(BokiWispCosmetics.equipped("trail") == "stardust", "no saved look wears the default")
	var different := {"trail": "comet_tail", "sparkle": "seafoam", "orbit": "weave"}
	for line in different:
		ok(BokiWispCosmetics.equip(line, different[line]), "equip " + line)
	var refused := not BokiWispCosmetics.equip("trail", "no_such_trail")
	ok(refused and BokiWispCosmetics.equipped("trail") == "comet_tail", "an unknown id is refused")
	var back = JSON.parse_string(JSON.stringify(Save.d["look"]))
	var kept := true
	for line in different:
		kept = kept and String(back["boki_wisp"][line]) == different[line]
	ok(kept, "the picks survive a save and load")
	Save.d["look"]["boki_wisp"]["orbit"] = "gone"
	ok(BokiWispCosmetics.equipped("orbit") == "shoulder_loop", "a pick that no longer exists falls back")
	var stranger: Dictionary = BokiWispCosmetics.worn(null)
	ok(stranger["trail"] == BokiWispCosmetics.options("trail")["stardust"], "a stranger's wisp wears the defaults")
	var old := {"v": 11, "look": {"glider": "classic"}}
	var up := Save.migrate(old) and int(old["v"]) == Save.VERSION
	ok(up and old["look"]["boki_wisp"]["trail"] == "stardust", "a v11 save upgrades with default picks")
	ok(old["look"]["glider"] == "classic", "...and keeps the rest of its look")
	var fresh := {"v": 11}
	ok(Save.migrate(fresh) and not fresh.has("look"), "a save with no look stays without one")

## Every orbit is a lap round the hunter at its radius, above shoulder height by its rise and wave.
func _orbits() -> void:
	var centre := Vector3(3, 0, -2)
	for id in BokiWispCosmetics.options("orbit"):
		var o: Dictionary = BokiWispCosmetics.options("orbit")[id]
		var lo := INF
		var hi := -INF
		var flat_ok := true
		for i in ORBIT_FRAMES * 3:
			var at := KinWisp.orbit_spot(o, TAU * i / ORBIT_FRAMES / 3.0, centre, 1.45)
			var out := Vector2(at.x - centre.x, at.z - centre.z).length()
			flat_ok = flat_ok and absf(out - float(o["radius"])) < 0.001
			lo = minf(lo, at.y)
			hi = maxf(hi, at.y)
		ok(flat_ok, id + " keeps its radius")
		var mid: float = 1.45 + float(o["rise"])
		var wave: float = o["wave"]
		ok(lo >= mid - wave - 0.001 and hi <= mid + wave + 0.001, id + " stays in its rise and wave")
		ok(hi - lo > 0.01 or wave == 0.0, id + " waves when it should")
		ok(float(o["hz"]) > 0.0 and float(o["radius"]) > 0.3, id + " is a real lap")
