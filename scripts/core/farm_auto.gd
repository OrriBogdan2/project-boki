class_name FarmAuto
extends RefCounted
## Farming is optional (DECISIONS 2026-11-08). Boki can be put on any farm job (Work.JOBS), and
## Auto-farm, one toggle on the Job Board and a Boki's card, sends every free Boki to whatever the
## farm needs: watering, harvesting, replanting, cooking, filling feeders and selling the surplus.
## Auto-farm and the farm's work while you're away yield EFF of what doing it by hand does, so
## farming by hand stays the best yield but is never required.
##
## This file is the rules (no nodes): HomeWork runs the live jobs, Work.catch_up calls away().
##
## On the save (Save.d["work"]):
##   "auto"      true while Auto-farm is on
##   "auto_acc"  the yield cut's carried fraction, so EFF holds exactly over many small harvests

const EFF := 0.8            # Auto-farm and away yield as a share of hand yield (hand stays best)
const KEEP := 10            # crops of a kind never sold (feeders and the cooking pot draw on them)
const SELL_LOAD := 4        # crops a Boki takes to sell per trip
const HAND_SELL := 0.4      # share of a crop's price the market pays when you sell it yourself
const CYCLE_WORK := 12.0    # seconds of a Boki's walking and work per sowing or harvest, away
const OVEN_SECS := 60.0     # seconds per Hearth Oven batch (1 wood -> 2 kibble) while you're away

static func on() -> bool:
	return bool(Work.ensure().get("auto", false))

static func set_on(v: bool) -> void:
	Work.ensure()["auto"] = v

## v11 -> v12 (Save._migrate_11_to_12): Auto-farm starts off; offline work now counts up to 8 hours.
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("work")) != TYPE_DICTIONARY:
		data["work"] = {}
	data["work"]["auto"] = false
	data["work"]["auto_acc"] = 0.0

## n made by hand -> what the farm makes on its own (EFF, the fraction carried to the next call).
static func cut(n: int, eff := EFF) -> int:
	if eff >= 1.0:
		return n
	var w := Work.ensure()
	var acc := float(w.get("auto_acc", 0.0)) + n * eff
	var out := int(floor(acc))
	w["auto_acc"] = acc - out
	return out

## A Boki's harvest under Auto-farm: takes the cut back off the crops HomeWork just added.
static func trim(crop: String, n: int) -> int:
	var kept := cut(n)
	Save.d["crops"][crop] = maxi(0, int(Save.d["crops"].get(crop, 0)) - (n - kept))
	return kept

## The seed a Boki sows: your most plentiful common seed (never the rare ones).
static func seed_pick() -> String:
	var best := ""
	var bn := 0
	for s in Data.CROPS:
		if float(Data.CROPS[s].get("weight", 1.0)) < 1.0: continue
		var n := int(Save.d["seeds"].get(s, 0))
		if n > bn:
			bn = n
			best = s
	return best

## Gems the market pays you for one crop sold by hand.
static func hand_gain(crop: String) -> int:
	return maxi(1, int(round(int(Data.CROPS[crop]["price"]) * HAND_SELL)))

## The crop you have most of over KEEP ("" if none).
static func surplus() -> String:
	var best := ""
	var bn := KEEP
	for c in Save.d["crops"]:
		if Data.CROPS.has(c) and int(Save.d["crops"][c]) > bn:
			bn = int(Save.d["crops"][c])
			best = c
	return best

## Sells up to `most` surplus crops at EFF of the hand price. Returns [crops sold, gems].
static func sell(most: int) -> Array:
	var n := 0
	var hand := 0
	while n < most:
		var c := surplus()
		if c == "": break
		Save.d["crops"][c] = int(Save.d["crops"][c]) - 1
		hand += hand_gain(c)
		n += 1
	var gems := maxi(1, int(floor(hand * EFF))) if n > 0 else 0
	Save.d["gems"] = int(Save.d.get("gems", 0)) + gems
	return [n, gems]

