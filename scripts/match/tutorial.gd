class_name Tutorial
extends RefCounted
## The first-match tutorial: a short scripted course on content/maps/tutorial.json (its "course" table
## holds each stop), eight steps (decision 0023: what the cut steps taught is
## MatchHints now). Match owns one of these as `tut` and calls update() every step.
## The steps, their words and the headless driver (TutorialDrive) live here and next door, not in Match.
## What the player sees is drawn by TutorialHud: a small banner at the top for each new step that
## settles into a pill, a pulse when they stall, a quiet check when a step is done; the marker (beam,
## arrow) is here and in the Hud. Pell, the guide who flies ahead and stops you before each new thing, is
## TutorialGuide. Only the first intro card and Pell's short talks ever pause play. Skip (TutorialHud) ends it.

## Steps: content/rules/tutorial.json. Steps a kit can't do are skipped (applies()).
static func steps() -> Array:
	return Content.rules("tutorial")["steps"]

const KEYS := {"move": "move", "dash": "dash", "glide": "glide", "shoot": "fire", "sig": "signature",
	"throw": "throw", "chest": "interact"}
## Which course stop a finished step leaves you at (a fall puts you back there).
const STOP_AFTER := {"move": "move", "dash": "glide"}
const PADS := ["dash", "glide"]      # course stops left from a glowing pad on one island, landed on the next
const FOE_STEPS := ["shoot", "sig", "throw", "fight"]     # the marker is the nearest monster
const WALK_LEAD := ["move", "chest", "extract"]

const CARD_T := 1.5        # s the top banner stays up before it settles into the pill
const NAG_T := 8.0         # s without progress before the pill pulses and the Boki says it again
const INTRO_T := 2.0       # s the first-time intro card stays up (any key closes it sooner)
const DONE_T := 0.9        # s of the step-done sting
const DASH_WAIT_T := 40.0  # s on the dash isle before the glide half starts without a dash seen
const FAR_SCOUT := 38.0    # m: a target this far off gets "crouch to scout ahead"
const MINT := Color(0.56, 0.89, 0.78)

var m: Match
var step := -1
var leg := 0                 # the dash step's half: 0 dash to the isle, 1 glide on to the range
var intro := true            # the "Training run" card: the first time only, until a key or INTRO_T
var intro_t := 0.0
var text := ""               # this step's one line, on the banner and the pill
var key_cap := ""            # the key cap beside it ("" for none)
var got := 0                 # times this step's action has landed (shown as got/need)
var got_seen := 0            # got at the last cooldown reset
var need := 0
var t := 0.0                 # s in this step
var card_t := 0.0            # s since the card (re)appeared
var done_t := 0.0            # s left of the step-done check
var flash_t := 0.0           # s the marker flashes (after a stall)
var nag_t := 0.0             # s the pill pulses (after a stall)
var wait := 0.0
var down_t := 0.0
var kills := 0               # monsters you or your Boki beat
var flag := false
var moved := 0.0
var stall_t := 0.0           # s since the last progress
var stall_got := 0            # got at the last look: a hit or a cast is progress too
var best_d := 1e9            # closest you've been to this step's target
var target := Vector3.INF    # where the marker points (INF for none)
var label := ""
var last_stop := Vector3.INF # where a fall puts you back
var used0 := {}
var throws0 := 0
var hits := 0                # your weapon hits on a monster this step
var recalled := false        # the Boki came back (it started out)
var need_back := false
var fight_n := 0
var _course: Dictionary = {}
var _beams: Array = []
var _pads: Array = []
var pell: TutorialGuide
var skip_btn: Button = null    # the Skip button (TutorialHud.add_skip), once the Hud is there

func _init(match_node: Match) -> void:
	m = match_node
	intro = not match_node.opts.get("tut_test", false) and not Save.d["tutorial"].get("tut_intro", false)
	_course = World.load_layout("tutorial").get("course", {})
	pell = TutorialGuide.new(self)

# ------------------------------------------------------------------ the course
## A course stop's ground position (INF when the stop isn't in the table). key: "at" or "pad".
func stop(id: String, key := "at") -> Vector3:
	var s: Dictionary = _course.get(id, {})
	if not s.has(key):
		return Vector3.INF
	var q: Array = s[key]
	return Vector3(float(q[0]), m.world.ground_at(float(q[0]), float(q[1])), float(q[1]))

## The course stop this step heads for: the dash step's second half is the glide stop.
func stop_id() -> String:
	return "glide" if id() == "dash" and leg == 1 else id()

