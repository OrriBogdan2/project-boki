class_name Shrubling
extends Mob
## The bush mimic. It sits disguised as a clump of tall grass (ShrublingModel), and while it does it
## IS a bush: its tile is cover (World.live_bush), hunters walk into it and hide in it like any clump,
## and being close gives nothing away. Only a hit wakes it (any damage, or a root, slow, stun, shove or
## grab): it pops up (alert, a rustle), and anyone hiding in it is suddenly in the open. Then it runs:
## faster than a hunter on foot, slower than a dash, weaving to break line of sight, along a tile A*
## (KinPath) to a grass patch away from the hunter, where it dives in and is a bush again. The tell:
## every 5 to 10 s (seeded per Shrubling) its blades wobble and the leaves shimmer for a moment.
## It always carries a chest key and counts toward
## its region's quota (KeyRun). Low health, no attack. Slows, roots, stuns, Grounded (it can no
## longer dive, and runs slower) and pulls all work on it, because it is an ordinary Mob.
## States (ss): disguised | alert | flee | dive. Net: ss rides in the monster snapshot (KeyCarry).

const STATES := ["disguised", "alert", "flee", "dive"]

var ss := "disguised"
var ss_t := 0.0
var threat: Hunter = null
var hide_at := Vector3.INF
var path: Array = []
var repath := 0.0
var flee_t := 0.0
var weave_ph := 0.0
var _pose := 0.0
var _clock := 0.0
var _twitch := 0.0
var next_tell := 0.0              # match time of the next tell (sim side, so every game agrees)
var tells := 0                    # how many tells it has given (the check counts them)
var _trng := RandomNumberGenerator.new()
var _held_last := 0.0             # root + stun + slow seconds last tick: a fresh one is a hit
var _bush_tile := -1              # the World.live_bush tile it is holding, or -1

func init_shrub(match_node: Node, id: String, at: Vector3, tier := 1.0) -> void:
	var sr: Dictionary = KeyRun.rules()["shrubling"]
	init_mob(match_node, id, "shrubling", at, 1.0)
	max_hp = float(sr["hp"]) * (1.0 + (tier - 1.0) * float(sr["tier_hp"]))
	hp = max_hp
	camp = at
	face = randf() * TAU
	weave_ph = randf() * TAU
	_trng.seed = hash(id) ^ int(KeyRun.rules()["keys"]["seed_mul"])
	next_tell = m.time + _tell_gap()
	KeyCarry.mark(self)
	_show_glint(false)
	ShrublingModel.recolour(model, leaf_colour(m, at))      # the same colour as the grass it hides in

## True for a Shrubling that is still pretending to be a bush. Anything that PICKS a target for a Boki
## (Chase, the engage scan) calls this and skips it, so a Boki does not give a bush away; a hit still lands.
static func hidden(e: Ent) -> bool:
	return e is Shrubling and (e as Shrubling).ss == "disguised"

## The colour World gives a tall-grass tile at `at` (its biome's leaf, a third of the way to the top).
static func leaf_colour(m: Node, at: Vector3) -> Color:
	var w: World = m.world if m != null and m.get("world") else null
	if w != null and w.inb(int(floor(at.x)), int(floor(at.z))):
		var b: Dictionary = w._bio(w.idx(int(floor(at.x)), int(floor(at.z))))
		return Color(b["leaf"]).lerp(Color(b["top"]), 0.35)
	return Color("5f9a46")

func mass() -> float:
	return 1.0

## Seconds to the next tell: 5 to 10, from its own seeded stream.
func _tell_gap() -> float:
	var tw: Array = KeyRun.rules()["shrubling"]["tell_s"]
	return _trng.randf_range(float(tw[0]), float(tw[1]))

