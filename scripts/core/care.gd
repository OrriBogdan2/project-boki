class_name Care
## Raising a kin: four needs that drift over time, likes and dislikes you find out by trying,
## a nature from its personality, four trained stats, bond ranks, life stages, eggs and shimmers.
## Everything lives on the kin's save record, so it travels into matches and to other players.

const NEEDS := ["food", "energy", "joy", "clean"]
const NEED_INFO := {
	"food": {"name": "Full", "col": Color("f2a24a")},
	"energy": {"name": "Energy", "col": Color("8fd0ff")},
	"joy": {"name": "Happy", "col": Color("ff8fb0")},
	"clean": {"name": "Clean", "col": Color("8fe3c8")},
}
## How fast each need drops at home, per minute. Sleeping refills energy instead.
const DECAY := {"food": 1.5, "energy": 0.7, "joy": 0.6, "clean": 0.45}
## What an expedition takes out of the kin that went.
const MATCH_COST := {"food": -26.0, "energy": -34.0, "clean": -30.0}

## Starving: hours a kin has spent with nothing in it (food at zero), real time, at home or away.
## Each stage keeps the ones before it. A meal takes 4 hours off; being fed (food over 20) undoes it
## three times as fast as it built up. Feeders keep it from ever starting. "dead" only counts while
## content/rules/care.json natural_death is on (off: neglect bottoms out at sick).
const STARVE := {"weak": 6.0, "refuse": 18.0, "sick": 30.0, "dead": 72.0}
const STARVE_INFO := {
	"starving": ["Starving", "Hasn't eaten in a while. Feed it, or fill a feeder."],
	"weak": ["Weak from hunger", "Slow, and weaker on expeditions. Losing trust in you."],
	"refuse": ["Too weak to go out", "Won't come on expeditions until it's eaten."],
	"sick": ["Sick from hunger", "Ill and miserable. Feed it and it will slowly get better."],
}

const STATS := {
	"power": {"name": "Power", "col": Color("ff7a5a"), "desc": "+0.4% damage a point", "drill": "Dummy strikes"},
	"guard": {"name": "Guard", "col": Color("e6c26a"), "desc": "+0.5% health a point", "drill": "Brace and hold"},
	"speed": {"name": "Speed", "col": Color("6ad8ff"), "desc": "+0.25% speed a point", "drill": "Hoop dash"},
	"focus": {"name": "Focus", "col": Color("b9a6f5"), "desc": "Skill recharges 0.3% faster a point", "drill": "Still pond"},
}

# ------------------------------------------------------------------ inborn gifts (IVs)
## Like a Pokemon's IVs: what a kin is born with, 0 to 31 in each of five stats, set when it hatches
## or is caught and never trained. Bred kin take IV_INHERIT of them from their parents. The effect
## is small and capped (IV_BONUS at 31, linear from 0), so a flawless kin is only a little ahead of
## a plain one: everything that reads them goes through iv_mult().
const IV_MAX := 31
const IV_KEYS := ["hp", "atk", "spd", "work", "bond"]
const IVS := {
	"hp": {"name": "Health", "col": Color("8fe39a"), "desc": "health in a match"},
	"atk": {"name": "Power", "col": Color("ff7a5a"), "desc": "damage in a match"},
	"spd": {"name": "Speed", "col": Color("6ad8ff"), "desc": "running speed in a match"},
	"work": {"name": "Work", "col": Color("f2c84a"), "desc": "how fast it does farm jobs"},
	"bond": {"name": "Bond", "col": Color("ffb3c6"), "desc": "how fast it fills your bond meter"},
}
## The most a stat can gain, at 31 (0 adds nothing). Speed is held lower: a step ahead in a chase
## matters more than a little extra health.
const IV_BONUS := {"hp": 0.10, "atk": 0.10, "spd": 0.05, "work": 0.10, "bond": 0.10}
## Stats a bred kin takes from a parent (each from a random one of the two); the rest are fresh.
## IV_INHERIT_MAX is the ceiling for a future nest upgrade or rare item (Care.breed's inherit_n):
## nothing in the game raises it yet.
const IV_INHERIT := 3
const IV_INHERIT_MAX := 5
## Rare Eggs from boss lairs: this many stats are always at least IV_RARE_FLOOR.
const IV_RARE_HIGH := 3
const IV_RARE_FLOOR := 26
const IV_EXPLAIN := "IVs are what a Boki is born with: 0 to 31 a stat, fixed for life, passed down when Boki breed. 31 is up to 10% better than 0."