## Chest, pads and their glowing edges, and the Skip button: built once the world is there.
func setup() -> void:
	var at := stop("chest")
	var n := Models.chest()
	n.position = at
	m.add_child(n)
	m.chests.append({"pos": at, "open": false, "prog": 0.0, "node": n, "tut": true})
	KeyChest.dress(n)
	for id in PADS:
		_add_pad(id)
	last_stop = stop("land")
	pell.build()

func _add_pad(id: String) -> void:
	var pad := stop(id, "pad")
	var to := stop(id)
	if pad == Vector3.INF:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(MINT, 0.8)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.25
	cyl.height = 0.06
	cyl.material = mat
	disc.mesh = cyl
	disc.position = pad + Vector3(0, 0.08, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(disc)
	# the glowing edge: a bar along the rim, square to the way across
	var bar := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.35, 0.12, 4.2)
	bx.material = mat
	bar.mesh = bx
	var dir := Vector2(to.x - pad.x, to.z - pad.z).normalized()
	bar.position = pad + Vector3(dir.x, 0.1, dir.y) * 1.0
	bar.rotation.y = atan2(dir.x, dir.y)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(bar)
	var lab := Label3D.new()
	lab.text = {"dash": "DASH HERE", "glide": "JUMP HERE"}[id]
	lab.font_size = 96
	lab.pixel_size = 0.012
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = MINT
	lab.no_depth_test = true
	lab.position = pad + Vector3(0, 2.6, 0)
	m.add_child(lab)
	_pads.append({"id": id, "disc": disc, "bar": bar, "label": lab})

# ------------------------------------------------------------------ each step
func id() -> String:
	return String(steps()[step][0]) if step >= 0 and step < steps().size() else ""

## Whether this hunter's kit has the thing a step teaches.
func applies(sid: String) -> bool:
	var p := m.player
	match sid:
		"sig": return p.ak != null or (p.kin != null and p.kin.runner != null and p.kin.runner.has_slot("k1"))
		"throw": return p.kin != null
	return true

## Called by Match every step.
func update(dt: float) -> void:
	var p := m.player
	if p == null or p.extracted:
		return
	if step < 0:
		step = 0
		_enter()
	if skip_btn == null and m.hud:
		skip_btn = TutorialHud.add_skip(m)      # (the Hud is built after setup)
	if p.downed:
		down_t += dt
		if down_t > 3.0:
			down_t = 0.0
			m.revive_hunter(p, null)
	if p.kin and p.kin.state == "downed":
		p.kin.down_t = minf(p.kin.down_t, 0.5)     # (a Boki that got knocked out here comes round at once)
	t += dt
	card_t += dt
	done_t = maxf(0.0, done_t - dt)
	flash_t = maxf(0.0, flash_t - dt)
	nag_t = maxf(0.0, nag_t - dt)
	if m.hud:
		m.hud.msgs.hold = card_up()      # messages wait while the banner is up
	var sid := id()
	var done := _is_done(sid)
	_quicken(p, dt)
	if got != got_seen:
		got_seen = got
		_refresh(p)          # (each move that lands is ready again at once)
	_point(sid)
	_stall(dt)
	_props()
	pell.tick(dt)
	if p.kin and p.kin.comp:
		p.kin.comp.tut(stop_id(), goal(sid))
	if wait > 0.0:
		wait -= dt
		return
	if done:
		_finish(sid)
	if step < steps().size():
		_words()

func _finish(sid: String) -> void:
	if STOP_AFTER.has(sid):
		last_stop = stop(STOP_AFTER[sid])
	step += 1
	if step == 1:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tut-from="): step = int(a.substr(11))     # test: skip ahead after landing
	while step < steps().size() and not applies(id()):
		step += 1
	_sting()
	_enter()

func _sting() -> void:
	flag = false
	wait = 0.6
	done_t = DONE_T
	m.sfx("unlock", null, -9.0)

## The dash step's first half is done (on the dash isle): the glide half starts, with its own banner.
func _next_leg() -> void:
	leg = 1
	last_stop = stop("dash")
	_sting()
	t = 0.0
	card_t = 0.0
	m.bubbles.clear()       # (the leg's banner has the floor too)
	stall_t = 0.0
	best_d = 1e9
	_refresh(m.player)
	_words()

## Cooldowns run 1/rules.cds times faster here, so each move can be tried again and again while learning.
func _quicken(p: Hunter, dt: float) -> void:
	var extra: float = dt * (1.0 / float(Content.rules("tutorial")["cds"]) - 1.0)
	p.dashes = minf(p.max_dashes(), p.dashes + extra / p.dash_regen())
	p.ex_cd = maxf(0.0, p.ex_cd - extra)
	p.sig_cd = maxf(0.0, p.sig_cd - extra)
	for r in _runners(p):
		r.tick(extra)

