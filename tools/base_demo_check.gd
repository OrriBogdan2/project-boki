extends RefCounted
## --base-demo-check (GARDEN.md section 9.8): the demo base (BaseDemo) loads on a throwaway save in under 10 s with
## four Boki, the two bonds set (friends, rivals), the three toys, the snacks and an egg ready to hatch, something
## happens within 5 s (a Boki at a toy, or a friend or rival reaction), and the player's real save file is untouched.

const LOAD_SECS := 10.0      # s: the base is ready
const SHOW_SECS := 5.0       # s: a Boki is doing something
const DT := 0.25             # s per farm step

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BASEDEMO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _by_name(recs: Array, nm: String) -> Dictionary:
	return recs.filter(func(r): return String(r["name"]) == nm)[0]

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	var real := Save.path_for(Save.slot)
	var before := FileAccess.get_md5(real)
	var t0 := Time.get_ticks_msec()
	var d := BaseDemo.save()
	var recs: Array = d["roster"]
	var home = await main._hb_home()
	var demo := BaseDemo.new()
	demo.stage(home)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	ok(secs < LOAD_SECS, "ready in %.1f s (under %.0f)" % [secs, LOAD_SECS])
	ok(FarmUnlocks.base_mode() and home.life != null, "base_mode on: the farm runs BaseLife")
	ok(home.kins.size() == 4 and recs.size() == 4, "4 Boki (%d on the farm)" % home.kins.size())
	var R: Dictionary = home.life.R
	var pip := _by_name(recs, "Pip")
	var moss := _by_name(recs, "Moss")
	var ash := _by_name(recs, "Ash")
	var rocky := _by_name(recs, "Rocky")
	ok(BaseLife.bond(pip, moss) >= float(R["friend_at"]) and BaseLife.bond(moss, pip) == BaseLife.bond(pip, moss),
		"Pip and Moss are friends (%.2f)" % BaseLife.bond(pip, moss))
	ok(BaseLife.bond(ash, rocky) <= float(R["rival_at"]) and BaseLife.bond(rocky, ash) == BaseLife.bond(ash, rocky),
		"Ash and Rocky are rivals (%.2f)" % BaseLife.bond(ash, rocky))
	ok(BaseLife.bond(pip, ash) == 0.0 and BaseLife.bond(moss, rocky) == 0.0, "no other bond is set")
	var toys: Array = home.toys.toys().map(func(t): return t["id"])
	toys.sort()
	ok(toys == ["toy_ball", "toy_post", "toy_tub"], "the three toys are placed (%s)" % str(toys))
	var snacks: Dictionary = d["crops"]
	ok(snacks.size() >= 3 and snacks.keys().all(func(c): return Lean.key_of(c) != ""),
		"element snacks in the bag (%s)" % str(snacks))
	ok(Incubator.ready_eggs().size() == 1 and home.hinc.node.visible, "an egg is ready to hatch in the incubator")
	var shown := -1.0
	var t := 0.0
	while t < SHOW_SECS and shown < 0.0:
		home._move_kin(DT)
		t += DT
		for k in home.kins:
			if not (k["life"] as Fsm).is_in(BaseLife.S.ROAM) or k.has("play"):
				shown = t
	ok(shown >= 0.0, "something happens within %.0f s (%.2f s)" % [SHOW_SECS, shown])
	print(home.life.readout())
	ok(Save.no_write and FileAccess.get_md5(real) == before, "the real save is untouched (no_write, file unchanged)")
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASEDEMO DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
