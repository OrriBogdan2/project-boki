extends RefCounted
## --tutorial-check[=<arch>]: the match tutorial works for any first Relic (gunslinger = Vex, archer = Lace,
## juggernaut = Kael; "<arch>:wisps" runs it with the Boki riding as a wisp: the Summon steps replace the
## Send-the-Boki step). The Hunter is forced by the param, so it never waits for the pick screen.
## Each run plays the whole course with the driver and asserts: every line names this kit's ability and
## key, no banner talks about ammo or a rifle, the E step (kin) waits for E, the shoot step takes the kit's own
## attack (Lace's draw and release, Kael's melee combo), the dummies stand where the kit can reach them,
## and the course ends at the lift. Every frame of a step with a place also keeps its marker (the beam at the
## place, the pin or the edge arrow, the label and the distance: DECISIONS, First 10 minutes); the table of
## frames lost per step is printed.

## Words no kit-neutral line may use: not every first Relic has a rifle or ammo.
const KIT_WORDS := ["ammo", "reload", "rifle", "bullet", "magazine"]
const FOE_STEPS := ["sec", "shoot", "gkey", "summon", "pack", "kin", "hook", "ult"]
const MAX_RUN_T := 900.0  # s of game time before the course counts as stuck
const IDLE_E_T := 3.0  # s the E step must keep waiting while E is not pressed
const LEAD_FAR := 10.0  # m: a player this far from a lead step target is where the Boki should be out ahead
const LEAD_STOP := 6.0  # m: the Boki ends a lead step this close to the target

## sim steps far from the target before "it runs ahead" is asked: from your side at run_speed it needs
## ~0.7 s to be 2 m ahead of a running Hunter (a shorter leg ends in a glide carry first)
const LEAD_MIN_FRAMES := 60
const SCREEN := Vector2(1920, 1080)  # px: the screen the edge arrow is laid out on
const REACH_FLAT := 12.0  # m: a dummy farther than this on foot is out of reach of any kit

var bad := 0
var arch := "gunslinger"
var wisps := false
var rng_seed := 7  # --tutorial-seed=N: the seed for the course's random draws


