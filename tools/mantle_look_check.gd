extends RefCounted
## --mantle-look-check (OWNER_REVIEW item 45, docs/decisions/0011-mantle-look.md): in a match a
## Bearer is the class's original Warden nudged by the player. For every Hunter, every slider at its
## ends stays inside the Warden's clamp and every colour pick inside its tint range; gender, folk and
## face come from the Warden; the hitbox (Hunter.r and the ring that shows it) never changes; the
## silhouette at the match camera still reads as its own Hunter at both slider extremes; at home the
## player is their own person. A v7 save migrates (to the Unmasked) and its Bearer is exactly the
## Warden; the slider creator panel works on its own. With
## --shots-dir=<dir>: one Hunter at 5 slider settings, one player's look across 4 Hunters, and the
## creator step. Never touches the real save.

const EPS := 0.0005
const GRID := 48              # cells across the silhouette window
const FILL_H := 40.0          # cells: every silhouette is scaled to this height (about its pixels at the match zoom)
const MIN_OWN_IOU := 0.78     # a slider end keeps at least this much of the neutral Warden's silhouette
const CAM_PITCH := 66.0       # degrees: the default match camera (CamRig STYLES "supervive")
const SHOT_HUNTERS := ["thief", "juggernaut", "mage", "tender"]

var bad := 0
var n := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MANTLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	var tree := main.get_tree()
	if shots != "" and main.fade != null:
		main.fade.reveal(0.05)      # (the boot splash would cover the screenshots)
	_wardens()
	_clamps()
	_tints()
	_hitbox()
	_own_person()
	await _silhouettes(tree)
	_save_round_trip()
	await _creator_step(tree)
	if shots != "":
		await _shot_settings(tree)
		await _shot_across(tree)
	print("MANTLE %d checks, %d failed" % [n, bad])
	print("MANTLE_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	tree.quit()

## Looks with every slider at v (and the colour picks given).
static func flat(v: float, picks := {}) -> Dictionary:
	var lk := PlayerLook.neutral()
	for k in lk["sliders"]:
		lk["sliders"][k] = v
	lk.merge(picks, true)
	return lk

# ---------------------------------------------------------------- 1. every Hunter has a Warden
func _wardens() -> void:
	var wardens: Dictionary = MantleLook.rules()["wardens"]
	var missing := Arch.ids().filter(func(a): return not wardens.has(a))
	ok(missing.is_empty(), "every Hunter has its Warden in content/rules/mantle_look.json (missing %s)" % str(missing))
	var bad_names: Array = []
	for a in wardens:
		var w: Dictionary = wardens[a]
		var race := Models.RACES.map(func(r): return String(r["id"])).find(String(w["race"]))
		var named := race >= 0 and Models.LOOK_FACES.has(w["face"]) and Models.LOOK_DETAILS.has(w["detail"])
		if not named or not Models.hair_styles(race).has(w["hair"]) or not w["gender"] in ["female", "male", "robot"]:
			bad_names.append(a)
	ok(bad_names.is_empty(), "every Warden's folk, face, hair, markings and gender are real names (%s)"
			% str(bad_names))
	# one home for the base character's gender once the archetypes carry it (ext/class-titles)
	var disagree := Arch.ids().filter(func(a):
		return Arch.def(a).has("gender") and String(Arch.def(a)["gender"]) != String(wardens.get(a, {}).get("gender")))
	ok(disagree.is_empty(), "the Warden's gender is the base character's (%s)" % str(disagree))

# ---------------------------------------------------------------- 2. sliders stay in the clamp
func _clamps() -> void:
	var outside: Array = []
	var not_full: Array = []
	var not_warden: Array = []
	for a in Arch.ids():
		var w := MantleLook.warden(a)
		var neutral := MantleLook.apply(w, PlayerLook.neutral())
		for v in [0.0, 1.0]:
			var p := MantleLook.apply(w, flat(v, {"race": 3, "gender": 0 if w["gender"] != "female" else 1, "face": 5}))
			for k in w["clamp"]:
				var reach := float(w["clamp"][k])
				var f := float(p[k])
				if f < 1.0 - reach - EPS or f > 1.0 + reach + EPS:
					outside.append("%s %s=%.3f" % [a, k, f])
				if absf(absf(f - 1.0) - reach) > EPS or absf(float(neutral[k]) - 1.0) > EPS:
					not_full.append("%s %s" % [a, k])
			var want_gender := 0 if w["gender"] == "female" else 1
			if p["gender"] != want_gender or p["race"] != w["race"] or p["face"] != w["face"] or p["hair"] != w["hair"]:
				not_warden.append(a)
	ok(outside.is_empty(), "every slider at 0 and 1, for every Hunter, stays inside its clamp (%s)" % str(outside))
	ok(not_full.is_empty(), "the ends reach exactly the clamp and the middle is the Warden's own size (%s)"
			% str(not_full))
	ok(not_warden.is_empty(), "gender, folk, face and hair come from the Warden whatever the player picked (%s)"
			% str(not_warden))
	var body: Dictionary = MantleLook.rules()["sliders"]
	var face_max := 0.0
	var body_min := 1.0
	for k in body:
		if String(body[k]["group"]) == "body" and k != "head" and k != "limbs":
			body_min = minf(body_min, float(body[k]["clamp"]))
		if k in ["face_w", "jaw"]:
			face_max = maxf(face_max, float(body[k]["clamp"]))
	ok(body_min >= 0.08 and face_max < body_min, "body sizes move ±%d%% or more, face shape less (±%d%%)"
			% [roundi(body_min * 100.0), roundi(face_max * 100.0)])

# ---------------------------------------------------------------- 3. colours tint, never replace
func _tints() -> void:
	var over: Array = []
	var keys := {"skin": ["skin", "skin_col", Models.LOOK_SKIN], "hair": ["hair_col", "hair_col", Models.LOOK_HAIR],
		"eyes": ["eyes", "eye_col", PlayerLook.EYES], "outfit": ["outfit", "outfit_col", Models.OUTFIT_COLS]}
	for a in Arch.ids():
		var w := MantleLook.warden(a)
		for t in keys:
			var spec: Dictionary = w["tint"][t]
			var base: Color = w[{"skin": "skin", "hair": "hair_col", "eyes": "eyes", "outfit": "outfit"}[t]]
			for i in (keys[t][2] as Array).size():
				var c: Color = MantleLook.apply(w, flat(0.5, {keys[t][0]: i}))[keys[t][1]]
				var dh := absf(wrapf(c.h - base.h, -0.5, 0.5))
				if dh > float(spec["hue"]) + 0.002 or absf(c.s - base.s) > float(spec["sat"]) + 0.002 \
						or absf(c.v - base.v) > float(spec["val"]) + 0.002:
					over.append("%s %s #%d" % [a, t, i])
	ok(over.is_empty(), "every skin, hair, eye and outfit pick only tints the Warden's palette (%s)" % str(over))
	var red := MantleLook.tint(Color("c43a3a"), Color("3a6aff"), MantleLook.rules()["tint"]["outfit"])
	ok(absf(wrapf(red.h - Color("c43a3a").h, -0.5, 0.5)) <= 0.02 + 0.002 and red.r > red.b * 2.0,
			"a signature red stays red under a blue pick (%s)" % red.to_html(false))
	var robot := MantleLook.apply(MantleLook.warden("dredge"), flat(0.5, {"skin": 15}))
	ok(robot["skin_col"].is_equal_approx(MantleLook.warden("dredge")["skin"]),
			"a Warden can lock a colour (the machine's plating takes no skin tint)")

# ---------------------------------------------------------------- 4. the hitbox never changes
func _hitbox() -> void:
	var moved: Array = []
	for a in Arch.ids():
		var cls := Arch.weight(a)
		var cdat: Dictionary = Data.CLASSES[cls]
		var ring_w := -1.0
		for lk in [PlayerLook.neutral(), flat(0.0), flat(1.0)]:
			var h := Hunter.new()
			h.cls = cls
			h.cdat = cdat
			h.arch = a
			h.r = Arch.hit_r(a, cdat)
			var r0 := h.r
			h.set_model(Models.hunter(cls, Data.TEAM_COLORS[0], Arch.signature(a), "", lk, a))
			var ring := h.model.get_node("TeamRing") as Node3D
			var w := h.model.scale.x * ring.scale.x
			if ring_w < 0.0: ring_w = w
			if absf(h.r - r0) > EPS or absf(w - ring_w) > EPS:
				moved.append(a)
			h.free()
	ok(moved.is_empty(), "the hit radius and the ring that shows it are the class's at every slider end (%s)"
			% str(moved))

# ---------------------------------------------------------------- 5. at home: your own person
func _own_person() -> void:
	var lk := flat(1.0, {"race": 1, "gender": 0, "skin": 9, "hair_col": 6, "outfit": 1})
	var p := MantleLook.params("juggernaut", MantleLook.at_home(lk))
	ok(p["own"] and p["race"] == 1 and p["gender"] == 0 and p["skin_col"] == Models.LOOK_SKIN[9]
			and p["outfit_col"] == Models.OUTFIT_COLS[1], "at home you're your own folk, body type and colours")
	var reach := float(MantleLook.rules()["sliders"]["build"]["clamp"]) * float(MantleLook.rules()["own_k"])
	ok(absf(float(p["build"]) - (1.0 + reach)) < EPS, "and your sliders count for more there (build %.2f)" % p["build"])
	var home := Models.hunter("heavy", Data.TEAM_COLORS[0], Arch.signature("juggernaut"), "", MantleLook.at_home(lk),
		"juggernaut")
	var match_m := Models.hunter("heavy", Data.TEAM_COLORS[0], Arch.signature("juggernaut"), "", lk, "juggernaut")
	ok(String(home.get_meta("arch")) == "" and String(match_m.get_meta("arch")) == "juggernaut",
			"no Warden's gear at home; the Mantle's in a match")
	home.free()
	match_m.free()

# ---------------------------------------------------------------- 6. silhouettes at the match camera
func _silhouettes(tree: SceneTree) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var neutral := {}
	var ends := {}
	for a in Arch.ids():
		neutral[a] = await _mask(tree, holder, a, PlayerLook.neutral())
		ends[a] = [await _mask(tree, holder, a, flat(0.0)), await _mask(tree, holder, a, flat(1.0)),
			await _mask(tree, holder, a, _mixed())]
	var wrong: Array = []
	var worst := 1.0
	var worst_at := ""
	var least_own := 1.0
	for a in ends:
		for mk in ends[a]:
			var own := _iou(mk, neutral[a])
			least_own = minf(least_own, own)
			var best_other := 0.0
			var other_at := ""
			for b in neutral:
				if b == a: continue
				var o := _iou(mk, neutral[b])
				if o > best_other:
					best_other = o
					other_at = b
			if own <= best_other:
				wrong.append("%s looks like %s" % [a, other_at])
			if own - best_other < worst:
				worst = own - best_other
				worst_at = "%s (vs %s)" % [a, other_at]
	holder.queue_free()
	ok(wrong.is_empty(), "at both slider ends every Hunter's silhouette is still closest to its own (%s)" % str(wrong))
	ok(least_own >= MIN_OWN_IOU, "and keeps at least %.2f of its own shape (least %.2f)" % [MIN_OWN_IOU, least_own])
	print("MANTLE silhouette: the closest call is %s, %.2f IoU ahead of the next Hunter" % [worst_at, worst])

## Body at one end and face at the other: the oddest proportions the sliders allow.
static func _mixed() -> Dictionary:
	var lk := PlayerLook.neutral()
	for k in lk["sliders"]:
		var group := String(MantleLook.rules()["sliders"][k]["group"])
		lk["sliders"][k] = 1.0 if group == "body" and k != "limbs" else 0.0
	return lk

## The hunter's silhouette seen down the match camera, scaled to a fixed height (overall size is not
## what tells two Hunters apart; their shapes are): the cells it covers in a GRID x GRID window.
func _mask(tree: SceneTree, holder: Node3D, a: String, lk: Dictionary) -> PackedByteArray:
	var mdl := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", lk, a)
	var ring := mdl.get_node_or_null("TeamRing") as Node3D
	if ring: ring.visible = false
	mdl.set_meta("anim_seed", 45)       # the same rest pose every build (it's seeded per character)
	HunterAnim.rest_pose(mdl)
	holder.add_child(mdl)
	var sync := mdl.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.orbits.pivots.clear()   # (they turn and bob by frame time: a shape must not depend on that)
	await tree.process_frame
	var pitch := deg_to_rad(CAM_PITCH)
	var up := Vector3(0, cos(pitch), -sin(pitch))        # screen up, for a camera looking down from +z
	var tris := PackedVector2Array()
	var stack: Array = [mdl]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children(): stack.append(ch)
		var mi := nd as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.has_meta("halo") or mi.has_meta("glb_hidden"):
			continue      # (tiny FX quads riding an orbit: where they are depends on frame time, not on the shape)
		var xf := mi.global_transform
		for p in mi.mesh.get_faces():
			var w := xf * p
			tris.append(Vector2(w.x, -w.dot(up)))
	mdl.queue_free()
	var top := INF
	var bottom := -INF
	for p in tris:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var k := FILL_H / maxf(0.01, bottom - top)
	var mask := PackedByteArray()
	mask.resize(GRID * GRID)
	for i in range(0, tris.size(), 3):
		var pts: Array = []
		for j in 3:
			var q := tris[i + j]
			pts.append(Vector2(q.x * k + GRID * 0.5, (q.y - top) * k + 2.0))
		_fill(mask, pts)
	return mask

func _fill(mask: PackedByteArray, pts: Array) -> void:
	var lo: Vector2 = (pts[0] as Vector2).min(pts[1]).min(pts[2])
	var hi: Vector2 = (pts[0] as Vector2).max(pts[1]).max(pts[2])
	for y in range(maxi(0, floori(lo.y)), mini(GRID - 1, ceili(hi.y)) + 1):
		for x in range(maxi(0, floori(lo.x)), mini(GRID - 1, ceili(hi.x)) + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), pts[0], pts[1], pts[2]):
				mask[y * GRID + x] = 1

