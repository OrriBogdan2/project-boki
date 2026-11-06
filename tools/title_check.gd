extends RefCounted
## --title-check: the title screen. It builds; its menu has the items it should (Continue or New
## game, Play with friends when online play is there, Save files, Settings, Quit off the web) and
## nothing called "The story so far"; the tagline is there; the key art has its squad of six with
## their Boki, the Wyrm and the logo; and the scene stays inside a frame budget, on the High preset
## and again on Low (which must build a cheaper scene). Headless, so the budget is the CPU side of a
## frame: scene logic, animation and particles. Never touches the real save or settings.

const BUDGET_MS := 12.0          # average CPU time per frame the title may take (headless)
const FRAMES := 150

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TITLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var q0 = Settings.v.get("quality", "auto")
	var stats_hi := await _pass("high")
	var stats_lo := await _pass("low")
	Settings.v["quality"] = q0
	ok(int(stats_lo["parts"]) < int(stats_hi["parts"]) and int(stats_lo["meshes"]) < int(stats_hi["meshes"]),
		"Low builds a cheaper scene (particles %d -> %d, meshes %d -> %d)" % [stats_hi["parts"], stats_lo["parts"], stats_hi["meshes"], stats_lo["meshes"]])
	# a save with a Boki: the main button carries on
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k); Save.d["active"] = k["uid"]
	main.show_screen("title", {})
	for i in 6: await main.get_tree().process_frame
	var ts: Node = main.screen_node()
	var labels: Array = ts.menu_labels() if ts and ts.has_method("menu_labels") else []
	ok(not labels.is_empty() and String(labels[0]) == "Continue", "with a save in progress the first item is Continue (%s)" % [labels])
	ok(ts != null and ts.lead_boki != null, "your partner stands with the lead hunter")
	print("TITLE CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

## Builds the title on one preset, checks it, and measures it. Returns counts of what it built.
func _pass(preset: String) -> Dictionary:
	Settings.v["quality"] = preset
	main.show_screen("title", {})
	for i in 6: await main.get_tree().process_frame
	var ts: Node = main.screen_node()
	ok(ts != null and ts.get_script() == load("res://scripts/ui/title.gd"), "[%s] the title screen builds" % preset)
	if ts == null:
		return {"parts": 0, "meshes": 0}
	var labels: Array = ts.menu_labels()
	var has: bool = not Save.d["roster"].is_empty()
	var want: Array = ["Continue" if has else "New game", "Arena"]
	if has: want.append_array(["Demo match", "Demo match (Hollow)"])
	if Net.available(): want.append("Play with friends")
	want.append_array(["Save files", "Settings"])
	if not OS.has_feature("web"): want.append("Quit")
	ok(labels == want, "[%s] menu items %s" % [preset, labels])
	var texts := _texts(ts)
	ok(not texts.any(func(s): return String(s).to_lower().contains("story so far")), "[%s] no \"The story so far\" anywhere on the title" % preset)
	ok(texts.any(func(s): return String(s).to_lower().contains("raise them") and String(s).to_lower().contains("bring them home")), "[%s] the tagline is there" % preset)
	ok(not texts.any(func(s): return String(s).to_lower().contains("gems")), "[%s] no currency on the title" % preset)
	ok(ts.squad.size() == 6 and ts.boki.size() == 6, "[%s] a squad of six hunters with six Boki (%d, %d)" % [preset, ts.squad.size(), ts.boki.size()])
	ok(ts.wyrm != null and ts.logo != null and ts.lead != null and ts.lead_boki != null, "[%s] the Wyrm, the logo, the lead hunter and their Boki are there" % preset)
	# the frame budget: the CPU cost of a frame of the title, scene logic and particles included
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times = times.slice(10)
	var avg := 0.0
	for x in times: avg += float(x)
	avg /= maxf(1.0, times.size())
	times.sort()
	var p95: float = times[int(times.size() * 0.95)]
	ok(avg < BUDGET_MS, "[%s] frame budget: %.2f ms average, %.2f ms p95 (budget %.0f ms)" % [preset, avg, p95, BUDGET_MS])
	var parts := 0
	for n in ts.find_children("*", "CPUParticles3D", true, false): parts += (n as CPUParticles3D).amount
	var meshes := ts.find_children("*", "MeshInstance3D", true, false).size()
	print("TITLE [%s] built %d particles, %d mesh instances, %d nodes" % [preset, parts, meshes, _count(ts)])
	return {"parts": parts, "meshes": meshes}

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	for ch in n.get_children(): out.append_array(_texts(ch))
	return out

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children(): c += _count(ch)
	return c
