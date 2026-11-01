extends Node3D
## The six archetypes (HeroKit.ARCHES) in galleries, for screenshots:
##   --arch-lineup   all six side by side, each on a different race, from a three-quarter view
##                   (--arch-close: a closer camera on them; --arch-top: the match camera's angle)
##   --arch-matrix   6 archetypes x 6 races (alternating gender), plus a gender / build pair per
##                   archetype in the last two columns
##   --arch-heads    every race's head under every archetype's headgear (fit and ears), close up
## Optional: --arch-yaw=<radians> turns everyone.

const WEAPONS := {"thief": "twin_blades", "archer": "sniper", "mage": "longsword", "gunslinger": "rifle", "juggernaut": "greatsword", "bulwark": "minigun"}
var anims: Array = []

func _arg(prefix: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix): return a.substr(prefix.length())
	return def

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0})
	add_child(env)
	var showcase := Array(OS.get_cmdline_user_args()).any(func(a): return String(a).begins_with("--showcase"))
	# the showcase is lit like a match (the sun high and in front of the camera's side), the rest backlit
	Look.lights(self, Color("fff1dc"), 1.0, Vector3(-50, 145, 0) if showcase else Vector3(-42, -32, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("6f9a4a"), false)
	add_child(ground)
	var args := OS.get_cmdline_user_args()
	if "--showcase" in args or "--showcase-top" in args or "--showcase-poses" in args:
		ground.material_override = Models.toon(Color("4f7a3e"), false)
		_showcase()
	elif "--arch-matrix" in args:
		_matrix()
	elif "--arch-heads" in args:
		_heads()
	else:
		_lineup()

func _hunter(arch: String, lk: Dictionary, team: int, outfit := "") -> Node3D:
	var cls := String(HeroKit.ARCHES[arch]["cls"])
	var h := Models.hunter(cls, Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()], WEAPONS[arch], outfit, lk, arch)
	add_child(h)
	anims.append([HunterAnim.new(h), h])
	return h

func _label(text: String, at: Vector3, size := 34) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size; l.pixel_size = 0.006; l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	add_child(l)

func _lineup() -> void:
	var yaw := float(_arg("--arch-yaw=", str(PI * 0.88)))
	var i := 0
	for arch in HeroKit.ARCH_ORDER:
		var race: int = [3, 0, 5, 1, 2, 4][i]
		var lk: Dictionary = {"race": race, "hair": [0, 1, 2, 3, 0, 1][i], "hair_v": 2, "hair_col": [0, 5, 3, 6, 10, 7][i], "skin": int(Models.RACES[race]["skin"]) if race > 0 else 2,
			"gender": i % 2, "face": [4, 0, 6, 8, 7, 3][i], "body": 1, "outfit": [1, 2, 3, 4, 7, 6][i]}
		var h := _hunter(arch, lk, i % 2)
		h.position = Vector3((i - 2.5) * 1.75, 0, 0)
		h.rotation.y = yaw
		_label("%s · %s" % [HeroKit.ARCHES[arch]["name"], Models.LOOK_RACES[race]], h.position + Vector3(0, 0.05, 1.0), 22)
		i += 1
	var cam := Camera3D.new()
	add_child(cam)
	if "--arch-top" in OS.get_cmdline_user_args():
		cam.position = Vector3(0, 13.0, 7.0); cam.rotation = Vector3(-1.08, 0, 0); cam.fov = 40
	elif "--arch-close" in OS.get_cmdline_user_args():
		cam.position = Vector3(0, 1.7, 6.6); cam.rotation = Vector3(-0.12, 0, 0); cam.fov = 52
	else:
		cam.position = Vector3(0, 4.2, 8.6); cam.rotation = Vector3(-0.42, 0, 0); cam.fov = 48
	cam.make_current()

