extends RefCounted
## --homecoming-react-check (GARDEN.md section 4): you come home from an expedition with a Rare Egg and the garden
## Boki notice. With base_mode on (each Boki lives through its BaseLife machine), four Boki live by you: Sniff
## (curious, walking off somewhere), Puff (bold, not curious, watching a rival), Shy (timid) and Busy (the most
## curious, but playing with the ball). The homecoming is "egg" news at you; Sniff, Puff and Shy come and Busy
## keeps playing; at least one stands within 2 m of you; each reacts by its traits on its body (Sniff sniffs, Puff
## puffs up, Shy hides) and then goes back to what it was doing (Sniff walks on to where it was going, Puff's Watch
## carries on where it waited). No panel or toast opens. An Ink homecoming is "ink" news that names the Ink, and
## the same trip is not news twice. Never touches the real save.

const STEP_S := 0.1
const RUN_S := 30.0
const NEAR_M := 2.0          # m: how close at least one Boki has to come
const TOY_U := 990001        # layout uid of the ball Busy plays with
const WATCH_BEFORE_S := 2.0  # s: Puff watched about 0.9 s before it set off (ComeLook.STAGGER_S); a look takes 3+
## name -> [species, curiosity, bravery]
const BOKI := {"Sniff": ["cindle", 0.9, 0.8], "Puff": ["basaltoad", 0.5, 0.9], "Shy": ["burrlet", 0.8, 0.2],
	"Busy": ["zapple", 0.95, 0.8]}
const POSE := {"Sniff": "sniff", "Puff": "puff", "Shy": "hide"}

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("HOMEREACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> void:
	var d := Save.fresh()
	for nm in BOKI:
		var rec := Save.new_kin(String(BOKI[nm][0]), nm)
		rec["traits"]["curiosity"] = BOKI[nm][1]
		rec["traits"]["bravery"] = BOKI[nm][2]
		d["roster"].append(rec)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}      # no base tutorial (Lead)
	Save.d = d
	HomeLayout.ensure(d)

func _entry(nm: String) -> Dictionary:
	for k in home.kins:
		if k["rec"]["name"] == nm:
			return k
	return {}

## A spot with open ground 6 m all round it on one island.
func _open_spot() -> Vector3:
	var at: Vector3 = home.world.random_ground(0)
	for i in 300:
		var isle: int = home.world.island_of(at.x, at.z)
		var open := true
		for a in 8:
			var p := at + Vector3(cos(a * 0.785), 0, sin(a * 0.785)) * 6.0
			open = open and home.world.island_of(p.x, p.z) == isle and not home.world.is_void(p.x, p.z)
		if open:
			return at
		at = home.world.random_ground(0)
	return at

## You stand at `at`, the Boki 4 m round you, each busy with its own thing.
func _set_scene(at: Vector3) -> Dictionary:
	home.ppos = at
	Save.d["layout"]["deco"].append({"id": "toy_ball", "u": TOY_U, "px": at.x - 5.0, "pz": at.z})
	var taken: Array = [at]
	var i := 0
	for nm in BOKI:
		var k := _entry(nm)
		var p: Vector3 = home.world.free_spot_near(at + Vector3(cos(i * 1.6), 0, sin(i * 1.6)) * 4.0, taken, 1.3)
		taken.append(p)
		for key in ["nap_t", "job", "chase", "fetch", "bath", "going_in", "called_t", "eat", "play", "life_eat"]:
			k.erase(key)
		if not home.life.machine(k).is_in(BaseLife.S.ROAM):
			home.life.machine(k).go(BaseLife.S.ROAM, "check")
		k["pos"] = p
		(k["node"] as Node3D).position = p
		k["goal"] = p
		k["t"] = RUN_S
		k["hold_t"] = 0.0
		i += 1
	var away: Vector3 = home.world.free_spot_near(at + Vector3(0, 0, 5.5), taken, 1.3)
	_entry("Sniff")["goal"] = away
	var puff := _entry("Puff")
	home.life.machine(puff).go(BaseLife.S.WATCH, "rival")
	puff["life_at"] = _entry("Busy")
	puff["life_for"] = RUN_S * 2.0
	_entry("Busy")["play"] = {"u": TOY_U, "phase": "play", "t": RUN_S * 2.0, "slot": 0}
	return {"away": away, "watch_line": _last_step(puff)}

