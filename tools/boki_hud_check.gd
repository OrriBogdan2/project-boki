extends RefCounted
## --boki-hud-check: the Boki HUD decisions (docs/HUD.md "Boki HUD"), driven in a real trio match at 1280x720.
##   1. the right-side box (GripHud.boki) shows the bond percent, and a tag for each state: FUSE (bond full, Boki
##      with you), TOO FAR (bond full, Boki out past the leap range), RESCUE (Boki down), RESTING (a Fusion ran out)
##   2. its health bar follows the Boki's health
##   3. a teammate's squad row carries their Boki's icon with its health
##   GAP lines name what the decision asks for and the game does not have yet; they are not failures.
## Reads GripHud.shown / TeamBoki.shown, what the last real draw put on screen. Never touches the save.

const SIZE := Vector2(1280, 720)
var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOKIHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func gap(what: String) -> void:
	print("BOKIHUD GAP  ", what)

func frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	main.get_window().size = Vector2i(SIZE)
	var m := Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=plates")
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "demo_kin": "cindle", "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.start(opts)
	await frames(60)
	var hud = m.hud
	var P: Hunter = m.player
	var k: Kin = P.kin
	var mates: Array = m.hunters.filter(func(x): return x != P and x.team == P.team and x.kin != null)
	ok(hud != null and k != null and mates.size() == 2,
			"a trio match with your Boki and two teammates (%d)" % mates.size())
	ok(hud.c.size == SIZE, "the HUD canvas is 1280x720 (%s)" % str(hud.c.size))
	if k == null or mates.size() < 2:
		return _done()
	P.slot_lv["ult"] = 1
	P.downed = false
	m.paused = true        # (the match stands still, the HUD draws on: the Boki's update would undo forced states)
	# ---------------------------------------------------------------- 1. the bond percent and the tags
	k.state = "shoulder"
	k.rest_t = 0.0
	P.ult = 0.4
	await hud.panels.draw
	ok(GripHud.shown.get("bond", -1) == 40 and GripHud.shown.get("tag", "x") == "",
			"bond 40%%, no tag (%s)" % str(GripHud.shown))
	P.ult = 1.0
	await hud.panels.draw
	ok(GripHud.shown.get("tag") == "FUSE", "bond full, Boki with you: FUSE (%s)" % str(GripHud.shown.get("tag")))
	k.state = "active"
	k.pos = P.pos + Vector3(float(KinCommand.rules().get("merge_leap_range", 32.0)) + 20.0, 0, 0)
	await hud.panels.draw
	ok(GripHud.shown.get("tag") == "TOO FAR",
			"Boki sent far with the bond full: TOO FAR (%s)" % str(GripHud.shown.get("tag")))
	k.pos = P.pos + Vector3(3, 0, 0)
	await hud.panels.draw
	ok(GripHud.shown.get("tag") == "FUSE", "back in range: FUSE again (%s)" % str(GripHud.shown.get("tag")))
	k.state = "downed"
	k.down_t = 30.0
	k.down_total = 30.0
	await hud.panels.draw
	ok(GripHud.shown.get("tag") == "RESCUE", "Boki downed: RESCUE (%s)" % str(GripHud.shown.get("tag")))
	k.state = "shoulder"
	k.hp = k.max_hp
	await hud.panels.draw
	ok(KinMerge.cast(P), "a full bond starts the Fusion")
	await frames(2)
	KinMerge.end(P, "time")
	await hud.panels.draw
	ok(k.resting() and GripHud.shown.get("tag") == "RESTING",
		"a Fusion that ran out leaves the Boki resting: RESTING (%.1f s, %s)" % [k.rest_t, GripHud.shown.get("tag")])
	# ---------------------------------------------------------------- 2. the box's health bar
	k.rest_t = 0.0
	k.state = "shoulder"
	k.hp = k.max_hp * 0.5
	await hud.panels.draw
	ok(absf(float(GripHud.shown.get("frac", -1.0)) - 0.5) < 0.05,
			"the box's bar follows the Boki's health (%s)" % str(GripHud.shown.get("frac")))
	# ---------------------------------------------------------------- 3. a teammate's Boki icon
	var mate: Hunter = mates[0]
	mate.downed = false
	mate.kin.hp = mate.kin.max_hp * 0.25
	await hud.panels.draw
	var row: Dictionary = TeamBoki.shown.get(mate.nid, {})
	ok(not row.is_empty() and absf(float(row["frac"]) - 0.25) < 0.05,
			"a teammate's Boki icon shows a quarter of its health (%s)" % str(row))
	# ---------------------------------------------------------------- what the decisions ask for and the game lacks
	if not Data.KIN[k.species].has("summon_s"):
		gap("no per-species summon duration: the summon ring has nothing to count (docs/HUD.md)")
	_done()

func _done() -> void:
	print("BOKIHUD %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)