static func _iou(a: PackedByteArray, b: PackedByteArray) -> float:
	var both := 0
	var either := 0
	for i in a.size():
		if a[i] > 0 and b[i] > 0: both += 1
		if a[i] > 0 or b[i] > 0: either += 1
	return float(both) / maxf(1.0, float(either))

# ---------------------------------------------------------------- 7. save and load
## On main the saved look is the Unmasked (Unmasked.migrate at load); in a match a Bearer is built from
## Unmasked.mask_look() through MantleLook, so every slider is neutral there: exactly the Warden. The
## sliders themselves are model params (PlayerLook.clean keeps them exactly); saving them waits for
## the mask-look rules. The v8 -> v9 step stays an empty placeholder.
func _save_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	var lk := PlayerLook.clean(PlayerLook.random(rng))
	ok(PlayerLook.clean(lk) == lk, "a slider look cleans back to itself, slider for slider")
	var path := "user://mantle_look_check.json"
	var old := Save.fresh()
	old["v"] = 7
	old["look"] = {"race": 2, "body": 2, "gender": 0, "face": 4, "skin": 5, "hair": 1, "hair_v": 2, "hair_col": 9,
		"detail": 2, "outfit": 5, "glider": "classic"}
	_write(path, old)
	Save.load_from(path)
	ok(int(Save.d["v"]) == Save.VERSION and Save.MIGRATIONS[8] == "_migrate_8_to_9",
			"a v7 save loads and upgrades to v%d through the v8 -> v9 step" % Save.VERSION)
	var worn := MantleLook.params("archer", Unmasked.mask_look())
	var plain := MantleLook.apply(MantleLook.warden("archer"), PlayerLook.neutral())
	var same := true
	for k in MantleLook.warden("archer")["clamp"]:
		same = same and absf(float(worn[k]) - float(plain[k])) < EPS
	ok(Unmasked.is_look(Save.d.get("look", {})) and same,
			"its look becomes the Unmasked, and its Bearer is exactly the Warden (every slider neutral)")
	old.erase("look")
	_write(path, old)
	Save.load_from(path)
	ok(int(Save.d["v"]) == Save.VERSION and MantleLook.params("archer", {})["gender"] == 0,
			"a v7 save with no look loads too, and builds the plain Warden")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Save.d = Save.fresh()

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

