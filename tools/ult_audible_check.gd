extends RefCounted
## --ult-audible-check: a hunter's ultimate cast is a positional cue for everyone else (Sfx, docs/AUDIO.md).
## For each of the 12 Hunters a rival casting its ultimate is heard at 20 m and not at 60 m, on the bus that
## skips the SFX compressor; the local hunter's own cast plays no cue; each cue is its own sound, and sits
## above the loudest combat category once the cue gain is added.

const NEAR_M := 20.0           # m: a rival this close is heard
const FAR_M := 60.0            # m: and this far is not (Sfx.ULT_REACH is 45)
const AUDIBLE_DB := -18.0      # dB: the least the cue may be at NEAR_M, so it is clearly there

var main: Node
var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("ULTAUDIBLE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77,
		"no_drop": true})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	m.player.ctrl = "local"      # autoplay makes the player a bot; for this check it is the one listening
	var rival: Hunter = m.hunters.filter(func(h): return h != m.player and h.team != m.player.team)[0]
	var levels_json := FileAccess.get_file_as_string("res://content/rules/sfx_levels.json")
	var levels: Dictionary = JSON.parse_string(levels_json)["cats"]
	var cues := {}          # cue sound -> Hunter group
	for f in DirAccess.get_files_at("res://content/sfx"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
		if d is Dictionary and d.has("ult_cue"):
			var cue := String(d["ult_cue"])
			var g := String(d["group"])
			ok(d["sounds"].has(cue), "%s: ult_cue %s is one of the set's sounds" % [g, cue])
			ok(Sfx.ult_cues.get(g, "") == cue and not cues.has(cue), "%s: Sfx loads it, no other Hunter shares it" % g)
			var boosted: float = Sfx.ULT_DB + float(levels[d["sounds"][cue]])
			ok(boosted > float(levels["heavy_impact"]), "%s: %s is louder than a heavy impact once boosted" % [g, cue])
			cues[cue] = g
	ok(cues.size() == 12, "all 12 Hunters have an ultimate cue (%d)" % cues.size())
	var near_db := Sfx.ult_cue_db(NEAR_M)
	var falls_off := is_nan(Sfx.ult_cue_db(FAR_M)) and near_db > AUDIBLE_DB
	ok(falls_off, "fall-off: %.1f dB at %d m, silent at %d m" % [near_db, NEAR_M, FAR_M])
	Sfx.listener = m.player.pos
	var bus := AudioServer.get_bus_index("SFXCue")
	ok(bus >= 0 and AudioServer.get_bus_send(bus) == &"Master" and not _has_compressor(bus),
		"the cue bus goes to Master with no compressor, so your own fire can't press it down")
	m.player.arch = "gunslinger"
	_cast(m.player)
	ok(_cue_voices().is_empty(), "your own ultimate keeps today's mix (no cue)")
	for cue in cues:
		var g: String = cues[cue]
		rival.arch = g
		rival.pos = m.player.pos + Vector3(FAR_M, 0.0, 0.0)
		_cast(rival)
		ok(_cue_voices().is_empty(), "%s: a rival at %d m is not heard" % [g, FAR_M])
		rival.pos = m.player.pos + Vector3(0.0, 0.0, -NEAR_M)
		_cast(rival)
		var heard := _cue_voices()
		var db: float = heard[0].volume_db if heard.size() == 1 else NAN
		ok(heard.size() == 1 and db > AUDIBLE_DB, "%s: a rival at %d m is heard (%s, %.1f dB)" % [g, NEAR_M, cue, db])
		for p in heard:
			p.stop()
	print("ULTAUDIBLE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _cast(h: Hunter) -> void:
	CombatBus.ability_used.emit(h, h.arch + "_x", "ultimate")

func _cue_voices() -> Array:
	return Sfx.players.filter(func(p): return p.playing and p.bus == &"SFXCue")

func _has_compressor(bus: int) -> bool:
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectCompressor:
			return true
	return false