## Every move is ready: on a new step, a retry (respawn) and each time the step's action lands.
func _refresh(p: Hunter) -> void:
	p.dashes = p.max_dashes()
	p.ex_cd = 0.0
	p.sig_cd = 0.0
	for r in _runners(p):
		r.reset()

func _runners(p: Hunter) -> Array:
	var out: Array = []
	if p.runner: out.append(p.runner)
	for k in [p.kin, p.kin2]:
		if k: out.append((k as Kin).runner)
	return out

func _enter() -> void:
	var p := m.player
	var sid := id()
	t = 0.0
	card_t = 0.0
	leg = 0
	m.bubbles.clear()       # one voice at a time: the old step's lines go, the banner has the floor
	if m.hud:
		m.hud.msgs.clear()
		m.hud.msgs.hold = true
	stall_t = 0.0
	nag_t = 0.0
	flash_t = 0.0
	best_d = 1e9
	got = 0
	got_seen = 0
	stall_got = 0
	_refresh(p)
	hits = 0
	recalled = false
	need_back = false
	used0 = p.used.duplicate()
	match sid:
		"shoot":
			kills = 0
			_foes(["skitter"])
		"sig":
			_foes(["skitter", "skitter", "skitter"])
		"throw":
			if p.kin:
				throws0 = p.kin.st_throws
			_foes(["spitter"])
		"fight":
			kills = 0
			var left := _live_foes()      # (one may be left from the Boki step: it joins the fight)
			_foes((["skitter", "spitter", "skitter"] as Array).slice(mini(left, 3)), true)
			fight_n = _live_foes()
		"chest":
			if p.chest_keys == 0:
				KeyChest.give(p, 1)      # (the key is handed over: finding one is a hint now)
			FirstTimeHint.mark("key")
			m.ping(stop("chest"), Color("dfe8f2"))
			for mb in m.mobs:
				if not mb.dead:
					mb.dead = true
					mb.visible = false
		"extract":
			var o := outpost()
			if not o.is_empty():
				m.exits.open_now(o, p.team)      # (the uplink and its defence are hints now: the lift is open)
				m.ping(o["pos"], ExitModels.UPLINK)
	_words()
	pell.begin(sid)

## Brings monsters in near the player for a step (only if none are left, unless topping up).
func _foes(kinds: Array, top_up := false) -> void:
	if not top_up and _live_foes() > 0:
		return
	var i := 0
	for kd in kinds:
		var at := spot(5.0 + i * 1.2, 0.6 + i * 1.3)
		if at != Vector3.INF:
			_tank(m.spawn_mob(kd, at))
		i += 1

func _live_foes() -> int:
	return m.mobs.filter(func(x): return not x.dead).size()

## Keeps a monster around for the shooting steps (another comes if it falls off).
func _keep_foe(kind: String) -> void:
	if m.mobs.any(func(x): return not x.dead) or int(m.time * 4.0) % 4 != 0:
		return
	var at := spot(5.5, randf() * TAU)
	if at != Vector3.INF:
		_tank(m.spawn_mob(kind, at))

## The tutorial's monsters: many times the health and bigger, barely a scratch when they hit, slow
## telegraphed attacks (content/rules/tutorial.json "mob"). Real matches keep the global stats.
func _tank(mb: Mob) -> void:
	var c: Dictionary = Content.rules("tutorial")["mob"]
	mb.max_hp *= float(c["hp"])
	mb.hp = mb.max_hp
	mb.dmg_mult = float(c["dmg"])
	mb.r *= float(c["scale"])
	mb.model.scale *= float(c["scale"])
	mb.md = mb.md.duplicate()
	mb.md["windup"] = float(mb.md["windup"]) * float(c["windup"])
	mb.md["cd"] = float(mb.md["cd"]) * float(c["cd"])

## Open ground a given distance from the player on the same island.
func spot(dist: float, ang0: float) -> Vector3:
	var w := m.world
	var p := m.player
	var isl := w.island_of(p.pos.x, p.pos.z)
	for i in 24:
		var a := ang0 + i * 0.52
		for d in [dist, dist * 0.7, dist * 0.5]:
			var x: float = p.pos.x + cos(a) * d
			var z: float = p.pos.z + sin(a) * d
			if w.island_of(x, z) == isl and not w.is_block(x, z) and w.edge_dist(int(x), int(z), 2) >= 2:
				return Vector3(floor(x) + 0.5, w.ground_at(x, z), floor(z) + 0.5)
	return Vector3.INF

