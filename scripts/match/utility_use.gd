class_name UtilityUse
extends RefCounted
## What each belt item does when you press its key (UtilityBelt holds the charges). Item data is in
## content/utility/*.json; "use" picks the behaviour:
##   drink   a tonic: a short, open channel, then a heal (all in the item's "channel" data: "heal" hp
##           plus "heal_max" of your max); a drink with "cleanse" first lifts anti-heal (blight); Deep
##           Draught, Lostway Scroll (warp) and Omen Draught (omen) are drinks too (UtilityMore.drank)
##   repair  an armor kit: the same channel, then its channel "repair" share of your armor by armor tier
##           (a list, Common first; the last entry serves the tiers past it)
##   mend    heal 40 and 20 armor at once
##   smoke   a cloud that hides everyone in it
##   pad     a launch pad on the ground
##   scan    reveal rival hunters nearby
##   key     a chest key: open the locked chest beside you, or ping the nearest one (BeltKeys)
##   fx      run the item's "effects" list through Effects (haste, shield, ...); "root_self" s holds the user still;
##           a "float" item (Cloud Raft) is for open air only and hangs you in the air for its effect's "delay"
##   field pilfer lamp ember   the source utilities (UtilityMore); pad and scan take their numbers from the item
## The drink and repair take time and spill if you are hit (Hunter._interrupt_consume): nothing is
## spent unless they finish. The rest take effect at once and spend one charge, in the air or mid-dash
## too, and never touch your speed (docs/SOURCE_UTILITIES.md "Using an item and moving").

const MEND_HP := 40.0
const MEND_ARMOR := 20.0

## One number of an item's "channel" data (time s, move = speed multiplier while channelling, heal hp,
## heal_max = share of max health); `none` when the item leaves it out.
static func channel(id: String, key: String, none := 1.0) -> float:
	return float((UtilityBelt.def(id).get("channel", {}) as Dictionary).get(key, none))

## The speed multiplier for a hunter who is drinking or repairing (1.0 otherwise).
static func channel_move(h: Hunter) -> float:
	if h.drink_t > 0.0:
		return channel(h.drink_id, "move")
	return channel("armor_kit", "move") if h.kit_t > 0.0 else 1.0

static func use_of(id: String) -> String:
	return String(UtilityBelt.def(id).get("use", "fx"))

## Is there anything for this item to do right now? (A tonic at full health buzzes instead.) A drink or
## a repair can't start mid-dash: the dash would spill it on the spot (tick).
static func can_use(h: Hunter, id: String) -> bool:
	match use_of(id):
		"drink": return (heal_of(h, id) <= 0.0 or h.hp < h.max_hp - 0.5) and h.roll_t <= 0.0
		"repair": return h.armor < h.max_armor - 0.5 and h.roll_t <= 0.0
		"fx": return not UtilityBelt.def(id).get("float", false) or h.over_void()
		"mend": return h.hp < h.max_hp - 0.5 or h.armor < h.max_armor - 0.5
		"ember", "field": return UtilityMore.can_use(h, id)
	return true

## Starts the item in belt slot i. Returns false if it could not start.
static func start(h: Hunter, i: int, id: String) -> bool:
	var m = h.m
	var d: Dictionary = UtilityBelt.def(id)
	var col: Color = d.get("col", Color.WHITE)
	if use_of(id) == "key":
		return BeltKeys.use(h, id)       # the lock spends the key when it opens
	if UtilityMore.regate(h, id):
		return true                      # a Twin Gate's second press: no charge
	BeltSfx.start(h, id)
	match use_of(id):
		"drink":
			h._fold_for_action()
			h.drink_id = id
			h.drink_t = channel(id, "time")
			h.vuln_fx_t = 0.0
			BeltSfx.channel(h, id, true)
			m.fx.word(h.pos + Vector3(0, 2.3, 0), "VULNERABLE", Color("ff6a4a"))
			return true
		"repair":
			h._fold_for_action()
			h.kit_t = channel(id, "time")
			h.vuln_fx_t = 0.0
			BeltSfx.channel(h, id, true)
			m.fx.word(h.pos + Vector3(0, 2.3, 0), "VULNERABLE", Color("ff6a4a"))
			return true
		"mend":
			h.heal(MEND_HP)
			h.armor = minf(h.max_armor, h.armor + MEND_ARMOR)
			m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 16, 3.0, 0.6, -3.0)
		"smoke":
			var n := Models.gear_smoke()
			n.position = h.pos
			m.add_child(n)
			m.smokes.append({"pos": h.pos, "r": 3.6, "t": 8.0, "node": n})
		"scan":
			var rng := float(d.get("range", 26.0))
			for o in m.hunters:
				if o.team != h.team and not o.out and o.flat_dist(h) < rng:
					o.reveal_t = maxf(o.reveal_t, float(d.get("time", 3.0)))
			m.fx.ring(h.pos, minf(rng, 40.0), Color(col, 0.6), 0.8)
		"pad", "field", "pilfer", "lamp", "ember":
			UtilityMore.start(h, id, d)
		_:
			Effects.run((d.get("effects", []) as Array).duplicate(true), h,
					{"slot": "utility", "ability": id, "level": 1})
			h.root_t = maxf(h.root_t, float(d.get("root_self", 0.0)))
			if d.get("float", false) and not h.grounded:
				h.float_t = cast_of(d)      # the source floats you over the abyss while the raft forms
				h.vel.y = maxf(h.vel.y, 0.0)
	# the instant ones are spent now; the channelled ones when they finish (tick)
	h.reveal_t = maxf(h.reveal_t, 0.6)
	UtilityBelt.take(h, id, 1)
	if i < UtilityBelt.SLOTS and not (h.belt[i] as Dictionary).is_empty():
		h.belt[i]["cd"] = float(d.get("cd", 0.0))
	return true

