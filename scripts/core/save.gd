extends Node
## The player's persistent state: gems, the farm, the kin roster with their personalities and memories.
##
## Saves are versioned (d["v"]). An older save is upgraded step by step through MIGRATIONS (a copy
## of the file is kept beside it as <file>.bak-v<n> first); a save from a newer game is left alone
## and never overwritten. Every kin has a lasting identity: a collision-proof id (new_id), its own
## inborn rolls (Unique, rec["dna"]) and provenance (register: origin, original trainer, serial,
## lineage, edition). A small append-only event log (d["log"], LOG_CAP) keeps what happened to whom.
## See docs/BOKI_IDENTITY.md.

const VERSION := 12
const MAX_MEMORY := 40
const SLOTS := 6
const LOG_CAP := 200
## Upgrades, oldest first: MIGRATIONS[n] turns a version-n save into version n + 1.
const MIGRATIONS := {1: "_migrate_1_to_2", 2: "_migrate_2_to_3", 3: "_migrate_3_to_4", 4: "_migrate_4_to_5",
		5: "_migrate_5_to_6", 6: "_migrate_6_to_7", 7: "_migrate_7_to_8",
		8: "_migrate_8_to_9", 9: "_migrate_9_to_10", 10: "_migrate_10_to_11", 11: "_migrate_11_to_12"}

var d: Dictionary = {}
var slot := 1                 # which save file is in play

func _ready() -> void:
	# the last save you played comes back (remembered next to the settings)
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		slot = clampi(int(cf.get_value("save", "slot", 1)), 1, SLOTS)
	load_game()

static func path_for(n: int) -> String:
	return "user://kinfall_save.json" if n == 1 else "user://kinfall_save_%d.json" % n

## What a save file holds, for the save list.
func slot_info(n: int) -> Dictionary:
	var out := {"exists": false}
	var p := path_for(n)
	if not FileAccess.file_exists(p):
		return out
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or (parsed.get("roster", []) as Array).is_empty():
		return out
	var when := Time.get_datetime_dict_from_unix_time(int(FileAccess.get_modified_time(p)))
	return {"exists": true, "name": String(parsed.get("name", "Hunter")), "kin": (parsed.get("roster", []) as Array).size(),
		"gems": int(parsed.get("gems", 0)), "matches": int(parsed.get("matches", 0)),
		"when": "%d-%02d-%02d" % [when["year"], when["month"], when["day"]]}

func use_slot(n: int) -> void:
	save_game()
	slot = clampi(n, 1, SLOTS)
	load_game()
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("save", "slot", slot)
	cf.save("user://settings.cfg")

func delete_slot(n: int) -> void:
	if FileAccess.file_exists(path_for(n)):
		DirAccess.remove_absolute(path_for(n))
	if n == slot:
		d = fresh()
		newer = false