## The newest line of a Boki's machine history ("time From>To why").
func _last_step(k: Dictionary) -> String:
	var history: PackedStringArray = home.life.machine(k).history
	return history[history.size() - 1] if not history.is_empty() else ""

## The farm notices you are back (FarmChatter's look, as every 2.5 s).
func _farm_looks() -> void:
	FarmChatter._look_t = 0.0
	FarmChatter.tick(home, 0.01)

func _mem(nm: String) -> String:
	var k := _entry(nm)
	if k.is_empty() or (k["rec"]["memory"] as Array).is_empty():
		return ""
	return String(k["rec"]["memory"][-1]["text"])

## How many memory lines a Boki has.
func _memories(nm: String) -> int:
	var k := _entry(nm)
	return 0 if k.is_empty() else (k["rec"]["memory"] as Array).size()

## Who ComeLook has, first one first.
func _lookers() -> Array:
	return ComeLook._looks.map(func(l): return String(l["k"]["rec"]["name"]))

## Runs the farm until everyone has looked; returns per Boki its closest metres to you, how far from you it stood
## to look, the pose it was cued, how far its body bent while ComeLook had it (pitch, lowest and highest height
## share), and its goal and machine the moment it let go.
func _run(at: Vector3) -> Dictionary:
	var seen := {}
	for nm in BOKI:
		seen[nm] = {"near": INF, "stood": -1.0, "pose": "", "pitch": 0.0, "low": 1.0, "high": 1.0, "back": {}}
	for i in int(RUN_S / STEP_S):
		var looking := _lookers()
		home._move_kin(STEP_S)
		ComeLook.tick(home, STEP_S)
		var still := _lookers()
		for l in ComeLook._looks:
			var s: Dictionary = seen[String(l["k"]["rec"]["name"])]
			if float(l["watch"]) >= 0.0 and float(s["stood"]) < 0.0:
				s["stood"] = Vector2(l["k"]["pos"].x - at.x, l["k"]["pos"].z - at.z).length()
		for nm in BOKI:
			var k := _entry(nm)
			var s: Dictionary = seen[nm]
			s["near"] = minf(float(s["near"]), Vector2(k["pos"].x - at.x, k["pos"].z - at.z).length())
			s["pose"] = String(k.get("q_as", s["pose"]))
			if k.has("look"):
				var body: Node3D = (k["node"] as Node3D).get_node("Body")
				s["pitch"] = maxf(float(s["pitch"]), absf(body.rotation.x))
				s["low"] = minf(float(s["low"]), body.scale.y)
				s["high"] = maxf(float(s["high"]), body.scale.y)
			if looking.has(nm) and not still.has(nm):
				var fsm: Fsm = home.life.machine(k)
				s["back"] = {"goal": k["goal"], "state": fsm.state, "since": fsm.since, "line": _last_step(k)}
	return seen

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(7)
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	_new_save()
	home = await main._hb_home()
	ok(home.life != null and home.kins.size() == 4, "base_mode on: four Boki live on the farm (BaseLife)")
	home.panel_open = ""      # the welcome card would keep the farm quiet
	home.day_t = 0.4          # day: nobody is asleep
	FarmChatter._known.clear()
	ComeLook._extracts = -1
	_farm_looks()
	ok(ComeLook._looks.is_empty(), "the first look only learns what is home: nobody comes")
	var at := _open_spot()
	var before := _set_scene(at)
	var ui_nodes: int = home.root_ui.get_child_count()
	# ------------------------------------------------ home from an expedition with a Rare Egg
	Incubator.add("cindle")
	Save.d["extracts"] = int(Save.d.get("extracts", 0)) + 1
	_farm_looks()
	var came := _lookers()
	var first := "" if came.is_empty() else String(came[0])
	ok(first != "" and ComeLook._looks[0]["kind"] == "egg", "home with a Rare Egg: egg news at you")
	came.sort()
	ok(came == ["Puff", "Shy", "Sniff"], "Sniff, Puff and Shy come; Busy keeps playing (%s)" % ", ".join(came))
	ok(_mem(first).contains("Rare Egg"), "the first to come (%s) keeps the day: '%s'" % [first, _mem(first)])
	var seen := _run(at)
	var nearest := INF
	for nm in seen:
		nearest = minf(nearest, float(seen[nm]["near"]))
	ok(nearest <= NEAR_M, "at least one Boki came within %.0f m of you (%.2f m)" % [NEAR_M, nearest])
	for nm in POSE:
		ok(seen[nm]["pose"] == POSE[nm], "%s reacts with a %s (%s)" % [nm, POSE[nm], seen[nm]["pose"]])
	ok(float(seen["Sniff"]["pitch"]) > 0.2, "Sniff's body dips its nose (%.2f rad)" % seen["Sniff"]["pitch"])
	ok(float(seen["Puff"]["high"]) > 1.1, "Puff's body swells (x%.2f)" % seen["Puff"]["high"])
	ok(float(seen["Shy"]["low"]) < 0.8, "Shy's body ducks low (x%.2f)" % seen["Shy"]["low"])
	ok(float(seen["Shy"]["stood"]) > float(seen["Sniff"]["stood"]) + 1.0 and float(seen["Sniff"]["stood"]) >= 0.0,
		"Shy hangs back (%.1f m), Sniff comes close (%.1f m)" % [seen["Shy"]["stood"], seen["Sniff"]["stood"]])
	ok(ComeLook._looks.is_empty(), "everyone who came has looked and let go")
	var sniff_back: Dictionary = seen["Sniff"]["back"]
	ok(not sniff_back.is_empty() and (sniff_back["goal"] as Vector3).is_equal_approx(before["away"])
		and sniff_back["state"] == BaseLife.S.ROAM, "Sniff roams on to where it was going")
	var puff_back: Dictionary = seen["Puff"]["back"]
	var waited: bool = not puff_back.is_empty() and puff_back["state"] == BaseLife.S.WATCH \
		and puff_back["line"] == before["watch_line"] and float(puff_back["since"]) < WATCH_BEFORE_S
	var since := float(puff_back.get("since", -1.0))
	ok(waited, "Puff's Watch waited while it looked and carries on (%.1f s in it)" % since)
	var busy := _entry("Busy")
	ok(busy.has("play") and seen["Busy"]["pose"] == "", "Busy stayed at its ball the whole time")
	ok(home.panel_open == "" and home.root_ui.get_child_count() == ui_nodes, "no panel or toast opened")
	var refused := 0
	for k in home.kins:
		refused += home.life.machine(k).refused
	ok(refused == 0, "no machine refused a transition (%d)" % refused)
	# ------------------------------------------------ home with an Ink, and the same trip twice
	Goods.give("good:ink_tide")
	Save.d["extracts"] = int(Save.d.get("extracts", 0)) + 1
	_farm_looks()
	came = _lookers()
	first = "" if came.is_empty() else String(came[0])
	ok(first != "" and ComeLook._looks[0]["kind"] == "ink" and _mem(first).contains("Tide Ink"),
		"home with an Ink: ink news, and %s keeps '%s'" % [first, _mem(first)])
	var lines := _memories(first)
	_farm_looks()
	ok(lines > 0 and _memories(first) == lines and _lookers() == came, "the same trip is not news twice")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("HOMEREACT done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
