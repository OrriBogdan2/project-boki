extends RefCounted
## --baby-parents-check (GARDEN.md section 6): a baby knows its parents. Care.breed saves both parent uids and
## who gave what (Parentage); the hatch card marks each gift with its parent (HatchParents); in base life a
## young Boki leans toward its parents for greeting and napping (a weight, not a rule) and gets one journal
## line the first time.
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BABYPARENTS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

class StubWorld:
	func island_of(_x: float, _z: float) -> int:
		return 0

class StubHome:
	var kins: Array = []
	var world := StubWorld.new()
	var emotes := 0
	func _emote(_k: Dictionary, _s: String, _big := false) -> void:
		emotes += 1

func _kin(sp: String, nick: String, lv: int) -> Dictionary:
	var k := Save.new_kin(sp, nick)
	k["level"] = lv
	return k

func _entry(home: StubHome, life: BaseLife, rec: Dictionary, x: float) -> Dictionary:
	var k := {"rec": rec, "pos": Vector3(x, 0, 0)}
	life.machine(k)
	home.kins.append(k)
	return k

## The hatch card's trait with this label ({} if the card doesn't list it).
func _trait(kid: Dictionary, what: String) -> Dictionary:
	for t in HatchParents.traits(kid):
		if t["what"] == what: return t
	return {}