func _is_done(sid: String) -> bool:
	var p := m.player
	var near := func(r: float) -> bool: return p.grounded and _dist(stop(stop_id())) < r
	match sid:
		"move":
			if p.dropping:
				return false
			if p.inp["move"].length() > 0.1:
				moved += Vector2(p.pos.x - p.prev.x, p.pos.z - p.prev.z).length()
			return moved > 3.0 and near.call(2.2)
		"dash":
			if leg == 0:
				flag = flag or p.roll_t > 0.0
				if near.call(4.0) and (flag or t > DASH_WAIT_T):
					_next_leg()
				return false
			flag = flag or p.gliding
			return flag and near.call(5.0)
		"shoot":
			_keep_foe("skitter")
			got = hits
			return got >= need
		"sig":
			_keep_foe("skitter")
			got = int(p.used.get("k1", 0)) - int(used0.get("k1", 0))
			return got >= need
		"throw":
			_keep_foe("spitter")
			return p.kin == null or p.kin.state == "downed" or _throw_done()
		"fight": return kills >= fight_n and not m.mobs.any(func(x): return not x.dead)
		"chest": return m.chests.any(func(c): return c.get("tut", false) and c["open"])
	return false      # (extract: the match ends when you step into the light)

## The Boki step: call it back first when it is out (a tap would call it back), then send it. A Boki
## beside you or on your shoulder just gets sent. Counts the call back and the send.
func _throw_done() -> bool:
	var k: Kin = m.player.kin
	if k.st_throws == throws0:
		if throw_recalls():
			need_back = true
		elif need_back:
			recalled = true
	got = int(recalled) + int(k.st_throws > throws0)
	need = 2 if need_back else 1
	return got >= need

## Would a G tap call the Boki back right now (it is out or fighting) rather than send it?
func throw_recalls() -> bool:
	var k: Kin = m.player.kin
	if k == null or k.state not in ["active", "returning"]:
		return false
	return KinCommand.is_away(m.player, k) or KinCommand.is_engaged(k)

# ------------------------------------------------------------------ the marker
## The outpost the course ends at (the map's).
func outpost() -> Dictionary:
	if m.exits == null:
		return {}
	var outs := m.exits.of_kind("outpost")
	return outs[0] if not outs.is_empty() else {}

## What a step is about (INF for nothing): where the marker points.
func goal(sid: String) -> Vector3:
	match sid:
		"move", "dash": return stop(stop_id())
		"shoot", "sig", "throw", "fight":
			var best: Ent = null
			var bd := 1e9
			for mb in m.mobs:
				if not mb.dead and m.player.flat_dist(mb) < bd:
					bd = m.player.flat_dist(mb)
					best = mb
			return best.pos if best else stop("yard")
		"chest":
			for c in m.chests:
				if c.get("tut", false):
					return c["pos"]
		"extract":
			var o := outpost()
			return o["pos"] if not o.is_empty() else Vector3.INF
	return Vector3.INF

## Where Pell flies ahead to: the glowing pad before a gap, else the goal itself.
func _lead_goal(sid: String) -> Vector3:
	if sid == "dash":
		return stop(stop_id(), "pad")
	if sid in WALK_LEAD:
		return goal(sid)
	return Vector3.INF

## The marker: from the first frame of a destination step to its last, monsters close by or not.
func _point(sid: String) -> void:
	target = Vector3.INF
	label = ""
	var at := goal(sid)
	if at == Vector3.INF or m.player.out:
		return
	target = at
	label = String(Content.rules("tutorial")["labels"].get(stop_id(), "Monster"))

## A stall (NAG_T without getting closer): the pill and the marker pulse and the Boki says it once
## more. No card comes back and nothing pauses.
func _stall(dt: float) -> void:
	stall_t += dt
	if got != stall_got:
		stall_got = got
		stall_t = 0.0
	if target != Vector3.INF and id() not in FOE_STEPS:      # (a monster walking up to you is not progress)
		var d := Vector2(target.x - m.player.pos.x, target.z - m.player.pos.z).length()
		if d < best_d - 1.0:
			best_d = d
			stall_t = 0.0
	if stall_t >= NAG_T and wait <= 0.0:
		stall_t = 0.0
		best_d = 1e9 if target == Vector3.INF else _dist(target)
		nag_t = 2.5
		flash_t = 2.5
		if m.player.kin and m.player.kin.comp:
			m.player.kin.comp.nag()

