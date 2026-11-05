class_name ChestLoot
extends RefCounted
## Opening the one chest type: the lid, and what falls out. Every chest is the same; what is inside
## follows the area's drop lean and rarity bonus (BiomeRun) and the match difficulty tier
## (content/rules/keys.json "chest"; the gear table is "chest" in content/rules/gear.json).

static func R() -> Dictionary:
	return KeyRun.rules()["chest"]

## How many rarity steps a chest at `at` adds: the region's bonus plus the match tier's.
static func rarity_bonus(m: Match, at: Vector3) -> int:
	var tb: Array = R()["tier_bonus"]
	return (m.biomes.rarity_bonus_at(at) if m.biomes else 0) + int(tb[clampi(m.tier, 0, tb.size() - 1)])

## The lid springs open and the chest bursts; then the loot (drop).
static func open(m: Match, h: Hunter, c: Dictionary, from_net: bool) -> void:
	var lid: Node3D = c["node"].get_node("Body/Lid")
	if lid.has_meta("hinged"):
		m.create_tween().tween_property(
				lid, "rotation:x", 1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lid.rotation.x = -1.1
		lid.position.y = 0.62
		lid.position.z = 0.2
	var beacon: Node3D = c["node"].get_node_or_null("Beacon")
	if beacon: beacon.visible = false
	KeyChest.unlock_fx(m, c)
	m.sfx("pickup", c["pos"], 0.0, 0.8)
	m.fx.burst(c["pos"] + Vector3(0, 0.6, 0), Color("f2c84a"), 28, 4.5, 0.6)
	m.fx.ring(c["pos"], 2.4, Color("f2c84a", 0.9), 0.4)
	if h == m.player and h.kin is Kin:
		BokiChatter.say(m, h.kin, "loot")
	drop(m, h, c, from_net)

## THE CALL SITE where a chest's contents appear (the perk orbs of ext/perkorbs go in here, at
## perk_hook). from_net: another game opened it; this game only shows the lid, the host drops the loot.
static func drop(m: Match, h: Hunter, c: Dictionary, from_net: bool) -> void:
	var r := R()
	var at: Vector3 = c["pos"]
	var rng: RandomNumberGenerator = m.rng
	var bonus := rarity_bonus(m, at)
	var n_pick := m.pickups.size()
	var n_w := m.wpicks.size()
	# a crate on the sky train pops its loot gently, so it lands on the car and rides along
	var soft = Vector3(randf_range(-0.8, 0.8), 4.5, randf_range(-0.8, 0.8)) if c.has("ride") else null
	var gems: Array = r["gems"]
	for i in randi_range(int(gems[0]), int(gems[1])):
		m.drop("gem", at + Vector3(0, 0.8, 0), int(round(float(r["gem_base"]) * float(m.T["loot"]))), "", "", soft)
	if randf() < float(r["seed_odds"]):
		m.drop("seed", at + Vector3(0, 0.8, 0), randi_range(1, 2), Data.pick_seed(), "", soft)
	if not from_net:
		# gear and weapon tunings, leaning toward what this region is known for
		GearDrops.run_table(
				m, String(r["table"]), at, rng,
				{"h": h, "bonus": bonus, "lean": m.biomes.slot_lean_at(at) if m.biomes else {}})
		if randf() < float(r["valuable_odds"]):
			# treasure for the backpack; a rich area sometimes holds a Soul Ember
			var a3 := randf() * TAU
			m.spawn_val(
					Loot.valuable(Loot.roll_valuable(rng, int(r["valuable_tier"]))), at + Vector3(cos(a3), 0, sin(a3)))
			if bonus >= int(r["rift_key_min_bonus"]) and rng.randf() < float(r["soul_ember_odds"]):
				m.spawn_val(Loot.valuable("soul_ember"), at + Vector3(-cos(a3), 0, -sin(a3)))
		# a rich area's chest sometimes holds a Rift Key
		if m.exits and not m.exits.list.is_empty() and bonus >= int(r["rift_key_min_bonus"]) \
				and rng.randf() < float(r["rift_key_odds"]):
			m.exits.drop_key(at)
	if c.has("ride") and not from_net:
		KeyBonus.on_break(m, at, "train_crate")      # a sky-train crate: a rare chest key
	if not from_net:
		perk_hook(m, h, c)
	if h and not h.remote and h.tonics < 5 and randf() < float(r["tonic_odds"]):
		h.tonics += 1
		if h == m.player: m.hud.toast("+1 tonic", Color("8ff0a0"))
	if c.has("ride"):
		for i in range(n_pick, m.pickups.size()): m.pickups[i]["ride"] = int(c["ride"])
		for i in range(n_w, m.wpicks.size()):
			# weapons and gear land on the deck, close to the crate
			var wp: Dictionary = m.wpicks[i]
			var off := Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-1.2, 1.2))
			var t3: Transform3D = m.skytrain.cur[int(c["ride"])]
			wp["pos"] = t3 * off
			wp["ride"] = int(c["ride"])
			(wp["node"] as Node3D).position = wp["pos"]

## Where a chest hands out its perk orb (PerkOrbs). The host rolls it; the orb syncs to the others.
static func perk_hook(m: Match, h: Hunter, c: Dictionary) -> void:
	PerkOrbs.drop(m, "chest", c["pos"], 0, h)
