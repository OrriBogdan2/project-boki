extends RefCounted
## --weapon-fire-sfx-check (briefs/SFX_AUDIT.md row 3): every Hunter's attack key and every pickup gun
## is fired on a training strip and the sounds it plays are recorded (Sfx.last_played). A Hunter's
## signature weapon may not play a stock weapon sound or a pickup gun's shot while it fires, the old
## class weapons' JSON names a Hunter's own sound, and the five pickup guns each play their own shot.

var main: Node
var fails := 0
var n := 0
var ak = null

## The guns a hunter without a Hunter kit picks from (Data.CLASSES weapon lists): each its own shot.
const PICKUP_GUNS := ["smg", "rifle", "burst_rifle", "shotgun", "sniper"]
## Signature-class weapons no current Hunter carries but a class list still offers: their JSON sound must be own too.
const OLD_SIGNATURES := ["longsword", "twin_blades", "spellstaff"]
## The shared weapon sounds the audit found standing in for Hunters' own (SFX_AUDIT row 3).
const STOCK := ["smg", "rifle", "shotgun", "sniper", "thump", "cleave", "swipe", "zap"]
const HOLD := 1.6           # s the attack key is held (past the sniper's wind-up and a melee charge)
const TAPS := 3             # quick taps after the hold (tap-to-throw / combo kits)

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("WFSFX %-52s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var not_own := STOCK + PICKUP_GUNS.map(func(w): return String(Data.weapon_stats(w)["sfx"]))
	for arch in Arch.ids():
		var r: Array = ak.setup(arch, 6.0)
		var heard := _fire(r[0], r[1])
		var stock := heard.filter(func(s): return s in not_own)
		ok("%s (%s) fires its own sound" % [arch, Arch.signature(arch)], stock.is_empty() and not heard.is_empty(),
				"heard %s" % [heard])
		await ak.done(r[0])
	for wid in PICKUP_GUNS + OLD_SIGNATURES:
		var own := String(Data.weapon_stats(wid)["sfx"])
		ok("%s JSON names a sound that exists" % wid, ResourceLoader.exists("res://audio/%s.wav" % own), own)
	for wid in OLD_SIGNATURES:
		var own := String(Data.weapon_stats(wid)["sfx"])
		ok("%s (old class weapon) names a Hunter's own sound" % wid, own not in not_own and own not in Sfx.NAMES, own)
	var shots := {}
	for wid in PICKUP_GUNS:
		var m := _pickup_match(wid)
		var heard := _fire(m, m.player)
		var own := String(Data.weapon_stats(wid)["sfx"])
		ok("pickup %s plays its shot" % wid, own in heard, "heard %s" % [heard])
		shots[own] = FileAccess.get_md5("res://audio/%s.wav" % own)
		await ak.done(m)
	var files: Array = shots.values()
	var unique := files.filter(func(h): return files.count(h) == 1)
	ok("the 5 pickup guns have 5 different shots", shots.size() == PICKUP_GUNS.size() and unique.size() == shots.size(),
			"%s" % [shots.keys()])
	print("WFSFX DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A plain training hunter (no Hunter kit) holding `wid`, in the first class that offers it.
func _pickup_match(wid: String) -> Match:
	var cls := "medium"
	for c in Data.CLASSES:
		if wid in Data.CLASSES[c]["weapons"]: cls = c
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"cls": cls, "weapon": wid})
	m.set_process(false)
	m.player.set_arch("")         # (training puts on the last Hunter played: this is the kit-less hunter)
	m.player.equip(wid)
	return m

## Holds the attack key, lets go, taps it a few times; returns the sounds that played meanwhile.
func _fire(m: Match, P: Hunter) -> Array:
	ak.aim_at(P, P.pos + Vector3(0, 0, 6.0))
	P.fire_cd = 0.0
	var t0 := Time.get_ticks_msec()
	Sfx.last_played.clear()
	Sfx.listener = P.pos      # (no camera runs here to set it: far sounds would be dropped)
	ak.step(m, HOLD, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	ak.step(m, 0.6)
	for i in TAPS:
		P.inp["fire"] = true
		m.step(ak.DT)
		P.inp["fire"] = false
		ak.step(m, 0.5)
	var heard := []
	for s in Sfx.last_played:
		if int(Sfx.last_played[s]) >= t0 and not String(s).contains("step"): heard.append(s)
	heard.sort()
	return heard
