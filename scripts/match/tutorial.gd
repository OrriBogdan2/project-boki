class_name Tutorial
extends RefCounted
## The Trial Expedition: a guided course on content/maps/tutorial.json, one stop per skill (its
## "course" table holds each stop), played before your first real expedition and again from the
## expedition panel. Match owns one of these as `tut` and calls update() every step.
## The steps, their words and the headless driver (TutorialDrive) live here and next door, not in Match.
## Each lesson opens with a calm centred card (one instruction, its key, a looping clip where one
## helps) and the world waits until you press a key; then a pill at the bottom while you do it and a
## pulse when you stall. Doing it brings the next lesson's card; nothing moves on by itself. Drawn by
## TutorialHud; the marker (beam, arrow) is here and in the Hud.

## Steps: content/rules/tutorial.json. Steps a kit can't do are skipped (applies()).
## Whether your Boki runs ahead for this step (to a pad before a gap, or to the goal).
static func leads(sid: String) -> bool:
	return sid in WALK_LEAD or sid in GAP_STEPS

static func steps() -> Array:
	return Content.rules("tutorial")["steps"]

const KEYS := {"land": "move", "move": "move", "dash": "dash", "exdash": "dash", "glide": "glide", "crouch": "crouch",
	"pickup": "interact", "shoot": "fire", "sig": "signature", "utility": "secondary", "throw": "throw",
	"orders": "throw", "chest": "interact", "uplink": "interact", "gkey": "throw"}
## Which course stop a finished step leaves you at (a fall puts you back there).
const STOP_AFTER := {"land": "land", "move": "move", "dash": "dash", "exdash": "exdash", "glide": "glide",
	"crouch": "crouch", "pickup": "yard"}
const GAP_STEPS := ["dash", "exdash", "glide"]      # leave from the glowing pad on one island, land on the next
const WALK_LEAD := ["move", "crouch", "pickup", "key", "chest", "goexit", "uplink", "extract"]

const READ_T := 0.4        # s a lesson card stays up before a key closes it (a held click can't skip it unread)
const NAG_T := 8.0         # s without progress before the pill pulses and the Boki says it once more
const SPOT_T := 5.0        # s the lookout shows the chest it spotted
const LOOKOUT_R := 4.2     # m: the lookout's top is 3.6 wide; any grounded height within this counts
const CROUCH_HOLD := 1.5   # s of crouching at the lookout
const KIN_WATCH_T := 12.0  # s to wait for your Boki to use its ability by itself before moving on
const FAR_SCOUT := 38.0    # m: a target this far off gets "crouch to scout ahead"
const MINT := Color(0.56, 0.89, 0.78)

var m: Match
var step := -1
var card := false            # this lesson's card is up: the world waits for a key
var card_t := 0.0            # s the card has been up
var clip: AbilityClip = null # the card's looping ability clip (TutorialHud places it)
var text := ""               # this step's one line, on the card and the pill
var detail := ""             # and the plain-words lines under it on the card ("" for none)
var key_cap := ""            # the key cap beside it ("" for none)
var got := 0                 # times this step's action has landed (shown as got/need)
var need := 0
var t := 0.0                 # s in this step
var flash_t := 0.0           # s the marker flashes (after a stall)
var nag_t := 0.0             # s the pill pulses (after a stall)
var spot_t := 0.0            # s left of "You spotted it!" and the chest beam
var down_t := 0.0
var kills := 0               # monsters you or your Boki beat
var flag := false
var moved := 0.0
var stall_t := 0.0           # s since the last progress
var best_d := 1e9            # closest you've been to this step's target
var target := Vector3.INF    # where the marker points (INF for none)
var label := ""
var last_stop := Vector3.INF # where a fall puts you back
var used0 := {}
var throws0 := 0
var skills0 := 0
var pts0 := 0                # skill points to spend once the rank-up lesson's level came
var taps := 0                # right click: taps so far
var held := false            # and whether it was held (kits with a hold only)
var hits := 0                # your weapon hits on a monster this step
var orders := 0              # order wheel picks (hold G)
var recalled := false        # the Boki came back (it started out)
var need_back := false
var crouch_t := 0.0
var rmb_t_prev := 0.0
var fight_n := 0
var _course: Dictionary = {}
var _beams: Array = []
var _pads: Array = []

func _init(match_node: Match) -> void:
	m = match_node
	_course = World.load_layout("tutorial").get("course", {})

## The Trial's match options. `replay`: started again from the expedition panel (nothing carries over).
static func opts(replay := false) -> Dictionary:
	return {"tutorial": true, "trial_replay": replay, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0}