func fresh() -> Dictionary:
	# a new save has no kin yet: the first thing you do is pick an egg and hatch it
	return {
		"v": VERSION,
		"name": "Hunter",
		"gems": 60,
		"cls": "medium",
		"classes": ClassUnlock.fresh(),   # which Hunters are open, the creation pick, challenges and mastery
		"active": "",
		"roster": [],
		"seeds": {"tidebloom": 2, "emberberry": 1},
		"crops": {},
		"items": {"tonic": 1},
		"treat": "",
		"plots": _empty_plots(4),
		"plot_cap": 4,
		"matches": 0,
		"extracts": 0,
		"settings": {"volume": 0.8, "cam_lead": 1.0},
		"tutorial": {},
		"farm_builder": 1,    # Hob and the farm tutorial are known to this save (FarmBuilder.migrate)
		"buildings": [],
		"music": [],
		"guild_perks": [],
		"bridges": [],
		"gh_plots": _empty_plots(4),
		"stats": {"kills": 0, "best_kills": 0, "best_gems": 0, "caught": 0, "knocks": 0},
		"lost_kin": [],       # your kin left behind on expeditions: at the Ransom House or held by a rival
		"rivals": {},         # rival hunters you've dealt with: how greedy they are, how they feel about you
		"offers": [],         # rivals asking to buy back kin you took from them
		"ransom_log": [],     # what happened at the Ransom House, newest last
		"armory": [],         # gear brought home (Loot items); see Econ
		"arm_lvl": 0, "scrap": 0,
		"belt_pick": ["tonic", "armor_kit", "", ""],   # the utility for the next expedition, one per belt slot (Equal)
		"raid_belt": {},      # utility charges out on an expedition right now (put back if it never ended)
		"loadout": {},        # what you take on the next expedition: slot -> armory uid
		"valuables": {},      # treasure to sell, and Soul Embers
		"raid_out": [],       # loadout pieces out on an expedition right now
		"feeders": [],        # troughs on the farm: {id, kind, x, z, food: [keys], auto}
		"feeder_inv": {},     # feeders bought but not set down yet
		"furniture": {"journal": 1, "gramophone": 1},   # house pieces in storage: the empty house's two useful ones
		"graves": [],         # kin that died, with their memories (Econ.kin_dies)
		"farm_lvl": 0,        # Kin Cottage expansions: room for 6 / 8 / 10 / 12 kin out on the farm (KinBox)
		"box_v": true,        # the Kin Burrow is set up (old saves get their overflow boxed once)
		"profile": {"id": new_id("p"), "name": "Hunter"},   # this save's trainer: original trainer on every kin it registers
		"serials": {},        # species -> the last serial handed out on this save (global once there's a server)
		"log": [],            # append-only event log, newest last, at most LOG_CAP
		"market": MarketSave.fresh(),   # your stall, auctions, the shelter, transfers, the Black Market's stock
		"goods": {},          # market goods: rare materials, trophies, dyes (Goods)
	}

func _empty_plots(n: int) -> Array:
	var a := []
	for i in n:
		a.append({"crop": "", "stage": 0})
	return a

## A new kin record. seed: where its inborn rolls (Unique) come from; leave it out for a fresh one
## from the system's random bytes, or pass one made from a match seed (Match.kin_seed) so wild and
## bot kin are the same every run of a seeded match.
func new_kin(species: String, kname := "", seed := -1) -> Dictionary:
	var sp: Dictionary = Data.KIN[species]
	var tr := {}
	for k in sp["traits"]:
		tr[k] = clampf(float(sp["traits"][k]) + randf_range(-0.15, 0.15), 0.05, 0.95)
	randi()      # the old id used one global roll here: kept so the global random stream doesn't shift
	var rec := {
		"uid": new_id(),
		"species": species,
		"name": kname if kname != "" else Data.default_kin_name(species),
		"level": 1, "xp": 0,
		"traits": tr,
		"trust": 35.0,
		"memory": [],
		"matches": 0, "wins": 0, "kos": 0,
		"born": int(Time.get_unix_time_from_system()),
		"dna": Unique.roll(seed if seed >= 0 else Unique.fresh_seed()),
		"edition": null,      # reserved for limited editions (see docs/BOKI_IDENTITY.md)
	}
	Care.ensure(rec)
	return rec

# ------------------------------------------------------------------ ids
const B32 := "0123456789abcdefghjkmnpqrstvwxyz"
static var _crypto: Crypto = null
static var _id_rng: RandomNumberGenerator = null

static func _b32(bytes: PackedByteArray, chars: int) -> String:
	var out := ""
	var bit := 0
	for i in chars:
		var v := 0
		for j in 5:
			var byte_i := bit >> 3
			var b := 0
			if byte_i < bytes.size():
				b = (bytes[byte_i] >> (7 - (bit & 7))) & 1
			v = (v << 1) | b
			bit += 1
		out += B32[v]
	return out

## A collision-proof id that never changes: prefix + creation time in milliseconds (9 base-32
## characters, so ids sort by age) + 64 random bits (13 characters) from the system's random bytes,
## never the global random stream. "b" for kin, "p" for a save profile. 23 characters for kin.
static func new_id(prefix := "b") -> String:
	if _crypto == null: _crypto = Crypto.new()
	var rnd := _crypto.generate_random_bytes(8)
	if rnd.size() < 8:
		# no system randomness (shouldn't happen): a dedicated generator, never the global one
		if _id_rng == null:
			_id_rng = RandomNumberGenerator.new(); _id_rng.randomize()
		rnd = PackedByteArray()
		for i in 8: rnd.append(_id_rng.randi() & 255)
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	var tb := PackedByteArray()
	tb.resize(6)
	for i in 6: tb[i] = (ms >> (8 * (5 - i))) & 255     # 48 bits, the top 45 used
	var t := _b32(tb, 10).substr(1)
	return prefix + t + _b32(rnd, 13)