# ---------------------------------------------------------------- 8. the slider creator
## The new-game flow and Change your look are main's Unmasked creator (--unmasked-check,
## --class-unlock-check); the slider CreatorPanel is checked on its own until it is wired in.
func _creator_step(tree: SceneTree) -> void:
	var c := CreatorPanel.make(PlayerLook.neutral(), ClassUnlock.open_ids())
	var ui := CanvasLayer.new()
	main.add_child(ui)
	ui.add_child(c)
	for i in 4: await tree.process_frame
	ok(_find_text(c, "Randomise") != null and _find_text(c, "Looks good") != null,
			"Randomise and Looks good are there, so a player who doesn't mind is through in one click")
	await _shot(tree, "creator_body", 30)
	var before: Dictionary = c.look.duplicate(true)
	c.randomise()
	ok(c.look != before and (c.look["sliders"] as Dictionary).values().all(func(v): return v >= 0.0 and v <= 1.0),
			"Randomise makes a new person, every slider in range")
	c.show_tab("Face")
	await _shot(tree, "creator_face", 12)
	c.show_tab("Colours")
	await _shot(tree, "creator_colours", 12)
	var made := [{}]
	c.done.connect(func(lk: Dictionary): made[0] = lk)
	var want: Dictionary = c.look.duplicate(true)
	(_find_text(c, "Looks good") as Button).pressed.emit()
	for i in 3: await tree.process_frame
	ok(PlayerLook.clean(made[0]) == PlayerLook.clean(want), "Looks good hands back the look it shows")
	ui.queue_free()
	for i in 3: await tree.process_frame