## Which parent gave the baby its highest inherited IV, worked out here on its own.
func _best_from(kid: Dictionary) -> int:
	var top := -1
	var side := -3
	for k in Care.IV_KEYS:
		if kid["iv_from"].has(k) and int(kid["ivs"][k]) > top:
			top = int(kid["ivs"][k])
			side = int(kid["iv_from"][k])
	return side

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	HomeLayout.ensure(Save.d)
	seed(5)
	var a := _kin("cindle", "Ash", 8)
	var b := _kin("puddlet", "Bri", 8)
	a["lean"] = {"ember": 6.0}
	a["mutations"] = ["giant"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# ---- saved on the baby: both parent uids and the gifts
	var uids := 0
	var words := 0
	var kinds := 0
	var leans := 0
	var stats := 0
	for i in 20:
		var pa: Dictionary = a if i % 2 == 0 else b
		var pb: Dictionary = b if i % 2 == 0 else a
		var kid := Care.breed(pa, pb, rng)
		var g: Dictionary = kid["gifts"]
		if kid["lineage"]["parents"] == [pa["uid"], pb["uid"]]: uids += 1
		var named := [_trait(kid, "Kind and colour"), _trait(kid, "Lean"), _trait(kid, "Loves"), _trait(kid, "Likes")]
		if not named.has({}) and int(named[1]["from"]) == int(g["lean"]): words += 1
		if int(_trait(kid, "Best stat").get("from", -2)) == _best_from(kid): stats += 1
		var src: Dictionary = pa if g["species"] == 0 else pb
		if kid["species"] == src["species"]: kinds += 1
		if g["lean"] == (0 if pa == a else 1): leans += 1
	ok(uids == 20, "20 of 20 babies save both parent uids (%d)" % uids)
	ok(kinds == 20, "the kind it hatched as is the kind the gift names (%d of 20)" % kinds)
	ok(leans == 20, "the lean gift names the parent with the stronger lean (%d of 20)" % leans)
	ok(words == 20, "the hatch card marks the kind, the lean and both habits with their parent (%d of 20)" % words)
	ok(stats == 20, "its best inherited stat is marked with the parent it came from (%d of 20)" % stats)
	var twin := Care.breed(_kin("cindle", "X", 8), _kin("cindle", "Y", 8), rng)
	var twin_kind := int(_trait(twin, "Kind and colour")["from"])
	var both: bool = twin["gifts"]["species"] == Parentage.BOTH and twin_kind == Parentage.BOTH
	ok(both, "two of one kind give the kind together")
	ok(not twin["gifts"].has("lean"), "no lean in either parent, no lean gift")
	var muts := 0
	for i in 40:
		var kid := Care.breed(a, b, rng)
		var got: Dictionary = kid["gifts"].get("muts", {})
		var mt := _trait(kid, "Mutation")
		var named_giant := String(mt.get("val", "")) == Mutations.name_of("giant")
		if got.has("giant") and named_giant and int(mt["from"]) == 0: muts += 1
	ok(muts > 0, "a mutation a parent carried is credited to that parent (%d of 40)" % muts)
	ok(not HatchParents.has_row(_kin("cindle", "Old", 8)), "an older or wild Boki with no gifts gets no parents row")
	var rare := _kin("cindle", "Rare", 1)
	rare["rare"] = true
	ok(not HatchParents.has_row(rare), "a Rare Egg's Boki gets no parents row")
	var row := HatchParents.view(Care.breed(a, b, rng), m.get_tree())
	var dots := row.find_children("*", "Control", true, false).filter(func(c): return c is HatchParents.Dot).size()
	var lines := row.get_child_count()
	ok(lines >= 6 and dots >= lines + 1, "parents, then a marker per trait (%d lines, %d dots)" % [lines, dots])
	row.free()
	# ---- base life: a young Boki leans toward its parents
	var home := StubHome.new()
	var life := BaseLife.new(home)
	var w := float(life.R["parent_weight"])
	var kid := Care.breed(a, b, rng)
	kid["level"] = 1
	var stranger := _kin("burrlet", "Sam", 8)
	var found := Parentage.is_parent_of(a, kid) and Parentage.is_parent_of(b, kid)
	ok(found and not Parentage.is_parent_of(stranger, kid), "its parents are found by uid")
	var liked := BaseLife.regard({"rec": kid}, {"rec": a}, w)
	ok(liked > BaseLife.regard({"rec": kid}, {"rec": stranger}, w), "a parent weighs more than a stranger")
	kid["bonds"] = {a["uid"]: -0.9}
	liked = BaseLife.regard({"rec": kid}, {"rec": a}, w)
	ok(liked < float(life.R["friend_at"]), "a weight, not a rule: a parent it fell out with is not greeted")
	kid.erase("bonds")
	var kk := _entry(home, life, kid, 0.0)
	var ak := _entry(home, life, a, 1.0)
	var sk := _entry(home, life, stranger, 1.5)
	for e in [ak, sk]:
		life.machine(e).go(BaseLife.S.NAP, "test")
		e["nap_t"] = 30.0
	var parent_naps := 0
	for i in 10:
		kk.erase("life_pile")
		life.machine(kk).go(BaseLife.S.ROAM, "test")
		life._nap(kk, "tired")
		if kk.get("life_pile") == ak: parent_naps += 1
	ok(parent_naps == 10, "it walks to its napping parent, not the napping stranger, 10 of 10 (%d)" % parent_naps)
	var first: Array = kid["memory"].filter(func(e): return e["kind"] == "parent")
	var text := String(first[0]["text"]) if first.size() == 1 else ""
	ok(text.contains("Ash"), "one journal line the first time (%d): %s" % [first.size(), text])
	var before: int = kid["memory"].size()
	life._greet(kk, [ak])
	BaseLife.note_parent(kk, ak, "said hello to")
	ok(kid["memory"].size() == before, "later greetings and naps add no second line")
	var grown := _kin("cindle", "Big", 8)
	grown["lineage"] = {"parents": [a["uid"], b["uid"]]}
	ok(not Parentage.is_parent_of(a, grown), "a Grown Boki has left the nest: no parent weight")
	var greeted := 0
	var kid2 := Care.breed(a, b, rng)
	kid2["level"] = 1
	var k2 := _entry(home, life, kid2, 0.0)
	var before_emotes := home.emotes
	for i in 40: life._greet(k2, [ak, sk])
	greeted = home.emotes - before_emotes
	ok(greeted > 5 and greeted < 35, "it greets a parent about half the time, not always (%d of 40)" % greeted)
	print("BABYPARENTS done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
