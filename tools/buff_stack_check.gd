extends RefCounted
## --buff-stack-check: the HUD's buff stack (BuffStack) shows what is on you, only while it is on you.
##   1. nothing active: no icons drawn
##   2. three statuses from three sources (a Hunter timer, a kin buff, a kit stack): three icons in
##      file order, the stacking one carries its count, the timed ones' rings are full at the start
##   3. rings drain with the time left and each icon leaves when its time runs out
##   4. seven at once: six icons and "+1"
## Runs the --hudref-demo=plates scene (real frames, the real HUD) and reads BuffStack.shown.
## --buff-stack-shots --shots-dir=<dir> (GPU): the stack mid-fight with three icons (three.png)
## and with seven (seven.png).
## Runs the --hudref-demo scene (real frames, the real HUD) and reads BuffStack.shown. Never touches the save.

var bad := 0
var main: Node
var m: Match
var hud

func ok(cond: bool, what: String) -> void:
	print("BUFFSTACK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func frames_until(t: float) -> void:
	var guard := 0
	while m.time < t and guard < 20000:
		await main.get_tree().process_frame
		guard += 1

func ids() -> Array:
	return hud.buffs.shown.map(func(r): return r["id"])

func row(id: String) -> Dictionary:
	for r in hud.buffs.shown:
		if r["id"] == id: return r
	return {}

func stacks(id: String) -> int:
	return int(row(id).get("stacks", 0))

func frac(id: String, none: float) -> float:
	return float(row(id).get("frac", none))

func start(demo: String) -> Hunter:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=" + demo)
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "arch": "gunslinger", "cls": Arch.weight("gunslinger"),
		"weapon": Arch.signature("gunslinger")})
	m.start(opts)
	hud = m.hud
	return m.player

## Swift, a kin damage buff and two Fever stacks, `secs` long (Swift lasts a third of that).
func three(p: Hunter, secs: float) -> void:
	p.haste_t = secs / 3.0
	p.add_buff("damage", 0.2, secs)
	p.ak.res = 2.0
	p.ak.res_wait = secs

func seven(p: Hunter) -> void:
	for f in ["haste_t", "cloak_t", "crit_t", "phase_t", "guard_t", "shield_t"]:
		p.set(f, 8.0)
	p.shield = 30.0
	p.ak.res = 1.0
	p.ak.res_wait = 8.0

func shots(out: String) -> void:
	var p := start("fight")
	await frames_until(5.0)
	three(p, 9.0)
	await frames_until(m.time + 2.0)
	main.get_viewport().get_texture().get_image().save_png(out.path_join("three.png"))
	seven(p)
	await frames_until(m.time + 1.0)
	main.get_viewport().get_texture().get_image().save_png(out.path_join("seven.png"))
	main.get_tree().quit(0)

func run(main_node: Node, mode := "check") -> void:
	main = main_node
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	if mode == "shots":
		var out := "user://buff_stack_shots"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots-dir="): out = a.substr(12)
		DirAccess.make_dir_recursive_absolute(out)
		await shots(out)
		return
	var p := start("plates")
	await frames_until(1.0)
	ok(hud != null and ids().is_empty() and hud.buffs.more == 0, "nothing on you: no icons")
	var t0 := m.time
	three(p, 3.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(ids() == ["swift", "fever", "kin_damage"], "three statuses, three icons in file order (%s)" % str(ids()))
	ok(stacks("fever") == 2 and stacks("swift") == 1, "the stacking one carries its count (fever x2), the others none")
	var fresh := frac("swift", 0.0)
	ok(fresh > 0.9, "a fresh timer's ring is nearly full (%.2f)" % fresh)
	await frames_until(t0 + 0.6)
	var mid := frac("swift", 1.0)
	ok(mid > 0.1 and mid < 0.7, "the ring drains with the time left (%.2f at 0.6 of 1.0 s)" % mid)
	await frames_until(t0 + 1.3)
	ok(not ids().has("swift") and ids().has("kin_damage"),
		"swift is gone at 1 s, the longer kin buff stays (%s)" % str(ids()))
	await frames_until(t0 + 3.4)
	ok(not ids().has("kin_damage"), "the kin buff leaves when its 3 s run out (%s)" % str(ids()))
	await frames_until(t0 + 3.6)
	ok(ids().is_empty(), "everything expired: the stack is empty again (%s)" % str(ids()))
	seven(p)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var n: int = hud.buffs.shown.size()
	ok(n == BuffStack.MAX_ICONS and hud.buffs.more == 1, "seven at once: %d icons and +%d" % [n, hud.buffs.more])
	print("BUFFSTACK CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
