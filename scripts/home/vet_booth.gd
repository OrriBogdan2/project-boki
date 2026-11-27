class_name VetBooth
extends RefCounted
## The vet booth beside the market stall (content/rules/vet_booth.json): walk up and every Boki on the island gets a
## free check-up (health, likes, mood), and a weak or sick one is cured for gems. The cure is the hunger cure a
## snack gives (Care.feed erases the starve clock, KinAiling.perk_up shows it). The booth is a fixture of the hub
## (HubLayout.DECO).

const ID := "vet_booth"
const REACH := 1.6  # m from the booth's middle you can open it
const PANEL_W := 620.0  # px


static func rules() -> Dictionary:
	return Content.rules("vet_booth")


## The booth's deco entry on this island, or {}.
static func entry(h) -> Dictionary:
	for e in h.hb.L()["deco"]:
		if String(e["id"]) == ID:
			return e
	return {}


## The booth as an interact entry if you stand within reach, else {}.
static func find(h, p2: Vector2) -> Dictionary:
	var e := entry(h)
	if e.is_empty():
		return {}
	var c := HomeLayout.deco_center(e)
	return {"kind": "vet", "e": e} if p2.distance_to(Vector2(c.x, c.z)) < REACH else {}


static func label() -> String:
	return "Vet booth: free check-up"


## The mood word for a joy value 0..100.
static func mood(joy: float) -> String:
	for band in rules()["moods"]:
		if joy >= float(band[0]):
			return String(band[1])
	return String(rules()["moods"][-1][1])


## What the check-up says about one Boki: {health: word, sick: bool, likes: line, mood: word}.
static func read(rec: Dictionary) -> Dictionary:
	Care.ensure(rec)
	var hours := Care.starve_h(rec)
	var health := "In good shape"
	if hours >= Care.STARVE["sick"]:
		health = "Sick from hunger"
	elif hours >= Care.STARVE["weak"]:
		health = "Weak from hunger"
	var likes: Dictionary = rec["likes"]
	return {
		"health": health,
		"sick": Care.ailing(rec),
		"likes":
		(
			"Likes %s and %s, dislikes %s"
			% [Care.food_name(String(likes["food"])), likes["play"], Care.food_name(String(likes["hates"]))]
		),
		"mood": mood(Care.need(rec, "joy")),
	}


static func cure_cost() -> int:
	return int(rules()["cure_gems"])


## "" when the cure can go ahead, else why not.
static func cure_why(rec: Dictionary) -> String:
	if not Care.ailing(rec):
		return "Nothing to cure"
	if int(Save.d["gems"]) < cure_cost():
		return "Needs %d gems" % cure_cost()
	return ""


## Pays and cures a weak or sick Boki. False when it is not ailing or the gems are short.
static func cure(h, rec: Dictionary) -> bool:
	if cure_why(rec) != "":
		return false
	Save.d["gems"] = int(Save.d["gems"]) - cure_cost()
	rec.erase("starve")
	var k: Dictionary = h._kin_entry(rec)
	if not k.is_empty():
		KinAiling.perk_up(h, k)
	Save.save_game()
	return true


## The booth's panel: a card for each Boki that is out on the island.
static func open(h) -> void:
	var v: VBoxContainer = h._new_panel("Vet booth", PANEL_W, true)
	UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	UI.subtitle(v, "A check-up is free. A cure is %d gems." % cure_cost())
	var seen: Array = h.kins.filter(func(k): return not k.has("indoors"))
	if seen.is_empty():
		v.add_child(UI.empty_state("heart", "Nobody here", "Bring a Boki along to the booth for a check-up."))
		return
	for k in seen:
		v.add_child(_card(h, k["rec"]))


static func _card(h, rec: Dictionary) -> Control:
	var res := read(rec)
	var card := UI.card(UI.CARD, 12, 12)
	var row := UI.hbox(12)
	card.add_child(row)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(8)
	head.add_child(UI.label(String(rec["name"]), UI.T_HEAD, UI.INK, UI.big))
	head.add_child(UI.tag(String(res["health"]), UI.BAD if res["sick"] else UI.GOOD))
	head.add_child(UI.tag("Mood: %s" % res["mood"], UI.MUTED))
	info.add_child(head)
	info.add_child(UI.label(String(res["likes"]), 12, UI.MUTED))
	row.add_child(info)
	if res["sick"]:
		var why := cure_why(rec)
		var btn := UI.button("Cure (%d gems)" % cure_cost(), func(): _cure_and_refresh(h, rec), 150)
		btn.disabled = why != ""
		btn.tooltip_text = why
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)
	return card


static func _cure_and_refresh(h, rec: Dictionary) -> void:
	if cure(h, rec):
		open(h)


static func model(_e: Dictionary) -> Node3D:
	var n := Node3D.new()
	var wood := Models.toon(Color("a8754a"))
	var cloth := Models.toon(Color("f3eee2"), false)
	var teal := Models.toon(Color("4fb3a5"), false)
	var red := Models.toon(Color("e0607e"), false)
	Models.part(n, Models.box(1.8, 0.7, 0.55), wood, Vector3(0, 0.35, 0.1))
	Models.part(n, Models.box(1.9, 0.08, 0.7), Models.toon(Color("c99a6a")), Vector3(0, 0.74, 0.1))
	for sx in [-0.85, 0.85]:
		Models.part(n, Models.box(0.08, 1.4, 0.08), wood, Vector3(sx, 0.7, -0.2))
	for i in 6:
		var band := teal if i % 2 == 0 else cloth
		Models.part(
			n,
			Models.box(0.32, 0.06, 0.7),
			band,
			Vector3(-0.8 + i * 0.32, 1.42, -0.05),
			Vector3.ONE,
			Vector3(0.25, 0, 0)
		)
	Models.part(n, Models.box(0.34, 0.1, 0.06), red, Vector3(0, 1.0, -0.16))
	Models.part(n, Models.box(0.1, 0.34, 0.06), red, Vector3(0, 1.0, -0.16))
	return n
