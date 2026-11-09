class_name UtilityUse
extends RefCounted
## What each belt item does when you press its key (UtilityBelt holds the charges). Item data is in
## content/utility/*.json; "use" picks the behaviour:
##   drink   a tonic: a short, open channel, then a flat heal (all in the item's "channel" data)
##   repair  an armor kit: the same channel, then armor to full
##   mend    heal 40 and 20 armor at once
##   smoke   a cloud that hides everyone in it
##   pad     a launch pad on the ground
##   scan    reveal rival hunters nearby
##   key     a Rift Key or chest key: open the lock beside you, or ping the nearest one (BeltKeys)
##   fx      run the item's "effects" list through Effects (haste, shield, ...)
## The drink and repair take time and spill if you are hit (Hunter._interrupt_consume): nothing is
## spent unless they finish. The rest take effect at once and spend one charge.

const MEND_HP := 40.0
const MEND_ARMOR := 20.0
const SCAN_RANGE := 26.0        # tiles
const SCAN_TIME := 3.0          # seconds rivals stay revealed

## One number of an item's "channel" data (time s, move = speed multiplier while channelling, heal hp).
static func channel(id: String, key: String) -> float:
	return float((UtilityBelt.def(id).get("channel", {}) as Dictionary).get(key, 1.0))

## The speed multiplier for a hunter who is drinking or repairing (1.0 otherwise).
static func channel_move(h: Hunter) -> float:
	if h.drink_t > 0.0:
		return channel("tonic", "move")
	return channel("armor_kit", "move") if h.kit_t > 0.0 else 1.0

static func use_of(id: String) -> String:
	return String(UtilityBelt.def(id).get("use", "fx"))

## Is there anything for this item to do right now? (A tonic at full health buzzes instead.)
static func can_use(h: Hunter, id: String) -> bool:
	match use_of(id):
		"drink": return h.hp < h.max_hp - 0.5
		"repair": return h.armor < h.max_armor - 0.5
		"mend": return h.hp < h.max_hp - 0.5 or h.armor < h.max_armor - 0.5
	return true

## Starts the item in belt slot i. Returns false if it could not start.
static func start(h: Hunter, i: int, id: String) -> bool:
	var m = h.m
	var d: Dictionary = UtilityBelt.def(id)
	var col: Color = d.get("col", Color.WHITE)
	if use_of(id) == "key":
		return BeltKeys.use(h, id)       # the lock spends the key when it opens
	match use_of(id):
		"drink":
			h._fold_for_action()
			h.drink_t = channel(id, "time")
			h.vuln_fx_t = 0.0
			m.sfx("pickup", h.pos, -6.0, 0.7)
			m.fx.word(h.pos + Vector3(0, 2.3, 0), "VULNERABLE", Color("ff6a4a"))
			return true
		"repair":
			h._fold_for_action()
			h.kit_t = channel(id, "time")
			h.vuln_fx_t = 0.0
			m.sfx("build", h.pos, -6.0, 1.3)
			m.fx.word(h.pos + Vector3(0, 2.3, 0), "VULNERABLE", Color("ff6a4a"))
			return true
		"mend":
			h.heal(MEND_HP)
			h.armor = minf(h.max_armor, h.armor + MEND_ARMOR)
			m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 16, 3.0, 0.6, -3.0)
			m.sfx("heal", h.pos, -2.0, 1.1)
		"smoke":
			var n := Models.gear_smoke()
			n.position = h.pos
			m.add_child(n)
			m.smokes.append({"pos": h.pos, "r": 3.6, "t": 8.0, "node": n})
			m.sfx("cloak", h.pos, 0.0, 0.7)
		"pad":
			_pad(h, col)
		"scan":
			for o in m.hunters:
				if o.team != h.team and not o.out and o.flat_dist(h) < SCAN_RANGE:
					o.reveal_t = maxf(o.reveal_t, SCAN_TIME)
			m.fx.ring(h.pos, SCAN_RANGE, Color(col, 0.6), 0.8)
			m.sfx("ping", h.pos, 0.0, 0.8)
		_:
			Effects.run((d.get("effects", []) as Array).duplicate(true), h,
					{"slot": "utility", "ability": id, "level": 1})
			m.sfx("skill", h.pos, -4.0, 1.0)
	# the instant ones are spent now; the channelled ones when they finish (tick)
	h.reveal_t = maxf(h.reveal_t, 0.6)
	UtilityBelt.take(h, id, 1)
	if i < UtilityBelt.SLOTS and not (h.belt[i] as Dictionary).is_empty():
		h.belt[i]["cd"] = float(d.get("cd", 0.0))
	return true

static func _pad(h: Hunter, col: Color) -> void:
	var m = h.m
	var d := h.aim_dir()
	var at := Vector3(h.pos.x + d.x * 1.6, h.pos.y, h.pos.z + d.y * 1.6)
	if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
		at = h.pos
	at.y = m.world.ground_at(at.x, at.z) if not m.world.is_void(at.x, at.z) else h.pos.y
	var n := Models.gear_pad(col)
	n.position = at
	m.add_child(n)
	m.gpads.append({"pos": at, "t": 20.0, "node": n, "cd": {}})
	m.sfx("throw", h.pos, -2.0, 1.2)

## Every step: a drink or repair in progress runs down, then spends its charge. Knocked out of it
## (down, stunned, rolling, gliding) and it spills with nothing used.
static func tick(h: Hunter, dt: float) -> void:
	if h.drink_t > 0.0:
		if h.downed or h.stun_t > 0.0 or h.roll_t > 0.0 or h.gliding or h.out:
			h.drink_t = 0.0
		else:
			h.drink_t -= dt
			if h.drink_t <= 0.0:
				h.drink_t = 0.0
				if UtilityBelt.take(h, "tonic", 1) > 0:
					h.heal(channel("tonic", "heal") * (1.0 + 0.4 * float(h.perk_n("remedy")) + h.gear_stat("tonic")))
					h.m.sfx("heal", h.pos, -2.0)
					h.m.fx.burst(h.pos + Vector3(0, 1.2, 0), Color("8ff0a0"), 14, 2.5, 0.5, -3.0)
	if h.kit_t > 0.0:
		if h.downed or h.stun_t > 0.0 or h.roll_t > 0.0 or h.gliding or h.out:
			h.kit_t = 0.0
		else:
			h.kit_t -= dt
			if h.kit_t <= 0.0:
				h.kit_t = 0.0
				if UtilityBelt.take(h, "armor_kit", 1) > 0:
					h.armor = h.max_armor
					h.m.sfx("shield", h.pos, -2.0, 1.2)
					h.m.fx.burst(h.pos + Vector3(0, 1.2, 0), Color("dfe9f7"), 16, 2.5, 0.5, -3.0)