# ------------------------------------------------------------------ provenance
## This save's trainer (made on first use; the name follows the save's).
func profile() -> Dictionary:
	if typeof(d.get("profile", null)) != TYPE_DICTIONARY or String(d["profile"].get("id", "")) == "":
		d["profile"] = {"id": new_id("p"), "name": String(d.get("name", "Hunter"))}
	d["profile"]["name"] = String(d.get("name", "Hunter"))
	return d["profile"]

## Appends to the event log (caught, hatched, traded, evolved, renamed, released, died, revived...).
func log_event(ev: String, rec: Dictionary, extra := {}) -> void:
	if typeof(d.get("log", null)) != TYPE_ARRAY:
		d["log"] = []
	var e := {"t": int(Time.get_unix_time_from_system()), "ev": ev, "uid": String(rec.get("uid", "")),
		"sp": String(rec.get("species", "")), "name": String(rec.get("name", ""))}
	for k in extra: e[k] = extra[k]
	var lg: Array = d["log"]
	lg.append(e)
	while lg.size() > LOG_CAP:
		lg.pop_front()

## A placeholder for trading (no trades exist yet): logs it and hands the kin a new trainer.
func log_trade(rec: Dictionary, from_name: String) -> void:
	log_event("traded", rec, {"from": from_name})

const HOW_EVENT := {"wild": "caught", "taken": "caught", "egg": "hatched", "boss_egg": "hatched", "starter": "hatched",
	"event": "caught", "market": "traded", "shelter": "adopted", "transfer": "received", "unknown": "registered"}

## Gives a kin joining this collection its provenance, once: where it came from (rec["origin"],
## set where it was made, or `how` / `where` here), when, its original trainer, its serial within
## its species on this save (global once there's a server), lineage and the edition slot. Logs it.
## Does nothing for a kin that already has a serial.
func register(rec: Dictionary, how := "", where := {}) -> void:
	if rec.is_empty() or rec.has("serial"):
		return
	Unique.ensure(rec)
	var o = rec.get("origin", null)
	if typeof(o) != TYPE_DICTIONARY:
		o = {}
	if how != "": o["how"] = how
	if not o.has("how"): o["how"] = "unknown"
	if not where.is_empty(): o["where"] = where
	if not o.has("where"): o["where"] = {"place": "home"} if String(o["how"]) in ["egg", "boss_egg", "starter"] else {}
	if not o.has("t"): o["t"] = int(Time.get_unix_time_from_system())
	rec["origin"] = o
	if not rec.has("born"): rec["born"] = int(o["t"])
	if typeof(rec.get("ot", null)) != TYPE_DICTIONARY:
		var p := profile()
		rec["ot"] = {"id": String(p["id"]), "name": String(p["name"])}
	if typeof(rec.get("lineage", null)) != TYPE_DICTIONARY:
		var names: Array = (rec.get("parents", []) as Array).duplicate()
		rec["lineage"] = {"parents": [], "names": names, "gen": 1 if not names.is_empty() else 0}
	if not rec.has("edition"): rec["edition"] = null
	if typeof(d.get("serials", null)) != TYPE_DICTIONARY:
		d["serials"] = {}
	var sp := String(rec.get("species", ""))
	var n := int(d["serials"].get(sp, 0)) + 1
	d["serials"][sp] = n
	rec["serial"] = n
	log_event(String(HOW_EVENT.get(String(o["how"]), "registered")), rec, {"how": String(o["how"]), "serial": n})

## Everyone in the collection has provenance (anything that came in without it gets it now).
func register_all() -> void:
	for r in d.get("roster", []):
		if typeof(r) == TYPE_DICTIONARY and not r.has("serial"): register(r)
	for L in d.get("lost_kin", []):
		if typeof(L) == TYPE_DICTIONARY and typeof(L.get("rec", null)) == TYPE_DICTIONARY and not L["rec"].has("serial"): register(L["rec"])

