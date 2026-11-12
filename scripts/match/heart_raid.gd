class_name HeartRaid
extends RefCounted
## Heart Raid (prototype; docs/design/PVE_HEART_RAID.md): the PvE mode on the expedition map. One squad
## (team 0, 1-4 Hunters; bots fill a squad of 4 offline, the host fills one online) and no rival squads.
## The Blight's tide closes on the Heart as in an Expedition; this director sends the waves and the boss:
##   WAVES  every wave_every_s a wave from content/rules/heart_raid.json: its "heart" monsters come out of the
##          ground round the Heart and guard it, its "edge" ones come from the Blight's side of the squad.
##          A wave monster with nothing to fight goes for the nearest standing Hunter (steer_r).
##   BOSS   at boss_s (sooner once the last wave is cleared) one boss rises at the Heart: a Lair boss kit
##          fought in a square round the Heart instead of a walled lair (Boss needs a lair dictionary).
##   HOLD   the boss is down: the Heart opens its final seat (Heart.go FINAL); holding the ring takes the
##          squad out with the raid's reward (Heart.pay reads rules "reward"). That is the win.
## Lost: the squad wiped (the match's own team-wiped end) or the islands fall at match_s.
## Everything scales with the squad's size (rules "scale"). Expeditions never build one (Match.heart_raid null),
## and the Heart is held shut (Heart.locked) so its timers never open it. The host runs the director and
## tells the others with ["hr", phase, wave, boss_nid] (on a change and every SYNC_S).

enum P {WAVES, BOSS, HOLD, WON, LOST}
const MODE := "heart_raid"    # the mode's spawn table name (Data.wild_kin, content/kin "only_in")
const RULES_PATH := "res://content/rules/heart_raid.json"
const THINK_S := 0.5           # s between the director's looks (waves, steering, rally)
const SYNC_S := 3.0            # s between the host's "hr" refreshes
const COL := Color("ff7a5a")   # the raid's HUD accent (the Blight's ember)
const EDGE_IN := 4.0           # m: edge monsters come out at least this far inside the tide ring (never in the tide)

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

static func r(k: String) -> float:
	return float(rules()[k])

static func on(o: Dictionary) -> bool:
	return bool(o.get("heart_raid", false))

## The wild spawn table this match draws from (Data.wild_kin).
static func mode_of(o: Dictionary) -> String:
	return MODE if on(o) else ""

## The match options of a raid for a squad of `squad` (1 = truly solo).
static func opts(squad: int) -> Dictionary:
	return {"heart_raid": true, "teams": 1, "squad": clampi(squad, 1, 4), "length": r("match_s")}

var m: Match
var phase := P.WAVES
var wave := 0                  # waves sent so far
var next_wave_t := 0.0         # session time of the next wave
var cleared_t := -1.0          # session time the last wave was cleared (-1 until then)
var squad_n := 1               # Hunters in the squad (1-4): the scale row
var boss: Mob = null           # the boss (a Boss on the host; a client mirrors a plain Mob)
var lair := {}                 # the boss's fight square round the Heart, in Lairs' lair shape
var foes: Array[Mob] = []      # wave monsters alive
var sent := 0                  # wave monsters spawned
var boss_down := false         # the boss fell (the Heart's final seat is open)
var trail: Array[String] = []  # "time what", every beat of the raid (the smoke check reads it)
var _think := 0.0
var _sync_t := 0.0
var _rng := RandomNumberGenerator.new()

func _init(match_node: Match) -> void:
	m = match_node
	_rng.seed = int(m.seed_val) * 31 + 7
	next_wave_t = r("first_wave_s")
	squad_n = clampi(m.hunters.filter(func(h): return h.team == 0).size(), 1, 4)
	m.heart.locked = true
	_note("start, squad of %d" % squad_n)

func host() -> bool:
	return not m.net_on or m.is_host

func waves_n() -> int:
	return (rules()["waves"] as Array).size()

func scale(k: String) -> float:
	return float(rules()["scale"][k][squad_n - 1])

func _note(what: String) -> void:
	trail.append("%7.2f %s" % [m.sess_time(), what])

# ------------------------------------------------------------------ tick
func tick(dt: float) -> void:
	if phase == P.WON or phase == P.LOST:
		return
	_think -= dt
	if _think > 0.0:
		return
	_think = THINK_S
	if host():
		foes = foes.filter(func(x): return is_instance_valid(x) and not x.dead)
		_direct()
		_steer()
		_rally()
		_sync_t -= THINK_S
		if _sync_t <= 0.0:
			_broadcast()
	_check_end()

