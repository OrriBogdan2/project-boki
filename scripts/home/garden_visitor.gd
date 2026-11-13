class_name GardenVisitor
extends RefCounted
## Wild visitors (briefs/design/GARDEN_MODERN.md section 5 rank 6). With a zone loaded, a wild Boki sometimes
## wanders in when the zone suits it: a toy there it likes and two residents of its type group. At most one
## at a time. It stays one garden day (care.json care_day_s), walks and plays your games as one more Boki
## (it is in the zone's kins, GardenZones.out_here) and eats only what you hand it: E on it opens the feed
## list and its favourite is shown. The third favourite meal makes it ask to stay as a new Boki when the
## zone has room, else leave an egg in the Incubator. The away card says who came and left.
## Save.d["visitor"] = {rec, zone, t, fed, told, notes, next}: a lazy key, no save bump; the rec carries
## "visitor": true until it joins. The egg it leaves carries {sp, zone, day} (Incubator "visitor"): the baby's
## lineage["visitor"] shows it as the wild parent on the Family tab, with one memory line.
## Tuning: content/rules/garden_visitor.json.

static var _look_t := 0.0
static var _rng := RandomNumberGenerator.new()      # its own stream: seeded checks keep the global one

static func rules() -> Dictionary:
	return Content.rules("garden_visitor")

## The wild Boki here now ({} for none).
static func rec() -> Dictionary:
	return Save.d.get("visitor", {}).get("rec", {})

## The visitor if it is staying in `zone`, else {}.
static func in_zone(zone: String) -> Dictionary:
	return rec() if String(Save.d.get("visitor", {}).get("zone", "")) == zone else {}

static func theme_of(species: String) -> String:
	return String(Data.KIN.get(species, {}).get("type", ""))

static func group(zone: String) -> Array:
	return rules()["groups"].get(zone, [])

## True when `zone` suits a wild `species`: its theme is one of the zone's group, one of `toy_ids` (what stands
## in the zone) is a toy it likes, and the zone has enough residents of the group (none while you have
## one Boki: the first friend must be able to come).
static func suits(zone: String, species: String, toy_ids: Array) -> bool:
	var theme := theme_of(species)
	var themes := group(zone)
	if not themes.has(theme):
		return false
	var toys: Dictionary = Content.rules("toys")["toys"]
	if not toy_ids.any(func(id): return (toys.get(String(id), {}).get("likes", []) as Array).has(theme)):
		return false
	var need := int(rules()["lone_residents"]) if (Save.d["roster"] as Array).size() <= 1 else int(rules()["residents"])
	var kin := GardenZones.residents(zone).filter(func(r): return themes.has(theme_of(String(r["species"]))))
	return kin.size() >= need

## A species that could visit `zone` now and has a rigged model, or "".
static func pick(zone: String, toy_ids: Array) -> String:
	var fits: Array = Data.common_kin().filter(func(sp): return BokiRig.has(sp) and suits(zone, sp, toy_ids))
	return "" if fits.is_empty() else String(fits[_rng.randi() % fits.size()])

## A visitor of `species` arrives in `zone` at unix time `now`: its record, a Boki that shows what it loves.
static func begin(zone: String, species: String, now: float) -> Dictionary:
	var r := Save.new_kin(species)
	r["visitor"] = true
	r["zone"] = zone
	r["known"] = ["food"]
	var notes: Array = Save.d.get("visitor", {}).get("notes", [])
	Save.d["visitor"] = {"rec": r, "zone": zone, "t": now, "fed": 0, "notes": notes}
	Care.dex_mark(species, "seen")
	return r

static func expired(now: float) -> bool:
	return not rec().is_empty() and now - float(Save.d["visitor"]["t"]) >= float(Content.rules("care")["care_day_s"])

static func _name(r: Dictionary) -> String:
	return String(Data.KIN[String(r["species"])]["name"])

static func zone_name(zone: String) -> String:
	return String(GardenZones.info(zone).get("name", ""))

static func _zone_name() -> String:
	return zone_name(String(Save.d["visitor"]["zone"]))

## The farm day at unix time `now`: day 1 is when the oldest Boki on the roster was born; a day is care_day_s.
static func farm_day(now: float) -> int:
	var first := now
	for r in Save.d["roster"]:
		first = minf(first, float(r.get("born", now)))
	return 1 + int((now - first) / float(Content.rules("care")["care_day_s"]))

## The one memory line of a baby hatched from a visitor's egg.
static func born_line(v: Dictionary) -> String:
	var wild := String(Data.KIN[String(v["sp"])]["name"])
	return "hatched from the egg a wild %s left in %s on day %d" % [wild, zone_name(String(v["zone"])), int(v["day"])]

