class_name Backpacks
extends RefCounted
## Backpack tiers (docs/decisions/0005-equal-footing.md): the Pouch, which everyone has for free, then
## the Satchel, the Pack and the Rucksack, each with more slots (content/rules/equal.json "backpacks").
## Every backpack exists once:
##   at home     Save.d["backpacks"] counts the ones you own by tier; you pick one to bring
##               (Save.d["pack_pick"]), capped by the difficulty tier like gloves and boots
##   brought     it leaves the stash (Save.d["raid_pack"] until the match ends) and is at risk
##   on death    it goes in your deathbox; you are back on the Pouch if revived
##   in a match  never dropped at random: take a bigger one from an enemy's deathbox (yours goes in
##               its place) or buy an upgrade at a shop (shop_price / shop_upgrade)
##   extracted   whatever you wear comes home to the stash (an enemy's pack too)
## The slot count goes through Equal.pack_slots(h), which adds slots(h.backpack).

const POUCH := 0
const COL := UI.ACCENT_HI      # backpacks in the HUD, toasts and the armory: the palette's warm accent text

static func tiers() -> Array:
	return Equal.rules().get("backpacks", [{"name": "Pouch", "slots": 0}])

static func top() -> int:
	return tiers().size() - 1

static func _tier(tier: int) -> Dictionary:
	return tiers()[clampi(tier, 0, top())]

## Slots a backpack tier adds on top of the base pack.
static func slots(tier: int) -> int:
	return int(_tier(tier).get("slots", 0))

static func name_of(tier: int) -> String:
	return String(_tier(tier).get("name", "Pouch"))

## "Satchel (+2 slots)".
static func label(tier: int) -> String:
	if tier <= POUCH:
		return name_of(POUCH)
	return "%s (+%d slots)" % [name_of(tier), slots(tier)]

## The biggest backpack that may be brought at a difficulty tier.
static func cap(diff_tier: int) -> int:
	var caps: Array = Equal.rules().get("backpack_cap_by_tier", [top()])
	return mini(top(), int(caps[clampi(diff_tier, 0, caps.size() - 1)]))

# ------------------------------------------------------------------ the farm side
## On load (Econ.ensure): the owned list, the pick, and a backpack left out by a crash.
static func ensure() -> void:
	_ensure_list()
	if not Save.d.has("pack_pick"):
		Save.d["pack_pick"] = POUCH
	recover()

static func _ensure_list() -> void:
	var have: Array = Save.d.get("backpacks", [])
	while have.size() < tiers().size():
		have.append(0)
	Save.d["backpacks"] = have

static func owned(tier: int) -> int:
	if tier <= POUCH:
		return 1
	var have: Array = Save.d.get("backpacks", [])
	return int(have[tier]) if tier < have.size() else 0

static func _add(tier: int, n: int) -> void:
	if tier <= POUCH:
		return
	_ensure_list()
	Save.d["backpacks"][tier] = maxi(0, owned(tier) + n)

## The backpack that will come at this difficulty: the pick if you own it and it is allowed, else the
## biggest one you own under the cap, else the Pouch.
static func pick(diff_tier: int) -> int:
	var want := int(Save.d.get("pack_pick", POUCH))
	for tier in range(mini(want, cap(diff_tier)), POUCH, -1):
		if owned(tier) > 0:
			return tier
	return POUCH

static func set_pick(tier: int) -> void:
	Save.d["pack_pick"] = clampi(tier, POUCH, top())

## Setting out: the backpack leaves the stash and rides with you. Returns its tier.
static func take_home(diff_tier: int) -> int:
	var tier := pick(diff_tier)
	_add(tier, -1)
	Save.d["raid_pack"] = tier
	return tier

## A match that never ended (a crash): the brought backpack goes back in the stash.
static func recover() -> void:
	var out_now := int(Save.d.get("raid_pack", POUCH))
	Save.d["raid_pack"] = POUCH
	_add(out_now, 1)

## The match result's backpack (r["backpack"]: what you wore out, POUCH if you didn't make it).
static func settle(r: Dictionary) -> void:
	Save.d["raid_pack"] = POUCH
	_add(int(r.get("backpack", POUCH)), 1)

