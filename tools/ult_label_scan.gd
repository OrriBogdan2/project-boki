extends RefCounted
## --ult-label-scan[=arch]: every Hunter casts the ultimate on tools/support_check.gd's flat strip (a rival
## dummy 6 m ahead) and, every 0.1 s for SCAN_T, the whole tree is read for a visible Label3D or Label whose
## text is a bare number (^[0-9.]+$) that was not there before the cast. Damage numbers on the rival dummy
## (Fx's pool) are listed apart and allowed; any other bare number is a stray debug readout and fails, and
## so is a status timer the HUD draws under a Hunter that never counts down (a hold refreshed every frame).
## A second X press at RECAST_T covers the recast ultimates. Prints ULTLABEL PASS/FAIL per Hunter.

const SCAN_T := 8.0  # s watched after the cast
const RECAST_T := 2.5  # s: the second X press (recasts, early ends)
const EVERY := 6  # frames between scans (0.1 s at 60 fps)
const STUCK_SCANS := 3  # scans a status timer may sit still before it counts as a stray number
const HUD_WAIT := 600  # process frames at most for the match HUD to finish building

var sc  # tools/support_check.gd: setup and step
var fails := 0
var num_re := RegEx.create_from_string("^[0-9.]+$")


func run(main: Node, only := "") -> void:
	Save.no_write = true
	sc = load("res://tools/support_check.gd").new()
	sc.main = main
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if String(a).begins_with("--ult-label-scan="):
			only = String(a).substr(17)
	for arch in Arch.ids():
		if only == "" or only == String(arch):
			await _scan_arch(main, String(arch))
	print("ULTLABEL done, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _scan_arch(main: Node, arch: String) -> void:
	var r: Array = sc.setup(arch, 6.0)
	var m: Match = r[0]
	var hero: Hunter = r[1]
	hero.ak.cd["x"] = 0.0
	for i in HUD_WAIT:  # the HUD builds in slices: wait until it is in the tree and drawn
		if m.hud != null and m.hud.is_inside_tree() and m.hud.process_mode != Node.PROCESS_MODE_DISABLED:
			break
		await main.get_tree().process_frame
	for i in 4:
		await main.get_tree().process_frame
	var before := _numbers(main.get_tree().root, m)
	HunterKeys.ult_pressed(hero)
	var seen := {}
	var held := {}  # hunter|status -> [last seconds shown, scans it did not go down]
	var frames := int(SCAN_T * 60.0)
	for f in frames:
		if f == int(RECAST_T * 60.0):
			HunterKeys.ult_pressed(hero)
		sc.step(m, 1.0 / 60.0)
		if f % EVERY != 0:
			continue
		await main.get_tree().process_frame  # the HUD and Fx draw on real frames
		for e in _numbers(main.get_tree().root, m):
			var key := "%s|%s" % [e["path"], e["text"]]
			if not seen.has(key) and not before.any(func(b): return b["path"] == e["path"] and b["text"] == e["text"]):
				e["t"] = f / 60.0
				seen[key] = e
		_timers(m, f / 60.0, held, seen)
	var stray := 0
	for e in seen.values():
		var why := "damage number (allowed)" if e.get("fx", false) else "STRAY"
		if not e.get("fx", false):
			stray += 1
		print("ULTLABEL %-11s t=%.1f %-8s '%s' over %s  %s" % [arch, e["t"], e["cls"], e["text"], e["owner"], why])
	print(
		"ULTLABEL %-11s %s  %d stray, %d allowed" % [arch, "PASS" if stray == 0 else "FAIL", stray, seen.size() - stray]
	)
	fails += 1 if stray > 0 else 0
	m.queue_free()
	await main.get_tree().process_frame


## The status timers the HUD draws under a Hunter (HudPlate.statuses, shows_time): one that does not count down
## for STUCK_SCANS scans in a row is a hold refreshed every frame, a stray number over them.
func _timers(m: Match, t: float, held: Dictionary, seen: Dictionary) -> void:
	for hn in m.hunters:
		for ic in HudPlate.statuses(hn):
			if not HudPlate.shows_time(float(ic[3])):
				continue  # the HUD draws no seconds for it
			var key := "%s|%s" % [hn.pname, ic[0]]
			var was: Array = held.get(key, [INF, 0])
			var stuck := int(was[1]) + 1 if float(ic[3]) >= float(was[0]) - 0.001 else 0
			held[key] = [float(ic[3]), stuck]
			if stuck >= STUCK_SCANS and not seen.has(key):
				seen[key] = {
					"t": t, "cls": "status", "text": "%.1f" % float(ic[3]), "owner": "%s %s timer" % [hn.pname, ic[2]]
				}


## Every visible Label3D / Label in the tree whose text is a bare number: its path, class, nearest named
## owner and whether it is one of Fx's damage numbers.
func _numbers(root: Node, m: Match) -> Array:
	var out: Array = []
	var pool: Array = m.fx.num_pool if m.fx else []
	for n in root.find_children("*", "", true, false):
		var txt := ""
		if n is Label3D and (n as Label3D).is_visible_in_tree():
			txt = (n as Label3D).text
		elif n is Label and (n as Label).is_visible_in_tree():
			txt = (n as Label).text
		else:
			continue
		txt = txt.strip_edges()
		if txt == "" or num_re.search(txt) == null:
			continue
		var cls := "Label3D" if n is Label3D else "Label"
		out.append({"path": str(n.get_path()), "text": txt, "cls": cls, "fx": n in pool, "owner": _owner(n)})
	return out


func _owner(n: Node) -> String:
	var p := n.get_parent()
	while p != null:
		if p.get_script() != null:
			return "%s (%s)" % [p.name, (p.get_script() as Script).resource_path.get_file()]
		p = p.get_parent()
	return "?"