## "#0042 of Vespyx" ("" before it has a serial).
static func serial_text(rec: Dictionary) -> String:
	if not rec.has("serial"):
		return ""
	return "#%04d of %s" % [int(rec["serial"]), String(Data.KIN.get(String(rec.get("species", "")), {}).get("name", "Boki"))]

# ------------------------------------------------------------------ migrations
## Upgrades a parsed save of any older version to VERSION, in place. Returns false if it can't
## (a save from a newer game, or a version with no upgrade path).
func migrate(data: Dictionary) -> bool:
	var v := int(data.get("v", 0))
	if v > VERSION:
		return false
	while v < VERSION:
		if not MIGRATIONS.has(v):
			push_warning("Save: no upgrade from version %d" % v)
			return false
		call(String(MIGRATIONS[v]), data)
		v += 1
		data["v"] = v
	return true

## v5 -> v6: Hunter unlocks. A save that predates them had every Hunter, so it keeps them all (ClassUnlock).
func _migrate_5_to_6(data: Dictionary) -> void:
	ClassUnlock.migrate(data)

## v8 -> v9: reserved for ext/mantle-look (nothing to change here).
func _migrate_8_to_9(_data: Dictionary) -> void:
	pass

## v9 -> v10: Hob and the farm tutorial. A save that has played skips the tutorial and keeps every
## blueprint it could already build (FarmBuilder.migrate, keyed by its own "farm_builder" field).
func _migrate_9_to_10(data: Dictionary) -> void:
	FarmBuilder.migrate(data)

## v10 -> v11: the house starts empty; a played house keeps its furniture, now all movable (HouseSave).
func _migrate_10_to_11(data: Dictionary) -> void:
	HouseSave.migrate(data)

## v11 -> v12: evolution by species (Evo, docs/decisions/0024). Levels and forms are kept, levels
## stop at the cap, and each Boki keeps its old form name.
func _migrate_11_to_12(data: Dictionary) -> void:
	Evo.migrate(data)

## v6 -> v7: equal footing in matches. Armor and kit pieces in the armory become gems and farm
## materials, the glove-turned-utility pieces become stash charges, backpack upgrades are refunded,
## and a one-time notice lists it all (EqualMigrate).
func _migrate_6_to_7(data: Dictionary) -> void:
	EqualMigrate.migrate(data)

## v7 -> v8: the market. Boki are never sold for gems: open Drift Pens and web market Boki listings
## go back to their owners' rosters, and the market's fields get their defaults (MarketSave).
func _migrate_7_to_8(data: Dictionary) -> void:
	MarketSave.migrate(data)

## v4 -> v5: the gear model. Stored weapons become scrap, gloves become gear items, the loadout
## moves to five gear slots (GearSave).
func _migrate_4_to_5(data: Dictionary) -> void:
	GearSave.migrate(data)

## v3 -> v4: the Field Book. Every species you own counts as seen, and each entry gets its "places" list.
func _migrate_3_to_4(data: Dictionary) -> void:
	FieldBook.migrate(data)

## v2 -> v3: every Boki's sex, written into its rolls (from its own seed, so it's what it always
## would have been).
func _migrate_2_to_3(data: Dictionary) -> void:
	for r in data.get("roster", []):
		if typeof(r) == TYPE_DICTIONARY: Unique.ensure_sex(r)
	for L in data.get("lost_kin", []):
		if typeof(L) == TYPE_DICTIONARY and typeof(L.get("rec", null)) == TYPE_DICTIONARY: Unique.ensure_sex(L["rec"])
	for g in data.get("graves", []):
		if typeof(g) == TYPE_DICTIONARY and typeof(g.get("rec", null)) == TYPE_DICTIONARY: Unique.ensure_sex(g["rec"])

