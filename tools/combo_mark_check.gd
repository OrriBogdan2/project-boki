extends RefCounted
## The overhead combo tag (scripts/ui/combo_mark.gd) for Sable's Marks, Vex's Daze, Sparkle's Static,
## Cinder's Ignite (Ablaze/Flashover), Neve's Chill and Meeko's Kindle, and Kael's Slam window (a knock
## readies the Riposte) and Warchain hold (the pull):
## it reads the kit's own status (ArchKit.combo_read), so it shows while the status runs, counts down, is
## gone when the status ends, belongs only to the hunter who applied it, and the payoff hit flashes the body.
## Run from each kit's combo check: `await load(...).new().run(ok, ac, "thief")`.

func run(ok: Callable, ac, arch: String) -> void:
	var r: Array = ac.setup(arch, 5.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArchKit = P.ak
	var tag := "combo tag (%s)" % arch
	ok.call("%s: nothing on a clean foe" % tag, K.combo_read(T).is_empty())
	apply(arch, K, T)
	var d := K.combo_read(T)
	var shown := not d.is_empty() and String(d["icon"]) != "" and float(d["left"]) > 0.0
	ok.call("%s: shows while the status runs, with an icon and the time left" % tag,
			shown and float(d["left"]) <= float(d["total"]), str(d))
	ok.call("%s: the foe's own kit has no tag on you" % tag, T.ak == null or T.ak.combo_read(P).is_empty())
	ac.step(m, 0.5)
	var d2 := K.combo_read(T)
	ok.call("%s: the time left shrinks" % tag, not d2.is_empty() and float(d2["left"]) < float(d["left"]), str(d2))
	if int(d["max"]) > 0:
		var pips_ok := int(d["n"]) == _stacks(arch) and int(d2["n"]) == _stacks(arch)
		ok.call("%s: pips match the stacks" % tag, pips_ok, str(d["n"]))
	ac.step(m, float(d["total"]) + 0.3)
	ok.call("%s: gone when the status ends" % tag, K.combo_read(T).is_empty())
	apply(arch, K, T)
	T.flash_t = 0.0
	payoff(arch, P, K, T)
	if arch == "juggernaut":
		ac.step(m, 0.03)                                        # the knock lands a step after the hit
	var stamp := float(T.get_meta(ComboMark.PAY_KEY, -9.0))
	var flashed := absf(stamp - float(m.time)) < 0.1 and T.flash_t >= ComboMark.FLASH_BODY - 0.05
	ok.call("%s: the payoff hit flashes the body white" % tag, flashed, "stamp %.2f flash %.3f" % [stamp, T.flash_t])
	ac.done(m)
	if arch == "juggernaut":
		await _chain(ok, ac)

## Kael's second state: the Warchain's hold on a foe shows for its 5s, ends with the chain, and the pull
## flashes the foe.
func _chain(ok: Callable, ac) -> void:
	var r: Array = ac.setup("juggernaut", 5.0, "", false)
	var m: Match = r[0]
	var K := r[1].ak as JuggernautKit
	var T: Hunter = r[2]
	K.warchain._hook(T, T.pos)
	var d := K.combo_read(T)
	ok.call("combo tag (chain): shows the hold with an icon and the time left",
			not d.is_empty() and d["icon"] == "chain" and float(d["left"]) > 4.0, str(d))
	ac.step(m, 0.5)
	ok.call("combo tag (chain): the time left shrinks", float(K.combo_read(T).get("left", 9.0)) < float(d["left"]))
	K.warchain.snap("")
	ok.call("combo tag (chain): gone when the chain breaks", K.combo_read(T).is_empty())
	K.warchain._hook(T, T.pos)
	K.warchain.pull()
	var stamp := float(T.get_meta(ComboMark.PAY_KEY, -9.0))
	ok.call("combo tag (chain): the pull flashes the foe white",
			absf(stamp - float(m.time)) < 0.1 and T.flash_t >= ComboMark.FLASH_BODY - 0.05)
	ac.done(m)

func _stacks(arch: String) -> int:
	match arch:
		"mage": return 2
		"ashwick", "rimewright": return 1
	return 3

func apply(arch: String, K: ArchKit, T: Hunter) -> void:
	match arch:
		"thief": (K as ThiefKit).add_mark(T, 3, true)
		"mage": (K as MageKit).add_spark(T, 2)
		"gunslinger": (K as GunslingerKit).daze(T, 1.4)
		"ashwick": (K as AshwickKit).stoke(T)
		"rimewright": (K as RimewrightKit).add_chill(T)
		"tender": (K as TenderKit).add_kindle(T, 3)
		"juggernaut":                                           # the Slam hit them: a knock in 2s readies X
			(K as JuggernautKit).slam_hit[T.get_instance_id()] = K.m.time
			K.cd["x"] = 15.0

## The real payoff hit where one is one call away; Sparkle's Blowout is a Wirerun through a Live foe.
func payoff(arch: String, P: Hunter, K: ArchKit, T: Hunter) -> void:
	match arch:
		"thief":
			(K as ThiefKit).primed_on = T
			T.hurt(10.0, P, {"src": "shot", "ab": ""})
		"gunslinger": T.hurt(10.0, P, {"src": "shot"})
		"mage": (K as MageKit)._blowout(T)
		"ashwick": (K as AshwickKit)._cinder_hit(T)          # the bonus damage on a burning foe
		"rimewright": (K as RimewrightKit).splinter(T.pos, 1.0, 2.0, T)     # the Shatter on a Chilled knock
		"tender": (K as TenderKit).add_kindle(T, 2)          # to full Kindle
		"juggernaut":
			T.hp = 4.0
			T.hurt(10.0, P, {"src": "shot"})                   # a knock: the Riposte is ready again