## What goes in the match result: your backpack if you got out, else nothing.
static func home_tier(h, extracted: bool) -> int:
	return int(h.backpack) if extracted else POUCH

## Buying one at the armory, for gems and scrap. Returns "" or why not.
static func buy(tier: int) -> String:
	if tier <= POUCH or tier > top():
		return "Not for sale"
	var cost := price(tier)
	if int(Save.d.get("gems", 0)) < cost[0]:
		return "Not enough gems"
	if int(Save.d.get("scrap", 0)) < cost[1]:
		return "Not enough scrap"
	Save.d["gems"] = int(Save.d["gems"]) - cost[0]
	Save.d["scrap"] = int(Save.d["scrap"]) - cost[1]
	_add(tier, 1)
	return ""

## [gems, scrap] for a backpack at the armory.
static func price(tier: int) -> Array:
	var cost: Array = _tier(tier).get("cost", [0, 0])
	return [int(cost[0]), int(cost[1])]

# ------------------------------------------------------------------ the match side
## Wear a backpack tier; the slot count follows (Gear.apply_worn through Equal.pack_bonus).
static func wear(h, tier: int) -> void:
	h.backpack = clampi(tier, POUCH, top())
	h.refresh_gear()

## A bot's backpack: by difficulty, now and then bigger than the Pouch (so a bot's box can hold one).
static func bot_start(h, rng: RandomNumberGenerator, diff: String) -> void:
	var odds := float((Equal.rules().get("bot_backpack", {}) as Dictionary).get(diff, 0.0))
	var diff_tier: int = h.m.tier if h.m != null else 0
	var roll := RandomNumberGenerator.new()      # its own stream: the bot's gear rolls stay as they were
	roll.seed = rng.seed ^ hash("backpack")
	if roll.randf() < odds and cap(diff_tier) > POUCH:
		h.backpack = roll.randi_range(1, cap(diff_tier))

## Into the deathbox: the box holds the backpack, the hunter is on the Pouch.
static func into_box(h, b: Dictionary) -> void:
	b["backpack"] = int(h.backpack)
	h.backpack = POUCH

## Is the backpack in this box bigger than the one you wear?
static func box_upgrade(h, b: Dictionary) -> bool:
	return int(b.get("backpack", POUCH)) > int(h.backpack)

## The deathbox loot row for its backpack, or {} when it holds none.
static func box_row(h, b: Dictionary) -> Dictionary:
	var tier := int(b.get("backpack", POUCH))
	if tier <= POUCH:
		return {}
	return {"key": "backpack", "name": label(tier), "sub": "Backpack: more slots for what you carry home",
		"icon": "satchel", "col": COL, "upgrade": box_upgrade(h, b)}

## Takes a bigger backpack from a box: yours goes in its place (a Pouch is nothing to leave).
## Returns true when it swapped.
static func take_from_box(m, h, b: Dictionary) -> bool:
	if not box_upgrade(h, b):
		return false
	var theirs := int(b["backpack"])
	b["backpack"] = int(h.backpack)
	wear(h, theirs)
	if h == m.player and m.hud:
		m.hud.toast_small("%s  ·  %d slots now" % [name_of(theirs), int(h.pack_cap)], COL)
	return true

## The shop pass: the run gems an upgrade to the next tier costs (-1 when there is none).
static func shop_price(h) -> int:
	var next := int(h.backpack) + 1
	if next > top():
		return -1
	var costs: Array = Equal.rules().get("backpack_shop", [])
	return int(costs[next]) if next < costs.size() else -1

## Buys the next tier at a shop with run gems; the old backpack is traded in. Returns true if bought.
static func shop_upgrade(h) -> bool:
	var cost := shop_price(h)
	if cost < 0 or int(h.gems) < cost:
		return false
	h.gems -= cost
	wear(h, int(h.backpack) + 1)
	return true

## The backpack's hover text: [[line, colour, size?]...].
static func tip(h) -> Array:
	var tier := int(h.backpack)
	var how := "Gear and treasure you're carrying home. Extract to keep it all; die and it stays in your deathbox, "
	how += "backpack too. Bring a bigger one from your armory, take one from a deathbox or buy one at a shop."
	return [["%s  %d/%d" % [name_of(tier), h.pack.size(), h.pack_cap], HudStyle.INK],
		[how, HudStyle.INK, 14]]