func _matrix() -> void:
	var r := 0
	for arch in HeroKit.ARCH_ORDER:
		for race in Models.RACES.size():
			var lk := {"race": race, "hair": (race + r) % Models.hair_styles(race).size(), "hair_v": 2, "hair_col": (race * 3 + r) % Models.LOOK_HAIR.size(),
				"skin": int(Models.RACES[race]["skin"]) if race > 0 else (r % 5), "gender": (race + r) % 2, "face": (race + r) % Models.LOOK_FACES.size(), "body": 1, "outfit": (r + race) % Models.LOOK_OUTFITS.size()}
			var h := _hunter(arch, lk, r)
			h.position = Vector3((race - 3.5) * 1.45, 0, (r - 2.5) * 2.3)
			h.rotation.y = PI * 0.9
		# a gender / build pair: a slim woman and a sturdy man
		for k in 2:
			var lk := {"race": 0, "hair": [1, 0][k], "hair_v": 2, "hair_col": [5, 1][k], "skin": [1, 4][k], "gender": k, "face": 0, "body": [0, 2][k], "outfit": r}
			var h := _hunter(arch, lk, r)
			h.position = Vector3((6 + k - 3.5) * 1.45 + 0.4, 0, (r - 2.5) * 2.3)
			h.rotation.y = PI * 0.9
		_label(String(HeroKit.ARCHES[arch]["name"]), Vector3(-6.4, 0.1, (r - 2.5) * 2.3 + 0.3), 30)
		r += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.6, 15.5, 11.0); cam.rotation = Vector3(-0.95, 0, 0); cam.fov = 50
	cam.make_current()