## Called from BaseLife.step at 10 Hz with the zone's home `h`: a visitor may arrive, or the one here may go.
static func step(h, dt: float, now := -1.0) -> void:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var r := rec()
	if r.is_empty():
		_look(h, dt, now)
		return
	var k: Dictionary = h._kin_entry(r)
	if not k.is_empty() and (k.get("busy", false) or k.has("indoors") or float(k.get("hold_t", 0.0)) > 0.0):
		return      # mid-game, in a house or being fed: it goes after
	if int(Save.d["visitor"]["fed"]) >= int(rules()["feeds"]):
		_thank(h, r, now)
	elif expired(now):
		leave(h, "A wild %s visited %s and went home" % [_name(r), _zone_name()], now)

static func _look(h, dt: float, now: float) -> void:
	_look_t += dt
	if _look_t < float(rules()["check_s"]) or now < float(Save.d.get("visitor", {}).get("next", 0.0)):
		return
	_look_t = 0.0
	if _rng.randf() >= float(rules()["chance"]):
		return
	var zone := GardenZones.current()
	var sp := pick(zone, h.toys.toys().map(func(t): return t["id"]))
	if sp == "":
		return
	var r := begin(zone, sp, now)
	h.add_kin(r, 0)
	var loves := Care.food_name(String(r["likes"]["food"]))
	h._toast("A wild %s wandered into %s. It loves %s" % [_name(r), _zone_name(), loves])

## A meal handed to a visitor (home.gd _care_feed): its favourite counts one.
static func fed(h, r: Dictionary, res: Dictionary) -> void:
	if not r.has("visitor") or not res.get("ok", false) or not res.get("love", false):
		return
	var st: Dictionary = Save.d["visitor"]
	st["fed"] = int(st["fed"]) + 1
	if int(st["fed"]) < int(rules()["feeds"]):
		h._toast("%s loved that (%d of %d)" % [r["name"], st["fed"], rules()["feeds"]])

## Three favourites: it asks to stay if the zone has room, else leaves an egg.
static func _thank(h, r: Dictionary, now: float) -> void:
	var zone := String(Save.d["visitor"]["zone"])
	if GardenZones.room(zone) > 0:
		r.erase("visitor")
		r["trust"] = 50.0
		r["origin"] = {"how": "visitor", "where": {"place": "home"}, "t": int(now)}
		CareJournal.note(r, "asked to stay after three favourite meals")
		Save.d["roster"].append(r)
		Save.register(r)
		var went := KinBox.route_new(r)      # a repeat of a species you have sleeps in the Burrow, as any new Boki does
		Care.dex_got(r)
		Save.d["visitor"] = {"notes": [], "next": now + float(rules()["gap_s"])}
		if went == "box":
			_dismiss(h, r)
		h._toast("%s asks to stay. It is yours now" % r["name"])
	else:
		var from := {"sp": String(r["species"]), "zone": zone, "day": farm_day(now)}
		var egg := Incubator.add(String(r["species"]), "", from)
		leave(h, "A wild %s left %s" % [_name(r), "a " + Incubator.egg_name(egg)], now)
		h._toast("%s left an egg" % _name(r))

## The visitor goes (its model with it when `h` has one): its line waits for the away card, the next one after gap_s.
static func leave(h, line: String, now: float) -> void:
	_dismiss(h, rec())
	var notes: Array = Save.d["visitor"].get("notes", [])
	notes.append(line)
	Save.d["visitor"] = {"notes": notes, "next": now + float(rules()["gap_s"])}

## `r` walks off the farm: its model goes with a puff.
static func _dismiss(h, r: Dictionary) -> void:
	var k: Dictionary = h._kin_entry(r) if h != null else {}
	if k.is_empty():
		return
	var n: Node3D = k["node"]
	h.fx.burst(n.position + Vector3(0, 0.5, 0), Color("bff8ec"), 14, 2.0, 0.5, -1.0)
	n.queue_free()
	h.kins.erase(k)

## The lines for the away card: a stay that ran out while you were away, what the visitors did, and who is here.
static func arrival_lines(now: float) -> Array:
	var r := rec()
	if expired(now):
		leave(null, "A wild %s visited %s and went home" % [_name(r), _zone_name()], now)
	var st: Dictionary = Save.d.get("visitor", {})
	var out: Array = (st.get("notes", []) as Array).duplicate()
	st["notes"] = []
	if st.has("rec") and not st.has("told"):
		st["told"] = true
		out.append("A wild %s is visiting %s" % [_name(r), _zone_name()])
	return out
