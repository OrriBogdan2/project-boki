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
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: ArchKit = p.ak
	if via == "chain":
		(k as JuggernautKit).warchain._hook(t, t.pos)
	else:
		cm.apply(arch, k, t)
	var d := k.combo_read(t)
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
	t.flash_t = 0.0
	Sfx.listener = p.pos  # the camera sets it each frame; a sound far from the origin is out of earshot
	var heard0 := int(Sfx.last_played.get(COMBO_SND, -1000))
	await main.get_tree().create_timer(0.05).timeout  # past the sound's own repeat gap
	_land(arch, via, ac, m, p, k, t)
	var stamp := float(t.get_meta(ComboMark.PAY_KEY, -9.0))
	ok(
		"%s: the payoff flashes the body white" % tag,
		absf(stamp - float(m.time)) < 0.1 and t.flash_t >= ComboMark.FLASH_BODY - 0.05,
		"stamp %.2f time %.2f flash %.3f" % [stamp, m.time, t.flash_t]
	)
	ok("%s: the payoff plays the combo sound" % tag, int(Sfx.last_played.get(COMBO_SND, -1000)) > heard0)
	ac.done(m)


func _land(arch: String, via: String, a, m: Match, p: Hunter, k: ArchKit, t: Hunter) -> void:
	match via:
		"needle":  # Longneedle down the lane through a Dazed foe
			a.aim_at(p, t.pos)
			(k as GunslingerKit)._fire_needle()
		"flashover":
			(k as AshwickKit).stoke(t)  # Ablaze stoked again: Flashover
		"knock":  # the knock on a Chilled foe: Shatter a beat later
			t.hp = 0.0
			(k as RimewrightKit).on_deal(t, 1.0, {})
			for i in 60:
				if t.has_meta(ComboMark.PAY_KEY):
					break
				a.step(m, 1.0 / 60.0)
		"chain":
			(k as JuggernautKit).warchain.pull()
		_:
			cm.payoff(arch, p, k, t)
			if arch == "juggernaut":
				a.step(m, 0.03)  # the knock lands a step after the hit