const BONDS := [
	[0.0, "Wary", "Might refuse a risky throw."],
	[25.0, "Friendly", "Follows you around the farm."],
	[50.0, "Close", "Starts picking up words. Skills hit 5% harder."],
	[70.0, "Devoted", "Rushes to revive you without a second thought."],
	[90.0, "Soulbound", "Never refuses you. +10% health and damage."],
]

const STAGES := [[1, "Hatchling"], [4, "Youngling"], [8, "Grown"], [16, "Elder"]]

## Natures from the two strongest traits.
const NATURES := {
	"bravery+temper": "Fiery", "bravery+loyalty": "Valiant", "bravery+curiosity": "Daring",
	"loyalty+temper": "Protective", "curiosity+loyalty": "Gentle", "curiosity+temper": "Mischievous",
}

## Things a kin can love or hate. Foods are crops plus what the stall sells.
const FOODS := {
	"kibble": {"name": "Boki kibble", "col": Color("c8a26a"), "food": 30.0, "joy": 0.0, "price": 6, "desc": "Plain and filling."},
	"sweetbun": {"name": "Sweet bun", "col": Color("f6c6a0"), "food": 18.0, "joy": 18.0, "price": 14, "desc": "A treat. Makes any Boki happy."},
	"tonicbrew": {"name": "Pep brew", "col": Color("8ff0a0"), "food": 6.0, "joy": 4.0, "energy": 35.0, "price": 18, "desc": "Wakes a tired Boki right up."},
}
const PLAYS := ["fetch", "brush", "bath", "chat", "pet"]
## Play is practice: a finished game of fetch trains this stat by one point, as long as the Boki has
## the energy (PLAY_TRAIN_ENERGY, the same line under which the Training post drill teaches less).
const PLAY_TRAINS := {"fetch": "speed"}
const PLAY_TRAIN_ENERGY := 35.0
const PLAY_NAMES := {"fetch": "playing fetch", "brush": "being brushed", "bath": "baths", "chat": "chatting", "pet": "scratches"}

## Fills in anything an older record is missing. Likes come from the kin's id, so they're fixed.
static func ensure(rec: Dictionary) -> void:
	if rec.is_empty():
		return
	if not rec.has("needs"):
		rec["needs"] = {"food": 70.0, "energy": 80.0, "joy": 70.0, "clean": 75.0}
	if not rec.has("needs_t"):
		rec["needs_t"] = Time.get_unix_time_from_system()
	if not rec.has("stats"):
		rec["stats"] = {"power": 0, "guard": 0, "speed": 0, "focus": 0}
	if not rec.has("likes"):
		var r := RandomNumberGenerator.new(); r.seed = hash(String(rec.get("uid", "x")) + "likes")
		var foods: Array = Data.CROPS.keys() + FOODS.keys()
		var love: String = foods[r.randi() % foods.size()]
		var hate: String = love
		while hate == love:
			hate = foods[r.randi() % foods.size()]
		rec["likes"] = {"food": love, "hates": hate, "play": PLAYS[r.randi() % PLAYS.size()]}
	if not rec.has("known"):
		rec["known"] = []          # which of food / hates / play you've found out
	if not rec.has("ivs") or typeof(rec["ivs"]) != TYPE_DICTIONARY:
		rec["ivs"] = ivs_from_uid(String(rec.get("uid", "x")))     # old saves: fixed by the kin's id
	Unique.ensure(rec)          # its inborn size, looks and habits (old saves: fixed by the kin's id)
	for old in ["pet_m", "played", "fed_m", "trained_m", "talked"]:
		rec.erase(old)              # the old once-per-expedition care stamps (now care_day)

static func need(rec: Dictionary, n: String) -> float:
	ensure(rec)
	return float(rec["needs"].get(n, 50.0))

static func change(rec: Dictionary, n: String, amt: float) -> float:
	ensure(rec)
	var before := float(rec["needs"].get(n, 50.0))
	rec["needs"][n] = clampf(before + amt, 0.0, 100.0)
	return float(rec["needs"][n]) - before

