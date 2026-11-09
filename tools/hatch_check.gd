extends RefCounted
## --hatch-check: hatching is a small, personal moment (docs/POSITIONING.md). An egg (EggHatch)
## cracks; the Boki inside is curled up asleep, wakes, blinks, looks around, then turns to look at
## you before it climbs out, and the shell throws no bursts, rings or flashes. The closer look after
## it (KinReveal) has no flash, rays, fanfare or rarity colours: the Boki finds you and calls to you,
## and only then can it be named. A shimmer shows as a faint sparkle on the Boki itself, a rare one
## gets a plain provenance line. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HATCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Records what the egg asks the effects layer for.
class FxSpy extends Fx:
	var got_bursts: Array = []
	var got_rings := 0
	func _ready() -> void:
		pass
	func burst(at: Vector3, col: Color, amount := 14, speed := 4.0, life := 0.5, grav := 12.0, size := 1.0, dir := Vector3.UP, spread := 180.0) -> void:
		got_bursts.append([col, amount])
	func ring(at: Vector3, radius: float, col: Color, dur := 0.35) -> void:
		got_rings += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var tree := main.get_tree()
	# ---------------------------------------------------------------- 1. the egg
	var holder := Node3D.new()
	main.add_child(holder)
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.0, 5.0)
	holder.add_child(cam)
	cam.make_current()
	cam.look_at(Vector3(0, 0.4, 0))
	var spy := FxSpy.new()
	holder.add_child(spy)
	var sp := "cindle"
	var egg := EggHatch.new(sp, spy, 0.32, 0.42, 1.0, {"species": sp})
	holder.add_child(egg)
	var seen := {"asleep": false, "woke": false, "popped": false, "done": false, "face_err": 9.0, "looked_away": false}
	egg.popped.connect(func(k: Node3D):
		seen["popped"] = true
		var want := EggHatch._yaw_to(k.global_position, cam.global_position)
		seen["face_err"] = absf(wrapf(k.rotation.y - want, -PI, PI)))
	egg.done.connect(func(): seen["done"] = true)
	egg.start()
	var t0 := Time.get_ticks_msec()
	while not seen["done"] and Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
		if is_instance_valid(egg.kin_node):
			var ks := String(egg.kin_node.get_meta("kstate", ""))
			if ks == "sleep": seen["asleep"] = true
			elif seen["asleep"]: seen["woke"] = true
			if not seen["popped"]:
				var want2 := EggHatch._yaw_to(egg.kin_node.global_position, cam.global_position)
				if absf(wrapf(egg.kin_node.rotation.y - want2, -PI, PI)) > 0.8: seen["looked_away"] = true
	ok(seen["done"], "the egg hatches all the way through (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	ok(seen["asleep"] and seen["woke"], "the Boki is curled up asleep in the shell, then wakes")
	ok(seen["looked_away"], "it looks around before it finds you")
	ok(seen["popped"] and float(seen["face_err"]) < 0.25, "then it looks right at you (off by %.2f rad)" % float(seen["face_err"]))
	ok(spy.got_rings == 0, "no ring bursts round the egg (%d)" % spy.got_rings)
	var big := spy.got_bursts.filter(func(b): return int(b[1]) > 8)
	var gold := spy.got_bursts.filter(func(b): return (b[0] as Color).is_equal_approx(Color("fff6c0")) or (b[0] as Color).is_equal_approx(UI.GOLD))
	ok(big.is_empty() and gold.is_empty(), "only a few flakes of shell, no sparkle showers (%d bursts, largest %d)" % [spy.got_bursts.size(), spy.got_bursts.map(func(b): return int(b[1])).max() if not spy.got_bursts.is_empty() else 0])
	holder.queue_free()
	await tree.process_frame
	# ---------------------------------------------------------------- 2. the closer look
	var rec := Save.new_kin(sp, "Ember")
	rec["shimmer"] = true
	rec["rare"] = true
	var rv := KinReveal.new(sp, rec)
	main.add_child(rv)
	var named := {"go": false}
	rv.proceed.connect(func(): named["go"] = true)
	for i in 4: await tree.process_frame
	ok(not ("rays" in rv) and not ("flash" in rv) and not rv.has_method("_jingle"), "no light rays, flash or fanfare")
	ok(rv.name_btn.disabled and not rv.met, "it can't be named before it has met you")
	var hot: Array = []
	for n in rv.find_children("*", "ColorRect", true, false):
		var c := (n as ColorRect).color
		if c.a > 0.7 and c.get_luminance() > 0.5: hot.append(n.name)
	ok(hot.is_empty(), "nothing flashes white (%s)" % [hot])
	t0 = Time.get_ticks_msec()
	while not rv.met and Time.get_ticks_msec() - t0 < 15000:
		await tree.process_frame
	ok(rv.met and not rv.name_btn.disabled, "after it looks at you, you can name it (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var face := wrapf(rv.kin.rotation.y + rv.turn.rotation.y - PI, -PI, PI)
	ok(absf(face) < 0.2, "it faces you (off by %.2f rad)" % face)
	ok(rv.sub_lbl.text.to_lower().contains("looking at you") and not rv.title_lbl.text.contains("!") and not rv.title_lbl.text.contains("RARE"),
		"quiet words: \"%s\" / \"%s\"" % [rv.title_lbl.text, rv.sub_lbl.text])
	var sparkle := rv.kin.get_node_or_null("FurSparkle") as CPUParticles3D
	ok(sparkle != null and sparkle.amount <= 8, "a shimmer is a faint sparkle in its coat")
	var labels: Array = rv.info.find_children("*", "Label", true, false)
	var golden := labels.filter(func(l): return (l as Label).get_theme_color("font_color").is_equal_approx(UI.GOLD))
	ok(golden.is_empty(), "no gold rarity text on its card (%d)" % golden.size())
	ok(labels.any(func(l): return (l as Label).text.contains("Its egg was guarded by")), "a rare one gets a line of provenance")
	rv._go()
	t0 = Time.get_ticks_msec()
	while not named["go"] and Time.get_ticks_msec() - t0 < 3000:
		await tree.process_frame
	ok(named["go"], "Name it hands over to naming")
	print("HATCH CHECK DONE, failures: %d" % bad)
	tree.quit()
