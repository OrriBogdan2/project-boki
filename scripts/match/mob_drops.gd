class_name MobDrops
extends RefCounted
## What a slain monster leaves behind. It spills out when the dissolve is mostly gone
## (MobDissolve.begin says when), so the body reads first and the loot after.

const BOSS_GEM_DROPS := 4     # a lair boss's gems come as this many big drops (same total)

## Everything `mb` leaves where it fell: a carried chest key and the big ones' perk orbs always, and when
## `loot` (not in the void, not its own blast) gems, armor, gear tunings, valuables, seeds and a Rift Key.
static func spill(m: Match, mb: Mob, credit: Ent, loot: bool) -> void:
	if not is_instance_valid(mb):
		return
	KeyCarry.on_mob_dead(m, mb)
	var big_one: bool = mb.mkind in ["warden", "brute"] and credit is Hunter and not (credit as Hunter).remote
	if big_one and (mb.mkind == "warden" or m.rng.randf() < 0.5):
		var tier_s := "boss" if mb.mkind == "warden" else "brute"
		PerkOrbs.drop(m, tier_s, mb.pos, 0, credit as Hunter)      # the Warden: a fan of three
	if loot:
		_loot(m, mb, credit)

static func _loot(m: Match, mb: Mob, credit: Ent) -> void:
	var at := mb.pos
	# a lair boss pays its gems out as a few big ones (fewer drops, each worth having); the rest scatter small
	var gn := int(mb.md["gems"])
	var big_n := BOSS_GEM_DROPS if mb is Boss else gn
	var gem_v := int(round(3 * float(m.T["loot"]) * float(gn) / float(big_n)))
	for i in big_n:
		m.drop("gem", at + Vector3(0, 0.6, 0), gem_v)
	if mb.md.get("stag", false) and not (mb is Boss) and m.rng.randf() < 0.6:
		m.drop("armor", at + Vector3(0, 0.6, 0), 25)
	# guards, the Warden, the Glimmerkin and the Blight drop gear and weapon tunings (content/rules/gear.json)
	var who: Hunter = credit as Hunter
	var bonus := 0
	if m.biomes:
		bonus = m.biomes.rarity_bonus_at(at)
	GearDrops.run_table(m, mb.mkind, at + Vector3(0, 0, 0.4), m.rng, {"h": who, "bonus": bonus})
	if mb.mkind == "warden":
		# the Warden guards the best things: treasure, maybe a Soul Ember
		m.spawn_val(Loot.valuable(Loot.roll_valuable(m.rng, 2)), at + Vector3(0, 0, -0.9))
		if m.rng.randf() < 0.5:
			m.spawn_val(Loot.valuable("soul_ember"), at + Vector3(0.9, 0, -0.6))
	elif mb.mkind == "brute" and m.rng.randf() < 0.25:
		m.spawn_val(Loot.valuable(Loot.roll_valuable(m.rng, 0 if m.tier == 0 else 1)), at + Vector3(0, 0, -0.8))
	if mb.mkind == "glimmer" and credit is Hunter:
		m.add_feed("%s caught the Glimmerkin's treasure" % credit.pname)
	if mb.mkind == "bl_warden":
		# a Warden's lamp holds something worth the risk: armor, often a tonic
		m.drop("armor", at + Vector3(0, 0.6, 0), 25)
		if m.rng.randf() < 0.4: m.drop("tonic", at + Vector3(0.4, 0.6, 0), 1)
	var seed_odds := 0.12
	if mb.mkind == "brute":
		seed_odds = 0.35
	elif mb is Blight or mb is Boss:
		seed_odds = 0.0
	if m.rng.randf() < seed_odds:
		m.drop("seed", at + Vector3(0, 0.6, 0), 1, Data.pick_seed())
	# a Rift Key: always from the Warden, sometimes from an elite (one that can be staggered, or a rare one)
	var elite: bool = (mb.md.get("stag", false) or mb.rarity >= 3) and mb.mkind != "glimmer"
	if m.exits and not m.exits.list.is_empty() and (mb.mkind == "warden" or (elite and m.rng.randf() < 0.06)):
		m.exits.drop_key(at)