func ok(cond: bool, what: String) -> void:
	print("TUTCHECK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tutorial-check="):
			arch = a.substr(17).get_slice(":", 0)
			wisps = a.ends_with(":wisps")
		elif a.begins_with("--tutorial-seed="):
			rng_seed = int(a.substr(16))
	seed(rng_seed)  # (the camps' random draws: a box-proof run; --tutorial-seed=N tries another course)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"tutorial": true,
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1500.0,
			"demo_kin": "cindle",
			"cls": Arch.weight(arch),
			"arch": arch,
			"weapon": Arch.signature(arch),
			"tut_test": true,
			"boki_wisps": wisps
		}
	)
	m.set_process(false)
	ok(m.player.ak != null and m.player.ak.id == arch, "the Hunter is forced to %s" % arch)
	var tu: Tutorial = m.tut
	var seen := {}
	var last := -1
	var t := 0.0
	var idle_ok := true
	var reach := ""
	var early_seen := false  # the summon step: the first window was called back early, and the step stayed
	var second_seen := false  # the pack step: summoned again after the ring went bright
	var lead := {}  # per leading step: how the Boki (or its wisp) moves to the step's target
	var lost := {}  # step id -> frame counts the marker was missing (see _marker)
	while t < MAX_RUN_T and not m.player.extracted:
		if tu.id() == "kin" and tu.t < IDLE_E_T:
			idle_ok = idle_ok and tu.got == 0
			_hold_fire(m)
		else:
			TutorialDrive.drive(m)
		var at_step := tu.step
		m.step(Match.DT)
		t += Match.DT
		_lead_sample(m, tu, lead)
		if tu.step == at_step:
			_marker(m, lost)
		early_seen = early_seen or (tu.id() == "summon" and tu.sm.early)
		second_seen = second_seen or (tu.id() == "pack" and tu.sm.second)
		if tu.step != last:
			last = tu.step
			seen[tu.id()] = {"text": tu.text, "detail": tu.detail, "cap": tu.key_cap}
			print("TUTCHECK STEP %d %s: %s" % [seen.size(), tu.id(), tu.text])
			if tu.id() in FOE_STEPS:
				reach += _unreachable(m, tu.id())  # (the step's dummies were just placed by its start)
	ok(m.player.extracted, "the course finishes (%d steps in %.0fs)" % [seen.size(), t])
	var banners := seen.keys().filter(func(k): return not TutorialHints.quiet(String(k)))
	print("TUTCHECK STEPS banner %d, hint-only %d, total %d: %s" % [
			banners.size(), seen.size() - banners.size(), seen.size(), str(banners)])
	ok(banners.size() >= 7 and banners.size() <= 9,
			"the match tutorial has about 8 banner steps (%d), the rest are hint lines" % banners.size())
	_words(m.player, seen)
	var teaches: Array = ["summon", "pack"] if wisps else ["gkey"]
	var skipped: Array = ["gkey"] if wisps else ["summon", "pack"]
	ok(
		teaches.all(func(k): return seen.has(k)) and not skipped.any(func(k): return seen.has(k)),
		"%s steps %s ran, %s did not" % ["wisp" if wisps else "walking Boki", teaches, skipped]
	)
	if wisps:
		var sk: Dictionary = seen.get("summon", {})
		ok(String(sk.get("cap", "")) == Settings.key_cap("summon"), "the summon line shows the Summon key")
		ok(early_seen, "a window called back early keeps the summon step (and says so)")
		ok(second_seen, "the pack step waited for a second summon after the ring went bright")
	_lead_rows(lead)
	_marker_rows(lost)
	ok(idle_ok, "the E step waits for E (no progress in the first %.0fs without it)" % IDLE_E_T)
	ok(reach == "", "every dummy stands where this kit can reach it" + reach)
	print("TUTCHECK DONE %s, failures: %d" % [arch, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## One frame of a step with a place: the beam stands at it, and it has a label and a distance, and either its pin
## is in the play box or an edge arrow for it lays out on the screen (a frame short of any of these is counted).
func _marker(m: Match, lost: Dictionary) -> void:
	var tu: Tutorial = m.tut
	var sid := tu.id()
	var at := tu.goal(sid)
	if at == Vector3.INF or m.player.out:
		return
	var row: Dictionary = lost.get(sid, {"frames": 0, "beam": 0, "label": 0, "arrow": 0, "edge": 0})
	lost[sid] = row
	row["frames"] += 1
	if tu.target != at or tu.beams_on() < 1:
		row["beam"] += 1
	if tu.label == "":
		row["label"] += 1
	var d := MarkerDir.off_dir(m.cam, SCREEN, at, m.player.pos)
	if d != Vector2.ZERO:
		row["edge"] += 1
		var e := EdgeMarker.new()
		e.begin(EdgeMarker.world_rim(SCREEN), 16.0)
		e.add(d, Color.WHITE, EdgeMarker.PRIO_GOAL, tu.label, tu.target.distance_to(m.player.pos))
		var arrows := e.layout()
		if arrows.size() != 1 or not Rect2(Vector2.ZERO, SCREEN).encloses(arrows[0]["rect"]):
			row["arrow"] += 1


## The per-step table, and a failure for every step that lost its marker on any frame.
func _marker_rows(lost: Dictionary) -> void:
	for sid in lost:
		var r: Dictionary = lost[sid]
		var gone: int = int(r["beam"]) + int(r["label"]) + int(r["arrow"])
		print(
			(
				"TUTCHECK MARKER %s: %d frames (%d off screen), beam lost %d, label lost %d, arrow lost %d"
				% [sid, r["frames"], r["edge"], r["beam"], r["label"], r["arrow"]]
			)
		)
		ok(gone == 0, "%s keeps its beam, label, distance and edge arrow on all %d frames" % [sid, r["frames"]])
	ok(not lost.is_empty(), "%d steps with a place were watched" % lost.size())


## Stands still and does nothing at the E step's start: any progress here would not be E.
func _hold_fire(m: Match) -> void:
	var p := m.player
	for k in ["fire", "sec", "sig", "dash", "jump", "throw", "interact"]:
		p.inp[k] = false
	p.inp["move"] = Vector2.ZERO


## " name@dist" for each live dummy off the player's island or too far to walk to.
func _unreachable(m: Match, sid: String) -> String:
	var out := ""
	var p := m.player
	var reach := REACH_FLAT
	var c: Dictionary = Content.rules("tutorial")["camps"].get(sid, {})
	if c.get("row", false):  # a row starts past an idle monster's notice by design: its far end may lie past 12 m
		reach = maxf(reach, TutorialCamps.ROW_FROM + TutorialCamps.ROW_STEP * (c.get("foes", []).size() - 1) + 1.0)
	for mb in m.mobs:
		if mb.dead:
			continue
		var off: bool = m.world.island_of(mb.pos.x, mb.pos.z) != m.world.island_of(p.pos.x, p.pos.z)
		if off or p.flat_dist(mb) > reach:
			out += " %s %s@%.1f" % [sid, mb.kind, p.flat_dist(mb)]
	return out


## The Relic line (DECISIONS, Identity and Masks): the first Relic moment explains the Relic in one short line, in
## current words only (Hunter, Relic, Fusion, Wisp), none of the retired ones.
func _mask_line() -> void:
	var line := String(Content.rules("lore").get("mask_line", ""))
	ok(line == "This Relic holds a fallen Hunter. Put it on, and you become them.", "the Relic line's words: '%s'" % line)
	var short := line.length() > 0 and line.length() < 80 and "\n" not in line
	ok(short, "the Relic line is one short line, no wall of text (%d chars)" % line.length())
	var old_words := ["Warden", "Mantle", "Bearer", "Merge", "Unmasked"].filter(func(w): return line.contains(w))
	ok(old_words.is_empty(), "the Relic line uses no retired word %s" % str(old_words))


## The kit's lines: ability and key named, no rifle or ammo talk, no unfilled %tokens.
func _words(p: Hunter, seen: Dictionary) -> void:
	var all := ""
	var banners := ""
	for sid in seen:
		all += " " + String(seen[sid]["text"]) + " " + String(seen[sid]["detail"])
		banners += " " + String(seen[sid]["text"])
	ok(not RegEx.create_from_string("%[A-Za-z]").search(all), "no unfilled token in any line")
	_mask_line()
	var low := banners.to_lower()  # (a detail may quote the kit's own card: Vex does have a rifle)
	var hit := KIT_WORDS.filter(func(w): return low.contains(w))
	ok(hit.is_empty(), "no line assumes ammo or a rifle %s" % str(hit))
	var e_name := String(p.ak.e_def().get("name", ""))
	var s: Dictionary = seen.get("kin", {})
	var e_line := String(s.get("text", ""))
	ok(e_name != "" and e_line.contains(e_name), "the E line names %s ('%s')" % [e_name, e_line])
	ok(String(s.get("cap", "")) == Settings.key_cap("signature"), "and shows the E key (%s)" % s.get("cap", ""))
	var r_name := String(p.ak.rmb_def().get("name", ""))
	var u: Dictionary = seen.get("sec", {})
	var r_line := String(u.get("text", ""))
	ok(r_name != "" and r_line.contains(r_name), "the right-click line names %s ('%s')" % [r_name, r_line])
	ok(String(u.get("cap", "")) == Settings.key_cap("secondary"), "and shows its key (%s)" % u.get("cap", ""))
	var sh: Dictionary = seen.get("shoot", {})
	var melee: bool = p.wpn.get("melee", false)
	var want := "Hold %s to draw" % Settings.key_cap("fire") if p.wpn.has("draw") else "Shoot"
	if melee:
		want = "Step in and swing"
	ok(String(sh.get("text", "")).begins_with(want), "the attack line fits the weapon ('%s')" % sh.get("text", ""))
	ok(String(sh.get("cap", "")) == Settings.key_cap("fire"), "and shows the attack key (%s)" % sh.get("cap", ""))


## The Boki leads (DECISIONS Nov 3: it runs ahead, waits, looks back; TutorialLead). One sample per sim step on every
## step with a lead goal (Tutorial.leads), while the player is still far from the target and the Boki is not being
## carried over a gap: "ahead" = it is nearer the target than the player, "wait" = it stood still for 0.6 s
## waiting for you (not blocked), and "bad" = such a wait with its face more than 60 degrees off the player.
## "min" is its closest approach to the target.
func _lead_sample(m: Match, tu: Tutorial, lead: Dictionary) -> void:
	var id := tu.id()
	var k = m.player.kin
	if not Tutorial.leads(id) or k == null:
		return
	var to: Vector3 = tu.goal(id) if id not in Tutorial.GAP_STEPS else tu.stop(id, "pad")
	if to == Vector3.INF:
		return
	var r: Dictionary = lead.get(id, {})
	var kp: Vector3 = k.seen_pos()
	if r.is_empty():
		r = {"far": 0, "ahead": 0, "wait": 0, "bad": 0, "min": 999.0, "last": kp, "still": 0.0}
		lead[id] = r
	var pd := Vector2(m.player.pos.x - to.x, m.player.pos.z - to.z).length()
	var d := Vector2(kp.x - to.x, kp.z - to.z).length()
	var sp: float = Vector2(kp.x - r["last"].x, kp.z - r["last"].z).length() / Match.DT
	r["still"] = float(r["still"]) + Match.DT if sp < 0.3 else 0.0
	r["last"] = kp
	if k.state == "shoulder" and not k.wisp:
		return  # (carried over a gap or a glide: it cannot lead then)
	r["min"] = minf(float(r["min"]), d)
	if pd < LEAD_FAR:
		return
	r["far"] += 1
	if d < pd - 2.0:
		r["ahead"] += 1
	if float(r["still"]) > 0.6 and (k.wisp or k.comp.lead_hold):
		r["wait"] += 1
		var fw := Vector2(-sin(k.face), -cos(k.face))
		var tp := Vector2(m.player.pos.x - kp.x, m.player.pos.z - kp.z).normalized()
		if rad_to_deg(acos(clampf(fw.dot(tp), -1.0, 1.0))) > 60.0:
			r["bad"] += 1


func _lead_rows(lead: Dictionary) -> void:
	ok(not lead.is_empty(), "the course has steps with a lead goal")
	for id in lead:
		var r: Dictionary = lead[id]
		print(
			(
				"TUTCHECK LEAD %s far %d ahead %d wait %d bad %d min %.1f"
				% [id, r["far"], r["ahead"], r["wait"], r["bad"], r["min"]]
			)
		)
		var near: bool = float(r["min"]) <= LEAD_STOP or float(r["min"]) == 999.0
		ok(near, "%s: the Boki gets within %.0f m of the target (closest %.1f)" % [id, LEAD_STOP, r["min"]])
		var ahead: bool = int(r["far"]) < LEAD_MIN_FRAMES or int(r["ahead"]) > 0
		ok(ahead, "%s: it runs ahead of you (%d of %d far frames)" % [id, r["ahead"], r["far"]])
		ok(int(r["bad"]) == 0, "%s: when it waits it faces you (%d of %d waits not)" % [id, r["bad"], r["wait"]])