# ------------------------------------------------------------------ the course
## A course stop's ground position (INF when the stop isn't in the table). key: "at" or "pad".
func stop(id: String, key := "at") -> Vector3:
	var s: Dictionary = _course.get(id, {})
	if not s.has(key):
		return Vector3.INF
	var q: Array = s[key]
	return Vector3(float(q[0]), m.world.ground_at(float(q[0]), float(q[1])), float(q[1]))

## Chest, pads and their glowing edges: built once the world is there.
func setup() -> void:
	var at := stop("chest")
	var n := Models.chest()
	n.position = at
	m.add_child(n)
	m.chests.append({"pos": at, "open": false, "prog": 0.0, "node": n, "tut": true})
	KeyChest.dress(n)
	for id in GAP_STEPS:
		_add_pad(id)
	last_stop = stop("land")

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
	lab.text = {"dash": "DASH HERE", "exdash": "JUMP HERE", "glide": "JUMP HERE"}[id]
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
		"utility": return p.ak != null or (p.runner != null and p.runner.has_slot("utility"))
		"throw", "orders": return p.kin != null
		"kin1": return p.kin != null and p.kin.runner != null and p.kin.runner.has_slot("k1")
		"gkey": return p.kin != null
		"rank": return p.ak != null
	return true

## Called by Match every step.
func update(dt: float) -> void:
	var p := m.player
	if p == null or p.extracted:
		return
	if step < 0:
		step = 0
		_enter()
	if p.downed:
		down_t += dt
		if down_t > 3.0:
			down_t = 0.0
			m.revive_hunter(p, null)
	if p.kin and p.kin.state == "downed":
		p.kin.down_t = minf(p.kin.down_t, 0.5)     # (a Boki that got knocked out here comes round at once)
	t += dt
	flash_t = maxf(0.0, flash_t - dt)
	nag_t = maxf(0.0, nag_t - dt)
	spot_t = maxf(0.0, spot_t - dt)
	if m.hud:
		m.hud.msgs.hold = card_up()      # messages wait while the card is up
	var sid := id()
	var done := _is_done(sid, dt)
	_point(sid)
	_stall(dt)
	_props()
	if p.kin and p.kin.comp:
		p.kin.comp.tut(sid, _lead_goal(sid))
	if done:
		_finish(sid)
	if step < steps().size():
		_words()

## The lesson's card comes up and the world waits (Match.step holds while `card`), from the very
## frame the lesson starts: nothing happens between one lesson and the next one's card.
func _open_card() -> void:
	card = true
	card_t = 0.0
	m.bubbles.clear()       # one voice at a time: the card has the floor
	if m.hud:
		m.hud.msgs.hold = true

## While the card is up: the match is held, button presses don't reach the hunter, the clip plays.
func hold(dt: float) -> void:
	for k in m.pending_input:
		m.pending_input[k] = false
	card_t += dt
	if m.hud:
		TutorialHud.sync_clip(m.hud, self)

## A key or click closes the card (after READ_T) and play goes on: now do it.
func ack() -> void:
	if not card or card_t < READ_T:
		return
	card = false
	stall_t = 0.0
	if m.hud:
		TutorialHud.sync_clip(m.hud, self)

func _finish(sid: String) -> void:
	if sid == "orders" and m.player.kin:
		KinFollow.set_cmd(m.player.kin, "follow", null)      # (back to walking beside you, so it can lead on)
	if STOP_AFTER.has(sid):
		last_stop = stop(STOP_AFTER[sid])
	step += 1
	if step == 1:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tut-from="): step = int(a.substr(11))     # test: skip ahead after landing
	while step < steps().size() and not applies(id()):
		step += 1
	flag = false
	m.sfx("unlock", null, -9.0)
	_enter()

