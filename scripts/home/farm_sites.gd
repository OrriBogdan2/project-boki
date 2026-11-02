class_name FarmSites
extends RefCounted
## Construction on the farm (docs/decisions/0003-farm-building.md). Putting down a new building in
## build mode pays gems and materials (wood, stone, Ember Coals, fibre) and leaves a construction
## SITE: the deco entry carries e["site"] = {need, got, to, up}. Boki walk over and build it, one
## swing at a time (HomeWork job "build", element Craft; any Boki that can work will, a Craft knack
## makes the swings quicker). When the last swing lands the site becomes the finished building.
## Upgrades (tier 1 to 3, e["t"]) are the same thing on a building that already stands: it keeps
## working while the scaffolding is up (site.up = true).
##
## On the deco entry:
##   t       tier 1..3 (missing = 1)
##   site    {need: swings, got: swings done, to: tier it becomes, up: upgrading a standing building,
##            paid: the cost that was paid, so taking the site down gives it back}
## Sites are drawn by FarmModels; HomeLayout.stations / fixtures skip new-build sites.

const MATS := ["gems", "wood", "stone", "coals", "fibre"]

static func rules() -> Dictionary:
	return FarmUnlocks.rules()

# ------------------------------------------------------------------ reading an entry
static func has_site(e: Dictionary) -> bool:
	return typeof(e.get("site")) == TYPE_DICTIONARY

## A building that is not standing yet (its first construction).
static func is_site(e: Dictionary) -> bool:
	return has_site(e) and not bool(e["site"].get("up", false))

static func is_upgrading(e: Dictionary) -> bool:
	return has_site(e) and bool(e["site"].get("up", false))

static func tier(e: Dictionary) -> int:
	return clampi(int(e.get("t", 1)), 1, 3)

static func progress(e: Dictionary) -> float:
	if not has_site(e): return 1.0
	return clampf(float(e["site"].get("got", 0)) / maxf(1.0, float(e["site"].get("need", 1))), 0.0, 1.0)

## Saves bring numbers back as floats: tidy one entry (HomeLayout.ensure calls this).
static func clean(e: Dictionary) -> void:
	if e.has("t"): e["t"] = clampi(int(e["t"]), 1, 3)
	if typeof(e.get("site")) == TYPE_DICTIONARY:
		var s: Dictionary = e["site"]
		s["need"] = maxi(1, int(s.get("need", 1))); s["got"] = clampi(int(s.get("got", 0)), 0, int(s["need"]))
		s["to"] = clampi(int(s.get("to", 1)), 1, 3)
		s["up"] = bool(s.get("up", false))
		if typeof(s.get("paid")) != TYPE_DICTIONARY: s["paid"] = {}
	elif e.has("site"):
		e.erase("site")

# ------------------------------------------------------------------ costs
## Does a new one of this go up as a site (not at once)? Only on farms under the building pass.
static func uses_site(id: String) -> bool:
	return FarmUnlocks.gated() and rules()["build"].has(id) and not (rules()["starter"] as Array).has(id)

static func build_cost(id: String) -> Dictionary:
	return (rules()["build"].get(id, {}) as Dictionary).duplicate()

## What upgrading to tier `to` costs ({} if it can't).
static func upgrade_cost(id: String, to: int) -> Dictionary:
	if not (rules()["upgradable"] as Array).has(id) or to < 2 or to > 3:
		return {}
	var tb: Dictionary = rules()["house_upgrade"] if id == "house" else rules()["upgrade"]
	return (tb.get(str(to), {}) as Dictionary).duplicate()

static func have(m: String) -> int:
	match m:
		"gems": return int(Save.d["gems"])
		"coals": return int(Save.d["items"].get("coals", 0))
		_: return Work.mat(m)

static func can_pay(cost: Dictionary) -> bool:
	return short_of(cost) == ""

## The first thing the cost needs more of ("" when there is enough).
static func short_of(cost: Dictionary) -> String:
	for m in MATS:
		if int(cost.get(m, 0)) > have(m):
			return m
	return ""

static func pay(cost: Dictionary) -> void:
	for m in MATS:
		_add(m, -int(cost.get(m, 0)))

static func refund(cost: Dictionary) -> void:
	for m in MATS:
		_add(m, int(cost.get(m, 0)))

static func _add(m: String, n: int) -> void:
	if n == 0: return
	match m:
		"gems": Save.d["gems"] = int(Save.d["gems"]) + n
		"coals": Save.add_item("coals", n)
		_: Work.add_mat(m, n)

static func label(m: String) -> String:
	return {"gems": "gems", "wood": "wood", "stone": "stone", "coals": "coals", "fibre": "fibre"}.get(m, m)

## "10 gems · 6 wood · 4 fibre"
static func cost_text(cost: Dictionary) -> String:
	var out: Array = []
	for m in MATS:
		if int(cost.get(m, 0)) > 0: out.append("%d %s" % [int(cost[m]), label(m)])
	return " · ".join(out)

## The top bar's materials line.
static func mats_text() -> String:
	return "%d wood · %d stone · %d fibre · %d coals" % [Work.mat("wood"), Work.mat("stone"), Work.mat("fibre"), have("coals")]

# ------------------------------------------------------------------ starting and finishing
## Turns a freshly placed deco entry into a site for its first construction. cost was already paid.
static func begin(e: Dictionary, cost: Dictionary) -> void:
	e["site"] = {"need": maxi(1, int(cost.get("labour", 4))), "got": 0, "to": 1, "up": false, "paid": _paid(cost)}
	e["t"] = 1

