extends RefCounted
## --loot-glow-shots --shots-dir=<dir>: loot rarity looks at the match camera's zoom (needs a renderer, so
## through jobq --needs gpu). One shot per ground: grass (the map as it is), stone (a grey slab under the
## drops) and shadow (a canopy over them casting its shadow). On each: one drop of every rarity, Common to
## Legendary, left to right, and a deathbox holding a Legendary on the right. <dir>/captions.txt names the files.

const DT := 1.0 / 60.0
const SPACING := 2.2          # m between drops
const STONE := Color("7d7b78")

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var at := _roomy()
	P.teleport(at + Vector3(0, 0, 3.0))
	_row(at)
	await _go(0.8)
	_take("loot_grass", "Common to Legendary on grass at match zoom, a Legendary deathbox on the right")
	var slab := _plate(at, 14.0, 0.06, STONE, true)
	await _go(0.4)
	_take("loot_stone", "The same row on a grey stone slab")
	slab.queue_free()
	var canopy := _plate(at + Vector3(0, 4.5, -1.0), 18.0, 0.3, Color("303030"), true)
	await _go(0.6)
	_take("loot_shadow", "The same row under a canopy, in its shadow")
	canopy.queue_free()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("LOOTGLOWSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## Open, flat ground.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-8, 9, 2):
			for dz in range(-6, 7, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat:
			return g
	return m.world.random_ground()

func _row(at: Vector3) -> void:
	var armor: Array = Gear.ALL.keys().filter(func(id): return Gear.slot_of(String(id)) == 2)
	for r in Data.RARITY.size():
		m.spawn_gear(String(armor[r % armor.size()]), r, at + Vector3((r - 2) * SPACING, 0, 0), "shot%d" % r, false)
	var b := {"owner": P, "team": P.team, "pos": at + Vector3(3.5 * SPACING, 0, 0), "gems": 0, "seeds": {}, "caught": [], "belt": {},
		"soul_until": 0.0, "prog": {}, "node": null, "empty": false, "gear": [{"id": String(armor[0]), "rar": 4}], "pack": []}
	var n := Models.deathbox(Life.box_color(b), Life.box_rarity(b))
	n.position = b["pos"]
	m.add_child(n)

func _plate(at: Vector3, size: float, thick: float, col: Color, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(size, thick, size)
	mi.mesh = bm
	mi.material_override = Models.toon(col, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, thick * 0.5, 0)
	m.add_child(mi)
	return mi

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for hh in m.hunters:
			hh.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
