class_name ComeLook
extends RefCounted
## Something new at home (a Boki, a Rare Egg, a new bit of furniture, you back from an expedition with a Rare Egg,
## an Ink or other loot): up to three Boki nearby walk over to look and chatter through FarmChatter. The curious
## come first, a timid one hangs back (and arrives last), and for furniture the most curious tries it first. Each
## reacts by its traits through KinHabit: a timid one hides, a curious one sniffs at it, the rest puff up. Then it
## goes back to what it was doing: its walk and think timer come back, and on the base its machine waited
## (BaseLife._taken sees k["look"]). A Boki napping, working, eating or at a toy stays out of it. The first to
## arrive keeps one memory line of the day (Save.remember). No rewards, no pop-ups: it is only life at home
## (GARDEN.md section 4).

const MAX_LOOKERS := 3
const NEAR_R := 16.0         # m: Boki this close to the news hear it and come
const STAGGER_S := 0.9       # s between one Boki setting off and the next
const CURIOUS := 0.6         # curiosity (0..1) from here a Boki comes first
const TIMID := 0.4           # bravery (0..1) under this a Boki hangs back
const LOOK_DIST := 1.7       # m: how close a Boki stands to look
const SNIFF_DIST := 1.0      # m: a curious one comes closer, to sniff at it
const HANG_DIST := 4.5       # m: how far a timid Boki stays back
const TRY_DIST := 0.6        # m: the first Boki touches a new toy
const ARRIVED_R := 0.7       # m: close enough to the spot to count as there
const WATCH_S := 3.0         # s a Boki stays looking once it is there
const GIVE_UP_S := 14.0      # s of walking before it looks from where it is
const RARE_MARK := "Rare Egg"      # in a hatched Boki's first memory line
const BUSY := ["job", "fetch", "bath", "indoors", "called_t", "eat", "play"]      # k keys: the farm has it

static var _looks: Array = []
static var _extracts := -1         # expeditions made when the farm last looked (a rise: you came home)
static var _eggs := {}             # Rare Egg ids at home when the farm last looked
static var _inks := {}             # Ink id -> how many you had when the farm last looked

## Every frame: walks each looker over, then lets it look and speak.
static func tick(h, d: float) -> void:
	for l in _looks.duplicate():
		var k: Dictionary = l["k"]
		if not h.kins.has(k) or not h.visit.is_empty() or not _free(k):
			_release(l)
			continue
		l["delay"] = float(l["delay"]) - d
		if float(l["delay"]) <= 0.0:
			_step(h, l, d)

## News at `at`. `who` is the new Boki's entry ({} for none); `what` names the toy (for "toy") or the Ink ("ink").
## Returns the Boki who set off, first one first.
static func event(h, kind: String, at: Vector3, who: Dictionary, what := "") -> Array:
	var came := _pick(h, at, who)
	for l in _looks.duplicate():
		_release(l)
	for i in came.size():
		var k: Dictionary = came[i]
		var timid := _timid(k)
		var dist := _stand_dist(k)
		if i == 0 and kind == "toy" and not timid:
			dist = TRY_DIST
		var a := 2.1 * i + 0.7
		_looks.append({"k": k, "kind": kind, "timid": timid, "delay": STAGGER_S * i, "walk": 0.0, "watch": -1.0,
			"said": false,
			"spot": h.world.free_spot_near(at + Vector3(cos(a), 0, sin(a)) * dist)})
	if not came.is_empty():
		Save.remember(came[0]["rec"], "look", _memory(kind, who, what))
	return came

## The three most curious Boki that can come; the timid ones among them go last.
static func _pick(h, at: Vector3, who: Dictionary) -> Array:
	var isle: int = h.world.island_of(at.x, at.z)
	var out: Array = (h.kins as Array).filter(func(k):
		return k != who and _free(k) and h.world.island_of(k["pos"].x, k["pos"].z) == isle \
			and (k["pos"] as Vector3).distance_to(at) < NEAR_R)
	out.sort_custom(func(a, b): return _trait(a, "curiosity") > _trait(b, "curiosity"))
	out = out.slice(0, MAX_LOOKERS)
	var bold: Array = out.filter(func(k): return not _timid(k))
	return bold + out.filter(func(k): return _timid(k))

static func _timid(k: Dictionary) -> bool:
	return _trait(k, "bravery") < TIMID

static func _free(k: Dictionary) -> bool:
	for key in BUSY:
		if k.has(key):
			return false
	return not k.get("busy", false) and float(k.get("nap_t", 0.0)) <= 0.0

## How a Boki takes the news, by its traits: a timid one hides, a curious one sniffs at it, the rest puff up.
static func _reaction(k: Dictionary) -> String:
	if _timid(k):
		return "hide"
	return "sniff" if _trait(k, "curiosity") >= CURIOUS else "puff"

