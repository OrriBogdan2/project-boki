extends RefCounted
## --ambience-check: the match's ambience beds (scripts/match/music_dir.gd, content/rules/ambience.json).
##   1. every Hollow Crown region (its islands' biomes) and every biome file resolves to a streamed bed
##   2. the title screen has a bed of its own that no region plays; the regions have at least 4 beds
##   3. every weather condition names a RaidLook condition and layers that exist
##   4. a crossfade never has more than two beds sounding, and the old one is gone after the fade
##   5. in a match the bed follows the island the player stands on, and the weather drives the layers
## Never touches the save.

var main: Node
var fails := 0
var n := 0
const MAP := "res://content/maps/hollowcrown.json"
const LAYERS := ["gust", "rain"]

func ok(cond: bool, what: String) -> void:
	n += 1
	print("AMBIENCE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func _streamed(bed: String) -> bool:
	var path := "res://audio/amb_%s.ogg" % bed
	return ResourceLoader.exists(path) and load(path) is AudioStreamOggVorbis

func _beds_sounding() -> int:
	var c := 0
	for p: AudioStreamPlayer in [Sfx.amb, Sfx.amb_out]:
		if p.playing and p.volume_db > -70.0: c += 1
	return c

func run(main_node: Node) -> void:
	main = main_node
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var biome_of := {}
	for isl: Dictionary in map["islands"]: biome_of[String(isl["id"])] = String(isl["biome"])
	var used := {}
	for reg: Dictionary in map["regions"]:
		var beds := {}
		for id: String in reg["islands"]: beds[MusicDir.bed_for(biome_of[id])] = true
		var what := "region %s resolves to a streamed bed %s" % [reg["id"], beds.keys()]
		ok(beds.size() >= 1 and beds.keys().all(_streamed), what)
		for b in beds: used[b] = true
	for f in DirAccess.get_files_at("res://content/biomes"):
		var b := MusicDir.bed_for(f.get_basename())
		ok(_streamed(b), "biome %s -> bed %s" % [f.get_basename(), b])
	ok(used.size() >= 4, "the map plays at least 4 distinct beds (%s)" % [used.keys()])
	ok(_streamed("title") and not used.has("title"), "the title screen has a bed of its own, no region plays it")
	ok(_streamed(String(MusicDir.rules()["default"])), "the default bed (no biome) exists")
	for cond: String in MusicDir.rules()["weather"]:
		ok(cond in RaidLook.CONDITIONS, "weather '%s' is a raid condition" % cond)
		var drives: Array = (MusicDir.rules()["weather"][cond] as Dictionary).keys()
		ok(drives.all(func(l): return l in LAYERS and _streamed(l)), "weather '%s' drives layers that exist" % cond)
	await _crossfade()
	await _in_match()
	print("AMBIENCE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _crossfade() -> void:
	var t := main.get_tree()
	Sfx.play_ambience("title")
	await t.create_timer(Sfx.AMB_FADE + 0.5).timeout
	ok(_beds_sounding() == 1 and Sfx.amb_name == "title", "title bed alone (%d sounding)" % _beds_sounding())
	Sfx.play_ambience("open")
	await t.create_timer(Sfx.AMB_FADE * 0.5).timeout
	ok(_beds_sounding() == 2, "mid-fade both the old and the new bed sound (%d)" % _beds_sounding())
	Sfx.play_ambience("cliff")      # a change inside the fade cuts the oldest
	Sfx.play_ambience("ember")
	var now := _beds_sounding()
	ok(now <= 2 and Sfx.amb_name == "ember", "a quick third and fourth change still has at most 2 beds (%d)" % now)
	await t.create_timer(Sfx.AMB_FADE + 0.5).timeout
	now = _beds_sounding()
	var db := Sfx.amb.volume_db
	ok(now == 1 and db > -20.0, "after the fade only the new bed (%d, %.1f dB)" % [now, db])

func _island_pos(m: Match, biome: String) -> Vector3:
	for isl: Dictionary in m.world.islands:
		if String(isl.get("biome", "")) == biome:
			var cell: Vector2i = isl["cells"][isl["cells"].size() / 2]
			return Vector3(cell.x + 0.5, m.player.pos.y, cell.y + 0.5)
	return Vector3.INF

func _in_match() -> void:
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77,
		"no_drop": true, "raid": "ash"})
	for i in 6: await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	ok(m.raid == "ash", "the match rolled the forced raid condition (%s)" % m.raid)
	var seen := {}
	for biome in ["frost", "ember", "gloom", "meadow"]:
		var at := _island_pos(m, biome)
		if at == Vector3.INF: continue
		m.player.pos = at
		m.music_dir.amb_t = 0.0
		m.music_dir.tick(m, 0.3)
		var want := MusicDir.bed_for(biome)
		ok(Sfx.amb_name == want, "standing on %s the bed is %s (%s)" % [biome, want, Sfx.amb_name])
		seen[Sfx.amb_name] = true
	ok(seen.size() >= 3, "walking between regions changes the bed (%s)" % [seen.keys()])
	var gust: float = float(Sfx.amb_layers["gust"]["want"]) if Sfx.amb_layers.has("gust") else 0.0
	ok(gust >= 0.99, "an ash storm drives the gust layer (%.2f)" % gust)
	Game.goto("home")
	for i in 6: await main.get_tree().process_frame