## Time passing at home. sleeping: curled up in bed or napping (or indoors); raining: rain on the
## farm, which some kinds love and some hate (BokiQuirks.rain_joy).
static func tick(rec: Dictionary, secs: float, sleeping := false, raining := false) -> void:
	ensure(rec)
	if rec.get("boxed", false):
		# asleep in the Kin Burrow: nothing changes
		rec["needs_t"] = Time.get_unix_time_from_system()
		return
	var mins := secs / 60.0
	var nd: Dictionary = rec["needs"]
	var f0 := float(nd["food"])
	var species := String(rec.get("species", ""))
	var rate := DECAY["food"] * BokiQuirks.food_rate(species) / 60.0 * (0.5 if sleeping else 1.0)
	nd["food"] = clampf(float(nd["food"]) - rate * secs, 0.0, 100.0)
	# the part of this stretch spent with nothing in it counts toward starving
	starve_step(rec, secs, maxf(0.0, secs - f0 / maxf(0.0001, rate)) if float(nd["food"]) <= 0.0 else 0.0)
	nd["clean"] = clampf(float(nd["clean"]) - DECAY["clean"] * mins * (0.2 if sleeping else 1.0), 0.0, 100.0)
	if sleeping:
		nd["energy"] = clampf(float(nd["energy"]) + 9.0 * mins, 0.0, 100.0)
	else:
		nd["energy"] = clampf(float(nd["energy"]) - DECAY["energy"] * mins, 0.0, 100.0)
	# a hungry, grubby or worn-out kin gets glum faster
	var glum := 1.0 + (1.0 if float(nd["food"]) < 25.0 else 0.0) + (0.5 if float(nd["clean"]) < 20.0 else 0.0) + (0.5 if float(nd["energy"]) < 15.0 else 0.0)
	nd["joy"] = clampf(float(nd["joy"]) - DECAY["joy"] * mins * glum * (0.3 if sleeping else 1.0), 0.0, 100.0)
	if raining and not sleeping:
		nd["joy"] = clampf(float(nd["joy"]) + BokiQuirks.rain_joy(species) * mins, 0.0, 100.0)
	if starve_h(rec) >= STARVE["sick"]:
		# sick from hunger: no energy and no joy to speak of
		nd["energy"] = minf(float(nd["energy"]), 35.0)
		nd["joy"] = minf(float(nd["joy"]), 25.0)
	rec["needs_t"] = Time.get_unix_time_from_system()

## The time you were away: it sleeps a lot of it off, and nothing drops below a floor (unless it
## was already hungry when you left). Returns the time away beyond half a day (up to two weeks):
## Econ.catch_up_all runs that slowly, hour by hour, with the feeders.
static func catch_up(rec: Dictionary) -> float:
	ensure(rec)
	if rec.get("boxed", false):
		rec["needs_t"] = Time.get_unix_time_from_system()
		return 0.0
	var all := clampf(Time.get_unix_time_from_system() - float(rec["needs_t"]), 0.0, 14.0 * 86400.0)
	var gone := minf(all, 12.0 * 3600.0)
	if gone > 30.0:
		var nd: Dictionary = rec["needs"]
		var floors := {"food": 25.0, "joy": 30.0, "clean": 25.0}
		var before := {}
		for k in floors: before[k] = float(nd[k])
		var st0 := float(rec.get("starve", 0.0))
		tick(rec, gone * 0.5, true)
		tick(rec, minf(gone * 0.5, 1800.0), false)
		for k in floors:
			nd[k] = maxf(float(nd[k]), minf(float(before[k]), floors[k]))
		# the floor means it found enough to get by; one that was already empty starved the whole time
		var st1 := st0 + gone if float(before["food"]) <= 0.5 else minf(float(rec.get("starve", 0.0)), st0)
		st1 = minf(st1, starve_cap())
		if st1 > 0.0: rec["starve"] = st1
		else: rec.erase("starve")
	rec["needs_t"] = Time.get_unix_time_from_system()
	return maxf(0.0, all - 12.0 * 3600.0)

# ------------------------------------------------------------------ starving
static func starve_h(rec: Dictionary) -> float:
	return float(rec.get("starve", 0.0)) / 3600.0