func _direct() -> void:
	var t := m.sess_time()
	match phase:
		P.WAVES:
			if wave < waves_n() and t >= next_wave_t:
				_send_wave(rules()["waves"][wave])
				wave += 1
				next_wave_t += r("wave_every_s")
				_broadcast()
			if wave >= waves_n():
				if foes.is_empty() and cleared_t < 0.0:
					cleared_t = t
				if t >= r("boss_s") or (cleared_t >= 0.0 and t >= cleared_t + r("boss_after_clear_s")):
					_spawn_boss()
		P.BOSS:
			if boss == null or not is_instance_valid(boss) or boss.dead:
				_boss_down()

func _check_end() -> void:
	if m.heart.state == Heart.S.DONE:
		phase = P.WON
		_note("won")
	elif not Life.team_alive(m, 0) or m.time >= m.length:
		phase = P.LOST
		_note("lost")

# ------------------------------------------------------------------ waves
## Spawns one wave: each group's list scaled to the squad (rules scale.count), up to the alive cap.
func _send_wave(w: Dictionary) -> void:
	var cap := int(scale("cap"))
	var made := 0
	for side in ["heart", "edge"]:
		var kinds: Array = w.get(side, [])
		var n := int(round(kinds.size() * scale("count")))
		for i in n:
			if foes.size() >= cap:
				break
			var mb := _spawn_foe(String(kinds[i % kinds.size()]), _spot(side), side == "heart")
			if mb:
				made += 1
	m.add_feed("Wave %d of %d" % [wave + 1, waves_n()])
	m.sfx("warn", null, -4.0, 0.8)
	if m.hud and m.player and not m.player.out:
		m.hud.toast("WAVE %d" % (wave + 1), COL)
	_note("wave %d: %d monsters" % [wave + 1, made])

func _spawn_foe(kind: String, at: Vector3, guard: bool) -> Mob:
	if at == Vector3.INF or not Data.MOBS.has(kind):
		return null
	var mb: Mob
	if Data.MOBS[kind].get("blight", false):
		if m.blight == null:
			return null
		mb = m.blight.spawn(kind, at, r("blight_lvl"))
	else:
		mb = m.spawn_mob(kind, at)
		mb.camp = m.heart.site if guard else at
	mb.max_hp *= scale("hp")
	mb.hp = mb.max_hp
	foes.append(mb)
	sent += 1
	return mb

## Where a wave monster comes out: round the Heart, or on the Blight's side of the squad (the line from
## the Heart through the squad's middle, on past them, but inside the tide ring). INF when there is no ground.
func _spot(side: String) -> Vector3:
	var site := m.heart.site
	var p: Vector3
	var a := _rng.randf() * TAU
	if side == "heart":
		var hr: Array = rules()["heart_r"]
		p = site + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(float(hr[0]), float(hr[1]))
	else:
		var c := _squad_mid()
		if c == Vector3.INF:
			return Vector3.INF
		var out := Vector2(c.x - site.x, c.z - site.z)
		var d := out.normalized() if out.length() > 4.0 else Vector2(cos(a), sin(a))
		d = d.rotated(_rng.randf_range(-0.6, 0.6))
		var eb: Array = rules()["edge_back"]
		p = c + Vector3(d.x, 0.0, d.y) * _rng.randf_range(float(eb[0]), float(eb[1]))
		var off := Vector2(p.x - site.x, p.z - site.z)
		var inside := Heart.tide_r(m) - EDGE_IN
		if inside > 0.0 and off.length() > inside:
			off = off.normalized() * inside
			p = Vector3(site.x + off.x, p.y, site.z + off.y)
	var q := m.world.free_spot_near(p, [], 1.0, 0.45, 6.0)
	return Vector3.INF if m.world.is_void(q.x, q.z) else q

## The middle of the squad's standing Hunters (INF if none stand).
func _squad_mid() -> Vector3:
	var s := Vector3.ZERO
	var n := 0
	for h in m.hunters:
		if h.team == 0 and not h.out and not h.extracted and not h.downed:
			s += h.pos
			n += 1
	return s / n if n > 0 else Vector3.INF

## Wave monsters with nobody to fight go for the nearest standing Hunter within steer_r, and keep their
## leash (Mob.camp) on whoever they chase. The Blight hunts by its own senses (Blight).
func _steer() -> void:
	var reach := r("steer_r")
	for mb in foes:
		if mb is Blight:
			continue
		var t := mb.tgt
		if t == null or t.dead or not t.hittable():
			t = _nearest(mb.pos, reach)
			if t == null:
				continue
			mb.tgt = t
			if mb.st == "idle":
				mb.st = "chase"
		mb.camp = t.pos

