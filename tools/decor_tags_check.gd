extends RefCounted
## --decor-tags-check (GARDEN_MODERN.md 5 rank 7, scripts/home/decor_comfort.gd): decor with a purpose.
## Every decoration in the build catalog has one known comfort tag. In the start zone three pieces of one
## tag switch that tag's effect on (its number reaches SnackPatch, GardenVisitor and the rest), the zone
## card lists it by name, and removing one switches it off again. A built zone counts its own pieces.
## Data only, no Home; never touches the real save.

const DECOR_CATS := ["Garden", "Lights", "Furniture", "Statues"]     # the catalog tabs that hold decorations
const THREE := {"cosy": ["rug", "kin_bed", "bench"], "bright": ["lantern", "lamp_post", "flowers"],
	"wild": ["bush", "tree", "pine"], "quiet": ["pillar", "kin_statue", "fountain"]}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DECOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	HomeLayout.ensure(Save.d)
	GardenZones.here = GardenZones.start()
	_tags_part()
	for tag in THREE:
		_switch_part(tag)
	_hooks_part()
	_built_zone_part()
	print("DECOR DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

func _tags_part() -> void:
	var known: Array = DecorComfort.rules()["effects"].keys()
	for id in HomeLayout.CATALOG:
		var c: Dictionary = HomeLayout.CATALOG[id]
		if DECOR_CATS.has(c.get("cat", "")) and id != SnackPatch.ID:
			ok(known.has(DecorComfort.tag_of(id)), "%s has a comfort tag (%s)" % [id, DecorComfort.tag_of(id)])
	for tag in known:
		var fx: Dictionary = DecorComfort.rules()["effects"][tag]
		var named := String(fx.get("name", "")) != "" and String(fx.get("does", "")) != ""
		ok(named, "%s effect has a name and a line" % tag)

## Only the given pieces on the start zone's island (the fresh layout's untagged pieces stay).
func _set_deco(ids: Array) -> void:
	var L: Dictionary = Save.d["layout"]
	var deco: Array = (L["deco"] as Array).filter(func(e): return DecorComfort.tag_of(String(e["id"])) == "")
	for id in ids:
		deco.append({"id": id, "x": 4 + deco.size(), "z": 4, "r": 0, "u": HomeLayout._next_uid(L)})
	L["deco"] = deco

func _card_has(zone: String, tag: String) -> bool:
	var title := String(DecorComfort.rules()["effects"][tag]["name"])
	var found := false
	for l in ZoneCards.open_lines(zone):
		found = found or (l as Label).text.begins_with(title + ":")
		l.free()
	return found

func _switch_part(tag: String) -> void:
	var three: Array = THREE[tag]
	var start := GardenZones.start()
	_set_deco(three.slice(0, 2))
	ok(not DecorComfort.on(tag) and not _card_has(start, tag), "%s: two pieces, effect off" % tag)
	_set_deco(three)
	ok(DecorComfort.on(tag), "%s: three pieces switch the effect on" % tag)
	ok(_card_has(start, tag), "%s: the zone card lists it" % tag)
	ok(DecorComfort.active(start).size() == 1, "%s: no other tag's effect is on" % tag)
	_set_deco(three.slice(1))
	ok(not DecorComfort.on(tag), "%s: removing one switches it off" % tag)
	ok(not _card_has(start, tag), "%s: the card no longer lists it" % tag)

## Each effect's number reaches the system it changes, and only while it is on.
func _hooks_part() -> void:
	var fx: Dictionary = DecorComfort.rules()["effects"]
	var grow := float(SnackPatch.rules()["grow_secs"])
	var chance := float(GardenVisitor.rules()["chance"])
	_set_deco([])
	ok(is_equal_approx(SnackPatch.grow_secs(), grow), "bright off: the patch ripens in grow_secs")
	ok(is_equal_approx(GardenVisitor.chance(), chance), "wild off: the visitor chance is the rules'")
	ok(DecorComfort.value("cosy", "nap_joy", 0.0) == 0.0, "cosy off: naps restore no joy")
	ok(DecorComfort.value("quiet", "clash", 1.0) == 1.0, "quiet off: squabbles at the rules' chance")
	_set_deco(THREE["bright"] + THREE["wild"] + THREE["cosy"] + THREE["quiet"])
	ok(DecorComfort.active(GardenZones.start()).size() == 4, "all four tags three times: four effects on")
	ok(is_equal_approx(SnackPatch.grow_secs(), grow * float(fx["bright"]["grow"])) and SnackPatch.grow_secs() < grow,
		"bright on: the patch ripens faster")
	ok(GardenVisitor.chance() > chance, "wild on: visitors come more often")
	ok(DecorComfort.value("cosy", "nap_joy", 0.0) > 0.0, "cosy on: naps restore joy")
	ok(DecorComfort.value("quiet", "clash", 1.0) < 1.0, "quiet on: fewer squabbles")

## A built zone counts its own fixed pieces, not the start zone's island.
func _built_zone_part() -> void:
	var built: Array = GardenZones.ids().filter(func(id): return ZoneLayout.built(id))
	ok(not built.is_empty(), "a built zone exists")
	if built.is_empty():
		return
	_set_deco(THREE["bright"])
	var zone := String(built[0])
	ok(DecorComfort.active(zone).is_empty(), "%s: the start zone's lanterns are not its own" % zone)
	ok(DecorComfort.active(GardenZones.start()).has("bright"), "the start zone keeps its own effect")