## "" (fine), "starving", "weak", "refuse", "sick" or "dead".
static func starve_stage(rec: Dictionary) -> String:
	var h := starve_h(rec)
	if h >= STARVE["dead"] and bool(Content.rules("care")["natural_death"]): return "dead"
	if h >= STARVE["sick"]: return "sick"
	if h >= STARVE["refuse"]: return "refuse"
	if h >= STARVE["weak"]: return "weak"
	if float(rec.get("starve", 0.0)) > 0.0 and need(rec, "food") <= 0.5: return "starving"
	return ""

## secs of time passing; zero_secs of it with an empty belly (defaults to all of it if food is 0).
static func starve_step(rec: Dictionary, secs: float, zero_secs := -1.0) -> void:
	if rec.get("boxed", false):
		return
	var z := zero_secs if zero_secs >= 0.0 else (secs if need(rec, "food") <= 0.5 else 0.0)
	var st := float(rec.get("starve", 0.0))
	if z > 0.0:
		if st / 3600.0 >= STARVE["weak"]:
			# weak and still hungry: it trusts you a little less every few hours
			rec["trust"] = clampf(float(rec.get("trust", 0.0)) - z / 10800.0, 0.0, 100.0)
		st = minf(st + z, starve_cap())
	elif need(rec, "food") > 20.0 and st > 0.0:
		st = maxf(0.0, st - secs * 3.0)
	if st > 0.0: rec["starve"] = st
	else: rec.erase("starve")

## The most the starve clock holds, in seconds. With natural_death off it stops at the "dead" mark, so
## a Boki left alone for weeks still recovers with a few meals and a day of care.
static func starve_cap() -> float:
	return INF if bool(Content.rules("care")["natural_death"]) else STARVE["dead"] * 3600.0

## It just ate: a meal takes four hours off the starve clock.
static func fed(rec: Dictionary) -> void:
	if rec.has("starve"):
		var st := maxf(0.0, float(rec["starve"]) - 4.0 * 3600.0)
		if st > 0.0: rec["starve"] = st
		else: rec.erase("starve")

## True once a farm day (care.json care_day_s) for each kind of care, and stamps it: the
## gate on how much trust looking after it at home builds.
static func care_day(rec: Dictionary, kind: String) -> bool:
	var now := Time.get_unix_time_from_system()
	var days: Dictionary = rec.get_or_add("care_day", {})
	if now - float(days.get(kind, 0.0)) < float(Content.rules("care")["care_day_s"]):
		return false
	days[kind] = now
	return true

## Overall condition, 0 to 100.
static func condition(rec: Dictionary) -> float:
	ensure(rec)
	var nd: Dictionary = rec["needs"]
	return float(nd["food"]) * 0.3 + float(nd["energy"]) * 0.25 + float(nd["joy"]) * 0.3 + float(nd["clean"]) * 0.15

static func condition_name(rec: Dictionary) -> String:
	var ss := starve_stage(rec)
	if ss != "" and ss != "dead": return String(STARVE_INFO[ss][0])
	var c := condition(rec)
	if c >= 75.0: return "In great shape"
	if c >= 50.0: return "Doing fine"
	if c >= 28.0: return "A bit run down"
	return "Struggling"

## What it most wants right now, or "" if it's content.
static func want(rec: Dictionary) -> String:
	ensure(rec)
	var nd: Dictionary = rec["needs"]
	var best := ""; var bv := 38.0
	for k in ["food", "energy", "clean", "joy"]:
		if float(nd[k]) < bv:
			bv = float(nd[k]); best = k
	return best

## How the kin's shape at home carries into a match.
static func match_mods(rec: Dictionary) -> Dictionary:
	ensure(rec)
	var st: Dictionary = rec["stats"]
	var c := condition(rec)
	var cm := 1.1 if c >= 75.0 else (1.0 if c >= 50.0 else (0.92 if c >= 28.0 else 0.82))
	if starve_h(rec) >= STARVE["weak"]:
		cm *= 0.85        # weak from hunger
	var trust := float(rec.get("trust", 50.0))
	var bond := 1.1 if trust >= 90.0 else 1.0
	return {
		"dmg": (1.0 + float(st["power"]) * 0.004) * cm * bond,
		"hp": (1.0 + float(st["guard"]) * 0.005) * cm * bond,
		"speed": 1.0 + float(st["speed"]) * 0.0025,
		"cd": 1.0 - minf(0.3, float(st["focus"]) * 0.003),
		"skill": 1.05 if trust >= 50.0 else 1.0,
		"mood": clampf((c - 50.0) / 50.0, -1.0, 1.0),
	}