## Disguised, its tile is cover like any grass clump; up and running, it is not.
func _sync_bush() -> void:
	var want := -1
	if not dead and ss == "disguised" and m.world.inb(int(floor(pos.x)), int(floor(pos.z))):
		want = m.world.idx(int(floor(pos.x)), int(floor(pos.z)))
	if want == _bush_tile:
		return
	if _bush_tile >= 0 and want < 0 and not dead:
		_expose_hiders()
	if _bush_tile >= 0:
		var left := int(m.world.live_bush.get(_bush_tile, 0)) - 1
		if left <= 0:
			m.world.live_bush.erase(_bush_tile)
		else:
			m.world.live_bush[_bush_tile] = left
	_bush_tile = want
	if want >= 0:
		m.world.live_bush[want] = int(m.world.live_bush.get(want, 0)) + 1

func _show_glint(on: bool) -> void:
	var g := KeyCarry.glint_of(self)
	if g: g.visible = on

# ------------------------------------------------------------------ the brain (the game that owns it)
func sim(dt: float) -> void:
	prev = pos
	_sync_bush()
	if dead:
		return
	tick_status(dt)
	if ss == "disguised" and m.time >= next_tell:
		_twitch = 1.0
		tells += 1
		next_tell = m.time + _tell_gap()
	if remote:
		net_follow(dt)
		return
	st = "idle"
	var sr: Dictionary = KeyRun.rules()["shrubling"]
	ss_t -= dt
	var wish := Vector2.ZERO
	var held_now := root_t + stun_t + slow_t
	match ss:
		"disguised":
			# nothing but a hit wakes it: a fresh root, slow or stun, a shove or a grab counts as one
			if held_now > _held_last + 0.01 or m.time - kb_time < 0.2 or _dragged():
				_reveal(_nearest_hunter(40.0))
		"alert":
			if ss_t <= 0.0:
				_set_state("flee")
				flee_t = 0.0
		"flee":
			wish = _flee(dt, sr)
		"dive":
			if ss_t <= 0.0:
				_rehide(sr)
	_held_last = held_now
	var spd: float = float(sr["flee_speed"]) * slow_mult(0.55)
	if KitStatus.grounded(self):
		spd *= float(sr["grounded_speed"])
	if root_t > 0.0 or stun_t > 0.0:
		spd = 0.0
	_move(dt, wish * spd, spd)

func _set_state(s: String) -> void:
	ss = s
	_show_glint(s != "disguised")
	_sync_bush()

## A hunter within `r` m (flat) and about level with it, or null.
func _nearest_hunter(r: float) -> Hunter:
	var best: Hunter = null
	var bd := r
	for h in m.hunters:
		if h.out or h.extracted or not h.targetable() or m.demo_shielded(h):
			continue
		var d := flat_dist(h)
		if d < bd and absf(h.pos.y - pos.y) < 2.5:
			bd = d
			best = h
	return best

## True while a grab or pull (Verbs.yank) is carrying it.
func _dragged() -> bool:
	if m.verbs == null:
		return false
	for dg in m.verbs.drags:
		if dg["ent"] == self: return true
	return false

func _reveal(by: Ent) -> void:
	if ss != "disguised":
		return
	_set_state("alert")
	ss_t = float(KeyRun.rules()["shrubling"]["alert_t"])
	threat = by as Hunter if by is Hunter else _nearest_hunter(40.0)
	m.sfx("rustle", pos, -2.0, randf_range(0.95, 1.1))
	m.fx.burst(pos + Vector3(0, 0.4, 0), Color(md["color"]).lightened(0.2), 14, 3.0, 0.5, 6.0)
	hide_at = Vector3.INF
	path = []
	if threat != null:
		var away := -dir_to(threat)
		face = atan2(-away.x, -away.y)