## The Boki on the roster that would do this farm job (Work.does): put on it, or free under Auto-farm.
static func crew(job: String) -> Array:
	var out: Array = []
	for r in Save.d.get("roster", []):
		if typeof(r) == TYPE_DICTIONARY and job != "" and Work.does(r, job): out.append(r)
	return out

# ------------------------------------------------------------------ while you were away
## The plots, the oven and the market for `secs` away (already capped by Work.AWAY_MAX), with the
## Boki on those jobs. Returns lines for the "While you were away" note.
static func away(secs: float) -> Array:
	var jobs := {}
	for job in ["water", "harvest", "replant", "cook", "sell"]:
		jobs[job] = not crew(job).is_empty()
	var lines: Array = []
	var got := grow(secs, jobs, EFF)
	var parts: Array = []
	for c in got: parts.append("%d %s" % [got[c], Data.CROPS[c]["name"]])
	if not parts.is_empty():
		lines.append("+%s picked by your Boki" % ", ".join(parts))
	if jobs["cook"] and HomeLayout.stations(Save.d).any(func(s): return s["id"] == "hearth_oven"):
		var room := (HomeWork.OVEN_KEEP - int(Save.d["items"].get("kibble", 0))) / 2
		var n := mini(mini(Work.mat("wood"), room), int(secs * EFF / OVEN_SECS))
		if n > 0:
			Work.add_mat("wood", -n)
			Save.add_item("kibble", n * 2)
			lines.append("+%d kibble from the Hearth Oven (%d wood)" % [n * 2, n])
	if jobs["sell"]:
		var r := sell(1 << 20)
		if int(r[0]) > 0: lines.append("Sold %d spare crops for %d gems" % r)
	return lines

## Runs every plot for `secs` with Boki on `jobs` (water, harvest, replant: true), at `eff` of hand
## yield, straight on the save. Returns {crop: picked}. Watered by a Boki counts as tended.
static func grow(secs: float, jobs: Dictionary, eff: float) -> Dictionary:
	var got := {}
	for arr in (["plots", "gh_plots"] if Save.has_building("greenhouse") else ["plots"]):
		var per := Data.WATER_TIME * (0.5 if arr == "gh_plots" else 1.0)
		for i in (Save.d[arr] as Array).size():
			var pd: Dictionary = Save.d[arr][i]
			var by_water: bool = arr == "plots" and FarmWater.plot_near(Save.d, i)
			var t: float = secs
			while t > 0.0:
				if String(pd["crop"]) == "":
					var sd := seed_pick()
					if not jobs.get("replant", false) or sd == "": break
					Save.d["seeds"][sd] = int(Save.d["seeds"][sd]) - 1
					pd.merge({"crop": sd, "stage": 0, "care": 0}, true)
					t -= CYCLE_WORK
				var crop := String(pd["crop"])
				var g := int(Data.CROPS[crop]["grow"])
				if int(pd["stage"]) < g:
					if not (jobs.get("water", false) or by_water): break
					var need := g - int(pd["stage"])
					var steps := mini(need, int(t / per))
					pd["stage"] = int(pd["stage"]) + steps
					if jobs.get("water", false): pd["care"] = int(pd.get("care", 0)) + steps
					pd.merge({"wt": 0.0, "wet": 0}, true)
					if steps < need: break
					t -= steps * per
				if not jobs.get("harvest", false): break
				var n := cut(2 + (1 if int(pd.get("care", 0)) * 2 >= g else 0), eff)
				Save.d["crops"][crop] = int(Save.d["crops"].get(crop, 0)) + n
				got[crop] = int(got.get(crop, 0)) + n
				pd.merge({"crop": "", "stage": 0, "care": 0, "wt": 0.0, "wet": 0}, true)
				pd.erase("tend")
				t -= CYCLE_WORK
	return got
