extends RefCounted
## The overhead combo tag (scripts/ui/combo_mark.gd) for Sable's Marks, Vex's Daze, Sparkle's Static,
## Cinder's Ignite (Ablaze/Flashover), Neve's Chill and Meeko's Kindle, Gil's splash marks, and Kael's Slam
## window (a knock readies the Riposte) and Warchain hold (the pull):
## it reads the kit's own status (ArchKit.combo_read), so it shows while the status runs, counts down, is
## gone when the status ends, belongs only to the hunter who applied it, and the payoff hit flashes the body.
## Run from each kit's combo check: `await load(...).new().run(ok, ac, "thief")`.

func run(ok: Callable, ac, arch: String) -> void:
	var r: Array = ac.setup(arch, 5.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: ArchKit = p.ak
	var tag := "combo tag (%s)" % arch
	ok.call("%s: nothing on a clean foe" % tag, k.combo_read(t).is_empty())
	apply(arch, k, t)
	var d := k.combo_read(t)
	var shown := not d.is_empty() and String(d["icon"]) != "" and float(d["left"]) > 0.0
	ok.call("%s: shows while the status runs, with an icon and the time left" % tag,
			shown and float(d["left"]) <= float(d["total"]), str(d))
	ok.call("%s: the foe's own kit has no tag on you" % tag, t.ak == null or t.ak.combo_read(p).is_empty())
	ac.step(m, 0.5)
	var d2 := k.combo_read(t)
	ok.call("%s: the time left shrinks" % tag, not d2.is_empty() and float(d2["left"]) < float(d["left"]), str(d2))
	if int(d["max"]) > 0:
		var pips_ok := int(d["n"]) == _stacks(arch) and int(d2["n"]) == _stacks(arch)
		ok.call("%s: pips match the stacks" % tag, pips_ok, str(d["n"]))
	ac.step(m, float(d["total"]) + 0.3)
	ok.call("%s: gone when the status ends" % tag, k.combo_read(t).is_empty())
	if arch == "thief":     # Marks have no cap: past the row of pips the tag reads the count
		var mine: Dictionary = ThiefKit.marked_by.get(p.nid, {})
		ok.call("%s: Marks run out, so the step stops fading on every foe (none tracked)" % tag, mine.is_empty(),
				str(mine.size()))
		(k as ThiefKit).add_mark(t, 11, true)
		mine = ThiefKit.marked_by.get(p.nid, {})
		ok.call("%s: a Mark put on a foe is tracked for the fade" % tag, mine.has(t.get_instance_id()), str(mine.size()))
		var d3 := k.combo_read(t)
		ok.call("%s: 11 Marks read 11 past the %d pips" % [tag, int(d3["max"])],
				int(d3["n"]) == 11 and int(d3["n"]) > int(d3["max"]), str(d3["n"]))
		(k as ThiefKit).clear_marks(t)
	apply(arch, k, t)
	t.flash_t = 0.0
	payoff(arch, p, k, t)
	if arch == "juggernaut":
		ac.step(m, 0.03)                                        # the knock lands a step after the hit
	var stamp := float(t.get_meta(ComboMark.PAY_KEY, -9.0))
	var flashed := absf(stamp - float(m.time)) < 0.1 and t.flash_t >= ComboMark.FLASH_BODY - 0.05
	ok.call("%s: the payoff hit flashes the body white" % tag, flashed, "stamp %.2f flash %.3f" % [stamp, t.flash_t])
	ac.done(m)
	if arch == "juggernaut":
		await _chain(ok, ac)

## Kael's second state: the Warchain's hold on a foe shows for its 5s, ends with the chain, and the pull
## flashes the foe.
func _chain(ok: Callable, ac) -> void:
	var r: Array = ac.setup("juggernaut", 5.0, "", false)
	var m: Match = r[0]
	var k := r[1].ak as JuggernautKit
	var t: Hunter = r[2]
	k.warchain._hook(t, t.pos)
	var d := k.combo_read(t)
	ok.call("combo tag (chain): shows the hold with an icon and the time left",
			not d.is_empty() and d["icon"] == "chain" and float(d["left"]) > 4.0, str(d))
	ac.step(m, 0.5)
	ok.call("combo tag (chain): the time left shrinks", float(k.combo_read(t).get("left", 9.0)) < float(d["left"]))
	k.warchain.snap(true)
	ok.call("combo tag (chain): gone when the chain breaks", k.combo_read(t).is_empty())
	k.warchain._hook(t, t.pos)
	k.warchain.pull()
	var stamp := float(t.get_meta(ComboMark.PAY_KEY, -9.0))
	ok.call("combo tag (chain): the pull flashes the foe white",
			absf(stamp - float(m.time)) < 0.1 and t.flash_t >= ComboMark.FLASH_BODY - 0.05)
	ac.done(m)

func _stacks(arch: String) -> int:
	match arch:
		"mage": return 2
		"ashwick", "rimewright": return 1
		"gil": return 2
	return 3

func apply(arch: String, k: ArchKit, t: Hunter) -> void:
	match arch:
		"thief": (k as ThiefKit).add_mark(t, 3, true)
		"mage": (k as MageKit).add_spark(t, 2)
		"gunslinger": (k as GunslingerKit).daze(t, 1.4)
		"ashwick": (k as AshwickKit).stoke(t)
		"rimewright": (k as RimewrightKit).add_chill(t)
		"tender": (k as TenderKit).add_kindle(t, 3)
		"gil":                                                  # two different splash marks: one more Beaches
			(k as GilKit)._mark(t, "fire", Color.WHITE)
			(k as GilKit)._mark(t, "slime", Color.WHITE)
		"juggernaut":                                           # the Slam hit them: a knock in 2s readies X
			(k as JuggernautKit).slam_hit[t.get_instance_id()] = k.m.time
			k.cd["x"] = 15.0

## The real payoff hit where one is one call away; Sparkle's Blowout is a Wirerun through a Live foe.
func payoff(arch: String, p: Hunter, k: ArchKit, t: Hunter) -> void:
	match arch:
		"thief":
			(k as ThiefKit).primed_on = t
			t.hurt(10.0, p, {"src": "shot", "ab": ""})
		"gunslinger": t.hurt(10.0, p, {"src": "shot"})
		"mage": (k as MageKit)._blowout(t)
		"ashwick": (k as AshwickKit)._cinder_hit(t)          # the bonus damage on a burning foe
		"rimewright": (k as RimewrightKit).splinter(t.pos, 1.0, 2.0, t)     # the Shatter on a Chilled knock
		"tender": (k as TenderKit).add_kindle(t, 2)          # to full Kindle
		"gil": (k as GilKit)._mark(t, "air", Color.WHITE)    # the third mark: Beached
		"juggernaut":
			t.hp = 4.0
			t.hurt(10.0, p, {"src": "shot"})                   # a knock: the Riposte is ready again