func _nearest(p: Vector3, reach: float) -> Hunter:
	var best: Hunter = null
	var bd := reach
	for h in m.hunters:
		if h.team != 0 or not h.targetable():
			continue
		var d := Vector2(h.pos.x - p.x, h.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = h
	return best

## Bot Hunters of the squad (and an autoplayed you) drift back to the fight: the Heart during the waves
## and the hold, the boss while it stands. A squad ping (Bot "ping_goal") does it, so a fight still comes first.
func _rally() -> void:
	var at := boss.pos if phase == P.BOSS and boss and not boss.dead else m.heart.site
	var near := Heart.r("final_r") * 0.5 if phase == P.HOLD else r("rally_r")
	for h in m.hunters:
		if h.team != 0 or h.ctrl != "bot" or h.out or h.extracted or h.downed:
			continue
		if h.flat_dist(at) > near:
			h.ai["ping_goal"] = {"pos": at, "until": m.time + THINK_S * 4.0, "by": null}

# ------------------------------------------------------------------ the boss
func _spawn_boss() -> void:
	var bd: Dictionary = rules()["boss"]
	var site := m.heart.site
	var tier_k := float(m.T.get("mob", 1.0))
	lair = {"c": site, "half": float(bd["half"]), "boss": String(bd["kind"]), "adds": [], "state": "awake",
		"name": String(bd["name"]), "heart_raid": true}
	var at := m.world.free_spot_near(site + Vector3(3.0, 0.0, 0.0), [site], 2.5, 1.2, 6.0)
	var b := Boss.new()
	b.init_boss(m, m.next_id("b"), String(bd["kind"]), at, tier_k, lair)
	b.md["name"] = String(bd["name"])
	b.md["enrage"] = float(bd["enrage"])
	b.max_hp = float(bd["hp"]) * tier_k * scale("boss_hp")
	b.hp = b.max_hp
	b.dormant = false
	m.add_child(b)
	m._draw_range(b)
	m.mobs.append(b)
	m.ents_by_id[b.nid] = b
	lair["boss_mob"] = b
	boss = b
	phase = P.BOSS
	m.add_feed("%s rises at the Heart" % bd["name"])
	m.sfx("warn", site, 3.0, 0.5)
	m.fx.ring(site + Vector3(0, 0.3, 0), float(bd["half"]), COL, 1.0)
	if m.hud and m.player and not m.player.out:
		m.hud.toast("%s RISES" % String(bd["name"]).to_upper(), COL)
	_note("boss %s, %d hp" % [bd["kind"], int(b.max_hp)])
	_broadcast()

func _boss_down() -> void:
	phase = P.HOLD
	boss_down = true
	_note("boss down")
	m.heart.go(Heart.S.FINAL, "boss down")
	if m.hud and m.player and not m.player.out:
		m.hud.toast("THE HEART OPENS  ·  HOLD ITS RING", Heart.COL)
	_broadcast()

## The raid boss for the HUD's boss bar while `p` stands in its square (Lairs.boss_for).
func boss_for(p: Hunter) -> Boss:
	if not (boss is Boss) or boss.dead or p == null:
		return null
	var c: Vector3 = lair["c"]
	var hf := float(lair["half"]) + 4.0
	return boss if absf(p.pos.x - c.x) <= hf and absf(p.pos.z - c.z) <= hf else null

## The raid's reward bundle (Heart.pay, the final seat in a raid) and the species of its egg: one of the
## Boki found only in raids.
static func reward() -> Dictionary:
	return rules()["reward"]

func egg_species() -> String:
	var pool: Array = Data.KIN.keys().filter(func(k): return String(Data.KIN[k].get("only_in", "")) == MODE)
	pool.sort()
	return String(pool[_rng.randi() % pool.size()]) if not pool.is_empty() else String(Data.common_kin()[0])

# ------------------------------------------------------------------ the end
## What the results screen shows (Match._finish puts it under r["heart_raid"]).
func summary() -> Dictionary:
	return {"won": m.heart.state == Heart.S.DONE and bool(m.result.get("extracted", false)), "wave": wave,
		"waves": waves_n(), "boss": String(rules()["boss"]["name"]), "boss_down": boss_down,
		"squad": squad_n, "t": m.sess_time()}

static func result_line(rd: Dictionary) -> String:
	var clock := "%d:%02d" % [int(rd["t"]) / 60, int(rd["t"]) % 60]
	if bool(rd["won"]):
		return "Heart Raid won: %s fell and your squad held the Heart (%s)." % [rd["boss"], clock]
	if bool(rd["boss_down"]):
		return "Heart Raid lost: %s fell, but the Heart ring was not held (%s)." % [rd["boss"], clock]
	return "Heart Raid lost on wave %d of %d (%s)." % [int(rd["wave"]), int(rd["waves"]), clock]

# ------------------------------------------------------------------ online
func _broadcast() -> void:
	_sync_t = SYNC_S
	if m.net_on and m.is_host:
		m.net_event(["hr", phase, wave, boss.nid if boss else ""])

func net_in(x: Array) -> void:
	if host() or x.size() < 4:
		return
	phase = int(x[1]) as P
	wave = int(x[2])
	boss_down = phase == P.HOLD or phase == P.WON
	boss = m.ents_by_id.get(String(x[3]), null) as Mob