## A game it just finished: the point it trains (0 when too tired or at its cap for now).
static func play_train(rec: Dictionary, play: String) -> int:
	if not PLAY_TRAINS.has(play) or need(rec, "energy") < PLAY_TRAIN_ENERGY:
		return 0
	return add_stat(rec, String(PLAY_TRAINS[play]), 1)

## What its raising does for it on an expedition, in one line (the expedition panel): match_mods
## as percentages, so the care at home shows up where you pick your Boki.
static func care_line(rec: Dictionary) -> String:
	var mm := match_mods(rec)
	var bits: Array = []
	for pair in [["dmg", "damage"], ["hp", "health"], ["speed", "speed"]]:
		var pct := roundi((float(mm[pair[0]]) - 1.0) * 100.0)
		if pct != 0:
			bits.append("%+d%% %s" % [pct, pair[1]])
	var faster := roundi((1.0 - float(mm["cd"])) * 100.0)
	if faster != 0:
		bits.append("skills recharge %d%% faster" % faster)
	if bits.is_empty():
		return "Care, training and trust at home make it stronger out there."
	return "From how you've raised it: %s." % ", ".join(bits)

## Trained points can't run too far ahead of its level.
static func stat_cap(rec: Dictionary) -> int:
	return 12 + int(rec.get("level", 1)) * 6

static func add_stat(rec: Dictionary, s: String, n: int) -> int:
	ensure(rec)
	var before := int(rec["stats"].get(s, 0))
	rec["stats"][s] = clampi(before + n, 0, stat_cap(rec))
	return int(rec["stats"][s]) - before

static func bond(rec: Dictionary) -> Array:
	var t := float(rec.get("trust", 0.0))
	var out: Array = BONDS[0]
	for b in BONDS:
		if t >= float(b[0]): out = b
	return out

static func bond_index(rec: Dictionary) -> int:
	var t := float(rec.get("trust", 0.0))
	var i := 0
	for j in BONDS.size():
		if t >= float(BONDS[j][0]): i = j
	return i

static func next_bond(rec: Dictionary) -> Array:
	var i := bond_index(rec)
	return BONDS[i + 1] if i + 1 < BONDS.size() else []

static func stage_name(rec: Dictionary) -> String:
	var lv := int(rec.get("level", 1))
	var out: String = STAGES[0][1]
	for s in STAGES:
		if lv >= int(s[0]): out = s[1]
	return out

static func nature(rec: Dictionary) -> String:
	var tr: Dictionary = rec.get("traits", {})
	var keys := ["bravery", "loyalty", "temper", "curiosity"]
	keys.sort_custom(func(a, b): return float(tr.get(a, 0.5)) > float(tr.get(b, 0.5)))
	var pair := [keys[0], keys[1]]
	pair.sort()
	return String(NATURES.get("+".join(pair), "Easygoing"))

## How well it speaks: 0 only its own name, 1 a few words, 2 simple sentences, 3 fluent.
static func speech(rec: Dictionary) -> int:
	var lv := int(rec.get("level", 1))
	var t := float(rec.get("trust", 0.0))
	if lv >= 12 and t >= 70.0: return 3
	if lv >= 8 and t >= 50.0: return 2
	if lv >= 4 and t >= 35.0: return 1
	return 0

static func food_name(f: String) -> String:
	if Data.CROPS.has(f): return String(Data.CROPS[f]["name"])
	if FOODS.has(f): return String(FOODS[f]["name"])
	return f

static func food_col(f: String) -> Color:
	if Data.CROPS.has(f): return Data.CROPS[f]["color"]
	if FOODS.has(f): return FOODS[f]["col"]
	return Color.WHITE