func _find_text(nd: Node, txt: String) -> Control:
	if nd is Button and (nd as Button).text == txt:
		return nd
	for ch in nd.get_children():
		var f := _find_text(ch, txt)
		if f: return f
	return null

func _shot(tree: SceneTree, file: String, frames := 25) -> void:
	if shots == "": return
	for i in frames: await tree.process_frame
	_save_scaled(tree.root.get_texture().get_image(), "%s/%s.png" % [shots, file])

func _save_scaled(img: Image, path: String) -> void:
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(path)

# ---------------------------------------------------------------- 9. screenshots
## One Hunter (the Dark Archer's Warden) at 5 slider settings, side by side.
func _shot_settings(tree: SceneTree) -> void:
	var looks := [flat(0.0, {"skin": 0, "hair_col": 3, "eyes": 4}), flat(0.25, {"skin": 2, "hair_col": 1}),
		PlayerLook.neutral(), flat(0.75, {"skin": 5, "hair_col": 5, "eyes": 3}), flat(1.0, {"skin": 6, "hair_col": 9})]
	var models: Array = []
	for lk in looks:
		models.append(Models.hunter("light", Data.TEAM_COLORS[0], Arch.signature("archer"), "", lk, "archer"))
	await _lineup(tree, models, ["all 0", "all 0.25", "neutral", "all 0.75", "all 1"], "settings_archer")

