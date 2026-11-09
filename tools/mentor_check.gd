extends RefCounted
## --mentor-check (GARDEN.md section 3, Legacy not death): an Elder retires to the Soul Shrine as a mentor
## (only an Elder, with the shrine built, not your partner), passes ONE gift (a trait, a habit or a memory line)
## to the next egg laid and never again, the baby wears it on hatching, and it all survives a save round trip.
## On the real farm with base_mode on, the mentor strolls slowly near the shrine and naps through the night.
## Never touches the real save.

const SIM_SECS := 120.0      # s of base life
const DT := 0.25             # s per farm step
const SPEED_SLACK := 1.6     # the fastest a Boki's own pace trait runs, against the 2.4 m/s walk

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("MENTOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _elder(who: String, species: String, level := 16) -> Dictionary:
	var rec := Save.new_kin(species, who)
	rec["level"] = level
	return rec

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(5)
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var d := Save.fresh()
	var young := _elder("Kit", "burrlet", 6)
	var partner := _elder("Pal", "zapple")
	var elder := _elder("Moss", "basaltoad")
	var mate := _elder("Ash", "cindle", 9)
	d["roster"] = [partner, elder, young, mate]
	d["active"] = partner["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	ok(Mentor.why_not(elder) != "", "no Soul Shrine yet: cannot retire (%s)" % Mentor.why_not(elder))
	Save.d["buildings"].append("shrine")
	Save.d["layout"]["b"]["shrine"] = {"x": 49, "z": 35, "r": 0}      # a farm-start lot is marked out first
	ok(Mentor.why_not(young) != "", "a younger Boki cannot retire (%s)" % Mentor.why_not(young))
	ok(Mentor.why_not(partner) != "", "your partner cannot retire (%s)" % Mentor.why_not(partner))
	ok(Mentor.why_not(elder) == "", "an Elder with the shrine built can")
	var level_before := int(elder["level"])
	var memories_before := (elder["memory"] as Array).size()
	Mentor.retire(elder)
	ok(Mentor.is_mentor(elder) and Mentor.why_not(elder) != "", "retired: a mentor now, and cannot retire twice")
	ok(int(elder["level"]) == level_before and Save.kin(String(elder["uid"])) == elder, "nothing reset, never lost")
	ok((elder["memory"] as Array).size() == memories_before + 1, "it remembers retiring")
	ok(not Work.can_work(elder), "a mentor takes no jobs")
	ok(Mentor.pace(elder) < Mentor.pace(young), "a mentor walks slowly")
	_gifts(elder, young, mate)
	await _roundtrip(elder, young, mate)
	await _base(elder, young, mate)
	rules["base_mode"] = false
	print("MENTOR DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The gift: once at the next lay, then none; every kind lands on the baby.
func _gifts(elder: Dictionary, young: Dictionary, mate: Dictionary) -> void:
	var seen := {}
	var landed := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		(elder["mentor"] as Dictionary)["gifted"] = false
		var gift := Mentor.take_gift()
		if gift.is_empty() or Mentor.take_gift() != {}:
			landed = false
			continue
		seen[gift["kind"]] = true
		var baby := Care.breed(young, mate, rng)
		var before := (baby["memory"] as Array).size()
		var quirk_before := String(baby["dna"]["quirk"])
		var trait_before: Dictionary = (baby["traits"] as Dictionary).duplicate()
		Mentor.apply(baby, gift)
		match gift["kind"]:
			"trait":
				var key: String = gift["key"]
				var gap_now := absf(float(baby["traits"][key]) - float(elder["traits"][key]))
				landed = landed and gap_now <= absf(float(trait_before[key]) - float(elder["traits"][key])) + 0.0001
			"habit":
				landed = landed and baby["dna"]["quirk"] == Unique.of(elder)["quirk"] and quirk_before != ""
			"memory":
				landed = landed and (baby["memory"] as Array).size() == before + 1
		landed = landed and baby["gift"] == gift and Mentor.line(gift) != ""
	ok(landed, "the next egg gets one gift, a second lay gets none, and the baby wears it")
	ok(seen.size() == Mentor.GIFTS.size(), "all of trait, habit and memory come up (%s)" % ", ".join(seen.keys()))
	ok(Mentor.take_gift().is_empty(), "no gift left once it is given")

## A save with a mentor, a laid egg carrying its gift and a hatched baby comes back the same.
func _roundtrip(elder: Dictionary, young: Dictionary, mate: Dictionary) -> void:
	(elder["mentor"] as Dictionary)["gifted"] = false
	Save.d["egg"] = {"a": young["uid"], "b": mate["uid"], "m": 0, "t": 0.0, "gift": Mentor.take_gift()}
	var baby := Care.breed(young, mate, RandomNumberGenerator.new())
	Mentor.apply(baby, Save.d["egg"]["gift"])
	Save.d["roster"].append(baby)
	var back: Dictionary = JSON.parse_string(JSON.stringify(Save.d))
	Save.migrate(back)
	var e2: Dictionary = {}
	var b2: Dictionary = {}
	for r in back["roster"]:
		if r["uid"] == elder["uid"]: e2 = r
		if r["uid"] == baby["uid"]: b2 = r
	ok(Mentor.is_mentor(e2) and e2["mentor"]["gifted"] == true, "save round trip: still a mentor, gift marked given")
	var laid: Dictionary = Save.d["egg"]["gift"]
	ok(String(back["egg"]["gift"]["kind"]) == String(laid["kind"]), "save round trip: the egg keeps its gift")
	var same_line := not b2.is_empty() and Mentor.line(b2["gift"]) == Mentor.line(baby["gift"])
	ok(same_line and String(b2["gift"]["from"]) == "Moss", "save round trip: the baby keeps its gift line")
	ok(not Mentor.is_mentor(Save.kin(String(young["uid"]))), "an old record without the keys loads as no mentor")
	Save.d["egg"] = {}
	Save.d["roster"].erase(baby)

## Base life: the mentor strolls near the shrine at a slow pace, and naps through the night.
func _base(elder: Dictionary, young: Dictionary, mate: Dictionary) -> void:
	Save.d["roster"] = [elder, young, mate]
	Save.d["active"] = young["uid"]
	var home = await main._hb_home()
	ok(home.life != null and home.lots.has("shrine"), "base_mode farm: BaseLife runs and the Soul Shrine stands")
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)
	var shrine: Vector3 = home.lots["shrine"]["at"]
	var mk: Dictionary = {}
	for k in home.kins:
		if k["rec"] == elder: mk = k
	ok(not mk.is_empty(), "the mentor is out on the farm")
	var in_state := 0
	var near := 0
	var frames := 0
	var top := 0.0
	var t := 0.0
	while t < SIM_SECS:
		home._move_kin(DT)
		t += DT
		frames += 1
		var fsm: Fsm = mk["life"]
		in_state += 1 if fsm.is_in(BaseLife.S.MENTOR) or fsm.is_in(BaseLife.S.NAP) else 0
		var from_shrine := Vector2(mk["pos"].x - shrine.x, mk["pos"].z - shrine.z).length()
		near += 1 if from_shrine < 4.0 + float(home.life.R["mentor_radius"]) else 0
		top = maxf(top, Vector2(mk["vel"].x, mk["vel"].z).length())
	ok(in_state >= frames * 0.9, "the mentor is in its Mentor (or Nap) state (%d of %d frames)" % [in_state, frames])
	ok(near >= frames * 0.8, "it stays near the Soul Shrine (%d of %d frames)" % [near, frames])
	ok(top <= 2.4 * Mentor.PACE * SPEED_SLACK, "it never hurries (top %.2f m/s)" % top)
	home.day_t = 0.0
	var asleep := 0
	var night_frames := 0
	t = 0.0
	while t < 60.0:
		home._move_kin(DT)
		t += DT
		if t >= 20.0:
			night_frames += 1
			asleep += 1 if (mk["life"] as Fsm).is_in(BaseLife.S.NAP) else 0
	ok(asleep >= night_frames * 0.8, "it naps through the night (%d of %d frames)" % [asleep, night_frames])
	ok((mk["life"] as Fsm).refused == 0, "its machine never refused a transition (%d)" % (mk["life"] as Fsm).refused)
	home.queue_free()
	await main.get_tree().process_frame