## Learns something about the kin. Returns true the first time.
static func discover(rec: Dictionary, what: String) -> bool:
	ensure(rec)
	if (rec["known"] as Array).has(what):
		return false
	rec["known"].append(what)
	return true

## Feeding. Returns {ok, love, hate, full, text}.
static func feed(rec: Dictionary, f: String) -> Dictionary:
	ensure(rec)
	var likes: Dictionary = rec["likes"]
	var out := {"ok": true, "love": f == likes["food"], "hate": f == likes["hates"], "full": need(rec, "food") >= 92.0, "new": false}
	if out["hate"]:
		out["ok"] = false
		change(rec, "joy", -6.0)
		out["new"] = discover(rec, "hates")
		return out
	if out["full"] and not out["love"]:
		out["ok"] = false
		return out
	var fill := 28.0
	var joy := 6.0
	if FOODS.has(f):
		fill = float(FOODS[f]["food"]); joy = float(FOODS[f].get("joy", 0.0))
		change(rec, "energy", float(FOODS[f].get("energy", 0.0)))
	if out["love"]:
		joy += 22.0
		fill *= Unique.FAV_FILL       # its favourite food: a little more filling too
		out["new"] = discover(rec, "food")
	var was := need(rec, "food")
	change(rec, "food", fill)
	change(rec, "joy", joy)
	fed(rec)
	out["hungry"] = was < 35.0
	return out