## Anyone hiding in it when it bolts is in the open at once: no more cover, and seen for a moment.
## Each game exposes the hunters it owns, so a hider on another machine is caught too.
func _expose_hiders() -> void:
	var t := int(floor(pos.x))
	var z := int(floor(pos.z))
	for h in m.hunters:
		if h.remote or h.out or h.extracted or absf(h.pos.y - pos.y) > 1.5:
			continue
		if (int(floor(h.pos.x)) == t and int(floor(h.pos.z)) == z) or flat_dist(h) < 0.9:
			h.reveal_t = maxf(h.reveal_t, float(KeyRun.rules()["shrubling"]["expose_s"]))
			if h == m.player and m.hud:
				m.hud.toast_small("Your bush ran off!", Color("f2c84a"))

func hurt(d: float, by: Ent, opts := {}) -> float:
	var dealt := super.hurt(d, by, opts)
	if not dead and (dealt > 0.0 or d > 0.0):
		if dealt > 0.0: m.sfx("squeak", pos, -2.0, randf_range(0.9, 1.2))
		if ss == "disguised" and not remote:
			_reveal(by if by is Hunter else _nearest_hunter(40.0))      # any hit wakes it, a Boki's too
	return dealt

# ------------------------------------------------------------------ running and hiding
func _flee(dt: float, sr: Dictionary) -> Vector2:
	flee_t += dt
	threat = _nearest_hunter(40.0)
	var on_bush: bool = m.world.in_bush(pos.x, pos.z)
	if threat == null:
		# nobody near: the nearest grass will do
		if on_bush and not KitStatus.grounded(self):
			_dive(sr)
			return Vector2.ZERO
	else:
		var d := flat_dist(threat)
		var seen: bool = m.world.los(threat.pos, pos, pos.y + 0.8)
		var relaxed := flee_t > 12.0
		var safe_far := d >= float(sr["hide_clear_r"])
		var safe_unseen := not seen and d >= float(sr["hide_los_r"])
		var safe_relaxed := relaxed and d >= float(sr["relax_r"])
		if on_bush and not KitStatus.grounded(self) and (safe_far or safe_unseen or safe_relaxed):
			_dive(sr)
			return Vector2.ZERO
	repath -= dt
	# (nobody chasing: it keeps its plan rather than dithering between two patches each repath)
	if hide_at == Vector3.INF or (repath <= 0.0 and (threat != null or path.size() <= 1)):
		repath = float(sr["repath_s"])
		_pick_hide()
	var dir := _follow_path()
	if dir == Vector2.ZERO and threat != null:
		dir = -dir_to(threat)
	var seen_now: bool = threat != null and m.world.los(threat.pos, pos, pos.y + 0.8)
	var amp := float(sr["weave_amp_seen"]) if seen_now else float(sr["weave_amp"])
	dir = dir.rotated(sin(m.time * TAU * float(sr["weave_hz"]) + weave_ph) * amp)
	if dir.length() > 0.1:
		var step := pos + Vector3(dir.x, 0, dir.y) * 0.9
		if m.world.is_block(step.x, step.z) or m.world.is_void(step.x, step.z):
			dir = _free_dir(dir)
	return dir.normalized()

## A free direction near `dir` (blocked ahead): tries either side, wider and wider.
func _free_dir(dir: Vector2) -> Vector2:
	for a in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var d2 := dir.rotated(a)
		var q := pos + Vector3(d2.x, 0, d2.y) * 0.9
		if not m.world.is_block(q.x, q.z) and not m.world.is_void(q.x, q.z):
			return d2
	return dir