func _enter() -> void:
	var p := m.player
	var sid := id()
	t = 0.0
	if m.hud:
		m.hud.msgs.clear()
		m.hud.msgs.hold = true
	stall_t = 0.0
	best_d = 1e9
	crouch_t = 0.0
	taps = 0
	got = 0
	held = false
	hits = 0
	orders = 0
	recalled = false
	need_back = false
	used0 = p.used.duplicate()
	skills0 = p.kin.st_skills if p.kin else 0
	match sid:
		"pickup":
			var at := stop("pickup")
			m.spawn_gear("vest", 1, at, "", false)
			m.wpicks[-1]["tut"] = true
			m.ping(at, Color("dfe8f2"))
		"gkey":
			if p.kin:
				throws0 = p.kin.st_throws
			_foes(["skitter"])
		"key":
			_spawn_key()
		"shoot":
			kills = 0
			_foes(["skitter"])
		"sig":
			_foes(["skitter", "skitter", "skitter"])
		"utility":
			_foes(["skitter", "skitter"])
		"throw":
			if p.kin:
				throws0 = p.kin.st_throws
			_foes(["spitter"])
		"kin1":
			_foes(["skitter"])
		"fight":
			for mb in m.mobs:
				if not mb.dead:
					mb.dead = true      # (the practice monster from the lessons before goes: a fresh group comes)
					mb.visible = false
			kills = 0
			fight_n = 3
			_foes(["skitter", "spitter", "skitter"])
		"chest":
			m.ping(stop("chest"), Color("dfe8f2"))
		"goexit":
			var o := outpost()
			if not o.is_empty():
				m.ping(o["pos"], ExitModels.UPLINK)
		"uplink", "defend", "extract":
			pass
	_words()
	if step < steps().size():
		_open_card()

## The Trial starts with every ability open, so a level-up is given once for real: the pop, the chime and
## a skill point (the gold + by the level ring), spent with Alt + the ability's key.
func _offer_rank() -> void:
	var p := m.player
	p.gain_xp(float(Hunter.XP_TO[p.lvl]) - p.xp)

## A chest key on the ground a few steps from the player, for the chest that needs one.
func _spawn_key() -> void:
	var at := spot(3.5, 0.3)
	if at == Vector3.INF:
		at = m.player.pos + Vector3(2.0, 0.0, 0.0)
	m.drop("ckey", at + Vector3(0, 0.6, 0), 1, "", "", Vector3.ZERO)

## Brings monsters in near the player for a step (only if none are left).
func _foes(kinds: Array) -> void:
	if m.mobs.any(func(x): return not x.dead):
		return
	var i := 0
	for kd in kinds:
		var at := spot(5.0 + i * 1.2, 0.6 + i * 1.3)
		if at != Vector3.INF:
			_tank(m.spawn_mob(kd, at))
		i += 1

## Keeps a monster around for the shooting steps (another comes if it falls off).
func _keep_foe(kind: String) -> void:
	if m.mobs.any(func(x): return not x.dead) or int(m.time * 4.0) % 4 != 0:
		return
	var at := spot(5.5, randf() * TAU)
	if at != Vector3.INF:
		_tank(m.spawn_mob(kind, at))

## The Trial's monsters: many times the health and bigger, barely a scratch when they hit, slow
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

func _is_done(sid: String, dt: float) -> bool:
	var p := m.player
	var near := func(r: float) -> bool: return p.grounded and _dist(stop(sid)) < r
	match sid:
		"land": return not p.dropping
		"move":
			if p.inp["move"].length() > 0.1:
				moved += Vector2(p.pos.x - p.prev.x, p.pos.z - p.prev.z).length()
			return moved > 3.0 and near.call(2.2)
		"dash":
			flag = flag or p.roll_t > 0.0
			return near.call(4.0) and (flag or t > 40.0)
		"exdash":
			# any dash started off the ground counts: kit air dashes (Vex's air slide) never set dash_is_ex
			flag = flag or (p.roll_t > 0.0 and (p.dash_is_ex or not p.grounded))
			return flag and near.call(4.5)
		"glide":
			flag = flag or p.gliding
			return flag and near.call(5.0)
		"crouch":
			if p.crouch and p.grounded and _dist(stop(sid)) < LOOKOUT_R:
				crouch_t += dt
			if crouch_t >= CROUCH_HOLD:
				spot_t = SPOT_T
				m.ping(stop("chest"), Color("dfe8f2"))
				if m.hud: m.hud.toast("Chest spotted across the bridge", MINT)
				return true
			return false
		"pickup": return ground_item().is_empty()
		"gkey": return p.kin == null or p.kin.st_throws > throws0 or p.kin.state == "downed"
		"rank":
			if not flag:
				flag = true      # (the first frame after the card: the level-up pop and the card never overlap)
				_offer_rank()
				pts0 = p.skill_pts
			return flag and p.skill_pts < pts0      # (one point spent: the lesson is learned)
		"key": return p.chest_keys > 0
		"shoot":
			_keep_foe("skitter")
			got = hits
			return got >= need
		"sig":
			_keep_foe("skitter")
			got = int(p.used.get("k1", 0)) - int(used0.get("k1", 0))
			return got >= need
		"utility":
			_keep_foe("skitter")
			return _rmb_done()
		"throw":
			_keep_foe("spitter")
			return p.kin == null or p.kin.state == "downed" or _throw_done()
		"orders": return p.kin == null or p.kin.state == "downed" or orders > 0
		"kin1":
			_keep_foe("skitter")
			var k: Kin = p.kin
			return k == null or k.state == "downed" or k.st_skills > skills0 or t >= KIN_WATCH_T
		"chest": return m.chests.any(func(c): return c.get("tut", false) and c["open"])
		"fight": return kills >= fight_n and not m.mobs.any(func(x): return not x.dead)
		"goexit":
			var o := outpost()
			return not o.is_empty() and m.exits.in_yard(o, p)
		"uplink":
			var o2 := outpost()
			return o2.is_empty() or o2["state"] != "idle"
		"defend":
			var o3 := outpost()
			return o3.is_empty() or o3["state"] == "open"
	return false

