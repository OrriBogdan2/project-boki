extends RefCounted
## --colour-vision-check: Settings > Accessibility > Colour vision (SideColor).
##   1. settings: an old settings file (no colour_vision key) loads as "default"; a bad value falls back
##      to it; a real pick is kept
##   2. palettes: you, your squad and rivals stay apart under simulated colour blindness (Machado 2009)
##      in each palette's own mode, and a palette changes nothing but those side colours
##   3. users: in a 2v2, with each palette picked, every side-colour user returns the palette's colour:
##      ground rings, Boki rings, nameplate and health roles, the hunter's hit marker, boxes, pings,
##      map colours and squad colours; and no script outside SideColor keeps a copy of a side colour
##   4. ways out: the seat tones, the Heart and its Gate stay apart from your squad's and the rivals' colours under
##      each simulation; a seat a squad or a rival uses reads by label and shape as well as by hue (beacon text,
##      strip word and pip, map badge); the Heart, Gate, tide, seat badges and uplink beams take the palette's colours
## Runs with a temporary XDG_DATA_HOME (it writes user://settings.cfg). Never touches the save.

const DT := 1.0 / 60.0
const MIN_APART := 0.16      # distance in simulated sRGB between two sides that must read as different
## The standard palette's you, squad and rim: only SideColor holds them.
const COPIES := ["9be36e", "63c7ff", "ff2d55", "ff5d78", "ffb4c0", "9fb0d8", "8a3a4a", "f4fbff"]
## The Ways Out's neutral colours (SideColor.tone) that must stay off the squad's and the rivals' colours.
const SEAT_TONES := ["seat_open", "seat_locked", "seat_lost", "beam_open", "beam_locked", "heart", "gate"]
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
	_ways_tones()
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

## A palette's tone as SideColor.tone would give it with that palette picked.
func _tone(id: String, key: String) -> Color:
	var p: Dictionary = SideColor.PALETTES[id]
	return p[key] if p.has(key) else SideColor.PALETTES["default"][key]

func _see(c: Color, mode: String) -> Color:
	return c if mode == "" else simulate(c, mode)

## 4a. the way-out tones apart from the sides, as seen plain and under each simulation the palette answers to.
func _ways_tones() -> void:
	for id in SideColor.ORDER:
		var p: Dictionary = SideColor.PALETTES[id]
		for mode in [""] + MODES[id]:
			var what := "%s %s: " % [id, mode if mode != "" else "plain"]
			var seen := {}
			for k in SEAT_TONES:
				seen[k] = _see(_tone(id, k), mode)
			var sides := [_see(p["ally"], mode), _see(p["foe"], mode)]
			var worst := 9.0
			for k in SEAT_TONES:
				for c in sides:
					worst = minf(worst, _apart(seen[k], c))
				for mate in p["mates"] if k in ["heart", "gate"] else []:
					worst = minf(worst, _apart(seen[k], _see(mate, mode)))
			ok(what + "seat, Heart and Gate tones stay off the squad's and the rivals' colours", worst > MIN_APART,
				"(%.2f)" % worst)
			var states: Array = [seen["seat_open"], seen["seat_locked"], seen["seat_lost"]]
			var gap := minf(_apart(states[0], states[1]), _apart(states[0], states[2]))
			gap = minf(gap, _apart(states[1], states[2]))
			ok(what + "open, locked and lost seats stay apart", gap > MIN_APART)

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
		_ways_users(m, me, mate, foe, id, tag)
	Settings.v[SideColor.KEY] = "default"
	main.remove_child(m)
	m.queue_free()

## A way-out seat as the strip and the maps read it (WaysOutHud.seats), seen by the squad `viewer`.
func _seat(st: int, team: int, viewer: int) -> Dictionary:
	return {"name": "LAIR", "st": st, "t": 60.0, "team": team, "viewer": viewer}

## 4b. the way-out users under one palette: squad and rival seats by colour and by label and shape; the neutral
## tones, the Heart, the tide and the uplink beam from the palette.
func _ways_users(m: Match, me: Hunter, mate: Hunter, foe: Hunter, id: String, tag: String) -> void:
	var p: Dictionary = SideColor.PALETTES[id]
	var ours := WaysOutLook.read(m, WaysOutLook.St.IN_USE, mate.team, 0.0, 1.0)
	var theirs := WaysOutLook.read(m, WaysOutLook.St.IN_USE, foe.team, 0.0, 1.0)
	ok(tag + "seat beacon: your squad's colour and a rival's",
		_same(WaysOutLook.color_of(ours), p["ally"]) and _same(WaysOutLook.color_of(theirs), p["foe"]))
	ok(tag + "seat beacon: a label tells them apart",
		WaysOutLook.tag(ours) == WaysOutLook.WORD_MINE and WaysOutLook.tag(theirs) == WaysOutLook.WORD_RIVAL)
	for st in [WaysOutHud.St.USE, WaysOutHud.St.TAKEN]:
		var dim := 0.25 if st == WaysOutHud.St.TAKEN else 0.0      # (a taken seat is its squad's colour, darker)
		var sm := _seat(st, mate.team, me.team)
		var sr := _seat(st, foe.team, me.team)
		ok(tag + "strip st %d: word and pip shape tell squad from rival" % st,
			WaysOutHud.state_word(sm) != WaysOutHud.state_word(sr)
			and WaysOutHud.rival(sr) and not WaysOutHud.rival(sm))
		ok(tag + "map st %d: the squad's colour and the rival's" % st,
			_same(WaysOutMap.color_of(sm), (p["ally"] as Color).darkened(dim))
			and _same(WaysOutMap.color_of(sr), (p["foe"] as Color).darkened(dim)))
		ok(tag + "map st %d: the words say whose" % st, WaysOutMap.word(0, sm) != WaysOutMap.word(0, sr))
	var neutral := {
		WaysOutHud.St.LOCKED: "seat_locked", WaysOutHud.St.OPEN: "seat_open", WaysOutHud.St.LOST: "seat_lost"}
	for st in neutral:
		ok(tag + "map: a %s seat" % neutral[st], WaysOutMap.color_of(_seat(st, -1, me.team)) == _tone(id, neutral[st]))
	ok(tag + "the Heart, its Gate and the tide", Heart.col() == _tone(id, "heart")
		and Heart.gate_col() == _tone(id, "gate") and SideColor.tone("tide") == _tone(id, "tide"))
	var up := {"state": "charging", "team": foe.team, "contested": false}
	var beam: Color = ExitSignal.colors(up, ExitSignal.ACTIVE, -1, 1.0, me.team)[0]
	ok(tag + "an uplink's beam: a rival's colour", _same(Color(beam, 1.0), p["foe"]))
