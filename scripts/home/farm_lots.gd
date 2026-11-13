class_name FarmLots
extends RefCounted
## Lot buildings (Workshop, Cottage, Armory, ...) go up as construction sites, the same ones the
## deco buildings use (FarmSites, docs/decisions/0004-farm-building.md). The lot's record in
## layout["b"][id] carries the e["site"] dict, and entry() hands it to FarmSites like a deco entry
## (id, and a uid of U0 + the lot's place in Data.BUILDINGS, which no deco uid reaches). When the last
## swing lands the lot is added to Save.d["buildings"] and the building pops up (Home._construct).

const U0 := 1000000      # uid of the first lot; deco uids count up from 0

static func uid(b: String) -> int:
	return U0 + Data.BUILDINGS.keys().find(b)

static func id_of(u: int) -> String:
	var keys := Data.BUILDINGS.keys()
	return String(keys[u - U0]) if u >= U0 and u - U0 < keys.size() else ""

static func is_lot(e: Dictionary) -> bool:
	return int(e.get("u", -1)) >= U0

## The lot's record as a site entry ({} while it has none: a lot that has not been put down).
static func entry(b: String, d: Dictionary = Save.d) -> Dictionary:
	var be = (HomeLayout.of(d).get("b", {}) as Dictionary).get(b)
	if typeof(be) != TYPE_DICTIONARY:
		return {}
	be["id"] = b
	be["u"] = uid(b)
	return be

## Every lot of this save that is under construction.
static func sites(d: Dictionary = Save.d) -> Array:
	var out: Array = []
	for b in (HomeLayout.of(d).get("b", {}) as Dictionary).keys():
		var e := entry(String(b), d)
		if FarmSites.has_site(e):
			out.append(e)
	return out

## What the lot costs to build: its gems or, on a farm under the building pass, the materials in
## farm_build.json "lots", plus the labour of the build.
static func cost(b: String) -> Dictionary:
	var c := FarmBuilder.lot_cost(b)
	if c.is_empty():
		c = {"gems": int(Data.BUILDINGS[b]["cost"])}
	c["labour"] = int(FarmUnlocks.rules()["lot_labour"])
	return c

## "" if a site may go up on this lot now, else why not (the Soul Shrine needs its expeditions, a Soul Ember and gems).
static func why_not(b: String) -> String:
	return Econ.shrine_why() if b == "shrine" else ""

## Puts a site on the lot (at its record, or where it stands by default). The shrine's ember goes into it.
static func start(h, b: String) -> void:
	var d: Dictionary = h._d()
	var lay := HomeLayout.of(d)
	if not (lay["b"] as Dictionary).has(b):
		lay["b"][b] = HomeLayout.place_of(b, d)
	if b == "shrine":
		Econ.use_ember()
	FarmSites.begin(entry(b, d), cost(b))
	redress(h, b)
	h.hb.apply(false)

## The model of a lot that is not built: its scaffold while a site, else the empty lot's plate.
static func look(b: String, d: Dictionary) -> Node3D:
	var e := entry(b, d)
	if FarmSites.is_site(e):
		var n := FarmModels.site(e)
		n.set_meta("sig", FarmModels.sig(e))
		return n
	var sz := HomeLayout.base_size(b)
	var lc := FarmBuilder.lot_cost(b)
	var price := FarmSites.cost_text(lc) if not lc.is_empty() else "%d gems" % int(Data.BUILDINGS[b]["cost"])
	return Models.lot(sz.x, sz.y, Data.BUILDINGS[b]["name"], price)

static func redress(h, b: String) -> void:
	var holder: Node3D = h.lots[b]["node"]
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	holder.add_child(look(b, h._d()))

## The scaffold of the site that just got a swing: rebuilt when its walls reach the next stage.
static func restage(h, e: Dictionary) -> void:
	var holder: Node3D = h.lots[String(e["id"])]["node"]
	if holder.get_child(0).get_meta("sig", "") != FarmModels.sig(e):
		redress(h, String(e["id"]))

## The scaffold of a site, for its progress bar.
static func node_of(h, e: Dictionary) -> Node3D:
	return (h.lots[String(e["id"])]["node"] as Node3D).get_child(0) as Node3D

## The last swing: the lot is built.
static func complete(h, e: Dictionary) -> void:
	var b := String(e["id"])
	if not Save.has_building(b):
		Save.d["buildings"].append(b)
	h._construct(b)

## Taking the layout apart: what the lots under construction cost so far comes back.
static func refund_sites(d: Dictionary = Save.d) -> void:
	for e in sites(d):
		FarmSites.cancel(e)

## Old saves: a lot of a farm under the building pass that was marked out but not built (the walk-up
## build is gone) becomes a site with nothing paid; a marked-out Soul Shrine is put away, since its
## ember is taken when the site starts.
static func migrate(d: Dictionary, lay: Dictionary) -> void:
	if int(lay.get("fb", 0)) < 1 or not is_same(d, Save.d):
		return
	for b in (lay["b"] as Dictionary).keys():
		var be: Dictionary = lay["b"][b]
		if FarmSites.has_site(be) or d.get("buildings", []).has(b):
			continue
		if b == "shrine":
			(lay["b"] as Dictionary).erase(b)
		else:
			FarmSites.begin(be, cost(String(b)))
