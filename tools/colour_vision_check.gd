extends RefCounted
## --colour-vision-check: Settings > Accessibility > Colour vision (SideColor).
##   1. settings: an old settings file (no colour_vision key) loads as "default"; a bad value falls back
##      to it; a real pick is kept
##   2. palettes: you, your squad and rivals stay apart under simulated colour blindness (Machado 2009)
##      in each palette's own mode, and a palette changes nothing but those side colours
##   3. users: in a 2v2, with each palette picked, every side-colour user returns the palette's colour:
##      ground rings, Boki rings, nameplate and health roles, the hunter's hit marker, shots, boxes, pings,
##      map colours and squad colours; and no script outside SideColor keeps a copy of a side colour
## Runs with a temporary XDG_DATA_HOME (it writes user://settings.cfg). Never touches the save.

const DT := 1.0 / 60.0
const MIN_APART := 0.16      # distance in simulated sRGB between two sides that must read as different
## The standard palette's you, squad and rim: only SideColor holds them.
const COPIES := ["9be36e", "63c7ff", "ff2d55"]
## Linear-RGB matrices that simulate each kind of colour blindness (Machado, Oliveira, Fernandes 2009, severity 1.0).
const SIM := {
	"protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
## The simulations each palette answers to ("default" answers to none).
const MODES := {"default": [], "red_green": ["protan", "deutan"], "tritan": ["tritan"]}

var bad := 0

func ok(what: String, cond: bool, extra := "") -> void:
	print("COLOURVISION %s %s %s" % ["ok  " if cond else "FAIL", what, extra])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	await _settings_file(main)
	_palettes()
	_copies()
	await _users(main)
	var pick: String = str(Settings.v[SideColor.KEY])
	print("COLOURVISION DONE, palette %s, failures: %d" % [pick, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. the settings file
func _loaded(main: Node, cf: ConfigFile) -> String:
	cf.save(Settings.PATH)
	var fresh: Node = load("res://scripts/core/settings.gd").new()
	main.add_child(fresh)
	for i in 2:
		await main.get_tree().process_frame
	var got := String(fresh.get_v(SideColor.KEY))
	main.remove_child(fresh)
	fresh.free()
	return got

func _settings_file(main: Node) -> void:
	var keep := ConfigFile.new()
	var had := keep.load(Settings.PATH) == OK
	var old := ConfigFile.new()
	old.set_value("s", "music", 0.42)
	old.set_value("s", "reduce_flashes", true)
	var got := await _loaded(main, old)
	ok("an old settings file loads with the standard palette", got == "default")
	var junk := ConfigFile.new()
	junk.set_value("s", SideColor.KEY, "neon")
	got = await _loaded(main, junk)
	ok("an unknown palette falls back to the standard one", got == "default")
	for id in SideColor.ORDER:
		var pick := ConfigFile.new()
		pick.set_value("s", SideColor.KEY, id)
		got = await _loaded(main, pick)
		ok("the '%s' pick is kept" % id, got == id)
	if had:
		keep.save(Settings.PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))

# ------------------------------------------------------------------ 2. the palettes
static func simulate(c: Color, mode: String) -> Color:
	var lin := [c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b]
	var out: Array = []
	for row in SIM[mode]:
		out.append(clampf(row[0] * lin[0] + row[1] * lin[1] + row[2] * lin[2], 0.0, 1.0))
	return Color(out[0], out[1], out[2]).linear_to_srgb()

func _apart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _palettes() -> void:
	ok("every palette is named", SideColor.ORDER.all(func(id): return SideColor.NAMES.has(id)))
	ok("every palette is defined", SideColor.ORDER.all(func(id): return SideColor.PALETTES.has(id)))
	for id in SideColor.ORDER:
		var p: Dictionary = SideColor.PALETTES[id]
		var sides := [p["you"], p["ally"], p["foe"]]
		var distinct: bool = sides[0] != sides[1] and sides[1] != sides[2] and sides[0] != sides[2]
		ok("%s: you, squad and rivals differ" % id, distinct)
		ok("%s: the squad colours avoid the rivals'" % id,
			(p["mates"] as Array).all(func(c): return _apart(c, p["foe"]) > MIN_APART))
		for mode in MODES[id]:
			var s := {}
			for k in ["you", "ally", "foe"]:
				s[k] = simulate(p[k], mode)
			var worst := minf(_apart(s["you"], s["ally"]), _apart(s["ally"], s["foe"]))
			worst = minf(worst, _apart(s["you"], s["foe"]))
			ok("%s under %s: the three sides stay apart" % [id, mode], worst > MIN_APART, "(%.2f)" % worst)
			var mate_worst := 9.0
			for c in p["mates"]:
				mate_worst = minf(mate_worst, _apart(simulate(c, mode), s["foe"]))
			ok("%s under %s: squad colours stay off rivals" % [id, mode], mate_worst > MIN_APART, "(%.2f)" % mate_worst)

# ------------------------------------------------------------------ 3. the users
## No script but SideColor spells out the standard palette's side colours.
func _copies() -> void:
	var hits: Array = []
	for dir in ["res://scripts", "res://tools"]:
		_scan(dir, hits)
	ok("no side colour is copied outside SideColor", hits.is_empty(), str(hits))

func _scan(dir: String, hits: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		var path := dir + "/" + f
		if not f.ends_with(".gd") or path.ends_with("side_color.gd") or path.ends_with("colour_vision_check.gd"):
			continue
		var src := FileAccess.get_file_as_string(path)
		for hex in COPIES:
			if src.contains("\"%s\"" % hex):
				hits.append("%s %s" % [path, hex])
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, hits)

func _same(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.02

func _users(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var me: Hunter = m.player
	var mate: Hunter = null
	var foe: Hunter = null
	for h in m.hunters:
		h.ctrl = "idle"
		if h != me and h.team == me.team: mate = h
		elif h.team != me.team: foe = h
	for id in SideColor.ORDER:
		Settings.v[SideColor.KEY] = id
		var p: Dictionary = SideColor.PALETTES[id]
		for h in m.hunters:
			SideRings.tick(h)
		var tag := "[%s] " % id
		var rings := {me: p["you"], mate: p["ally"], foe: p["foe"]}
		for h in rings:
			var ground := h.model.get_node_or_null("TeamRing") as MeshInstance3D
			ok(tag + "%s's ground ring" % h.pname, _same(SideRings.shown(ground), rings[h]))
			if h.kin:
				ok(tag + "%s's Boki ring" % h.pname, _same(SideRings.shown((h.kin as Kin).ring), rings[h]))
		var roles := [HudStyle.role_col(me, me), HudStyle.role_col(me, mate), HudStyle.role_col(me, foe)]
		ok(tag + "nameplate and health roles", roles == [p["you"], p["ally"], p["foe"]])
		ok(tag + "a rival's hit marker", foe._marker_col() == p["foe"])
		ok(tag + "your squad's hit marker", _same(Color(mate._marker_col(), 1.0), p["ally"]))
		ok(tag + "a rival's box", Life.owner_col(m, {"owner": foe}) == p["foe"])
		ok(tag + "an enemy ping", PingInput.color(m, me, "enemy") == p["foe"])
		ok(tag + "squad map colours", m.mate_col(me) == p["mates"][0] and m.mate_col(mate) == p["mates"][1])
		ok(tag + "the hostile tint on telegraphs", SideColor.rim() == p["rim"])
	Settings.v[SideColor.KEY] = "default"
	main.remove_child(m)
	m.queue_free()
