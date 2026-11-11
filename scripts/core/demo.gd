class_name Demo
extends RefCounted
## Recording-ready demo presets: `-- --demo=<farm|match|training|care|tier2>` skips the menus and lands in a
## ready state, on a made-up save held in memory only (Save.no_write: the player's saves are never read
## back over or written). Debug overlays are hidden through Record (clean HUD; --record=2 for none).
## `--hunter=<archetype id>` picks the Hunter for the match presets. See docs/DEMO_PRESETS.md.

const NAMES := ["farm", "match", "training", "care", "tier2"]
const DEFAULT_HUNTER := "gunslinger"
const HOLLOW_TIER := 2                  # Data.TIERS index of the highest expedition tier
const HUNGRY_FOOD := 30.0               # care: below Econ.HUNGRY_AT (50), so the Boki walk to the trough
const FARM_KIN_LEVEL := 8

## The preset asked for on the command line ("" when none, or an unknown name).
static func name_in(args: PackedStringArray) -> String:
	for a in args:
		if not String(a).begins_with("--demo="):
			continue
		var n := String(a).substr(7)
		if n in NAMES:
			return n
		push_warning("--demo=%s: unknown preset (use one of %s)" % [n, ", ".join(NAMES)])
	return ""

## The Hunter for the match presets: --hunter=<id>, else the default.
static func hunter_in(args: PackedStringArray) -> String:
	for a in args:
		if String(a).begins_with("--hunter="):
			var id := String(a).substr(9)
			if Arch.exists(id):
				return id
			push_warning("--hunter=%s: no such Hunter, using %s" % [id, DEFAULT_HUNTER])
	return DEFAULT_HUNTER

## Before anything else reads the save: the demo save in place, never written, overlays hidden.
static func setup(preset: String) -> void:
	Save.no_write = true
	Save.d = save(preset)
	Record.set_level(1)

## A grown farm (HomeWork.demo_save) with every Hunter open, tools, ripe crops and the first
## expeditions behind it; the care preset has the Boki hungry.
static func save(preset: String) -> Dictionary:
	var d := HomeWork.demo_save()
	d["name"] = "Hunter"
	d["gems"] = 1200
	d["matches"] = 12
	d["extracts"] = 9      # the Hollow opens at 5 extractions
	d["classes"] = ClassUnlock.legacy()
	d["tools"] = HomeGather.TOOLS.keys()
	for p in d["plots"]:
		if String(p.get("crop", "")) != "":
			p["stage"] = int(Data.CROPS[p["crop"]]["grow"])
	var now := Time.get_unix_time_from_system()
	for r in d["roster"]:
		r["level"] = FARM_KIN_LEVEL
		r["starve"] = 0.0
		r["needs_t"] = now
		if preset == "care":
			r["needs"]["food"] = HUNGRY_FOOD
	return d

## Straight into the preset's screen.
static func open(main: Node, preset: String, args: PackedStringArray) -> void:
	var hunter := hunter_in(args)
	match preset:
		"farm", "care":
			main.show_screen("home", {})
		"match":
			main.show_screen("match", _as_hunter(Match.demo_opts(), hunter))
		"training":
			main.show_screen("match", _as_hunter({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0,
				"length": 1e9, "seed": 4242, "no_drop": true}, hunter))
		"tier2":
			var o := Match.demo_opts()
			o["tier"] = HOLLOW_TIER
			o.erase("live_lair")
			main.show_screen("match", _as_hunter(o, hunter))

static func _as_hunter(o: Dictionary, id: String) -> Dictionary:
	o["arch"] = id
	o["cls"] = Arch.weight(id)
	o["weapon"] = Arch.signature(id)
	return o