## How long an instant item's effect takes to land: its first effect's "delay" (0 = at once).
static func cast_of(d: Dictionary) -> float:
	var effs: Array = d.get("effects", [])
	return float(effs[0].get("delay", 0.0)) if not effs.is_empty() else 0.0

## What a drink heals before perks and gear: its channel "heal" hp plus "heal_max" of max health.
static func heal_of(h: Hunter, id: String) -> float:
	return channel(id, "heal", 0.0) + h.max_hp * channel(id, "heal_max", 0.0)

## How much of the armor a kit puts back on this hunter: its channel "repair" list by armor tier.
static func repair_frac(h: Hunter) -> float:
	var r: Array = (UtilityBelt.def("armor_kit").get("channel", {}) as Dictionary).get("repair", [1.0])
	return float(r[clampi(h.armor_tier, 0, r.size() - 1)])

## Every step: a drink or repair in progress runs down, then spends its charge. Knocked out of it
## (down, stunned, rolling, gliding) and it spills with nothing used.
static func tick(h: Hunter, dt: float) -> void:
	h.float_t = maxf(0.0, h.float_t - dt)
	if h.drink_t > 0.0:
		if h.downed or h.stun_t > 0.0 or h.roll_t > 0.0 or h.gliding or h.out:
			h.drink_t = 0.0
		else:
			h.drink_t -= dt
			if h.drink_t <= 0.0:
				h.drink_t = 0.0
				Sfx.loop_stop(BeltSfx.loop_key(h, h.drink_id))
				var dd := UtilityBelt.def(h.drink_id)
				if UtilityBelt.take(h, h.drink_id, 1) > 0:
					if dd.get("cleanse", false):
						h.blight_t = 0.0        # before the heal, so it is not cut
					var amount := heal_of(h, h.drink_id)
					if amount > 0.0:
						h.heal(amount * (1.0 + 0.4 * float(h.perk_n("remedy")) + h.gear_stat("tonic")))
					BeltSfx.play(h, h.drink_id, "end")      # before drank(): a warp moves the drinker
					UtilityMore.drank(h, dd)
					h.m.fx.burst(h.pos + Vector3(0, 1.2, 0), Color(dd.get("col", Color("8ff0a0"))), 14, 2.5, 0.5, -3.0)
	if h.kit_t > 0.0:
		if h.downed or h.stun_t > 0.0 or h.roll_t > 0.0 or h.gliding or h.out:
			h.kit_t = 0.0
		else:
			h.kit_t -= dt
			if h.kit_t <= 0.0:
				h.kit_t = 0.0
				Sfx.loop_stop(BeltSfx.loop_key(h, "armor_kit"))
				if UtilityBelt.take(h, "armor_kit", 1) > 0:
					h.armor = minf(h.max_armor, h.armor + h.max_armor * repair_frac(h))
					BeltSfx.play(h, "armor_kit", "end")
					h.m.fx.burst(h.pos + Vector3(0, 1.2, 0), Color("dfe9f7"), 16, 2.5, 0.5, -3.0)
	BeltSfx.channel(h, h.drink_id, h.drink_t > 0.0)
	BeltSfx.channel(h, "armor_kit", h.kit_t > 0.0)
