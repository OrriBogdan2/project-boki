extends RefCounted
## --combo-payoff-check: every mark-then-payoff pair of docs/heroes/combo_payoffs.md, through the kit's own
## payoff path. Each pair must show its tag on the foe (icon, time left inside the total) while the mark runs, and
## when the payoff lands the body flashes white and the combo sound plays (ComboMark.payoff does both).

const COMBO_SND := "combo"

var main: Node
var ac  # the archetype check, for its match setup and stepping
var cm  # tools/combo_mark_check.gd: the mark and plain payoff for each kit
var n := 0
var fails := 0


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("PAYCHECK %-72s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	cm = load("res://tools/combo_mark_check.gd").new()
	for arch in ["thief", "gunslinger", "mage", "ashwick", "rimewright", "tender", "gil", "juggernaut"]:
		await _pair(arch, "")
	await _pair("gunslinger", "needle")
	await _pair("ashwick", "flashover")
	await _pair("rimewright", "knock")
	await _pair("juggernaut", "chain")
	print("PAYCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## One pair on a fresh strip: mark the foe, read the tag, land the payoff, read the flash and the sound.
func _pair(arch: String, via: String) -> void:
	var tag := "%s%s" % [arch, " (" + via + ")" if via != "" else ""]
	var r: Array = ac.setup(arch, 6.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArchKit = P.ak
	if via == "chain":
		(K as JuggernautKit).warchain._hook(T, T.pos)
	else:
		cm.apply(arch, K, T)
	var d := K.combo_read(T)
	ok(
		"%s: tag shows an icon and the time left" % tag,
		(
			not d.is_empty()
			and String(d["icon"]) != ""
			and float(d["left"]) > 0.0
			and float(d["left"]) <= float(d["total"])
		),
		str(d)
	)
	T.flash_t = 0.0
	Sfx.listener = P.pos  # the camera sets it each frame; a sound far from the origin is out of earshot
	var heard0 := int(Sfx.last_played.get(COMBO_SND, -1000))
	await main.get_tree().create_timer(0.05).timeout  # past the sound's own repeat gap
	_land(arch, via, ac, m, P, K, T)
	var stamp := float(T.get_meta(ComboMark.PAY_KEY, -9.0))
	ok(
		"%s: the payoff flashes the body white" % tag,
		absf(stamp - float(m.time)) < 0.1 and T.flash_t >= ComboMark.FLASH_BODY - 0.05,
		"stamp %.2f time %.2f flash %.3f" % [stamp, m.time, T.flash_t]
	)
	ok("%s: the payoff plays the combo sound" % tag, int(Sfx.last_played.get(COMBO_SND, -1000)) > heard0)
	ac.done(m)


func _land(arch: String, via: String, a, m: Match, P: Hunter, K: ArchKit, T: Hunter) -> void:
	match via:
		"needle":  # Longneedle down the lane through a Dazed foe
			a.aim_at(P, T.pos)
			(K as GunslingerKit)._fire_needle()
		"flashover":
			(K as AshwickKit).stoke(T)  # Ablaze stoked again: Flashover
		"knock":  # the knock on a Chilled foe: Shatter a beat later
			T.hp = 0.0
			(K as RimewrightKit).on_deal(T, 1.0, {})
			for i in 60:
				if T.has_meta(ComboMark.PAY_KEY):
					break
				a.step(m, 1.0 / 60.0)
		"chain":
			(K as JuggernautKit).warchain.pull()
		_:
			cm.payoff(arch, P, K, T)
			if arch == "juggernaut":
				a.step(m, 0.03)  # the knock lands a step after the hit
