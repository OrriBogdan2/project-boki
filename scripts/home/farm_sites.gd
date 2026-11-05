class_name FarmSites
extends RefCounted
## Construction on the farm (docs/decisions/0004-farm-building.md). Putting down a new building in
## build mode is free: it leaves a construction SITE, the deco entry carries
## e["site"] = {need, got, to, up, cost, paid, steps}. The materials (gems, wood, stone, Ember Coals,
## fibre) are spent as the build goes, in STEPS quarters: each quarter's share is paid when its first
## swing is due, and with too little of a material the site waits ("Needs 2 more wood") until you
## bring it. The player hammers by holding interact (FarmHob), and Boki walk over and build it, one
## swing at a time (HomeWork job "build", element Craft; any Boki that can work will, a Craft knack
## makes the swings quicker). When the last swing lands the site becomes the finished building.
## Upgrades (tier 1 to 3, e["t"]) are the same thing on a building that already stands: it keeps
## working while the scaffolding is up (site.up = true).
##
## On the deco entry:
##   t       tier 1..3 (missing = 1)
##   site    {need: swings, got: swings done, to: tier it becomes, up: upgrading a standing building,
##            cost: the materials the whole build takes, paid: what has been spent so far (taking the
##            site down gives it back), steps: how many quarters of the cost are paid}
## Sites are drawn by FarmModels; HomeLayout.stations / fixtures skip new-build sites.

const MATS := ["gems", "wood", "stone", "coals", "fibre"]
const STEPS := 4          # quarters of the build; each one's share of the materials is spent as it starts
const CALL_R := 14.0      # m: Boki this near come to help when you start hammering

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
		if typeof(s.get("cost")) != TYPE_DICTIONARY:
			# a site from before materials were spent in steps: the whole cost was paid up front
			s["cost"] = (s["paid"] as Dictionary).duplicate()
			s["steps"] = STEPS
		s["steps"] = clampi(int(s.get("steps", 0)), 0, STEPS)
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
## Turns a freshly placed deco entry into a site for its first construction. Nothing is paid yet.
static func begin(e: Dictionary, cost: Dictionary) -> void:
	e["site"] = {"need": maxi(1, int(cost.get("labour", 4))), "got": 0, "to": 1, "up": false,
			"cost": _paid(cost), "paid": {}, "steps": 0}
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
	e["site"] = {"need": maxi(1, int(cost.get("labour", 6))), "got": 0, "to": to, "up": true,
			"cost": _paid(cost), "paid": {}, "steps": 0}
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

## Adds one swing to a site; true when that finished it. A site waiting for materials takes none.
static func add_swing(e: Dictionary, n := 1) -> bool:
	if not has_site(e) or stalled(e): return false
	settle(e)
	var s: Dictionary = e["site"]
	s["got"] = mini(int(s["need"]), int(s["got"]) + n)
	return int(s["got"]) >= int(s["need"]) and finish(e)

# ------------------------------------------------------------------ materials, a quarter at a time
## The swing a quarter starts at: quarter k (0-based) begins after this many swings.
static func step_start(need: int, k: int) -> int:
	return need * k / STEPS

## How many quarters the next swing needs paid: every quarter that has begun by now.
static func steps_due(s: Dictionary) -> int:
	var due := 0
	for k in STEPS:
		if step_start(int(s["need"]), k) <= int(s["got"]):
			due += 1
	return due

## What quarter k of the cost is: the shares add up to the whole cost.
static func step_share(cost: Dictionary, k: int) -> Dictionary:
	var out := {}
	for m in cost:
		var n := int(cost[m]) * (k + 1) / STEPS - int(cost[m]) * k / STEPS
		if n > 0: out[m] = n
	return out

## The materials the quarters due but not yet paid ask for.
static func owed(e: Dictionary) -> Dictionary:
	var out := {}
	var s: Dictionary = e["site"]
	for k in range(int(s["steps"]), steps_due(s)):
		var share := step_share(s["cost"], k)
		for m in share:
			out[m] = int(out.get(m, 0)) + int(share[m])
	return out

## True when the build waits for materials.
static func stalled(e: Dictionary) -> bool:
	return has_site(e) and not can_pay(owed(e))

