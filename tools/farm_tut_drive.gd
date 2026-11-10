extends RefCounted
## --farm-tut-time: a timed headless run of the whole farm tutorial on a fresh farm, step by step, as a
## player who knows what to do would play it (decision 0023: this gives the seconds).
## The clock is the drive's own: walking between the spots at the farm's walking speed, chopping and
## mining and hammering by holding the key (the real tools, 0.05 s ticks), the crop's real growing time,
## and a fixed cost for reading each new prompt and for each menu or panel. No Boki help is counted.
## Prints "FTT step <id> t=..." per step and "FTT DONE <n> steps, t=<s>" (exit 1 if it never finishes).
## Every step id the tutorial ever had is driven, so the same file times an older version of the tutorial.

const READ_S := 2.0         # s to read a new prompt (each step stage's line, once)
const MENU_S := 3.0         # s to open the build menu, pick a tile and click the spot
const PANEL_S := 2.0        # s for a panel: plant a seed, fill the trough, pick a job, buy or sell
const TALK_LINE_S := 2.5    # s per line Hob says
const DT := 0.05            # s per tick while holding the key
const LIMIT_S := 900.0      # s of drive time before it gives up

var main: Node
var home
var t := 0.0
var ripe_at := -1.0

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = _new_save()
	HomeLayout.ensure(Save.d)
	home = await main._hb_home()
	while home.panel_host == null:
		await main.get_tree().process_frame
	home._close_panel()
	var ok := FarmTutorial.active()
	print("FTT start: %d steps, active %s" % [FarmTutorial.steps().size(), str(ok)])
	var seen := {}
	var last := ""
	var tries := 0
	while ok and FarmTutorial.active() and t < LIMIT_S and tries < 400:
		tries += 1
		var g := FarmCropGuide.growing()
		if ripe_at < 0.0 and not g.is_empty():
			ripe_at = t + float(g["left"])      # (it grows on the drive's clock while the other steps go on)
		if ripe_at >= 0.0 and t >= ripe_at:
			_ripen()
		FarmTutorial.detect()
		var id := FarmTutorial.current()
		if id == "":
			break
		var stg := FarmTutorial.stage(id)
		if id != last:
			print("FTT step %s t=%.1f" % [id, t])
			last = id
		if not seen.has(id + ":" + stg):
			seen[id + ":" + stg] = true
			t += READ_S
		await _act(id, stg)
		await main.get_tree().process_frame
	var done := bool(FarmTutorial.state()["done"])
	print("FTT DONE %d steps, t=%.1f (finished %s)" % [FarmTutorial.steps().size(), t, str(done)])
	main.get_tree().quit(0 if done else 1)

func _new_save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	k["starter"] = true
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}      # (no "home": a brand new farm-start island)
	return d

func _walk(to: Vector3) -> void:
	if to == Vector3.INF:
		return
	t += Vector2(to.x - home.ppos.x, to.z - home.ppos.z).length() / float(home.SPEED)
	home.ppos = Vector3(to.x, home.ppos.y, to.z)
	home.player.position = home.ppos

func _act(id: String, stg: String) -> void:
	match id:
		"chop":
			_gather("tree")
		"stone":
			_gather("rock")
		"house":
			if stg == "place":
				_walk(home.guide.house_spot())
				t += MENU_S
				home.guide.place_house()
			else:
				_hammer()
		"hammer":
			_hammer()
		"hob":
			_walk(home.hob.pos)
			t += TALK_LINE_S * (FarmBuilder.rules()["talk"]["intro"] as Array).size()
			FarmBuilder.state()["met"] = true
			FarmTutorial.event("hob")
		"task":
			_walk(home.guide.target("task"))
			t += PANEL_S
			var rec := Save.active_kin()
			Work.set_pin(rec, String(Work.list(rec)[0][0]))
			FarmTutorial.event("task")
		"feed":
			_feed(stg)
		"crop":
			_crop(stg)
		"buy", "sell":
			var stalls := HomeLayout.fixtures(Save.d, "stall")
			_walk(HomeLayout.deco_center(stalls[0]) if not stalls.is_empty() else Vector3.INF)
			t += PANEL_S
			FarmTutorial.event(id)
		"expedition":
			_walk(home.spots["portal"])
			t += PANEL_S
			FarmTutorial.event("portal")

