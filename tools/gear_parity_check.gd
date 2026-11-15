extends RefCounted
## --gear-parity-check: boots and charms against the source (DECISIONS 2026-11-07 PARITY FIRST; audit in
## docs/KIT_PARITY.md "Boots and charms"). briefs/supervive-data and briefs/hero-ref hold no boots or
## charm items (no actives, cooldowns or move-speed numbers), so every piece is "no source match": the
## check pins today's numbers so a change has to go through the owner list, and checks each boots
## slot on the HUD (GearPanel) has no key and no cooldown, the way a passive piece should.
## Prints GEARPARITY PASS/FAIL.

## Boots, as audited: id -> [cd in s, stats at Common]. None has a source match; owner list.
const BOOTS := {
	"boots": [0.0, {"speed": 0.08}],
	"quickstep_boots": [0.0, {"dodge": 0.15, "speed": 0.03}],
	"skylark_boots": [0.0, {"heat": 0.35}],
	"windstep_boots": [0.0, {"glide_speed": 0.1, "heat": 0.15}],
}
## Charms are not built (decision 0005: not yet a gear kind); the passive gloves are the pieces meant to
## become charms. Pinned the same way: id -> [cd in s, stats at Common]. None has a source match.
const CHARM_CANDIDATES := {
	"booster": [0.0, {"glide_speed": 0.2, "heat": 0.2}],
	"focus": [0.0, {"cdr": 0.18}],
	"heat_sink": [0.0, {"heat": 0.45}],
	"power_core": [0.0, {"dmg": 0.12}],
}
const BOOTS_SLOT := 3        # Gear.SLOTS index of boots, also the h.gear index they are worn in

var fails := 0
var checks := 0

func ok(label: String, cond: bool, info := "") -> void:
	checks += 1
	printerr("GEARPARITY %-56s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main: Node) -> void:
	_pinned("boots", BOOTS, BOOTS_SLOT)
	_pinned("charm", CHARM_CANDIDATES, Gear.SLOTS.find("passive"))
	ok("no gear kind named charm yet (charms not built)", Gear.SLOTS.find("charm") == -1)
	_boots_hud()
	print("GEARPARITY DONE, %d checks, failures: %d" % [checks, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Every piece of the slot is in the audit table and still has the audited cooldown and stats.
func _pinned(what: String, table: Dictionary, slot: int) -> void:
	var ids := Gear.ids_for(slot)
	ok("every %s piece is in the audit table" % what, ids == table.keys().map(func(k): return String(k)), str(ids))
	for id in table:
		var d: Dictionary = Gear.ALL.get(id, {})
		ok("%s %s: cooldown %.1f s" % [what, id, table[id][0]], float(d.get("cd", -1.0)) == table[id][0])
		ok("%s %s: stats as audited" % [what, id], d.get("stats", {}) == table[id][1], str(d.get("stats", {})))

## The boots cell on the gear panel: passive pieces show no key and no cooldown, and the hover
## names the slot and the stat line.
func _boots_hud() -> void:
	var h := Hunter.new()
	for id in BOOTS:
		h.gear[BOOTS_SLOT] = {"id": id, "rar": 1}
		var tip := GearPanel.tip(h, BOOTS_SLOT)
		var kind := String(tip[1][0])
		var stats := String(tip[3][0])
		ok("boots %s: HUD says Boots, no key" % id, kind == Gear.WORN_NAMES[BOOTS_SLOT], kind)
		ok("boots %s: HUD stat line" % id, stats == Gear.stat_text(id, 1) and stats != "", stats)
		ok("boots %s: no cooldown to draw" % id, not Gear.active(id))
	h.free()