## What is missing, by material: {"wood": 2}.
static func missing(e: Dictionary) -> Dictionary:
	var out := {}
	var owe := owed(e)
	for m in owe:
		var lack := int(owe[m]) - have(String(m))
		if lack > 0: out[m] = lack
	return out

## "Needs 2 more wood" ("" when the build can go on).
static func need_text(e: Dictionary) -> String:
	var parts: Array = []
	var lack := missing(e)
	for m in MATS:
		if lack.has(m): parts.append("%d more %s" % [int(lack[m]), label(m)])
	return "" if parts.is_empty() else "Needs " + " and ".join(parts)

## Spends the quarters that are due (when they can be paid). Returns what was spent.
static func settle(e: Dictionary) -> Dictionary:
	var spent := {}
	var s: Dictionary = e["site"]
	var due := steps_due(s)
	while int(s["steps"]) < due:
		var share := step_share(s["cost"], int(s["steps"]))
		if not can_pay(share):
			break
		pay(share)
		for m in share:
			s["paid"][m] = int(s["paid"].get(m, 0)) + int(share[m])
			spent[m] = int(spent.get(m, 0)) + int(share[m])
		s["steps"] = int(s["steps"]) + 1
	return spent

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
		if stalled(e): continue
		var u := int(e["u"])
		var left := int(e["site"]["need"]) - int(e["site"]["got"])
		var nm := String(HomeLayout.CATALOG[String(e["id"])]["name"]).to_lower()
		for slot in mini(slots, left):
			hw._job("build:%d:%d" % [u, slot], "craft", "build", hw.stand(e, slot), HomeLayout.deco_center(e), {"u": u, "site": true, "what": nm})

## You start hammering: the nearest Boki that can work (CALL_R) drop what they are doing and come to
## take the open swings of this site (hw.jobs). Returns how many were called.
static func call_helpers(hw, e: Dictionary) -> int:
	var at := HomeLayout.deco_center(e)
	var called := 0
	for j in hw.jobs:
		if String(j.get("kind", "")) != "build" or int(j["u"]) != int(e["u"]) or hw.taken.has(j["key"]):
			continue
		var best := {}
		var best_d := CALL_R
		for k in hw.h.kins:
			var near := Vector2(k["pos"].x - at.x, k["pos"].z - at.z).length()
			var on_site: bool = k.has("job") and String(k["job"].get("kind", "")) == "build"
			if near < best_d and not on_site and hw.fit_to_work(k) and hw.takes_job(k["rec"], j):
				best = k
				best_d = near
		if best.is_empty():
			break
		hw.drop(best)
		hw.take(best, j)
		called += 1
	return called

## Is this build job still wanted?
static func valid(J: Dictionary) -> bool:
	var e := entry(int(J["u"]))
	return not e.is_empty() and has_site(e) and not stalled(e)

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
	land(hw, e, J["look"], String(k["rec"]["name"]))

## The player's own swing (FarmHob): the same as a Boki's.
static func player_swing(hw, e: Dictionary) -> void:
	if has_site(e):
		land(hw, e, HomeLayout.deco_center(e), "You")

static func land(hw, e: Dictionary, at: Vector3, who: String) -> void:
	if stalled(e): return
	var up := is_upgrading(e)
	var spent := settle(e)
	if not spent.is_empty():
		hw.h.fx.word(at + Vector3(0, 2.2, 0), "-" + cost_text(spent), Color("d8b07a"))
		hw.h._refresh_top()
	hw.h.fx.dust(at + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6)), 6)
	Sfx.play("build", at, -8.0, 0.15)
	if add_swing(e):
		Sfx.play("unlock", at, -4.0)
		hw.h.fx.burst(at + Vector3(0, 1.4, 0), UI.GOLD, 22, 5.0, 0.8, 8.0, 1.2)
		hw.h.fx.ring(at, 3.0, Color(UI.GOLD, 0.9), 0.5)
		hw.produced(at, "%s %s the %s" % [who, "upgraded" if up else "finished", HomeLayout.CATALOG[String(e["id"])]["name"].to_lower()], "craft", "")
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
