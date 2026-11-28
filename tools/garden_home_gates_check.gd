extends RefCounted
## --garden-home-gates-check: a home-only save (base mode, no expedition, matches 0, extracts 0) reaches every
## unlock an expedition used to hold alone, through content/rules/home_gates.json (docs/GARDEN.md, "Gates for
## a player who never extracts"). Walks every shop requirement, challenge, farm milestone, glider and wisp look
## that counts an expedition stat: each must be out of reach on a fresh home save, and reached once the save
## has done only the home stats the table names. Also: farm points do not double count the road, and an
## expedition stat never drops after a run.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HOMEGATES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh() -> void:
	Save.d = Save.fresh()
	Save.d["roster"] = [Save.new_kin(Data.common_kin()[0], "Home")]

## Stats (name -> n) an expedition would raise, found by walking every reader of Progress.stat.
func _gates() -> Dictionary:
	var g := {}   # stat -> biggest n anything asks of it
	for c in Progress.CHALLENGES:
		g[c[3]] = maxi(int(g.get(c[3], 0)), int(c[4]))
	for k in Progress.SHOP_REQ:
		if Progress.SHOP_REQ[k].has("extracts"):
			g["extracts"] = maxi(int(g.get("extracts", 0)), int(Progress.SHOP_REQ[k]["extracts"]))
	var ms: Dictionary = FarmUnlocks.rules()["milestones"]
	for id in ms:
		g[ms[id]["stat"]] = maxi(int(g.get(ms[id]["stat"], 0)), int(ms[id]["n"]))
	return g

func run(m: Node) -> void:
	Save.no_write = true
	var was: bool = Content.rules("farm_build")["base_mode"]
	Content.rules("farm_build")["base_mode"] = true
	var road: Dictionary = Content.rules("home_gates")
	var home_stats := ["harvested", "hatched", "built", "fb_built", "max_trust"]
	_fresh()
	ok(int(Save.d.get("matches", 0)) == 0 and int(Save.d.get("extracts", 0)) == 0, "fresh home save has no expedition")
	var gates := _gates()
	# 1. out of reach to begin with
	for k in ["extracts", "matches", "bosses", "caught", "mobs", "rings", "knocks"]:
		ok(Progress.stat(k) == 0, "fresh save: %s is 0 (is %d)" % [k, Progress.stat(k)])
	# 2. which expedition-only stats have a road, which stay away (match feats with no garden twin)
	var away: Array = []
	for k in gates:
		if home_stats.has(String(k)):
			continue   # a home stat gates itself
		if road["stats"].has(k):
			var hs := String(road["stats"][k]["home"])
			ok(home_stats.has(hs), "%s road uses a home stat (%s)" % [k, hs])
		else:
			away.append(k)
	print("HOMEGATES away (match feats, Hunter unlocks and mastery, no gate on the farm): %s" % [away])
	for k in away:
		var feat := ["glide_s", "feathers", "staggers", "slams", "spikes"].has(k)
		ok(feat, "%s is a pure match feat (gates only a reward challenge)" % k)
	# 3. do only the home stats the table asks for, and every road gate opens
	var stats := {}
	for k in gates:
		if road["stats"].has(k):
			var h: Dictionary = road["stats"][k]
			stats[h["home"]] = maxi(int(stats.get(h["home"], 0)), int(ceil(float(h["per"]) * int(gates[k]))))
	Save.d["roster"][0]["trust"] = float(stats.get("max_trust", 0))
	stats.erase("max_trust")   # trust is read off the roster, not the stats table
	Save.d["stats"] = stats
	ok(int(Save.d["matches"]) == 0 and int(Save.d["extracts"]) == 0, "still no expedition after the home work")
	for k in gates:
		if road["stats"].has(k):
			var have := Progress.stat(String(k))
			ok(have >= int(gates[k]), "home road reaches %s %d (have %d)" % [k, gates[k], have])
	for k in Progress.SHOP_REQ:
		var r: Dictionary = Progress.SHOP_REQ[k]
		if r.has("extracts"):
			ok(Progress.unlocked(k), "shop %s opens (needs %d extractions)" % [k, r["extracts"]])
		elif r.has("challenge"):
			var cid: String = r["challenge"]
			var claimable := Progress.ready_to_claim().any(func(c): return c[0] == cid)
			if Progress.stat(Progress.challenge(cid)[3]) >= int(Progress.challenge(cid)[4]):
				ok(claimable, "shop %s: challenge %s claimable" % [k, cid])
	for id in FarmUnlocks.rules()["milestones"]:
		ok(FarmUnlocks.milestone_done(String(id)), "milestone %s done" % id)
		ok(road["milestones"].has(id), "milestone %s has a goal row text" % id)
	# 4. farm level counts the real stats only (no double count)
	Save.d["stats"] = {"harvested": 25}
	ok(is_equal_approx(FarmUnlocks.points(), 25 * 0.25), "farm points count harvested once (%s)" % FarmUnlocks.points())
	# 5. a real expedition keeps what it unlocked
	Save.d["extracts"] = 3
	ok(Progress.stat("extracts") == 5, "5 harvests still count 5 extractions beside 3 real (the larger)")
	Save.d["extracts"] = 9
	ok(Progress.stat("extracts") == 9, "9 real extractions count 9")
	Save.d["stats"] = {}
	ok(Progress.stat("extracts") == 9, "the real count stays after the home work is gone")
	Content.rules("farm_build")["base_mode"] = false
	Save.d["stats"] = {"harvested": 100}
	Save.d["extracts"] = 0
	ok(Progress.stat("extracts") == 0, "base mode off: the road is closed")
	Content.rules("farm_build")["base_mode"] = was
	print("HOMEGATES %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)
