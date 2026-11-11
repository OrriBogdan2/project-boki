extends RefCounted
## --hatch-sfx-check: each hatch stage plays its sound (wobble, first crack, bigger crack, pop, first
## chirp) once and in order; each starter type has its own chirp; the black mystery egg uses its own
## darker set and none of the plain ones; every sound exists and is in the hatch sound set.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HATCHSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## An egg that records the sound names it asks for.
class EggSpy extends EggHatch:
	var heard: Array = []
	func _init(sp_id: String, fx_ref: Fx, mystery_egg := false) -> void:
		super(sp_id, fx_ref, 0.32, 0.42, 1.0, {"species": sp_id})
		mystery = mystery_egg
	func _sfx(n: String, _vol := 0.0, _pitch := 1.0) -> void:
		heard.append(n)

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var tree := m.get_tree()
	var holder := Node3D.new()
	m.add_child(holder)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.0, 5.0)
	holder.add_child(cam)
	cam.make_current()
	var fx := Fx.new()
	holder.add_child(fx)
	# [species, mystery, chirp it should make]
	var cases := [
		["cindle", false, "hatch_chirp_venom"],
		["puddlet", false, "hatch_chirp_prism"],
		["burrlet", false, "hatch_chirp_spore"],
		["zapple", true, "hatch_mystery_chirp"],
		["pebbit", false, "kin_happy"]]
	var eggs: Array = []
	var finished := {}
	for i in cases.size():
		var egg := EggSpy.new(cases[i][0], fx, cases[i][1])
		egg.position = Vector3(i * 1.5 - 3.0, 0, 0)
		holder.add_child(egg)
		egg.done.connect(func(): finished[i] = true)
		egg.start()
		eggs.append(egg)
	var t0 := Time.get_ticks_msec()
	while finished.size() < cases.size() and Time.get_ticks_msec() - t0 < 40000:
		await tree.process_frame
	ok(finished.size() == cases.size(), "all %d eggs hatch" % cases.size())
	var files: Array = []
	for i in cases.size():
		var tag: String = "%s%s" % [cases[i][0], " (mystery)" if cases[i][1] else ""]
		var heard: Array = eggs[i].heard.filter(func(n): return n.begins_with("hatch_") or n == "kin_happy")
		var pre := "hatch_mystery_" if cases[i][1] else "hatch_"
		ok(heard.count(pre + "crack_1") == 1 and heard.count(pre + "crack_2") == 1 and heard.count(pre + "pop") == 1,
			"%s: first crack, bigger crack and pop once each" % tag)
		ok(heard.count(cases[i][2]) == 1, "%s: its first chirp %s once" % [tag, cases[i][2]])
		ok(heard.count(pre + "wobble") >= 2, "%s: wobble ticks (%d)" % [tag, heard.count(pre + "wobble")])
		var order := heard.filter(func(n): return n != pre + "wobble")
		ok(order == [pre + "crack_1", pre + "crack_2", pre + "pop", cases[i][2]], "%s: in order %s" % [tag, order])
		if cases[i][1]:
			ok(heard.all(func(n): return n.begins_with("hatch_mystery_")), "%s: only its own sounds" % tag)
		else:
			ok(not heard.any(func(n): return n.begins_with("hatch_mystery_")), "%s: none of the mystery sounds" % tag)
		files.append_array(heard)
	var seen := {}
	for n in files:
		if seen.has(n): continue
		seen[n] = true
		ok(FileAccess.file_exists("res://audio/%s.wav" % n), "%s exists" % n)
	holder.queue_free()
	print("HATCHSFX CHECK DONE, failures: %d" % bad)
	tree.quit()