## Starts an upgrade of a standing building to the next tier. "" if it worked, else why not.
static func start_upgrade(e: Dictionary) -> String:
	var id := String(e.get("id", ""))
	if has_site(e):
		return "It is still being built"
	var to := tier(e) + 1
	var cost := upgrade_cost(id, to)
	if cost.is_empty():
		return "Nothing more to add to this one" if tier(e) >= 3 else "This can't be upgraded"
	var lv := int(cost.get("level", 1))
	if FarmUnlocks.gated() and FarmUnlocks.level() < lv:
		return "Tier %d needs farm level %d" % [to, lv]
	if not can_pay(cost):
		return "Not enough %s" % label(short_of(cost))
	pay(cost)
	e["site"] = {"need": maxi(1, int(cost.get("labour", 6))), "got": 0, "to": to, "up": true, "paid": _paid(cost)}
	return ""

static func _paid(cost: Dictionary) -> Dictionary:
	var out := {}
	for m in MATS:
		if int(cost.get(m, 0)) > 0: out[m] = int(cost[m])
	return out

## Takes a site down: what was paid comes back. The entry is left as it was before (tier kept).
static func cancel(e: Dictionary) -> void:
	if not has_site(e): return
	refund(e["site"].get("paid", {}))
	e.erase("site")

## The last swing: the building stands (or reaches its new tier). True if it just finished.
static func finish(e: Dictionary) -> bool:
	if not has_site(e): return false
	var to := int(e["site"].get("to", 1))
	var was_new := not bool(e["site"].get("up", false))
	e["t"] = maxi(tier(e), to)
	e.erase("site")
	if was_new:
		Progress.add("fb_built", 1)
	return true

## Adds one swing to a site; true when that finished it.
static func add_swing(e: Dictionary, n := 1) -> bool:
	if not has_site(e): return false
	var s: Dictionary = e["site"]
	s["got"] = mini(int(s["need"]), int(s["got"]) + n)
	return int(s["got"]) >= int(s["need"]) and finish(e)

## All the sites on this save's layout (new builds and upgrades).
static func sites(d: Dictionary = Save.d) -> Array:
	var out: Array = []
	for e in HomeLayout.of(d).get("deco", []):
		if has_site(e): out.append(e)
	return out

## Station speed from tier (1.0, 1.25, 1.5).
static func tier_speed(e: Dictionary) -> float:
	var tb: Array = rules()["tier_speed"]
	return float(tb[tier(e) - 1])

static func entry(u: int) -> Dictionary:
	for e in HomeLayout.of(Save.d).get("deco", []):
		if int(e["u"]) == u: return e
	return {}

# ------------------------------------------------------------------ the farm's builders (HomeWork hooks)
## Called by HomeWork.scan(): a job per open swing (up to two Boki at a site at once).
static func scan(hw) -> void:
	var slots := int(rules()["crew_slots"])
	for e in sites():
		var u := int(e["u"])
		var left := int(e["site"]["need"]) - int(e["site"]["got"])
		var nm := String(HomeLayout.CATALOG[String(e["id"])]["name"]).to_lower()
		for slot in mini(slots, left):
			hw._job("build:%d:%d" % [u, slot], "craft", "build", hw.stand(e, slot), HomeLayout.deco_center(e), {"u": u, "site": true, "what": nm})

## Is this build job still wanted?
static func valid(J: Dictionary) -> bool:
	var e := entry(int(J["u"]))
	return not e.is_empty() and has_site(e)

## Any Boki that can work may build; a Craft knack is not needed (but Craft Off on the Job Board
## and a pin to another element still count).
static func takes(rec: Dictionary, _j: Dictionary) -> bool:
	if not Work.can_work(rec) or Work.prio("craft") <= 0:
		return false
	var p := Work.pin(rec)
	return p == "" or p == "craft"

## Building skill: the Craft level, at least 1.
static func level(rec: Dictionary, j: Dictionary) -> int:
	var lv := Work.level(rec, String(j["el"]))
	return maxi(lv, 1) if String(j.get("kind", "")) == "build" else lv

## A swing lands (HomeWork._finish): dust and a thunk; the building appears on the last one.
static func swing(hw, k: Dictionary, J: Dictionary) -> void:
	var e := entry(int(J["u"]))
	if e.is_empty() or not has_site(e): return
	var at: Vector3 = J["look"]
	var up := is_upgrading(e)
	hw.h.fx.dust(at + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6)), 6)
	Sfx.play("build", at, -8.0, 0.15)
	if add_swing(e):
		Sfx.play("unlock", at, -4.0)
		hw.h.fx.burst(at + Vector3(0, 1.4, 0), UI.GOLD, 22, 5.0, 0.8, 8.0, 1.2)
		hw.h.fx.ring(at, 3.0, Color(UI.GOLD, 0.9), 0.5)
		hw.produced(at, "%s %s the %s" % [k["rec"]["name"], "upgraded" if up else "finished", HomeLayout.CATALOG[String(e["id"])]["name"].to_lower()], "craft", "")
		Work.count("built", 1)
		if hw.h.hb: hw.h.hb.apply(false)
		hw.scan_t = 0.0
	Save.save_game()

## Station tiers speed their jobs up (HomeWork._boost).
static func speed(J: Dictionary) -> float:
	if not J.has("u") or String(J.get("kind", "")) == "build":
		return 1.0
	var e := entry(int(J["u"]))
	return tier_speed(e) if not e.is_empty() else 1.0

## Fibre from a harvest (the stalks left over): one per harvest of two or more.
static func on_harvest(n: int) -> void:
	if n >= 2:
		Work.add_mat("fibre", 1)