## How far from the news it stands: a timid one hangs back, a curious one comes close to sniff.
static func _stand_dist(k: Dictionary) -> float:
	match _reaction(k):
		"hide": return HANG_DIST
		"sniff": return SNIFF_DIST
	return LOOK_DIST

static func _trait(k: Dictionary, key: String) -> float:
	return float(k["rec"]["traits"].get(key, 0.5))

static func _memory(kind: String, who: Dictionary, what: String) -> String:
	match kind:
		"boki": return "was there the day %s arrived" % who["rec"]["name"]
		"rare": return "was there the day %s hatched from a Rare Egg" % who["rec"]["name"]
		"toy": return "was first to try the new %s" % what
		"egg": return "was there the day you brought a Rare Egg home"
		"ink": return "was there the day you brought %s home" % what
	return "was there the day you came home with loot"

## One looker: walk to its spot, then react once (emote and its pose, then a line when it is its turn to talk).
static func _step(h, l: Dictionary, d: float) -> void:
	var k: Dictionary = l["k"]
	if not l.has("was"):
		l["was"] = {"goal": k["goal"], "t": float(k["t"])}      # what it was doing, for when it has looked
		k["look"] = true
	k["t"] = maxf(float(k["t"]), 1.0)      # the farm's think timer waits while it looks
	if float(l["watch"]) < 0.0:
		l["walk"] = float(l["walk"]) + d
		var to: Vector3 = l["spot"]
		k["goal"] = to
		k.erase("chase")
		if (k["pos"] as Vector3).distance_to(to) > ARRIVED_R and float(l["walk"]) < GIVE_UP_S:
			return
		l["watch"] = WATCH_S
		h._emote(k, _emote_mark(l), true)
		KinHabit.react(k, _reaction(k))
	l["watch"] = float(l["watch"]) - d
	k["hold_t"] = maxf(float(k.get("hold_t", 0.0)), 0.5)
	if not l["said"]:
		l["said"] = FarmChatter.react(h, k, _topic(l))
	if float(l["watch"]) <= 0.0:
		_release(l)

## The look is over (or cut short): the Boki goes back to what it was doing and the farm has it again.
static func _release(l: Dictionary) -> void:
	var k: Dictionary = l["k"]
	_looks.erase(l)
	if not l.has("was"):
		return
	k.erase("look")
	k["hold_t"] = 0.0
	k["goal"] = l["was"]["goal"]
	k["t"] = l["was"]["t"]

static func _emote_mark(l: Dictionary) -> String:
	if l["timid"]:
		return "?"
	return "♪" if l["kind"] == "toy" else "!"

static func _topic(l: Dictionary) -> String:
	if l["timid"]:
		return "look_shy"
	return {"boki": "new_boki", "rare": "look_rare", "egg": "look_rare", "toy": "look_toy", "loot": "look_loot",
		"ink": "look_loot"}[l["kind"]]

## A Boki that has just arrived is news; was it from a Rare Egg?
static func arrival_kind(rec: Dictionary) -> String:
	for m in rec.get("memory", []):
		if String(m["text"]).contains(RARE_MARK):
			return "rare"
	return "boki"

## You are home and the expeditions count went up since the farm last looked: you came back with news. A new
## Rare Egg (in a cradle or on the shelf) is the news, else a new Ink (it changes what a Boki evolves into), else loot.
static func loot_home(h) -> void:
	var now := int(Save.d.get("extracts", 0))
	var came := _extracts >= 0 and now > _extracts
	_extracts = now
	var eggs := _egg_ids()
	var new_egg := eggs.keys().any(func(id): return not _eggs.has(id))
	var inks := _ink_counts()
	var new_ink := _more_ink(inks)
	_eggs = eggs
	_inks = inks
	if not came:
		return
	if new_egg:
		event(h, "egg", h.ppos, {})
	elif new_ink != "":
		event(h, "ink", h.ppos, {}, Goods.name_of("good:" + new_ink))
	else:
		event(h, "loot", h.ppos, {})

## Every Rare Egg at home, by id: in the incubator's cradles and on its shelf.
static func _egg_ids() -> Dictionary:
	var out := {}
	for e in Incubator.eggs() + Incubator.shelf():
		out[String(e.get("id", ""))] = true
	return out

## The first Ink you have more of than when the farm last looked, or "".
static func _more_ink(inks: Dictionary) -> String:
	for id in inks:
		if int(inks[id]) > int(_inks.get(id, 0)):
			return String(id)
	return ""

## How many of each Ink (market goods of kind "ink") you have.
static func _ink_counts() -> Dictionary:
	var out := {}
	var goods: Dictionary = Goods.rules()["goods"]
	for id in goods:
		if String(goods[id]["kind"]) == "ink":
			out[id] = Goods.have("good:" + String(id))
	return out
