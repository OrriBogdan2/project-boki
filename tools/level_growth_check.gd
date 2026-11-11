extends RefCounted
## --level-growth-check: Hunter numbers grow with the run level along the source's straight lines
## (docs/ABILITIES.md "Level growth"). For every Hunter, at levels 1, 5 and 10, a damage slot, a heal
## and a shield must sit on the source curve: ability damage and ability heals on ability power
## (+3.9% of the level-1 number a level), max health and the shields that scale with it on +6% a level.
## The expected numbers are written out here, not read from LevelGrowth, so a curve change fails.
## Never touches the save.

var bad := 0
const LEVELS := [1, 5, 10]
const AP := {1: 1.0, 5: 1.156, 10: 1.351}      # ability power: 1 + 0.039 x (level - 1)
const HP := {1: 1.0, 5: 1.24, 10: 1.54}        # max health: 1 + 0.06 x (level - 1)
## The slot whose damage each Hunter's check reads (an ability that deals damage in its kit).
const DMG_SLOT := {
	"gunslinger": "kin", "juggernaut": "sec", "ashwick": "dash", "tender": "sec", "dolm": "dash", "archer": "sec",
	"dredge": "sec", "rimewright": "sec", "mage": "dash", "bulwark": "dash", "thief": "kin", "ostra": "sec",
	"gil": "dash",
}
## Hunters whose heal or shield is the kit's own (others heal and shield through Effects' ability path).
const KIT_HEAL := ["tender", "bulwark"]
const MAXHP_SHIELD := ["bulwark", "ashwick"]
const SHIELD_NAME := {"bulwark": "aegis shield_max", "ashwick": "cloak shield (max health)"}

func ok(what: String, cond: bool, info := "") -> void:
	if cond:
		print("LEVELGROWTH ok   " + what)
		return
	print("LEVELGROWTH FAIL %s  (%s)" % [what, info])
	bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	var opts := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true}
	opts.merge({"arch": "thief", "cls": Arch.weight("thief")})
	await m.start(opts)
	m.set_process(false)
	var P: Hunter = m.player
	var tip := LevelGrowth.tip(P)
	var named := tip.contains("+6% max health") and tip.contains("+3.9% ability power")
	ok("the level badge names the per-level growth", named, tip)
	for a in Arch.ORDER:
		P.reclass(Arch.weight(a), a)
		var base := {}
		for lvl in LEVELS:
			P.lvl = lvl
			LevelGrowth.apply(P)
			var got := _read(P, String(a))
			if lvl == 1: base = got
			var shield_k: float = HP[lvl] if MAXHP_SHIELD.has(a) else AP[lvl]
			var want := {"dmg": AP[lvl], "heal": AP[lvl], "shield": shield_k, "hp": HP[lvl]}
			for k in want:
				var r := float(got[k]) / maxf(float(base[k]), 0.0001)
				var what := "%s L%d: %s x%.3f" % [a, lvl, _what(String(a), k), want[k]]
				ok(what, absf(r - float(want[k])) < 0.002, "x%.3f" % r)
	m.queue_free()
	print("LEVELGROWTH %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(0 if bad == 0 else 1)

## The numbers the slots read at the hunter's current level.
func _read(P: Hunter, a: String) -> Dictionary:
	var k := P.ak
	var heal: float = Effects._heal_k(P)
	if a == "tender": heal = (k as TenderKit).heal_k()
	elif a == "bulwark": heal = (k as BulwarkKit).heal_k()
	var shield: float = Effects._heal_k(P)
	if a == "bulwark": shield = (k as BulwarkKit).shield_max()
	elif a == "ashwick": shield = P.max_hp      # Furnace Cloak, rank-3 Soot Ram: a share of max health
	return {"dmg": k.power(String(DMG_SLOT[a])), "heal": heal, "shield": shield, "hp": P.max_hp - P.kin_hp_added}

func _what(a: String, k: String) -> String:
	match k:
		"dmg": return "%s damage" % DMG_SLOT[a]
		"heal": return "kit heal (heal_k)" if KIT_HEAL.has(a) else "ability heal (Effects)"
		"shield": return SHIELD_NAME.get(a, "ability shield (Effects)")
	return "max health"
