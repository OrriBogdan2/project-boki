extends RefCounted
## --tutorial-playtest-check[=<arch>]: the owner's first-match playtest (11-17), played back.
##   1. crouch: standing and crouching at the far edge of the lookout top counts, from every side; the ground at the
##      foot of the cliff does not
##   2. the Boki send: the camp stands in the open (no wall, no cliff, a clear line from the lookout), holds its
##      posts while nobody touches it, and a real G tap from the lookout registers the step, even for a Boki
##      that trusts you not at all (it never refuses in the tutorial)
##   3. every step's final text, in order: it names its key (the real bound one), unlocks say "Press <key> to
##      unlock <name>", the Ultimate (R) and the Fusion (X) are told apart, the Fusion unlock comes before the
##      Fusion step and can't be pressed early, and no text is the old jargon
##   4. every text fits the strip at 1280x720 and 1920x1080 beside the key cap, the arrow, the distance and the
##      counter, at a readable size
## It prints every step (TUTSTEP lines) so a reader sees what the player sees. Never touches the save.

const MIN_TEXT_PX := 15  # px: the smallest type the strip may shrink a line to, at 720 p and up
const EDGE_R := 3.3  # m from the lookout's middle: its far edge (the top is 3.6 m in radius)
const IDLE_S := 3.0  # s the camp must stay put while nobody touches it
const SEND_S := 9.0  # s a real tap has to register
const CROUCH_S := 3.2  # s to hold crouch at the edge (the step wants 1.5)
const LINE_STEP := 0.25  # m between the samples of a throw line
const OPEN_R := 2.0  # m of level open ground round each post
const NO_KEY := ["points", "wayout", "defend", "extract"]  # steps with nothing to press
const OLD_WORDS := ["Hit the line", "big move", "Merge with"]
const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]

var bad := 0
var arch := "gunslinger"
var order: Array = []  # step ids, first seen first
var seen := {}  # id -> {text, detail, cap, lvl, pts, ult_open}