## v1 -> v2: lasting ids, inborn rolls and provenance for every kin. Each kin's tastes and IVs
## (which older saves worked out from the old id) are written down first, so changing the id
## doesn't change them; its rolls come from the old id too, so a migration always gives the same
## kin. Every reference to an old id anywhere in the save is rewritten; the old one stays as
## rec["legacy_uid"].
func _migrate_1_to_2(data: Dictionary) -> void:
	var recs: Array = []
	for r in data.get("roster", []):
		if typeof(r) == TYPE_DICTIONARY: recs.append(r)
	for L in data.get("lost_kin", []):
		if typeof(L) == TYPE_DICTIONARY and typeof(L.get("rec", null)) == TYPE_DICTIONARY: recs.append(L["rec"])
	for g in data.get("graves", []):
		if typeof(g) == TYPE_DICTIONARY and typeof(g.get("rec", null)) == TYPE_DICTIONARY: recs.append(g["rec"])
	var remap := {}
	for r in recs:
		var old := String(r.get("uid", ""))
		Care.ensure(r)          # likes and IVs from the old id, written down
		Unique.ensure(r)        # inborn rolls from the old id
		if old == "" or old.begins_with("b"):
			continue
		if not remap.has(old):
			remap[old] = new_id()
	for g in data.get("graves", []):
		# a grave keeps the id too, even when its record copy is missing
		if typeof(g) == TYPE_DICTIONARY and String(g.get("uid", "")) != "" and not remap.has(String(g["uid"])) and not String(g["uid"]).begins_with("b"):
			remap[String(g["uid"])] = new_id()
	_rewrite_ids(data, remap)
	var inv := {}
	for k in remap: inv[remap[k]] = k
	for r in recs:
		if inv.has(String(r.get("uid", ""))): r["legacy_uid"] = inv[String(r["uid"])]
	for g in data.get("graves", []):
		if typeof(g) == TYPE_DICTIONARY and inv.has(String(g.get("uid", ""))): g["legacy_uid"] = inv[String(g["uid"])]
	# provenance: what can be told from the old record; serials in the order they were got
	if typeof(data.get("profile", null)) != TYPE_DICTIONARY:
		data["profile"] = {"id": new_id("p"), "name": String(data.get("name", "Hunter"))}
	if typeof(data.get("serials", null)) != TYPE_DICTIONARY: data["serials"] = {}
	if typeof(data.get("log", null)) != TYPE_ARRAY: data["log"] = []
	var order: Array = recs.duplicate()
	order.sort_custom(func(a, b): return float(a.get("got_t", 0.0)) < float(b.get("got_t", 0.0)))
	var hold := d
	d = data       # register() works on the save being migrated
	for r in order:
		var how := "unknown"
		if r.get("starter", false): how = "starter"
		elif r.get("rare", false) or String(r.get("from_boss", "")) != "": how = "boss_egg"
		elif r.has("parents"): how = "egg"
		else:
			for m in r.get("memory", []):
				if typeof(m) != TYPE_DICTIONARY: continue
				if String(m.get("kind", "")) == "caught": how = "wild"
				elif String(m.get("kind", "")) == "taken": how = "taken"
				elif String(m.get("kind", "")) == "market": how = "market"
		var o := {"how": how, "where": {}, "t": int(float(r.get("got_t", 0.0)))}     # t 0: from before records were kept
		if how == "boss_egg": o["where"] = {"place": "home", "lair": String(r.get("from_boss", ""))}
		elif how in ["egg", "starter"]: o["where"] = {"place": "home"}
		r["origin"] = o
		if not r.has("born"): r["born"] = int(o["t"])
		r.erase("serial")
		register(r)
	d = hold
	data["log"].append({"t": int(Time.get_unix_time_from_system()), "ev": "migrated", "from": 1, "to": 2, "kin": recs.size()})

## Every string in the save equal to an old id (as a value or a key) becomes the new one.
static func _rewrite_ids(node, remap: Dictionary):
	if typeof(node) == TYPE_DICTIONARY:
		var dct: Dictionary = node
		for k in dct.keys():
			var v = dct[k]
			var nv = _rewrite_ids(v, remap)
			if typeof(v) == TYPE_STRING and remap.has(v): nv = remap[v]
			var nk = k
			if typeof(k) == TYPE_STRING and remap.has(k): nk = remap[k]
			if nk != k:
				dct.erase(k)
			dct[nk] = nv
		return dct
	if typeof(node) == TYPE_ARRAY:
		var arr: Array = node
		for i in arr.size():
			if typeof(arr[i]) == TYPE_STRING and remap.has(arr[i]): arr[i] = remap[arr[i]]
			else: _rewrite_ids(arr[i], remap)
		return arr
	return node

func load_game() -> void:
	load_from(path_for(slot))

