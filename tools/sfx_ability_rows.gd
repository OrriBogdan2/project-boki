extends RefCounted
## --sfx-set-check section 21: no Hunter ability is silent (docs/AUDIO.md, "Ability sounds").
## Every move of the 13 Hunters (LMB held, RMB held, E, Shift, R) is pressed once in a real match at a dummy 3 m
## away, and every cue it asks for is logged (Sfx.cue_log). A move must be heard in its Hunter's own set
## (content/sfx/<arch>.json, the <arch>_ult_cue for R) and, when it hurts the dummy, an own sound must sit within
## HIT_WINDOW of the damage: a shared stock cue alone is silence. The passives' procs are listed in PROCS: the
## sound exists and the proc's script (or content/vfx file) names it. Prints one ABILITY row per move (cast, hit,
## end) for the table in docs/AUDIO.md. Never touches the save.

const DT := 1.0 / 60.0
const MOVES := ["lmb", "rmb", "e", "dash", "r"]
const WATCH := 6.0  # s watched after each press (Stone Row, Hearthlight and the like end late)
const HELD := 0.5  # s LMB and RMB stay down
const CAST_S := 0.35  # s: a sound first heard before this (or before the first damage) is the cast
const HIT_WINDOW := 0.1  # s: an own sound this close to the first damage is the hit's
const QUIET := ["step", "grunt"]  # categories that are not an ability's
## arch -> [[the passive's proc, its sound, the file that names it]]; Lace's Red Thread (sight through cover and a
## wall climb) and the Boki bond have no proc moment.
const PROCS := {
	"ashwick":
	[
		["Ablaze", "as_ignite", "scripts/arch/kits/ashwick_kit.gd"],
		["Flashover", "lw_blaze", "scripts/arch/kits/ashwick_kit.gd"]
	],
	"bulwark":
	[
		["Guard gained", "bjorn_block", "scripts/arch/kits/bulwark_kit.gd"],
		["Shield Slam", "pay_slam", "scripts/arch/kits/bulwark_kit.gd"]
	],
	"dolm": [["Shardskin stack", "br_raise", "scripts/arch/kits/dolm_kit.gd"]],
	"dredge": [["Salvage stack", "dredge_coin_jingle", "scripts/arch/kits/dredge_kit.gd"]],
	"gil":
	[
		["Beached", "gil_beached", "content/vfx/gil.json"],
		["Beached payoff", "pay_flashpoint", "scripts/arch/kits/gil_kit.gd"]
	],
	"gunslinger": [["Fever lit", "vn_stim", "scripts/arch/kits/gunslinger_kit.gd"]],
	"juggernaut": [["Enraged", "juggernaut_enrage", "content/vfx/juggernaut.json"]],
	"mage": [["Static full", "vv_static_full", "scripts/arch/kits/mage_kit.gd"]],
	"ostra": [["Swollen", "os_empower", "content/vfx/ostra.json"]],
	"rimewright": [["Shatter", "rime_splinter", "scripts/arch/kits/rimewright_kit.gd"]],
	"tender": [["Shoulder a mate", "tend_pickup", "scripts/arch/kits/tender_kit.gd"]],
	"thief": [["Marks cashed in", "pay_cashin", "scripts/arch/kits/thief_kit.gd"]],
}

var ok: Callable
var arch_check


func run(main: Node, check_ok: Callable) -> void:
	ok = check_ok
	Save.no_write = true
	arch_check = load("res://tools/archetype_check.gd").new()
	arch_check.main = main
	ok.call(Arch.ORDER.size() == 13, "ability sounds: the roster is 13 Hunters (%d)" % Arch.ORDER.size())
	for arch: String in Arch.ORDER:
		var own := _own(arch)
		for mv: String in MOVES:
			_row(arch, mv, own, _measure(arch, mv))
		for p: Array in PROCS.get(arch, []):
			var named := FileAccess.get_file_as_string("res://" + String(p[2])).contains('"%s"' % p[1])
			var made := (
				FileAccess.file_exists("res://audio/%s.wav" % p[1])
				or FileAccess.file_exists("res://audio/%s_1.wav" % p[1])
			)
			ok.call(named and made, "%s passive %s: %s is made and played from %s" % [arch, p[0], p[1], p[2]])