## Picks the grass patch to run to: far from the hunter, away from them, out of their sight, not
## far to run. Only the best few get the A*.
func _pick_hide() -> void:
	var run: KeyRun = m.keys
	hide_at = Vector3.INF
	path = []
	if run == null:
		return
	var from := Vector2(pos.x, pos.z)
	var tp := Vector2(threat.pos.x, threat.pos.z) if threat != null else from + Vector2(1, 0)
	var scored: Array = []
	for pt in run.patches:
		var c: Vector2 = pt["c"]
		var dme := c.distance_to(from)
		if dme > 34.0 or dme < 1.5 or int(pt["island"]) < 0:
			continue
		# the patch tile farthest from the hunter
		var bt := Vector2i.ZERO
		var bd := -1.0
		for t in pt["tiles"]:
			var dd := Vector2(t.x + 0.5, t.y + 0.5).distance_to(tp)
			if dd > bd:
				bd = dd
				bt = t
		var tile := Vector3(bt.x + 0.5, m.world.ground_at(bt.x + 0.5, bt.y + 0.5), bt.y + 0.5)
		var away := (c - from).normalized().dot((from - tp).normalized())
		var hidden_from_threat: bool = threat != null and not m.world.los(threat.pos, tile, tile.y + 0.8)
		var s := bd - dme * 0.45
		if hidden_from_threat:
			s += 6.0
		if away < -0.2:
			s -= 14.0
		scored.append([s, tile])
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for i in mini(3, scored.size()):
		var tile: Vector3 = scored[i][1]
		var p := KinPath.find(m.world, pos, tile, 12, true)
		if not p.is_empty():
			hide_at = tile
			path = p
			return

func _follow_path() -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var from := Vector2(pos.x, pos.z)
	while path.size() > 1 and from.distance_to(path[0]) < 0.7:
		path.pop_front()
	var pick: Vector2 = path[0]
	for i in range(mini(path.size() - 1, 3), 0, -1):
		if KinPath.clear_line(m.world, from, path[i], r, true):
			pick = path[i]
			break
	var d := pick - from
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO

func _dive(sr: Dictionary) -> void:
	_set_state("dive")
	ss_t = float(sr["dive_t"])
	vel.x = 0.0
	vel.z = 0.0
	m.sfx("rustle", pos, -6.0, randf_range(0.75, 0.9))
	m.fx.burst(pos + Vector3(0, 0.3, 0), Color(md["color"]).lightened(0.1), 10, 2.5, 0.4, 5.0)

func _rehide(_sr: Dictionary) -> void:
	camp = pos
	hide_at = Vector3.INF
	path = []
	_set_state("disguised")
	next_tell = m.time + _tell_gap()
	ShrublingModel.recolour(model, leaf_colour(m, pos))      # (it may have run onto another island)

## The same move step as every Mob: ease the velocity toward the wish, never walk off the edge.
func _move(dt: float, wish: Vector2, spd: float) -> void:
	if (root_t > 0.0 or stun_t > 0.0) and m.time - kb_time > 0.3:
		# pinned: a root or stun stops it dead (a shove still carries it)
		vel.x = 0.0
		vel.z = 0.0
	var hv := Vector2(vel.x, vel.z)
	var k := 10.0 if hv.length() <= spd * 1.3 + 0.5 else 2.5
	hv += (wish - hv) * (1.0 - exp(-k * dt))
	var ahead := Vector2(pos.x, pos.z) + hv.normalized() * (r + 0.3)
	if grounded and hv.length() > 0.1 and m.world.is_void(ahead.x, ahead.y):
		hv = Vector2.ZERO
	vel.x = hv.x
	vel.z = hv.y
	slide(dt)
	body_vertical(dt)
	if hv.length() > 0.3:
		face = lerp_angle(face, atan2(-hv.x, -hv.y), minf(1.0, dt * 12.0))

# ------------------------------------------------------------------ looks
func render(delta: float, alpha: float) -> void:
	super.render(delta, alpha)
	if dead or model == null:
		return
	_clock += delta
	var want := 0.0 if ss in ["disguised", "dive"] else 1.0
	_pose = move_toward(_pose, want, delta * (7.0 if ss != "dive" else 3.0))
	_twitch = maxf(0.0, _twitch - delta * 2.0)      # (a tell lasts about half a second)
	if ss == "alert":
		_twitch = 0.8
	ShrublingModel.pose(model, _pose, _clock, Vector2(vel.x, vel.z).length(), _twitch)
	if ss == "disguised":
		_show_glint(false)
	elif _pose > 0.3:
		_show_glint(true)
