extends RefCounted
## Part of --hero-vfx-check: every Hunter's abilities wear the Hunter's colour (DECISIONS 2026-11-08). Per Hunter, three
## rows: each colour its content/vfx recipes use, each literal Color in its kit scripts, and each slot and signature
## weapon colour sit within FAMILY_DEG of hue of the archetype's "color" (pale, grey and dark colours are free).
## What carries a meaning stays: MEANING (heals, a shield's blue, timing and status cues, materials) and EXEMPT_MOVES.

const FAMILY_DEG := 40.0  # degrees of hue a colour may sit from the Hunter's own
const NEUTRAL_S := 0.25  # below this saturation a colour is grey or a pale tint: free
const NEUTRAL_V := 0.25  # below this value a colour is a shadow: free
const KITS := "res://scripts/arch/kits/"
## Kit script prefixes of each Hunter (shared helpers like kit_looks and dj_fx get their colours passed in).
const KIT_FILES := {
	"archer": ["archer_", "pin_", "hawk_"],
	"ashwick": ["ashwick_"],
	"bulwark": ["bulwark_", "bjorn_"],
	"dolm": ["dolm_", "breah_"],
	"dredge": ["dredge_"],
	"gil": ["gil_"],
	"gunslinger": ["gunslinger_", "burr_"],
	"juggernaut": ["juggernaut_"],
	"mage": ["mage_", "vv_"],
	"ostra": ["ostra_"],
	"rimewright": ["rimewright_", "ice_", "rime_"],
	"tender": ["tender_"],
	"thief": ["thief_"]
}
## Colours that mean something, by html hex, and why they stay.
const MEANING := {
	"5ae07a": "heal pillar",
	"7fe08a": "heal number and burst",
	"7dffb0": "Albert's heal burst",
	"9ad8ff": "Aegis: a shield's blue",
	"8fe3c8": "Mending Ground: a heal",
	"ffd27a": "Hearthlight and Hearth Call: heals",
	"ff8a6a": "Hearth Call's tether snap",
	"ffc02a": "Lace's perfect-release cue",
	"ffe27a": "Lace's Deadeye payoff",
	"ffc23a": "Sable's empowered-bolt aim line",
	"ff4fb0": "the Daze status",
	"d8ff6a": "Lace's aimed-foe ring",
	"0a144d": "Lace's Spirit Walk wash (footage)",
	"2e0c3e": "Lace's Spirit Walk wash (footage)",
	"b9732f": "Burr Charge's bronze shell",
	"6b4a2e": "dust where a dud lands",
	"e08a46": "Storm Rod's copper",
	"c8b48c": "arrow feathers",
	"c8b496": "earth dust",
	"b8946a": "earth dust",
	"7a5c3a": "earth thrown up by a dive",
	"1a5a6a": "the anchor spiral: seafoam stands off the grass",
	"f6a6c8": "Hearthlight's rose heal motes"
}
## Moves whose colours are the thing they act on or heal: a broken Boki's type, a heal.
const EXEMPT_MOVES := {
	"gil": ["shatter_air", "shatter_fire", "shatter_slime", "shatter_zeep"],
	"tender":
	["bloom", "call", "call_land", "call_plus", "heal_stars", "hearth", "hearth_land", "hearth_motes", "mended"]
}
const HEX_LITERAL := '[Cc]olor\\("#?([0-9a-fA-F]{6})"'
const FLOAT_LITERAL := "Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*[,)]"


## False when `c` sits outside `fam`'s hue family and is neither neutral nor a named meaning.
static func in_family(c: Color, fam: Color) -> bool:
	if c.s < NEUTRAL_S or c.v < NEUTRAL_V or MEANING.has(c.to_html(false)):
		return true
	var d := absf(c.h - fam.h) * 360.0
	return minf(d, 360.0 - d) <= FAMILY_DEG


## `ok` is the --hero-vfx-check row printer.
func run(ok: Callable) -> void:
	for arch: String in Arch.ids():
		var fam := Arch.color(arch)
		var rows := {
			"every recipe colour is on its hue": _stray_recipes(arch, fam),
			"every literal kit colour is on its hue": _stray_literals(arch, fam),
			"slot and weapon colours are on its hue": _stray_slots(arch, fam),
		}
		for what: String in rows:
			ok.call((rows[what] as Array).is_empty(), "%s: %s %s" % [arch, what, rows[what]])


func _stray_recipes(arch: String, fam: Color) -> Array:
	var d := HeroVfx.data(arch)
	var pal: Dictionary = d.get("palette", {})
	var out: Array = []
	for mv: String in d.get("moves", {}):
		if EXEMPT_MOVES.get(arch, []).has(mv):
			continue
		for layer: Dictionary in d["moves"][mv].get("fx", []):
			for key in ["c", "c2", "c3"]:
				if layer.has(key) and pal.has(layer[key]) and not in_family(Color(String(pal[layer[key]])), fam):
					out.append("%s.%s" % [mv, layer[key]])
	return out


func _stray_literals(arch: String, fam: Color) -> Array:
	var hex := RegEx.create_from_string(HEX_LITERAL)
	var flt := RegEx.create_from_string(FLOAT_LITERAL)
	var out: Array = []
	for f in DirAccess.get_files_at(KITS):
		if not f.ends_with(".gd") or not KIT_FILES[arch].any(func(p: String) -> bool: return f.begins_with(p)):
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(KITS + f).split("\n"):
			n += 1
			var cols: Array = []
			for m in hex.search_all(line):
				cols.append(Color(m.get_string(1)))
			for m in flt.search_all(line):
				cols.append(Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3))))
			for c: Color in cols:
				if not in_family(c, fam):
					out.append("%s:%d #%s" % [f, n, c.to_html(false)])
	return out


func _stray_slots(arch: String, fam: Color) -> Array:
	var def := Arch.def(arch)
	var out: Array = []
	for slot in ["rmb", "e", "x", "dash"]:
		var col: String = def[slot].get("col", "")
		if col != "" and not in_family(Color(col), fam):
			out.append("%s #%s" % [slot, col.trim_prefix("#")])
	var wpath := "res://content/weapons/%s.json" % Arch.signature(arch)
	var w = JSON.parse_string(FileAccess.get_file_as_string(wpath)) if FileAccess.file_exists(wpath) else null
	if (
		w is Dictionary
		and w.get("primary", {}).has("color")
		and not in_family(Color(String(w["primary"]["color"])), fam)
	):
		out.append("lmb %s" % w["primary"]["color"])
	return out
