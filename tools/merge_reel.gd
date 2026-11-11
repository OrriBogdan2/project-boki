extends "res://tools/parity_reel.gd"
## --merge-reel --shots-dir=<dir> --reel-hero=<arch> [--reel-boki=<species>]: one Hunter merged with a Boki
## (KinMerge, R) going through its moves at the match camera, then unmerged: walk and run, jump and glide, LMB, RMB,
## Shift, E, and after the merge ends a walk and an LMB. Frames and key caps as --parity-reel (run it under
## jobq --needs gpu); what each state plays is asserted by --merge-anim-check. Never writes the save.

const MERGED := ["merge", "walk", "air", "lmb", "rmb", "dash", "e", "unmerge"]

var boki := "pebbit"

func parts() -> Array:
	return MERGED

func run(main_node: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--reel-boki="):
			boki = String(a).substr(12)
	extra_opts = {"demo_kin": boki}
	await super.run(main_node)

func _build_keys() -> void:
	super._build_keys()
	P.ak.cd_off = true          # (every press finds its move ready, merged or not)

## The merge timer is held full: the reel outlasts one merge.
func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	var held := func(t: float) -> void:
		if MergeKit.is_live(P):
			P.merge_st["t"] = maxf(float(P.merge_st.get("t", 0.0)), 5.0)
		if each.is_valid():
			each.call(t)
	await super._go(secs, held, marks, lead)

func _p_merge() -> void:
	title.text = "R: merge with the Boki"
	await _reset(7.0)
	P.kin.trust = 60.0
	P.kin.stow()
	P.ult = 1.0
	r_down = true
	KinMerge.press(P)
	await _go(1.6, func(_t: float) -> void: _aim(T.pos))
	print("REEL_MERGED %s" % MergeKit.is_live(P))

func _p_walk() -> void:
	var walk := func(t: float) -> void:
		var pace := 0.4 if t < 1.4 else 1.0        # walk, then run
		P.inp["move"] = Vector2(pace, 0.0) if t < 2.6 else Vector2.ZERO
	await _seg("Merged: walk, then run", 3.0, walk, FAR)

func _p_air() -> void:
	var air := func(t: float) -> void:
		P.inp["move"] = Vector2(1, 0) if t < 2.4 else Vector2.ZERO
		P.inp["jump"] = _in(t, 0.2, 2.2)
	await _seg("Merged: jump, hold Space to glide", 3.0, air, FAR)

func _p_lmb() -> void:
	await _seg("Merged: LMB x3", 2.4, func(t: float) -> void:
		P.inp["fire"] = _in(t, 0.2) or _in(t, 0.9) or _in(t, 1.6))

func _p_rmb() -> void:
	await _seg("Merged: RMB", 2.2, func(t: float) -> void:
		P.inp["sec"] = _in(t, 0.2)
		P.inp["sec_hold"] = _in(t, 0.2, 0.7))

func _p_dash() -> void:
	var dash := func(t: float) -> void:
		P.inp["move"] = Vector2(1, 0) if t < 1.2 else Vector2.ZERO
		P.inp["dash"] = _in(t, 0.3)
	await _seg("Merged: Shift", 2.0, dash, FAR)

func _p_e() -> void:
	await _seg("Merged: E", 2.4, func(t: float) -> void:
		P.inp["sig"] = _in(t, 0.2))

func _p_unmerge() -> void:
	title.text = "Merge over: walk, LMB"
	KinMerge.end(P, "test")
	await _go(2.6, func(t: float) -> void:
		_aim(T.pos)
		P.inp["move"] = Vector2(0.5, 0.0) if t > 0.6 and t < 1.6 else Vector2.ZERO
		P.inp["fire"] = _in(t, 1.9))