func ok(cond: bool, what: String) -> void:
	print("TUTPLAY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tutorial-playtest-check="):
			arch = a.substr(26)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(
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
			"tut_test": true
		}
	)
	m.set_process(false)
	var tu: Tutorial = m.tut
	_play_to(m, "gkey")
	m.opts["tut_test"] = false  # (the driver stops: the player's keys are this check's own)
	_send(m)
	_crouch(m)
	m.opts["tut_test"] = true
	_play_to(m, "")
	ok(m.player.extracted, "the course still finishes after the lookout and the send")
	_words(m)
	_fit()
	print("TUTPLAY DONE %s, failures: %d" % [arch, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## Plays the course with the driver up to the start of step `sid` ("" for the end), writing every step's words down.
func _play_to(m: Match, sid: String) -> void:
	var tu: Tutorial = m.tut
	var t := 0.0
	while t < 900.0 and not m.player.extracted and tu.id() != sid:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		_note(m)


## What the step shows right now (the last frame of a step is its final text).
func _note(m: Match) -> void:
	var tu: Tutorial = m.tut
	var sid := tu.id()
	if sid == "":
		return
	if not seen.has(sid):
		order.append(sid)
		seen[sid] = {"lvl": m.player.lvl, "pts": m.player.skill_pts, "ult_open": m.player.can_level("ult")}
	seen[sid].merge({"text": tu.text, "detail": tu.detail, "cap": tu.key_cap}, true)


func _restart(m: Match, sid: String) -> void:
	var tu: Tutorial = m.tut
	for i in Tutorial.steps().size():
		if String(Tutorial.steps()[i][0]) == sid:
			tu.step = i
	tu._enter()
	tu.wait = 0.0


# ------------------------------------------------------------------ 1. the lookout
func _crouch(m: Match) -> void:
	var tu: Tutorial = m.tut
	var p := m.player
	var mid := tu.stop("crouch")
	for i in 4:
		var dir := Vector2.from_angle(PI * 0.5 * i)
		var at := mid + Vector3(dir.x, 0.0, dir.y) * EDGE_R
		at.y = m.world.ground_at(at.x, at.z)
		var on_top: bool = at.y > mid.y - 0.1
		ok(on_top, "far-edge point %d (%.1f, %.1f) is on the lookout top" % [i, at.x, at.z])
		_restart(m, "crouch")
		p.teleport(at)
		var t := 0.0
		while t < CROUCH_S and tu.id() == "crouch":
			p.inp["crouch"] = true
			_note(m)
			m.step(Match.DT)
			t += Match.DT
		ok(tu.id() != "crouch", "crouching at the far edge %d finishes the crouch step (%.1f s)" % [i, t])
	var foot := tu.foe_spot("gkey", 0)
	_restart(m, "crouch")
	p.teleport(foot)
	for i in int(CROUCH_S / Match.DT):
		p.inp["crouch"] = true
		m.step(Match.DT)
	ok(tu.id() == "crouch", "crouching at the foot of the cliff does not count")


# ------------------------------------------------------------------ 2. the Boki send
func _send(m: Match) -> void:
	var tu: Tutorial = m.tut
	var p := m.player
	var k: Kin = p.kin
	var posts: Array = []
	for e: Dictionary in tu.camps.ledger:
		posts.append((e["mb"] as Mob).pos)
	ok(posts.size() == 2, "the camp is two monsters")
	_open_ground(m, tu, posts)
	var start := p.pos
	for i in int(IDLE_S / Match.DT):
		_note(m)
		m.step(Match.DT)
		if tu.flag:
			break
	var drift := 0.0
	for i in posts.size():
		drift = maxf(drift, ((tu.camps.ledger[i]["mb"] as Mob).pos - (posts[i] as Vector3)).length())
	ok(drift < 0.6, "the camp holds its posts while untouched (moved %.2f m in %.0f s)" % [drift, IDLE_S])
	ok(not tu.flag and p.pos.distance_to(start) < 1.0, "nothing is registered before a send")
	k.trust = 0.0
	k.hp = k.max_hp * 0.4
	var foe: Mob = tu.camps.nearest()
	ok(k.consider_throw(foe.pos) == "go", "a Boki that does not trust you yet still goes in the tutorial")
	var t := 0.0
	var tapped := 0
	while t < SEND_S and not tu.flag and tu.id() == "gkey":
		foe = tu.camps.nearest()
		if foe == null:
			break
		p.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		if fmod(t, 1.2) < Match.DT:
			KinCommand.tap(p)  # (the G key: it sends the Boki at the cursor, or calls it back when it is out)
			tapped += 1
		_note(m)
		m.step(Match.DT)
		t += Match.DT
	var done := tu.flag or tu.id() != "gkey"
	ok(done, "a real G tap at a monster registers the Boki send (%d taps, %.1f s)" % [tapped, t])


## Each post: level open ground round it, and a clear line from the lookout (no block, nothing above the top).
func _open_ground(m: Match, tu: Tutorial, posts: Array) -> void:
	var w := m.world
	var top := tu.stop("crouch")
	var isl := w.island_of(top.x, top.z)
	for post: Vector3 in posts:
		var flat := true
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if Vector2(dx, dz).length() > OPEN_R:
					continue
				var q := Vector2(post.x + dx, post.z + dz)
				flat = flat and not w.is_void(q.x, q.y) and not w.is_block(q.x, q.y)
				flat = flat and absf(w.ground_at(q.x, q.y) - post.y) < 0.01 and w.island_of(q.x, q.y) == isl
		ok(flat, "post (%.1f, %.1f): level open ground %.0f m round it, on its island" % [post.x, post.z, OPEN_R])
		var gap := Vector2(post.x - top.x, post.z - top.z)
		var clear := true
		for i in int(gap.length() / LINE_STEP):
			var q := Vector2(top.x, top.z) + gap.normalized() * LINE_STEP * i
			clear = clear and not w.is_block(q.x, q.y) and w.ground_at(q.x, q.y) <= top.y + 0.01
		ok(clear, "the line from the lookout to post (%.1f, %.1f) has no wall (%.1fm)" % [post.x, post.z, gap.length()])
		ok(gap.length() < float(KinCommand.rules()["throw_range"]), "and the post is within a send's reach")


# ------------------------------------------------------------------ 3. the words
func _words(m: Match) -> void:
	var p := m.player
	var caps := {"land": _wasd(), "ranks": TutorialText.rank_combo(), "glide": Settings.key_cap("jump")}
	for sid in order:
		var s: Dictionary = seen[sid]
		print("TUTSTEP %2d %-9s [%s] %s  | %s" % [order.find(sid), sid, s["cap"], s["text"], s["detail"]])
		var want: String = caps.get(sid, Settings.key_cap(String(Tutorial.KEYS.get(sid, ""))))
		if not NO_KEY.has(sid):
			ok(want != "" and String(s["text"]).contains(want), "%s names its key %s: '%s'" % [sid, want, s["text"]])
		if sid.begins_with("pick_"):
			ok(
				String(s["text"]).begins_with("Press ") and String(s["text"]).contains(" to unlock "),
				"%s says what to press to unlock: '%s'" % [sid, s["text"]]
			)
		for w in OLD_WORDS:
			ok(not String(s["text"]).contains(w), "%s has no '%s'" % [sid, w])
	var fuse: String = Settings.key_cap("ultimate")
	var ulti: String = Settings.key_cap("hunter_ult")
	ok(fuse != ulti, "the Fusion key (%s) and the Ultimate key (%s) are two keys" % [fuse, ulti])
	ok(
		String(seen["pick_ult"]["text"]).contains("Fusion") and String(seen["pick_ult"]["text"]).contains(fuse),
		"pick_ult unlocks the Fusion with its own key: '%s'" % seen["pick_ult"]["text"]
	)
	var open_line: String = seen["pick_ult"]["detail"]
	ok(
		open_line.contains(ulti) and open_line.contains(String(p.ak.x_def().get("name", "?"))),
		"pick_ult tells you the Ultimate (%s) is open too: '%s'" % [ulti, open_line]
	)
	var name: String = p.kin.rec.get("name", "")
	ok(
		String(seen["ult"]["text"]).contains("fuse with " + name) and String(seen["ult"]["text"]).contains(fuse),
		"ult tells you to fuse with %s: '%s'" % [name, seen["ult"]["text"]]
	)
	var xname: String = p.ak.x_def().get("name", "")
	var dt: String = seen["ult"]["detail"]
	ok(
		xname != "" and dt.contains(ulti) and dt.contains(xname) and dt.contains("Ultimate") and dt.contains(fuse),
		"and its second line names the Ultimate (%s, %s) and the Fusion (%s): '%s'" % [ulti, xname, fuse, dt]
	)
	var pu: int = order.find("pick_ult")
	var fuse_at := order.find("ult")
	ok(pu >= 0 and pu < fuse_at, "the Fusion unlock (step %d) comes before the Fusion step (%d)" % [pu, fuse_at])
	ok(
		not bool(seen["hook"]["ult_open"]) and bool(seen["pick_ult"]["ult_open"]),
		(
			"X can't take the point before level %d, and can at pick_ult (lvl %d, %d points)"
			% [Hunter.ULT_AT[0], seen["pick_ult"]["lvl"], seen["pick_ult"]["pts"]]
		)
	)


func _wasd() -> String:
	return "".join(["up", "left", "down", "right"].map(func(a): return Settings.key_cap(a)))


# ------------------------------------------------------------------ 4. the strip
func _fit() -> void:
	var font: Font = HudStyle.BIG
	for sz: Vector2 in SIZES:
		var r := TutorialStrip.rect(sz)
		var worst := 99
		var who := ""
		for sid in order:
			var line := {
				"text": seen[sid]["text"],
				"key_cap": seen[sid]["cap"],
				"count": "3/3",
				"dist": "999m",
				"dir": Vector2.RIGHT
			}
			var lay := TutorialStrip.layout(font, r, line)
			if int(lay["text_px"]) < worst:
				worst = int(lay["text_px"])
				who = sid
			var text_end: float = (lay["text_at"] as Vector2).x + float(lay["text_w"])
			var cap_end: float = (lay["cap_rect"] as Rect2).end.x if lay.has("cap_rect") else -1.0
			ok(
				text_end <= float(lay["arrow_end"]) + 0.5 and (lay["text_at"] as Vector2).x >= cap_end,
				"%s: '%s' sits between its key cap and its arrow" % [sz, sid]
			)
		var tight := "%s: the tightest line (%s) still gets %d px (at least %d)" % [sz, who, worst, MIN_TEXT_PX]
		ok(worst >= MIN_TEXT_PX, tight)
