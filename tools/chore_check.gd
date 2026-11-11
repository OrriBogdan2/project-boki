extends RefCounted
## --chore-check (GARDEN.md section 4): with base_mode on, four Boki live on the real farm for 4 simulated minutes
## (home.gd _move_kin at 4 steps a second): an Ember one (Wren) with an egg in the Nook, a Mend one (Glom) beside a
## glum friend, a Haul one (Mole) with a toy spot to fetch the ball back to, and a Boki with none of those knacks
## (Bur). Each chore starts for the right Boki and nobody else, ends, writes exactly one journal line each time
## and shows on the debug readout; its effect lands (egg time halved once, joy up); each chore's guard refuses
## when its reason is gone; no machine refuses a transition. Never touches the real save.

const SIM_SECS := 240.0      # simulated seconds
const DT := 0.25             # s per farm step
const HATCH_S := 600.0       # s of home hatch time the egg starts with (home.gd _start_egg)
const GLUM_JOY := 25.0       # Bur's joy at the start: glum, but one cheer lifts it out of it

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("CHORE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> Dictionary:
	var d := Save.fresh()
	var recs: Array = []
	for spec in [["kindlewren", "Wren"], ["glomwort", "Glom"], ["glintmole", "Mole"], ["burrlet", "Bur"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		rec["mutations"] = []
		recs.append(rec)
		Care.ensure(rec)
		rec["needs"]["joy"] = 80.0
	recs[0]["starter"] = true
	recs[3]["needs"]["joy"] = GLUM_JOY
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["egg"] = {"a": recs[0]["uid"], "b": recs[1]["uid"], "m": 99999, "t": Time.get_unix_time_from_system() + HATCH_S}
	Save.d = d
	HomeLayout.ensure(d)
	return d

func _lines(rec: Dictionary, words: String) -> int:
	return (rec.get("journal", []) as Array).filter(func(e): return String(e["words"]).begins_with(words)).size()

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(7)
	Content.rules("farm_build")["base_mode"] = true
	var d := _new_save()
	var home = await main._hb_home()
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)
	var center: Vector3 = home.world.random_ground(0)
	d["layout"]["deco"].append({"id": "training_post", "u": 990001, "px": center.x + 3.0, "pz": center.z})
	d["layout"]["deco"].append({"id": "nesting_nook", "u": 990002, "px": center.x - 6.0, "pz": center.z})
	home._sync_fixtures()
	home._refresh_nest()
	home.life.R["chore_chance"] = 1.0      # a chore whenever one can run: the check is about the chores, not the dice
	home.life.find_toys()
	for k in home.kins:
		k["pos"] = home.world.free_spot_near(center + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
	ok(is_instance_valid(home.nest) and home.life.toys.size() == 1, "an egg sits in the Nook and one toy stands")
	var left0 := float(d["egg"]["t"]) - Time.get_unix_time_from_system()
	var kinds := {}        # name -> {kind: true}: the chores each Boki was seen doing
	var starts := {}       # name -> chores begun (a Boki can finish one and begin the next in a single step)
	var writes := {}       # name -> journal lines written
	var last_since := {}   # name -> s in its machine's state on the last step
	var last_chore := {}   # name -> it was in a chore on the last step
	var last_line := {}    # name -> its newest journal entry on the last step
	var shown := {}        # kind -> true: it appeared on the debug readout
	var t := 0.0
	while t < SIM_SECS:
		home._move_kin(DT)
		t += DT
		for k in home.kins:
			var kind := BaseChore.label(k)
			var who := String(k["rec"]["name"])
			var fsm: Fsm = k["life"]
			var lines: Array = k["rec"].get("journal", [])
			if not lines.is_empty() and not is_same(lines.back(), last_line.get(who, null)):
				writes[who] = int(writes.get(who, 0)) + 1
				last_line[who] = lines.back()
			var chore := fsm.is_in(BaseLife.S.CHORE)
			if chore and (not last_chore.get(who, false) or fsm.since < float(last_since.get(who, 0.0))):
				starts[who] = int(starts.get(who, 0)) + 1
			last_since[who] = fsm.since
			last_chore[who] = chore
			if fsm.is_in(BaseLife.S.CHORE) and kind != "":
				kinds[who] = kinds.get(who, {})
				kinds[who][kind] = true
				if not shown.has(kind) and home.life.readout().contains("Chore " + kind):
					shown[kind] = true
	print(home.life.readout())
	var by := {}
	for k in home.kins:
		by[k["rec"]["name"]] = k
	var want := {"Wren": "mind", "Glom": "cheer", "Mole": "fetch"}
	for who in want:
		var seen: Dictionary = kinds.get(who, {})
		ok(seen.keys() == [want[who]], "%s does only the %s chore (%s)" % [who, want[who], seen.keys()])
		var ended := int(starts.get(who, 0)) - (1 if last_chore.get(who, false) else 0)
		ok(ended >= 1, "%s's %s chore ends (%d of %d begun)" % [who, want[who], ended, int(starts.get(who, 0))])
		ok(int(writes.get(who, 0)) == ended,
			"%s wrote one journal line per chore (%d lines)" % [who, int(writes.get(who, 0))])
		ok(shown.has(want[who]), "the readout shows Chore %s" % want[who])
	ok(not kinds.has("Bur"), "Bur has no chore knack and does none")
	var wren: Dictionary = by["Wren"]["rec"]
	var left := float(d["egg"]["t"]) - Time.get_unix_time_from_system()
	ok(_lines(wren, "minded the egg") == 1, "the egg was minded once, with one line")
	ok(d["egg"].get("minded", false) and left <= left0 * 0.55,
		"minding halved the egg's hatch time once (%.0f of %.0f s)" % [left, left0])
	ok(Care.need(by["Bur"]["rec"], "joy") > GLUM_JOY, "Bur's joy went up (%.0f)" % Care.need(by["Bur"]["rec"], "joy"))
	ok(BaseChore.pick(home.life, by["Glom"]) == "" or Care.need(by["Bur"]["rec"], "joy") < BaseChore.GLUM_AT,
		"Glom has nobody left to cheer once Bur is up")
	d["egg"] = {}
	ok(BaseChore.pick(home.life, by["Wren"]) == "", "no egg in the Nook: no Ember chore")
	home.life.toys.clear()
	ok(BaseChore.pick(home.life, by["Mole"]) == "", "no toy spot: no Haul chore")
	var refused := 0
	for k in home.kins:
		refused += (k["life"] as Fsm).refused
	ok(refused == 0, "no machine refused a transition (%d)" % refused)
	Content.rules("farm_build")["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("CHORE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