# ------------------------------------------------------------------ IVs
## A fresh set of IVs, each 0 to 31.
static func roll_ivs(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for k in IV_KEYS: out[k] = rng.randi_range(0, IV_MAX)
	return out

## The IVs a kin with this id is born with: the same every time, so old saves get stable ones (and
## a new kin's random id gives it random ones).
static func ivs_from_uid(uid: String) -> Dictionary:
	var r := RandomNumberGenerator.new(); r.seed = hash(uid + "|ivs")
	return roll_ivs(r)

## A kin's IVs as whole numbers, all five there. Doesn't change the record (a record from another
## player that has none reads the same ones its id would give).
static func ivs(rec: Dictionary) -> Dictionary:
	var src = rec.get("ivs", null)
	if typeof(src) != TYPE_DICTIONARY:
		src = ivs_from_uid(String(rec.get("uid", "x")))
	var out := {}
	for k in IV_KEYS: out[k] = clampi(int(src.get(k, 0)), 0, IV_MAX)
	return out

static func iv(rec: Dictionary, stat: String) -> int:
	return int(ivs(rec).get(stat, 0))

## THE one place IVs turn into numbers: 1.0 at 0, up to 1.0 + IV_BONUS[stat] at 31, linear.
## stat: hp, atk, spd (match), work (farm jobs), bond (bond meter). Anything else is 1.0.
static func iv_mult(rec: Dictionary, stat: String) -> float:
	if rec.is_empty() or not IV_BONUS.has(stat):
		return 1.0
	return 1.0 + float(IV_BONUS[stat]) * float(iv(rec, stat)) / float(IV_MAX)

static func iv_total(rec: Dictionary) -> int:
	var t := 0
	var v := ivs(rec)
	for k in IV_KEYS: t += int(v[k])
	return t

## One stat in words, like the Pokemon judge.
static func iv_word(v: int) -> String:
	if v >= 31: return "Best"
	if v >= 30: return "Fantastic"
	if v >= 26: return "Very good"
	if v >= 16: return "Pretty good"
	if v >= 1: return "Decent"
	return "Faint"

## The whole set in words, from the total out of 155: [short, line].
static func iv_grade(rec: Dictionary) -> Array:
	var t := iv_total(rec)
	if t >= 126: return ["Remarkable", "Born remarkable: one in a great many."]
	if t >= 101: return ["Fine stock", "Comes from fine stock, well above most."]
	if t >= 76: return ["Good stock", "Comes from good stock, a cut above average."]
	return ["Ordinary stock", "Ordinary stock: much like any other Boki."]

## Its best stats (all those tied for the top).
static func iv_best(rec: Dictionary) -> Array:
	var v := ivs(rec)
	var top := -1
	for k in IV_KEYS: top = maxi(top, int(v[k]))
	return IV_KEYS.filter(func(k): return int(v[k]) == top)

## The judge's line: overall, then what stands out.
static func iv_judge(rec: Dictionary) -> String:
	var best := iv_best(rec)
	var nm: Array = best.map(func(k): return String(IVS[k]["name"]))
	var top := iv(rec, String(best[0]))
	var names: String = nm[0] if nm.size() == 1 else (" and ".join(nm) if nm.size() == 2 else ", ".join(nm.slice(0, -1)) + " and " + nm[-1])
	var what := ""
	if top >= IV_MAX: what = "Its %s can't get any better." % names
	else: what = "Its best %s %s (%s)." % ["is" if nm.size() == 1 else "are", names, iv_word(top).to_lower()]
	return "%s %s" % [String(iv_grade(rec)[1]), what]

## A bred kin's IVs: n stats (IV_INHERIT, at most IV_INHERIT_MAX) each from a random parent, the rest
## rolled fresh. Returns {"ivs": {...}, "from": {stat: 0 or 1}} (which parent each came from).
static func inherit_ivs(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, n := IV_INHERIT) -> Dictionary:
	var out := roll_ivs(rng)
	var keys: Array = IV_KEYS.duplicate()
	# shuffle with the given rng so a seeded breed is repeatable
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp
	var from := {}
	var va := ivs(a); var vb := ivs(b)
	for k in keys.slice(0, clampi(n, 0, IV_INHERIT_MAX)):
		var side := rng.randi_range(0, 1)
		out[k] = int(va[k]) if side == 0 else int(vb[k])
		from[k] = side
	return {"ivs": out, "from": from}

## A Rare Egg's IVs: IV_RARE_HIGH stats are IV_RARE_FLOOR or better, the rest anything.
static func rare_ivs(rng: RandomNumberGenerator) -> Dictionary:
	var out := roll_ivs(rng)
	var keys: Array = IV_KEYS.duplicate()
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp
	for k in keys.slice(0, IV_RARE_HIGH):
		out[k] = rng.randi_range(IV_RARE_FLOOR, IV_MAX)
	return out

## Kin from an egg: mostly one parent's species, a blend of both personalities, a head start
## along a parent's way of growing, and a very small chance to shimmer (Shiny.egg_chance: 1 in
## 4096; a shimmering parent only nudges it, to 1 in 2048, or about 1 in 1365 with two).
## IVs: IV_INHERIT stats from the parents (inherit_n, up to 5, for a future nest upgrade), the rest fresh.
static func breed(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator, sp := "", inherit_n := IV_INHERIT) -> Dictionary:
	if sp == "" or not Data.KIN.has(sp):
		sp = a["species"] if rng.randf() < 0.5 else b["species"]
	var baby := Save.new_kin(sp)
	for t in baby["traits"]:
		var mix := (float(a["traits"].get(t, 0.5)) + float(b["traits"].get(t, 0.5))) * 0.5
		baby["traits"][t] = clampf(mix + rng.randf_range(-0.12, 0.12), 0.05, 0.95)
	Evo.ensure(baby)
	var lead := Evo.leading(a if rng.randf() < 0.5 else b)
	Evo.add(baby, lead, 8.0)
	baby["shimmer"] = rng.randf() < Mutations.shimmer_breed_chance(a, b)
	# rare mutations: a good chance of a parent's passing on, and its own small roll
	var muts := Mutations.inherit(a, b, rng)
	if not muts.is_empty(): baby["mutations"] = muts
	baby["trust"] = 55.0
	baby["parents"] = [String(a["name"]), String(b["name"])]
	var inh := inherit_ivs(a, b, rng, inherit_n)
	baby["ivs"] = inh["ivs"]
	baby["iv_from"] = inh["from"]       # stat -> which parent (index into "parents") it came from
	# its own looks and habits, a blend of both parents' (Unique.inherit, its own seed: rng untouched)
	baby["dna"] = Unique.inherit(a, b, int(baby["dna"]["seed"]))
	BokiQuirks.set_sex(baby)
	baby["lineage"] = {"parents": [String(a.get("uid", "")), String(b.get("uid", ""))], "names": [String(a["name"]), String(b["name"])],
		"gen": maxi(int((a.get("lineage", {}) as Dictionary).get("gen", 0)), int((b.get("lineage", {}) as Dictionary).get("gen", 0))) + 1}
	baby["origin"] = {"how": "egg", "where": {"place": "home"}}
	ensure(baby)
	return baby

## Rare Eggs no longer use the breeding nest: they hatch on the Incubator (scripts/core/incubator.gd).
## Kept for older callers: puts shelf eggs into free incubator cradles. True if any went in.
static func settle_rare_egg() -> bool:
	Incubator.ensure()
	return Incubator.settle() > 0

## What hatches from a Rare Egg: a kin of the rare species its boss guarded, a little grown already,
## glad to see you, now and then shimmering too.
static func hatch_rare(egg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var sp := String(egg.get("sp", ""))
	if not Data.KIN.has(sp):
		sp = String(Data.common_kin()[0])
	var baby := Save.new_kin(sp)
	baby["rare"] = true
	baby["level"] = 3
	baby["trust"] = 50.0
	baby["shimmer"] = rng.randf() < Shiny.EGG[0]      # as rare as any egg
	baby["from_boss"] = String(egg.get("boss", ""))
	baby["ivs"] = rare_ivs(rng)        # three stats 26 or better (shimmer doesn't touch IVs)
	baby["origin"] = {"how": "boss_egg", "where": {"place": "home", "lair": String(egg.get("boss", ""))}}
	Evo.ensure(baby)
	ensure(baby)
	return baby

## The old shimmer colours, a turn round the colour wheel: only a fallback now, for a species with
## no hand-picked palette (Shiny.palette). Use Shiny.col(species, rec, slot) for a kin's colours.
static func shimmer_col(c: Color) -> Color:
	var h := fposmod(c.h + 0.45, 1.0)
	return Color.from_hsv(h, clampf(c.s * 0.85 + 0.1, 0.0, 1.0), clampf(c.v * 1.05 + 0.05, 0.0, 1.0), c.a)

## A kin back from the Soul Shrine: its colours washed pale and cool, like moonlight.
static func ghost_col(c: Color) -> Color:
	return c.lerp(Color("cfeff0"), 0.55).lerp(Color("9ff0e0"), 0.12)

## The Field Book entry for a species ({} if never seen).
static func dex_entry(species: String) -> Dictionary:
	return (Save.d.get("dex", {}) as Dictionary).get(species, {})

## The Field Book: what you've seen (and where), caught and grown.
static func dex_mark(species: String, what: String, extra := "") -> void:
	if not Save.d.has("dex"):
		Save.d["dex"] = {}
	var dx: Dictionary = Save.d["dex"]
	if not dx.has(species):
		dx[species] = {"seen": false, "caught": false, "forms": [], "shimmer": false}
	var e: Dictionary = dx[species]
	if not e.has("mutations"): e["mutations"] = []
	if not e.has("places"): e["places"] = []
	match what:
		"place":
			if extra != "" and not (e["places"] as Array).has(extra):
				(e["places"] as Array).append(extra)
				while (e["places"] as Array).size() > int(Content.rules("capture")["sight_places_kept"]):
					(e["places"] as Array).pop_front()
		"seen": e["seen"] = true
		"caught": e["seen"] = true; e["caught"] = true
		"form":
			if extra != "" and not (e["forms"] as Array).has(extra): e["forms"].append(extra)
		"shimmer": e["shimmer"] = true
		"mutation":
			if extra != "" and not (e["mutations"] as Array).has(extra): e["mutations"].append(extra)

## Everything already in the roster counts toward the Field Book.
static func dex_sync() -> void:
	for rec in Save.d.get("roster", []):
		dex_mark(rec["species"], "caught")
		var fn := Evo.form_name(rec)
		if fn != String(Data.KIN[rec["species"]]["name"]): dex_mark(rec["species"], "form", fn)
		if rec.get("shimmer", false): dex_mark(rec["species"], "shimmer")
		for mid in Mutations.of(rec): dex_mark(rec["species"], "mutation", mid)

## A new kin of yours: caught, seen through to the Field Book, shimmer and mutations noted.
static func dex_got(rec: Dictionary) -> void:
	dex_mark(rec["species"], "caught")
	if rec.get("shimmer", false): dex_mark(rec["species"], "shimmer")
	for mid in Mutations.of(rec): dex_mark(rec["species"], "mutation", mid)