## One player's look (tall, broad, dark skin, red hair, green eyes) across 4 Hunters, and as themselves.
func _shot_across(tree: SceneTree) -> void:
	var lk := flat(0.85, {"skin": 5, "hair_col": 16, "eyes": 3, "outfit": 1, "gender": 1, "hair": 10})
	var models: Array = [Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", MantleLook.at_home(lk))]
	var names: Array = ["at home"]
	for a in SHOT_HUNTERS:
		models.append(Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", lk, a))
		names.append(Arch.name_of(a))
	await _lineup(tree, models, names, "one_player_4_hunters")

func _lineup(tree: SceneTree, models: Array, names: Array, file: String) -> void:
	var stage := Node3D.new()
	main.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("1a1440"), "mid": Color("4a3a7a"), "horizon": Color("c89070"),
		"below": Color("2a1e4a"), "ambient": Color("c8cdf0"), "fog_density": 0.0})
	stage.add_child(env)
	Look.lights(stage, Color("ffe2c4"), 1.0, Vector3(-40, -25, 0), 30.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.position = Vector3(0, 1.6, 9.5)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.make_current()
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	for i in models.size():
		var mdl: Node3D = models[i]
		var ring := mdl.get_node_or_null("TeamRing") as Node3D
		if ring: ring.visible = false
		mdl.position = Vector3((i - (models.size() - 1) * 0.5) * 1.35, 0, 0)
		mdl.rotation.y = PI + 0.35
		stage.add_child(mdl)
		var l := UiText.label(String(names[i]), 18, UI.INK, UI.semi)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09))
		layer.add_child(l)
		l.position = cam.unproject_position(mdl.position + Vector3(0, -0.12, 0)) - Vector2(50, 0)
	await _shot(tree, file, 30)
	stage.queue_free()
	for i in 3: await tree.process_frame
