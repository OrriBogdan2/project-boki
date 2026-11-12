extends RefCounted
## Damage-ratio parity (docs/specs/DAMAGE_RATIOS.md): the fixed rows must stay within 1.5x of the source's
## share of an average Hunter's health. Source numbers are supervive_kits.md at level 1; the HP averages
## are the 12 base HPs (1285.4) and our 12 class HPs (154). Called from --hero-combo-check.
const SRC_HP := 1285.4
const OUR_HP := 154.0

static func _arch(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % id))

static func _share_ok(ours: float, src: float) -> bool:
	var r := (ours / OUR_HP) / (src / SRC_HP)
	return r <= 1.5 and r >= 1.0 / 1.5

static func run(t: RefCounted) -> void:
	var mage := _arch("mage")
	var rime := _arch("rimewright")
	var md := float(mage["x"]["dmg"])
	var rd := float(rime["x"]["dmg"])
	var ld: Dictionary = rime["rmb"]["lance"]
	var both := float(ld["dmg"]) + float(ld["burst_dmg"])
	t.ok("ratio: Sparkle Kitefall vs Thunderstorm 72", _share_ok(md, 72.0), str(md))
	t.ok("ratio: Neve Rimelock vs Chilling Finale 155", _share_ok(rd, 155.0), str(rd))
	t.ok("ratio: Neve Cryo Spear vs 156+190", _share_ok(both, 346.0), str(both))