## Chops trees (or mines rocks) nearest the house spot until the step moves on.
func _gather(what: String) -> void:
	var hg = home.hg
	var best := -1
	var at := Vector3.INF
	for i in home.hb.wild_t:
		if String(home.hb.wild_t[i]) != what:
			continue
		var b: Vector3 = hg.beside(i, home.guide.house_spot())
		if b != Vector3.INF and hg.find(Vector2(b.x, b.z)).get("i", -1) == i:
			if best < 0 or b.distance_to(home.ppos) < at.distance_to(home.ppos):
				best = i
				at = b
	if best < 0:
		t = LIMIT_S
		return
	_walk(at)
	hg.use(hg.find(Vector2(at.x, at.z)))
	home.tw.test_hold = true
	for n in 400:
		if not hg.busy():
			break
		hg.tick(DT)
		t += DT
	home.tw.test_hold = false

## Holds the key at the house site until it stands (no Boki help).
func _hammer() -> void:
	var e := FarmHob.house_entry()
	if e.is_empty() or not FarmSites.has_site(e):
		return
	var at := HomeLayout.deco_center(e) + Vector3(2.0, 0, 2.2)
	_walk(at)
	var it: Dictionary = home.hob.find(Vector2(at.x, at.z))
	if String(it.get("kind", "")) != "site" or FarmSites.stalled(e):
		_gather("rock" if FarmSites.have("stone") < int(FarmSites.build_cost("house").get("stone", 0)) else "tree")
		return
	home.hob.use(it)
	home.tw.test_hold = true
	for n in 4000:
		if not FarmSites.has_site(e) or FarmSites.stalled(e):
			break
		home.hob.tick(DT)
		t += DT
	home.tw.test_hold = false

func _feed(stg: String) -> void:
	var hc := HomeLayout.deco_center(FarmHob.house_entry())
	var at := hc + Vector3(4.0, 0, 3.0)
	if stg == "place":
		t += MENU_S
		Save.d["feeders"] = [{"id": "f1", "kind": "trough", "x": at.x, "z": at.z, "food": [], "auto": false}]
		return
	_walk(at)
	t += PANEL_S
	FarmTutorial.give_food()
	Econ.put_in(Econ.feeders()[0], "kibble", 3)

func _crop(stg: String) -> void:
	match stg:
		"patch", "patch_dry":
			var hb = home.hb
			if not hb.active:
				hb.toggle()
			hb.take("crop_patch")
			var cs: Array = home.guide.place_cells()
			if cs.is_empty():
				t = LIMIT_S
				return
			hb.cells = cs
			hb._check_cells()
			hb.place_held()
			hb.toggle()
			t += MENU_S
		"plant":
			_walk(home.plots[0].position)
			t += PANEL_S
			var d: Dictionary = Save.d["plots"][0]
			var seed := ""
			for s in Save.d["seeds"]:
				if int(Save.d["seeds"][s]) > 0:
					seed = String(s)
			Save.d["seeds"][seed] = int(Save.d["seeds"][seed]) - 1
			d["crop"] = seed
			d["stage"] = 0
			d["care"] = 0
			d["wt"] = 0.0
			home._refresh_plot("plots", 0)
		"water":
			_walk(home.plots[0].position)
			home._water("plots", 0)
		"grow":
			t = maxf(t, ripe_at)      # (only waiting: the step shown is the crop's because nothing else is open)
			_ripen()
		"pick":
			_walk(home.plots[0].position)
			home._harvest("plots", 0)

## The first crop's growing time has passed on the drive's clock: it is ripe.
func _ripen() -> void:
	var d: Dictionary = Save.d["plots"][0]
	if String(d["crop"]) != "":
		d["stage"] = int(Data.CROPS[String(d["crop"])]["grow"])
		home._refresh_plot("plots", 0)
	ripe_at = -1.0
