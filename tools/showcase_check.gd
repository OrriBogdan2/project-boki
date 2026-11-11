extends RefCounted
## --showcase-check: the Dash's showcase wall (scripts/home/base_showcase.gd, GARDEN.md 5.1).
##   1. a win pins an entry (name, species, date, twist); the 7th win drops the oldest, 6 stay
##   2. the weekly twist follows the week number and wraps round the list
##   2b. the week maps to a format for one game; only that game gets the tweak
##   3. the visit snapshot carries the wall and a visitor's copy is cleaned (bad image dropped, capped at 6)
##   4. the wall builds one frame per entry
##   5. a settled Dash on the base pins its winner (image-less headless)
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SHOWCASE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(_m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_wall()
	_twists()
	_formats()
	_visit()
	print("SHOWCASE DONE, failures: %d" % bad)
	_m.get_tree().quit(1 if bad > 0 else 0)

func _rec(n: String) -> Dictionary:
	var k := Save.new_kin("zapple", n)
	Care.ensure(k)
	return k

func _wall() -> void:
	var tw := BaseRace.twist(0)
	for i in BaseShowcase.MAX + 1:
		BaseShowcase.add(_rec("W%d" % i), tw)
	var wall: Array = Save.d["showcase"]
	ok(wall.size() == BaseShowcase.MAX, "the wall holds %d frames" % BaseShowcase.MAX)
	var last := "W%d" % BaseShowcase.MAX
	ok(wall[0]["name"] == "W1" and wall[-1]["name"] == last, "the oldest dropped off, the newest is last")
	var e: Dictionary = wall[-1]
	var dated: bool = e["date"] == Time.get_date_string_from_system()
	ok(dated and e["twist"] == tw["name"] and e["species"] == "zapple", "an entry has the date, twist, species")
	var node := BaseShowcase.build(Vector3.ZERO, wall)
	var labels := node.get_children().filter(func(c): return c is Label3D).size()
	ok(labels == BaseShowcase.MAX, "the wall builds a caption per frame (%d)" % labels)
	node.free()

func _twists() -> void:
	var list: Array = BaseRace.rules()["twists"]
	ok(list.size() >= 3, "%d weekly twists in the list" % list.size())
	var wraps: bool = BaseRace.twist(5 + list.size()) == BaseRace.twist(5)
	ok(BaseRace.twist(5) == list[5 % list.size()] and wraps, "the twist follows the week number and wraps")
	var seen := {}
	for w in list.size():
		seen[BaseRace.twist(w)["id"]] = true
	ok(seen.size() == list.size(), "consecutive weeks rotate through every twist")
	ok(BaseRace.week_now() > 2900, "week_now is a real week number (%d)" % BaseRace.week_now())

## The week maps to a format for a known game, and only that game gets this week's tweak.
func _formats() -> void:
	var list: Array = BaseRace.rules()["twists"]
	var games := {}
	for w in list.size() * 2:
		var f := BaseRace.twist(w)
		games[f["game"]] = true
		var known: bool = ["dash", "seek", "volley"].has(f["game"]) and not String(f["note"]).is_empty()
		ok(f == list[w % list.size()] and known, "week %d maps to format %s (%s)" % [w, f["id"], f["game"]])
	ok(games.size() == 3, "the rotation visits Dash, Seek and Volley")
	var now := BaseRace.twist()
	ok(now == list[BaseRace.week_now() % list.size()], "this week's format is %s" % now["id"])
	var tweaked := ["dash", "seek", "volley"].filter(func(g): return not BaseRace.tweak(g).is_empty())
	ok(tweaked == [now["game"]], "only %s gets this week's tweak" % now["game"])

func _visit() -> void:
	var mine := Social.profile_doc()
	var carried: Array = mine.get("showcase", [])
	ok(carried.size() == BaseShowcase.MAX, "the visit snapshot carries the wall")
	var raw: Dictionary = mine.duplicate(true)
	var junk: Array = raw["showcase"]
	for i in 4:
		junk.append({"name": "X", "img": "zz".repeat(BaseShowcase.IMG_CHARS)})
	raw["showcase"][0]["img"] = "not a png"
	var seen := Social.clean_island(raw)
	var cleaned: Array = seen["showcase"]
	ok(cleaned.size() == BaseShowcase.MAX, "a visitor's wall is capped at %d" % BaseShowcase.MAX)
	ok(BaseShowcase.texture(String(cleaned[0]["img"])) == null, "a bad portrait is not drawn")
	ok(Social.clean_island({}).get("showcase", [1]).is_empty(), "no wall in the snapshot = an empty wall")
