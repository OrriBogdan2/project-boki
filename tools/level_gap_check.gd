extends RefCounted
## --level-gap-check: a rival's plate level badge shows who out-levels you (LevelGap). Plain within one level,
## warm and an up triangle at 2+ above, cool and a down triangle at 2+ below; teammates and yourself stay plain;
## the two colours stay apart in luminance (so they survive colour-vision loss).

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("LEVELGAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
		"arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	P.lvl = 4
	rivals[0].lvl = 2
	rivals[1].lvl = 3
	rivals[2].lvl = 6
	var below := LevelGap.of(P, rivals[0])
	ok(below == -2 and LevelGap.band(below) == -1, "two below: cool band")
	ok(LevelGap.tint(below) == LevelGap.COOL, "two below: the blue entry")
	ok(LevelGap.band(LevelGap.of(P, rivals[1])) == 0, "one below: plain")
	var above := LevelGap.of(P, rivals[2])
	ok(above == 2 and LevelGap.band(above) == 1, "two above: warm band")
	ok(LevelGap.tint(above) == LevelGap.WARM, "two above: the orange entry")
	ok(LevelGap.band(1) == 0 and LevelGap.band(0) == 0 and LevelGap.band(-1) == 0, "within one level: plain")
	ok(LevelGap.band(9) == 1 and LevelGap.band(-9) == -1, "far above and far below keep their side")
	ok(LevelGap.of(P, P) == 0 and LevelGap.of(null, rivals[2]) == 0, "yourself and no viewer: plain")
	var mate := Hunter.new()
	mate.team = P.team
	mate.lvl = 9
	ok(LevelGap.of(P, mate) == 0, "a teammate keeps their plain level at any gap")
	mate.free()
	var dl := absf(LevelGap.WARM.get_luminance() - LevelGap.COOL.get_luminance())
	ok(dl > 0.25, "warm and cool differ in luminance, not hue alone")
	var badge := Rect2(0, 0, 15, 15)
	var up := LevelGap.cue_points(badge, 2)
	var down := LevelGap.cue_points(badge, -2)
	ok(up[0].y < up[1].y and down[0].y > down[1].y, "warm points up, cool points down")
	ok(m.hud != null, "a match with a HUD")
	print("LEVEL GAP CHECK DONE, failures: ", bad)
	m.over = true
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)