## Does this hunter's right click have a hold variant? Read from its kit; every other kit is taps only.
func rmb_has_hold() -> bool:
	var ak: ArchKit = m.player.ak
	return ak != null and float(ak.rmb_def().get("hold", 0.0)) > 0.0

## Right click: a tap, then a hold when the kit has one; else a couple of taps (counted as casts).
func _rmb_done() -> bool:
	var p := m.player
	if not rmb_has_hold():
		got = int(p.used.get("utility", 0)) - int(used0.get("utility", 0))
		return got >= need
	var ak: ArchKit = p.ak
	if ak.rmb_down:
		rmb_t_prev = ak.rmb_t
	elif rmb_t_prev > 0.0:
		if rmb_t_prev >= float(ak.rmb_def().get("hold", 0.3)):
			held = true
		else:
			taps += 1
		rmb_t_prev = 0.0
	got = mini(taps, 1) + (1 if held else 0)
	return got >= need

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
## The outpost the course ends at (the map's; one is made nearby on a map without).
func outpost() -> Dictionary:
	if m.exits == null:
		return {}
	var outs := m.exits.of_kind("outpost")
	return outs[0] if not outs.is_empty() else {}

## The gear on the ground that the pickup step is about ({} when it is gone).
func ground_item() -> Dictionary:
	for wp in m.wpicks:
		if wp.get("tut", false):
			return wp
	return {}

## What a step is about (INF for nothing): where the marker points.
func goal(sid: String) -> Vector3:
	match sid:
		"land", "move", "dash", "exdash", "glide", "crouch": return stop(sid)
		"pickup":
			var wp := ground_item()
			return wp["pos"] if not wp.is_empty() else stop("pickup")
		"shoot", "sig", "utility", "throw", "kin1", "fight":
			var best: Ent = null
			var bd := 1e9
			for mb in m.mobs:
				if not mb.dead and m.player.flat_dist(mb) < bd:
					bd = m.player.flat_dist(mb)
					best = mb
			return best.pos if best else stop("yard")
		"key":
			for pk in m.pickups:
				if pk["kind"] == "ckey":
					return pk["pos"]
		"chest":
			for c in m.chests:
				if c.get("tut", false):
					return c["pos"]
		"goexit", "uplink", "defend", "extract":
			var o := outpost()
			return o["pos"] if not o.is_empty() else Vector3.INF
	return Vector3.INF

## Where your Boki runs ahead to: the glowing pad before a gap, else the goal itself.
func _lead_goal(sid: String) -> Vector3:
	if sid in GAP_STEPS:
		return stop(sid, "pad")
	if sid in WALK_LEAD:
		return goal(sid)
	return Vector3.INF

## The marker: from the first frame of a destination step to its last. A fight step only gets one
## once the monsters are some way off.
func _point(sid: String) -> void:
	target = Vector3.INF
	label = ""
	var at := goal(sid)
	if at == Vector3.INF or m.player.out:
		return
	var foe_step := sid in ["shoot", "sig", "utility", "throw", "kin1", "fight"]
	if foe_step and Vector2(at.x - m.player.pos.x, at.z - m.player.pos.z).length() <= 6.0:
		return
	target = at
	label = String(Content.rules("tutorial")["labels"].get(sid, "Monster"))