## sound name -> category of the Hunter's own set (the ult cue counts for R).
func _own(arch: String) -> Dictionary:
	var set_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/%s.json" % arch))
	var out := {}
	for sname: String in set_json["sounds"]:
		if not String(set_json["sounds"][sname]) in QUIET:
			out[sname] = true
	out[arch + "_ult_cue"] = true
	return out


## cue_log entries [[ms, name]] and the ms of the first damage (-1 for none) after one press of `mv`.
func _measure(arch: String, mv: String) -> Dictionary:
	var r: Array = arch_check.setup(arch, 3.0)
	var m: Match = r[0]
	var hero: Hunter = r[1]
	var dummy: Hunter = r[2]
	var ally: Hunter = null
	if arch == "tender":  # Hearth Call needs a mate to call
		ally = m.make_hunter(
			"A", hero.team, "medium", "Ally", "idle", {}, hero.pos + Vector3(-2.5, 0, 1.5), {"arch": "none"}
		)
	for f in 20:
		m.step(DT)
	var hp := dummy.hp
	var out := {"cues": [], "hit": -1}
	for f in int(WATCH / DT):
		var held := f < int(HELD / DT)
		Sfx.cue_log = []
		arch_check.aim_at(hero, ally.pos if ally != null and mv == "r" else dummy.pos)
		hero.inp["fire"] = mv == "lmb" and held
		hero.inp["sec"] = mv == "rmb" and f == 0
		hero.inp["sec_hold"] = mv == "rmb" and held
		hero.inp["sig"] = mv == "e" and f == 0
		hero.inp["dash"] = mv == "dash" and f == 0
		if mv == "r" and f == 0:
			HunterKeys.ult_pressed(hero)
		Sfx.listener = hero.pos
		m.step(DT)
		var at := roundi(f * DT * 1000.0)
		for c: Array in Sfx.cue_log:
			out["cues"].append([at, String(c[0])])
		if int(out["hit"]) < 0 and dummy.hp < hp - 0.01:
			out["hit"] = at
		hp = dummy.hp
	Sfx.cue_log = null
	m.queue_free()
	return out


## The own sounds of a move in three buckets by when each is first heard, a fail line for a silent move or a hit
## with no own sound beside it, and the ABILITY row.
func _row(arch: String, mv: String, own: Dictionary, r: Dictionary) -> void:
	var hit_ms := int(r["hit"])
	var cast_to := roundi(CAST_S * 1000.0) if hit_ms < 0 else mini(hit_ms, roundi(CAST_S * 1000.0))
	var win := roundi(HIT_WINDOW * 1000.0)
	var buckets := {"cast": [], "hit": [], "end": []}
	var first := {}
	var hit_heard := false
	for c: Array in r["cues"]:
		var sname: String = c[1]
		if not own.has(sname):
			continue
		if hit_ms >= 0 and absi(int(c[0]) - hit_ms) <= win:
			hit_heard = true
		if first.has(sname):
			continue
		first[sname] = true
		var at := int(c[0])
		if at < cast_to:
			buckets["cast"].append(sname)
		elif hit_ms >= 0 and at <= hit_ms + win:
			buckets["hit"].append(sname)
		else:
			buckets["end"].append(sname)
	print(
		(
			"ABILITY | %s | %s | %s | %s | %s |"
			% [arch, mv, ", ".join(buckets["cast"]), ", ".join(buckets["hit"]), ", ".join(buckets["end"])]
		)
	)
	ok.call(not first.is_empty(), "%s %s: heard in its own set (not silent, not only shared cues)" % [arch, mv])
	if hit_ms >= 0:
		ok.call(hit_heard, "%s %s: an own sound sits on its hit (%d ms)" % [arch, mv, hit_ms])
