extends RefCounted
## --base-stray-check (GARDEN.md section 4): a Boki adopted from the Shelter is a garden moment. With base_mode on it
## arrives at the zone's stone (the pad), the Boki near by come to look and the first to arrive keeps "was there the
## day <name> arrived"; for its first farm day it keeps to the island's edge and takes no part in tag or toys,
## then it cheers up and the shy mark is gone. A Boki with no shy mark (an old save) is settled. Never touches the
## real save.

const DT := 0.25             # s per farm step
const LOOK_S := 20.0         # s the residents get to come over and look
const SHY_RUN_S := 150.0     # s of the shy day that are watched
const PAD_R := 3.0           # m: how close to the pad it arrives

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BASESTRAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> void:
	var d := Save.fresh()
	var names := ["Ash", "Crag", "Moss"]
	var species := ["cindle", "basaltoad", "burrlet"]
	for i in names.size():
		var rec := Save.new_kin(species[i], names[i])
		rec["traits"]["curiosity"] = 0.9
		rec["traits"]["bravery"] = 0.9
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["gems"] = 500
	d["matches"] = 3
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	Econ.ensure()
	HomeLayout.ensure(d)
	HomeLayout.of(d)["fb"] = 0      # no building pass: the stall is open at every level, so is the Shelter

func _entry(home, rec: Dictionary) -> Dictionary:
	for k in home.kins:
		if k["rec"] == rec:
			return k
	return {}

func _near_pad(home, k: Dictionary) -> float:
	return Vector2(k["pos"].x, k["pos"].z).distance_to(Vector2(home.hway.pad["pos"].x, home.hway.pad["pos"].z))

func _from_middle(home, k: Dictionary) -> float:
	var isle := maxi(home.world.island_of(k["pos"].x, k["pos"].z), 0)
	return Vector2(k["pos"].x, k["pos"].z).distance_to(home.world.islands[isle]["c"])

func _memory_of_day(home, nm: String) -> bool:
	for k in home.kins:
		for m in k["rec"]["memory"]:
			if String(m["text"]).contains("the day %s arrived" % nm):
				return true
	return false

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(5)
	ok(not BaseShy.shy({}) and not BaseShy.shy({"shy_s": 0.0}), "no shy mark (an old save, a hatched Boki): settled")
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	_new_save()
	var home = await main._hb_home()
	home.panel_open = ""
	home.ppos = Vector3(-500, 0, -500)
	FarmChatter._known.clear()
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)      # the first look only learns who lives here
	home._move_kin(DT)      # the base has met its residents: the next new uid is an arrival
	var cards: Array = Shelter.cards()
	var stray: Dictionary = cards.filter(func(c): return String(c.get("from", "")) == "")[0]
	var r := Shelter.adopt(String(stray["id"]))
	ok(r["ok"], "adopting a stray works (%s)" % r["why"])
	var rec: Dictionary = r.get("rec", {})
	ok(r["ok"] and BaseShy.shy(rec), "adopting a stray starts its shy day (%.0f s)" % float(rec.get("shy_s", 0.0)))
	home._spawn_kin()
	var pad: Vector3 = home.hway.pad["pos"]
	for k in home.kins:
		if k["rec"] != rec:
			k["pos"] = home.world.free_spot_near(pad + Vector3(cos(k["pos"].x), 0, sin(k["pos"].x)) * 5.0, [], 1.3)
			(k["node"] as Node3D).position = k["pos"]
			k["goal"] = Vector3.INF
	home._move_kin(DT)
	var kid := _entry(home, rec)
	ok(not kid.is_empty() and _near_pad(home, kid) < PAD_R, "it arrives at the pad (%.1f m)" % _near_pad(home, kid))
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)
	ok(not ComeLook._looks.is_empty() and ComeLook._looks[0]["kind"] == "boki",
		"the residents come to look (%d)" % ComeLook._looks.size())
	var reacted := false
	var t := 0.0
	while t < LOOK_S:
		home._move_kin(DT)
		FarmChatter.tick(home, DT)
		t += DT
		for k in home.kins:
			reacted = reacted or (k != kid and (k["life"] as Fsm).is_in(BaseLife.S.REACT))
	ok(_memory_of_day(home, String(rec["name"])), "the first to reach it keeps 'the day %s arrived'" % rec["name"])
	ok(reacted or ComeLook._looks.is_empty(), "they have looked and gone back to what they do")
	var center: Vector3 = home.world.random_ground(0)
	Save.d["layout"]["deco"].append({"id": "toy_ball", "u": 990001, "px": center.x + 3.0, "pz": center.z})
	var kid_d := 0.0
	var res_d := 0.0
	var res_n := 0
	var kid_n := 0
	var played := false
	while t < LOOK_S + SHY_RUN_S:
		home._move_kin(DT)
		t += DT
		var fsm: Fsm = kid["life"]
		played = played or fsm.is_in(BaseLife.S.PLAY) or fsm.is_in(BaseLife.S.PLAY_WITH) or kid.has("play")
		if not fsm.is_in(BaseLife.S.NAP):
			kid_d += _from_middle(home, kid)
			kid_n += 1
		for k in home.kins:
			if k != kid and not (k["life"] as Fsm).is_in(BaseLife.S.NAP):
				res_d += _from_middle(home, k)
				res_n += 1
	ok(not played, "the shy Boki joins no tag and no toy")
	var kid_mean := kid_d / maxf(kid_n, 1.0)
	var res_mean := res_d / maxf(res_n, 1.0)
	ok(kid_n > 0 and kid_mean > res_mean + 1.0,
		"it keeps to the edge (%.1f m out, the others %.1f m)" % [kid_mean, res_mean])
	var left := float(rec.get("shy_s", 0.0))
	ok(left > 0.0 and left < float(BaseShy.rules()["secs"]), "the shy day is counting down (%.0f s left)" % left)
	rec["shy_s"] = 1.0
	for i in int(2.0 / DT):
		home._move_kin(DT)
	ok(not BaseShy.shy(rec) and not rec.has("shy_s"), "after its day it is settled: the shy mark is gone")
	ok(not BaseShy.keep_to_edge(home, kid), "and it no longer keeps to the edge")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASESTRAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