## A stall (NAG_T without getting closer): the pill and the marker pulse and the Boki says it once
## more. The card doesn't come back.
func _stall(dt: float) -> void:
	stall_t += dt
	if target != Vector3.INF:
		var d := Vector2(target.x - m.player.pos.x, target.z - m.player.pos.z).length()
		if d < best_d - 1.0:
			best_d = d
			stall_t = 0.0
	if stall_t >= NAG_T:
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
	if spot_t > 0.0:
		want.append(stop("chest"))
	while _beams.size() < want.size():
		_beams.append(_make_beam())
	for i in _beams.size():
		var b: MeshInstance3D = _beams[i]
		b.visible = i < want.size()
		if b.visible:
			b.position = (want[i] as Vector3) + Vector3(0, 30.0, 0)
			var wide := pulse * (1.6 if flash_t > 0.0 else 1.0)
			b.scale = Vector3(wide, 1.0, wide)
	for pd in _pads:
		var on: bool = pd["id"] == id()
		(pd["disc"] as Node3D).scale = Vector3.ONE * (pulse if on else 1.0)
		(pd["label"] as Node3D).visible = on

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
	if sid == "utility" and rmb_has_hold():
		line = String(alt["utility_hold"])
	elif sid == "throw" and not recalled and (need_back or throw_recalls()):
		line = String(alt["throw_back"])
	elif sid == "throw" and need_back:
		line = String(alt["throw_send"])
	text = _fill(line)
	need = int(Content.rules("tutorial")["need"].get(sid, 0))
	if sid == "utility" and rmb_has_hold():
		need = 2
	elif sid == "throw":
		need = 2 if need_back or throw_recalls() else 1
	detail = _fill(TutorialText.fill(String(Content.rules("tutorial")["detail"].get(sid, "")), m.player))
	key_cap = ""
	if sid in ["land", "move", "key", "goexit", "extract"]:
		key_cap = _wasd()
	elif sid == "rank":
		key_cap = TutorialText.rank_combo()
	elif KEYS.has(sid):
		key_cap = Settings.key_cap(KEYS[sid])

## The ability clip this lesson's card plays ("" for none: a kit without archetype data has no clips).
func preview() -> String:
	if m.player.ak == null:
		return ""
	return String(Content.rules("tutorial")["preview"].get(id(), ""))

## [this lesson's number, how many lessons this kit gets] for the card's kicker.
func lesson() -> Array:
	var n := 0
	var total := 0
	for i in steps().size():
		if applies(String(steps()[i][0])):
			total += 1
			if i <= step:
				n += 1
	return [n, total]

## "1/3" for a step that wants its action a few times, else "".
func progress_text() -> String:
	return "%d/%d" % [mini(got, need), need] if need > 1 else ""

## The player's own keys, Boki name and ability names in a line.
func _fill(txt: String) -> String:
	var p := m.player
	var sid := id()
	var an := ""
	if sid == "sig" and p.ak != null:
		an = String(p.ak.e_def().get("name", "your ability"))
	elif sid == "utility":
		if p.ak:
			an = String(p.ak.rmb_def().get("name", "your hunter ability"))
		elif p.runner and p.runner.has_slot("utility"):
			an = p.runner.def_of("utility").display_name
	elif p.kin and p.kin.runner and p.kin.runner.has_slot("k1"):
		an = p.kin.runner.def_of("k1").display_name
	var kname := "your Boki"
	if p.kin:
		kname = String(p.kin.rec.get("name", kname))
	txt = txt.replace("%W", "Swing at" if p.wpn.get("melee", false) else "Shoot")
	txt = txt.replace("%J", Settings.key_cap("jump")).replace("%G", Settings.key_cap("glide"))
	txt = txt.replace("%E", Settings.key_cap("signature")).replace("%T", Settings.key_cap("throw"))
	return txt.replace("%A", an).replace("%s", kname)

func _wasd() -> String:
	var caps: Array = ["up", "left", "down", "right"].map(func(a): return Settings.key_cap(a))
	return "".join(caps)

## Flat distance from the player to a spot.
func _dist(at: Vector3) -> float:
	return Vector2(at.x - m.player.pos.x, at.z - m.player.pos.z).length()

## The extra line for a faraway target: a hint to scout ahead from a crouch.
func scout_hint() -> String:
	if target == Vector3.INF or m.player.crouch or id() in ["land", "crouch"]:
		return ""
	var d := Vector2(target.x - m.player.pos.x, target.z - m.player.pos.z).length()
	return "Hold %s to crouch and scout ahead" % Settings.key_cap("crouch") if d > FAR_SCOUT else ""

## The lesson card is up: other popups wait their turn.
func card_up() -> bool:
	return card

# ------------------------------------------------------------------ the fall, and the hits
## Where a fall into the void puts you back: the last stop you reached.
func respawn() -> Vector3:
	return last_stop if last_stop != Vector3.INF else stop("land")

## A weapon hit of yours on a monster (Match).
func on_hit() -> void:
	hits += 1
