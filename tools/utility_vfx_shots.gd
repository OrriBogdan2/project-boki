extends RefCounted
## --utility-vfx-shots --shots-dir=<dir>: every belt item in use at the match camera (UtilityVfx, UtilityLook), one
## <id>.png each, taken while it works (a drink mid-drink, a pad as it launches, a reveal on its rival, a fuse
## late in its burn), plus skyfall_charge_start.png. Each item gets its own patch of ground, so nothing an
## earlier one left (a lamp, a pad) covers it; an item that can't be used fails the run.
## <dir>/captions.txt gets "file: area / does / ends" per file.
## Runs under xvfb with a renderer (jobq submit --needs gpu), or on llvmpipe with --rendering-driver opengl3.

const DT := 1.0 / 60.0
const AIM := Vector3(-5.0, 0.0, 0.0)   # every cast lands this far from the player, in clear screen
const AT := {                          # s after the use the shot is taken (default SHOT_T)
	"tonic": 0.6, "deep_draught": 2.0, "lostway_scroll": 2.0, "omen_draught": 1.0, "armor_kit": 0.8, "medkit": 0.3,
	"jump_pad": 2.65, "gust_fan": 2.65, "warp_seed": 0.9, "toss_satchel": 0.45, "twin_gate": 1.0,
	"skyfall_charge": 4.4, "shatter_charge": 0.33, "blight_flask": 1.5, "thorn_wall": 0.8, "lookout_lantern": 1.2,
	"scanner": 0.5,
	"hawk_whistle": 0.5, "bounty_banner": 1.0, "stim": 0.8, "smoke": 0.8, "cloud_raft": 0.6, "shield_cell": 0.5,
}
const SHOT_T := 0.14           # s: an instant item's moment, at its brightest
const APART := 20.0            # m between two items' spots, and from where the others wait
const ROOM := 8                # m: a spot is flat ground this far round (an aim reaches 5 m, Skyfall's ring 6)

var main: Node
var m: Match
var P: Hunter
var cast_at := Vector3.ZERO   # where P used the item: its field is the one nearest this
var rival: Hunter
var mate: Hunter
var dir := ""
var focus := Vector3.ZERO      # the camera centres here: the effect, not the player
var spots: Array = []          # every spot used so far, the others' park first
var park := Vector3.ZERO       # solid ground far off where the others wait
var lines: Array = []
var unused: Array = []         # ids the player could not use

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var ids: Array = UtilityBelt.ids()
	for id in ids.filter(BeltKeys.is_key) + ids.filter(func(i): return not BeltKeys.is_key(i)):
		await _item(String(id))     # the keys first, while the match still has sealed locks
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("UVFXSHOTS %d in %s, not used: %s" % [lines.size(), dir, unused])
	main.get_tree().quit(1 if not unused.is_empty() else 0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 2, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P and h.team == P.team and mate == null:
			mate = h
		elif h.team != P.team and rival == null:
			rival = h
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false     # the panels sit over the effects; the shots are about the ground
	park = _roomy()
	spots.append(park)
	for h in m.hunters:
		if h != P:
			h.teleport(park + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	await _go(0.4)

## Open ground APART from every spot used so far.
func _fresh() -> Vector3:
	var at := _roomy()
	for k in 300:
		if spots.all(func(u: Vector3) -> bool: return u.distance_to(at) > APART):
			break
		at = _roomy()
	spots.append(at)
	return at

## Open, flat ground, out of the lairs (their walls hide whoever is inside).
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := m.lairs == null or m.lairs.lair_of(g, ROOM).is_empty()
		for dx in range(-ROOM, ROOM + 1, 2):
			for dz in range(-ROOM, ROOM + 1, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat:
			return g
	return m.world.random_ground()

## Nothing left over from the last item.
func _clear() -> void:
	m.fields.clear()
	for w in m.verbs.walls:
		w["t"] = 0.0
	for gp in m.gpads:
		gp["t"] = 0.0
	for sm in m.smokes:
		sm["t"] = 0.0
	for h in [rival, mate]:
		h.teleport(park)
		h.downed = false

func _item(id: String) -> void:
	_clear()
	await _go(0.3)
	while P.drink_t > 0.0 or P.kit_t > 0.0:     # the last drink or repair finishes first
		await _go(0.25)
	P.out = false
	P.downed = false
	P.hp = P.max_hp * 0.5
	P.armor = 0.0
	P.teleport(_fresh())
	P.inp["aim"] = P.pos + AIM
	focus = P.pos + AIM * 0.5
	m.remove_meta("banner_%d" % P.team)
	match id:
		"scanner", "hawk_whistle":
			rival.teleport(P.pos + Vector3(0, 0, 3.0))
		"lookout_lantern":
			rival.teleport(P.pos + Vector3(-1.6, 0, 6.0))
		"pilfer_pouch":
			rival.teleport(P.inp["aim"] + Vector3(0.8, 0, 0.5))
			rival.gems = 100
		"revive_ember":
			mate.teleport(P.pos + Vector3(1.5, 0, 1.5))
			mate.downed = true
		"chest_key":
			var locks: Array = BeltKeys._locks(m, id)
			if not locks.is_empty():
				P.teleport(locks[0]["pos"] + Vector3(0.6, 0, 0))
				focus = P.pos
		"skyfall_charge":
			focus = P.pos + AIM      # the whole 6 m circle on screen
	Sfx.listener = focus     # HeroVfx thins and drops looks by their distance from it (LOD_FAR)
	UtilityBelt.clear(P)
	UtilityBelt.grant(P, id, 1)
	cast_at = P.pos
	if not UtilityBelt.use_id(P, id):
		unused.append(id)
	var t := 0.0
	var at := float(AT.get(id, SHOT_T))
	while t < at:
		_during(id, t)
		if id == "skyfall_charge" and t < 0.6 and t + DT * 6.0 >= 0.6:
			_take(id + "_start", "Skyfall, fuse start: rim up, the disc begins to fill, the warhead high")
		var dt := minf(DT * 6.0, at - t)     # the last step lands on the shot's time
		await _go(dt)
		t += dt
	var e := UtilityVfx.entry(id)
	_take(id, "%s / %s / %s" % [e.get("area", ""), e.get("does", ""), e.get("ends", "")])

## Steps into what the item made, once it is ready.
func _during(id: String, t: float) -> void:
	match id:
		"jump_pad", "gust_fan":
			if t >= 2.5 and not m.gpads.is_empty() and P.grounded and P.flat_dist(m.gpads.back()["pos"]) > 0.3:
				P.teleport(m.gpads.back()["pos"])
		"warp_seed", "toss_satchel":
			if t < 0.2 and not m.fields.list.is_empty():
				P.teleport(_own_field()["at"])
				focus = P.pos

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		P.inv_t = 1.0
		m.cam.snap(focus)
		Sfx.listener = focus
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])

## The item's own field: the one nearest where it was used (a field from anything else may be newer).
func _own_field() -> Dictionary:
	var best: Dictionary = m.fields.list[0]
	for z: Dictionary in m.fields.list:
		if cast_at.distance_to(z["at"]) < cast_at.distance_to(best["at"]):
			best = z
	return best