## Loads a save file into d (fresh if there's none), upgrading an older one (a copy of the old
## file is written beside it first, <path>.bak-v<n>, unless no_write).
func load_from(p: String) -> void:
	d = fresh()
	newer = false
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var v := int(parsed.get("v", 0))
	if v > VERSION:
		# from a newer game: leave it alone, and never write over it
		newer = true
		push_warning("Save: %s is from a newer version (%d > %d); not loaded, and won't be overwritten" % [p, v, VERSION])
		return
	if v < VERSION:
		if not no_write:
			var bak := FileAccess.open(p + ".bak-v%d" % v, FileAccess.WRITE)
			if bak: bak.store_string(text)
		if not migrate(parsed):
			return
	FarmBuilder.migrate(parsed)      # keyed by its own field: holds if another branch also took v8
	for k in parsed:
		d[k] = parsed[k]
	Unmasked.migrate(d)      # an old detailed look becomes the closest Unmasked
	# JSON numbers come back as floats; plots and roster are fine with that.
	register_all()
	Evo.catch_up(d.get("roster", []))     # Boki that were waiting for their next form's art

var no_write := _tool_run()   # headless checks play with a save without touching the real file

## Tooling runs (--no-save, checks that ask for it, screenshots) never write the real save file,
## from the very first frame (other autoloads may save while starting up).
static func _tool_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--no-save" or a == "--archetype-check":
			return true
		if String(a).begins_with("--shot=") or String(a).begins_with("--demo="):
			return true
	return false
var newer := false            # the slot holds a save from a newer game: never overwrite it

func save_game() -> void:
	register_all()
	if no_write or newer:
		return
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func reset() -> void:
	d = fresh()
	newer = false
	save_game()

# --- roster helpers ---
func kin(uid: String) -> Dictionary:
	for k in d["roster"]:
		if k["uid"] == uid:
			return k
	return {}

func active_kin() -> Dictionary:
	var k := kin(str(d.get("active", "")))
	if k.is_empty() or not KinLoss.selectable(k):     # (a held Boki stays home: KinLoss)
		k = {}
		for r in d["roster"]:
			if KinLoss.selectable(r):
				k = r
				d["active"] = k["uid"]
				break
	return k

## The kin you bring as your second (benched, swapped in with X). "none" means bring only one.
## If you haven't picked, your most trusted other kin comes along.
func second_kin() -> Dictionary:
	var a := str(d.get("active", ""))
	var b := str(d.get("active2", ""))
	if b == "none":
		return {}
	var k := kin(b)
	if not k.is_empty() and b != a and KinLoss.selectable(k):
		return k
	var best: Dictionary = {}
	for r in d["roster"]:
		if r["uid"] == a or not KinLoss.selectable(r): continue
		# kin out on the farm first; one asleep in the Kin Burrow only if nobody else is around
		var better: bool = best.is_empty() or (best.get("boxed", false) and not r.get("boxed", false)) \
			or (best.get("boxed", false) == r.get("boxed", false) and float(r.get("trust", 0.0)) > float(best.get("trust", 0.0)))
		if better:
			best = r
	if not best.is_empty():
		d["active2"] = best["uid"]
	return best

func remember(k: Dictionary, kind: String, text: String, trust_delta := 0.0) -> void:
	if k.is_empty():
		return
	var mem: Array = k["memory"]
	var m := int(d.get("matches", 0))
	# the same care again since the last expedition stays one memory (the trust still counts)
	var again := mem.slice(-6).any(func(e):
		return int(e.get("m", -1)) == m and String(e.get("kind", "")) == kind and String(e.get("text", "")) == text)
	if not again:
		mem.append({"m": m, "kind": kind, "text": text})
	while mem.size() > MAX_MEMORY:
		mem.pop_front()
	k["trust"] = clampf(float(k["trust"]) + trust_delta, 0.0, 100.0)

func has_building(b: String) -> bool:
	return d.get("buildings", []).has(b)

func has_bridge(b: String) -> bool:
	return d.get("bridges", []).has(b)

func add_item(key: String, n: int) -> void:
	d["items"][key] = int(d["items"].get(key, 0)) + n

func add_seed(key: String, n: int) -> void:
	d["seeds"][key] = int(d["seeds"].get(key, 0)) + n