func _heads() -> void:
	var r := 0
	for arch in HeroKit.ARCH_ORDER:
		for race in Models.RACES.size():
			var lk := {"race": race, "hair": [1, 0, 0, 0, 0, 0][race], "hair_v": 2, "hair_col": 5, "skin": int(Models.RACES[race]["skin"]) if race > 0 else 1,
				"gender": (race + r) % 2, "face": 0, "body": 1, "outfit": 3}
			var h := _hunter(arch, lk, 0)
			# heads only: everything below the neck is hidden so the rows sit close together
			var torso: Node3D = h.get_node("Rig/Torso")
			for ch in torso.get_children():
				if ch.name != "HeadPivot" and ch is Node3D: (ch as Node3D).visible = false
			(h.get_node("Rig/Legs") as Node3D).visible = false
			(h.get_node("TeamRing") as Node3D).visible = false
			h.scale = Vector3.ONE * 1.5
			h.rotation.y = PI + 0.55
			var hp: Vector3 = (h.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
			h.position += Vector3(race * 1.15, -r * 1.3, 0) - Vector3(hp.x, hp.y, 0)
			if race == 0:
				_label(String(HeroKit.ARCHES[arch]["name"]), Vector3(-1.0, -r * 1.3 + 0.2, 1.0), 26)
		r += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.6
	cam.position = Vector3(2.6, -3.0, 20.0)
	add_child(cam)
	cam.make_current()

## The hero showcase (Thief and Juggernaut), for the hero-art screenshots:
##   --showcase        three of each across races and genders, close up from a three-quarter view
##   --showcase-top    the same hunters from the match camera (Supervive preset: 65°, 25 m, fov 35);
##                     --showcase-zoom halves the field of view to inspect what reads at that angle
##   --showcase-poses  each archetype frozen in idle, run, attack, RMB cast and ultimate
## Optional: --showcase-arch=thief|juggernaut (only that one), --showcase-outfit=<index>.
var frozen := false
func _showcase() -> void:
	var args := OS.get_cmdline_user_args()
	var only := _arg("--showcase-arch=", "")
	# --showcase-arch=archer or a list (mage,bulwark); --showcase-six: all six, one look each
	var six := "--showcase-six" in args
	var arches: Array = (["thief", "juggernaut"] if only == "" else Array(only.split(","))) if not six else HeroKit.ARCH_ORDER.duplicate()
	var looks := {
		"thief": [{"race": 0, "gender": 0, "hair": 1, "hair_col": 0, "skin": 2, "face": 4, "outfit": 1},
			{"race": 1, "gender": 1, "hair": 0, "hair_col": 5, "skin": 2, "face": 7, "outfit": 3},
			{"race": 3, "gender": 0, "hair": 0, "hair_col": 3, "skin": 11, "face": 0, "outfit": 2}],
		"juggernaut": [{"race": 0, "gender": 1, "hair": 0, "hair_col": 1, "skin": 4, "face": 7, "outfit": 7, "detail": 5},
			{"race": 2, "gender": 1, "hair": 0, "hair_col": 10, "skin": 19, "face": 4, "outfit": 5},
			{"race": 4, "gender": 0, "hair": 1, "hair_col": 6, "skin": 12, "face": 0, "outfit": 8}],
		"archer": [{"race": 0, "gender": 0, "hair": 2, "hair_col": 5, "skin": 1, "face": 7, "outfit": 3},
			{"race": 5, "gender": 1, "hair": 1, "hair_col": 4, "skin": 2, "face": 0, "outfit": 2},
			{"race": 1, "gender": 0, "hair": 3, "hair_col": 13, "skin": 2, "face": 4, "outfit": 4}],
		"mage": [{"race": 0, "gender": 1, "hair": 4, "hair_col": 4, "skin": 3, "face": 1, "outfit": 1, "detail": 5},
			{"race": 3, "gender": 0, "hair": 1, "hair_col": 7, "skin": 11, "face": 6, "outfit": 0},
			{"race": 5, "gender": 1, "hair": 2, "hair_col": 11, "skin": 2, "face": 8, "outfit": 2}],
		"gunslinger": [{"race": 0, "gender": 1, "hair": 0, "hair_col": 1, "skin": 2, "face": 8, "outfit": 4, "detail": 4},
			{"race": 1, "gender": 0, "hair": 6, "hair_col": 5, "skin": 2, "face": 5, "outfit": 5},
			{"race": 4, "gender": 1, "hair": 2, "hair_col": 3, "skin": 12, "face": 7, "outfit": 7}],
		"bulwark": [{"race": 0, "gender": 0, "hair": 1, "hair_col": 3, "skin": 4, "face": 7, "outfit": 6},
			{"race": 2, "gender": 1, "hair": 1, "hair_col": 10, "skin": 19, "face": 1, "outfit": 0},
			{"race": 5, "gender": 0, "hair": 0, "hair_col": 8, "skin": 2, "face": 0, "outfit": 2}],
	}
	var oo := int(_arg("--showcase-outfit=", "-1"))
	var cam := Camera3D.new()
	add_child(cam)
	if "--showcase-poses" in args:
		var poses := ["idle", "run", "attack", "cast", "ult"]
		var r := 0
		for arch in arches:
			for i in poses.size():
				var lk: Dictionary = (looks[arch][0] as Dictionary).duplicate()
				lk["hair_v"] = 2; lk["body"] = 1
				if oo >= 0: lk["outfit"] = oo
				var h := _hunter(arch, lk, 0)
				h.position = Vector3((i - 2.0) * 1.9, 0, -r * 3.2)
				h.rotation.y = PI * 0.82
				_pose(anims[anims.size() - 1][0], h, poses[i], arch)
				_label(poses[i], h.position + Vector3(0, 0.03, 1.0), 22)
			r += 1
		frozen = true
		cam.position = Vector3(0, 4.6 + 1.2 * (arches.size() - 1), 6.2); cam.rotation = Vector3(-0.5, 0, 0); cam.fov = 50
		cam.make_current()
		return
	var i := 0
	for arch in arches:
		for lk0 in ((looks[arch] as Array).slice(0, 1) if six else looks[arch]):
			var lk: Dictionary = (lk0 as Dictionary).duplicate()
			lk["hair_v"] = 2; lk["body"] = 1
			if oo >= 0: lk["outfit"] = oo
			var h := _hunter(arch, lk, i % 2)
			var n := arches.size() * (1 if six else 3)
			h.position = Vector3((i - (n - 1) * 0.5) * 1.55, 0, 0)
			h.rotation.y = PI * 0.86
			i += 1
	if "--showcase-top" in args:
		# the Supervive camera preset (Cam.STYLES "supervive"), looking at the middle of the row
		var p := deg_to_rad(65.0)
		cam.position = Vector3(0, sin(p) * 25.0, cos(p) * 25.0); cam.rotation = Vector3(-p, 0, 0)
		cam.fov = 17.5 if "--showcase-zoom" in args else 35.0
	else:
		var nn := arches.size() * (1 if six else 3)
		cam.position = Vector3(0, 1.55, 3.8 + 0.6 * nn); cam.rotation = Vector3(-0.1, 0, 0); cam.fov = 40 if nn <= 3 else 46
	cam.make_current()

## Runs the animation into a pose and holds it there (a few hundred small steps).
func _pose(an: HunterAnim, h: Node3D, pose: String, arch: String) -> void:
	var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var steps := 90
	for k in steps:
		s["fired"] = 99.0
		match pose:
			"run":
				s["vel"] = fwd * (5.2 if arch == "thief" else 4.7)
			"attack":
				if k == steps - 9: s["swing_n"] = 1; s["combo"] = 0
			"cast":
				if k >= steps - 12: s["cast"] = (k - (steps - 12)) / 60.0; s["cast_slot"] = "utility"
			"ult":
				if k >= steps - 14: s["cast"] = (k - (steps - 14)) / 60.0; s["cast_slot"] = "ult"
		an.update(1.0 / 60.0, s)

func _process(delta: float) -> void:
	if frozen:
		return
	for a in anims:
		(a[0] as HunterAnim).update(delta, {"fired": 99.0, "face": (a[1] as Node3D).rotation.y})