func _props() -> void:
	var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	var want: Array = []
	if target != Vector3.INF:
		want.append(target)
	while _beams.size() < want.size():
		_beams.append(_make_beam())
	for i in _beams.size():
		var b: MeshInstance3D = _beams[i]
		b.visible = i < want.size()
		if b.visible:
			b.position = (want[i] as Vector3) + Vector3(0, 30.0, 0)
			var wide := pulse * (1.6 if flash_t > 0.0 else 1.0)
			b.scale = Vector3(wide, 1.0, wide)
	var on_id := stop_id()
	for pd in _pads:
		var on: bool = pd["id"] == on_id
		(pd["disc"] as Node3D).scale = Vector3.ONE * (pulse if on else 1.0)
		(pd["label"] as Node3D).visible = on

## Beams standing in the world right now (--tutorial-idle-check).
func beams_on() -> int:
	return _beams.filter(func(b: MeshInstance3D): return b.visible).size()

func _make_beam() -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 60.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(MINT, 0.32)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	n.mesh = cyl
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(n)
	return n

# ------------------------------------------------------------------ words
func _words() -> void:
	if step >= steps().size():
		return
	var sid := id()
	var line := String(steps()[step][1])
	var alt: Dictionary = Content.rules("tutorial")["alt"]
	if sid == "dash" and leg == 1:
		line = String(alt["glide"])
	elif sid == "throw" and not recalled and (need_back or throw_recalls()):
		line = String(alt["throw_back"])
	elif sid == "throw" and need_back:
		line = String(alt["throw_send"])
	text = _fill(line)
	need = int(Content.rules("tutorial")["need"].get(sid, 0))
	if sid == "throw":
		need = 2 if need_back or throw_recalls() else 1
	key_cap = ""
	if sid == "move":
		key_cap = _wasd()
	elif KEYS.has(stop_id()):
		key_cap = Settings.key_cap(KEYS[stop_id()])

## "1/3" for a step that wants its action a few times, else "".
func progress_text() -> String:
	return "%d/%d" % [mini(got, need), need] if need > 1 else ""

## The player's own keys, Boki name and ability names in a line.
func _fill(txt: String) -> String:
	var p := m.player
	var an := ""
	if p.ak != null:
		an = String(p.ak.e_def().get("name", "your ability"))
	elif p.kin and p.kin.runner and p.kin.runner.has_slot("k1"):
		an = p.kin.runner.def_of("k1").display_name
	var kname := "your Boki"
	if p.kin:
		kname = String(p.kin.rec.get("name", kname))
	txt = txt.replace("%W", "Swing at" if p.wpn.get("melee", false) else "Shoot")
	txt = txt.replace("%J", Settings.key_cap("jump")).replace("%G", Settings.key_cap("glide"))
	txt = txt.replace("%A", an).replace("%s", kname)
	return TutorialText.fill(txt, p)

func _wasd() -> String:
	var caps: Array = ["up", "left", "down", "right"].map(func(a): return Settings.key_cap(a))
	return "".join(caps)

## Flat distance from the player to a spot.
func _dist(at: Vector3) -> float:
	return Vector2(at.x - m.player.pos.x, at.z - m.player.pos.z).length()

## The extra line for a faraway target: a hint to scout ahead from a crouch.
func scout_hint() -> String:
	if target == Vector3.INF or m.player.crouch or m.player.dropping:
		return ""
	var d := Vector2(target.x - m.player.pos.x, target.z - m.player.pos.z).length()
	return "Hold %s to crouch and scout ahead" % Settings.key_cap("crouch") if d > FAR_SCOUT else ""

## The banner is up (the first CARD_T of a step): other popups wait their turn.
func card_up() -> bool:
	return intro or (step >= 0 and card_t < CARD_T)

# ------------------------------------------------------------------ the fall, and the key press
## Where a fall into the void puts you back: the last stop you reached.
func respawn() -> Vector3:
	_refresh(m.player)          # (a fall is a retry: every move is ready for it)
	return last_stop if last_stop != Vector3.INF else stop("land")

## A weapon hit of yours on a monster (Match).
func on_hit() -> void:
	hits += 1

## The match waits: for the first-time intro card, or while Pell talks (TutorialGuide.TALK_MAX_S at most).
func holding() -> bool:
	return intro or pell.talking()

## The intro card waits for a key or INTRO_T seconds; Pell, for you to read its line.
func hold_wait(dt: float) -> void:
	for k in m.pending_input:
		m.pending_input[k] = false
	if not intro:
		pell.hold(dt)
		if m.opts.get("tut_test", false):
			pell.test_skip()      # (the headless driver reads it: the match step that would drive it is held)
		return
	intro_t += dt
	if intro_t >= INTRO_T:
		ack()

## Any key or click closes the intro card; it is shown only the first time.
func ack() -> void:
	if intro:
		intro = false
		Save.d["tutorial"]["tut_intro"] = true
