extends "res://tools/vv_shots.gd"
## --declutter-shots --shots-dir=<dir>: the same three busy fights, for before/after shots of the combat UI
## declutter (docs/UI_DECLUTTER.md): Sable's bolts and Marks with the dagger stuck in a rival and its window
## about to close; Kael Enraged with the chain hooked in; Vex's Burr Dazing a rival under rifle fire. Each is
## the full view plus a close-up round the target (the vv_shots rig). Needs a renderer (jobq submit --needs gpu).

const FIGHTS := [["thief", "sable"], ["juggernaut", "kael"], ["gunslinger", "vex"]]

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in FIGHTS:
		who = String(f[0])
		hero_name = String(f[1])
		await _setup()
		await Callable(self, "_" + hero_name).call()
		m.queue_free()
		await main.get_tree().process_frame
	print("DECLUTTERSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## Holds fire on the target for `secs`.
func _fire(secs: float) -> void:
	await _go(secs, func(_t): P.inp["fire"] = true)
	P.inp["fire"] = false

## Bolts stack Marks, then the dagger goes in; the shot lands as its window is about to close.
func _sable() -> void:
	await _fire(1.2)
	P.ak.use_e()
	await _go(0.4)
	var close := maxf(0.0, P.ak.e_t - 0.35)
	var mark := [close, "full", "fight", "Sable: Marks and the dagger closing", _on_target]
	await _go(close + 0.05, func(_t): P.inp["fire"] = true, [mark])
	P.inp["fire"] = false

## Full rage (Enraged), then the chain hooks the rival: the hold is open.
func _kael() -> void:
	(P.ak as JuggernautKit).gain_rage(100.0)
	await _go(0.2)
	P.ak.use_e()
	await _go(0.9, Callable(), [[0.85, "full", "fight", "Kael: Enraged, chain hooked", _on_target]])

## The Burr Dazes the rival, then rifle fire into it.
func _vex() -> void:
	P.ak.press_rmb()
	await _go(0.8)
	await _go(0.6, func(_t): P.inp["fire"] = true, [[0.55, "full", "fight", "Vex: Dazed rival under fire", _on_target]])
	P.inp["fire"] = false
