class_name HeartRaid
extends RefCounted
## Heart Raid (prototype; docs/design/PVE_HEART_RAID.md): the PvE mode on the expedition map. One squad
## (team 0, 1-4 Hunters; bots fill a squad of 4 offline, the host fills one online) and no rival squads.
## The Blight's tide closes on the Heart as in an Expedition; this director sends the waves and the boss:
##   WAVES  every wave_every_s a wave from content/rules/heart_raid.json, each group out of one fixed gate
##          round the Heart (HeartRaidGates), marked with a countdown warn_s before: inner gates' monsters guard
##          the Heart, outer gates' come for the squad. Nothing random in where or when (principle 1).
##          A wave monster with nothing to fight goes for the nearest standing Hunter (steer_r).
##   BOSS   at boss_s (sooner once the last wave is cleared) one boss rises at the Heart: a Lair boss kit
##          fought in a square round the Heart instead of a walled lair (Boss needs a lair dictionary).
##   HOLD   the boss is down: the Heart opens its final seat (Heart.go FINAL); holding the ring takes the
##          squad out with the raid's reward (Heart.pay reads rules "reward"). That is the win.
## Lost: the squad wiped (the match's own team-wiped end) or the islands fall at match_s.
## Everything scales with the squad's size (rules "scale") and the difficulty picked (rules "difficulty":
## Normal, Hard, Nightmare; Nightmare's boss has one more attack), and the raid's Boki (wild spots, the reward
## egg) are the raid's own lines of boki_modes.json open at that difficulty (HeartRaid.boki).
## Expeditions never build one (Match.heart_raid null),
## and the Heart is held shut (Heart.locked) so its timers never open it. The host runs the director and
## tells the others with ["hr", phase, wave, boss_nid] (on a change and every SYNC_S).

enum P {WAVES, BOSS, HOLD, WON, LOST}
const MODE := "heart_raid"    # the mode's name in content/rules/boki_modes.json (BokiModes)
const RULES_PATH := "res://content/rules/heart_raid.json"
const THINK_S := 0.5           # s between the director's looks (waves, steering, rally)
const SYNC_S := 3.0            # s between the host's "hr" refreshes
const COL := Color("ff7a5a")   # the raid's HUD accent (the Blight's ember)
const SPREAD := 1.4            # m: a group's monsters stand this far apart round their gate
static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

static func r(k: String) -> float:
	return float(rules()[k])

static func on(o: Dictionary) -> bool:
	return bool(o.get("heart_raid", false))

## The match options of a raid for a squad of `squad` (1 = truly solo) at a difficulty (rules "difficulty").
static func opts(squad: int, difficulty := "normal") -> Dictionary:
	var d := difficulty if rules()["difficulty"].has(difficulty) else "normal"
	return {"heart_raid": true, "teams": 1, "squad": clampi(squad, 1, 4), "length": r("match_s"), "raid_diff": d}

## --heart-raid=N or N:hard (with --match).
static func from_arg(s: String) -> Dictionary:
	var parts := s.split(":")
	return opts(int(parts[0]), parts[1] if parts.size() > 1 else "normal")

## The difficulty ladder, easiest first (boki_modes.json modes.heart_raid.difficulties).
static func difficulties() -> Array:
	return BokiModes.rules()["modes"][MODE]["difficulties"]

static func diff_name(difficulty: String) -> String:
	return String(rules()["difficulty"][difficulty]["name"])

## The raid's Boki at a difficulty: its lines of boki_modes.json open there, as their game species, or (while a
## line has no kin yet) its stand-in (rules "stand_ins"). Draw from it with BokiModes.draw (rarity tickets).
static func boki(difficulty: String) -> Array:
	var ladder := difficulties()
	var lines: Dictionary = BokiModes.rules()["lines"]
	var out := BokiModes.pool(MODE, ["common", "rare", "very_rare"], difficulty)
	for line in rules()["stand_ins"]:
		if not line.begins_with("_") and ladder.find(lines[line]["min_difficulty"]) <= ladder.find(difficulty):
			out.append(String(rules()["stand_ins"][line]))
	return out

## The pool a wild or rare-spot Boki of this match draws from: the raid's own Boki in a raid.
static func site_pool(o: Dictionary, site: String) -> Array:
	return boki(String(o.get("raid_diff", "normal"))) if on(o) else BokiModes.site_pool("expedition", site)

var m: Match
var phase := P.WAVES
var wave := 0                  # waves sent so far
var next_wave_t := 0.0         # session time of the next wave
var cleared_t := -1.0          # session time the last wave was cleared (-1 until then)
var squad_n := 1               # Hunters in the squad (1-4): the scale row
var difficulty := "normal"     # rules "difficulty" key
var gates: HeartRaidGates      # where and when each wave comes out, and its marks
var boss_nid := ""             # a client: the host's boss id, until its Mob arrives
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
	difficulty = String(m.opts.get("raid_diff", "normal"))
	gates = HeartRaidGates.new(self)
	m.heart.locked = true
	_note("start, squad of %d, %s" % [squad_n, difficulty])

func host() -> bool:
	return not m.net_on or m.is_host

func waves_n() -> int:
	return (rules()["waves"] as Array).size()

## A squad-size scale (rules "scale") times the difficulty's (rules "difficulty") where it has one.
func scale(k: String) -> float:
	return float(rules()["scale"][k][squad_n - 1]) * float(diff().get("count" if k == "cap" else k, 1.0))

func diff() -> Dictionary:
	return rules()["difficulty"][difficulty]

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
	if phase == P.WAVES and m.sess_time() >= next_wave_t - r("warn_s"):
		gates.mark(wave, next_wave_t)
	gates.show_marks()
	if host():
		foes = foes.filter(func(x): return is_instance_valid(x) and not x.dead)
		_direct()
		_steer()
		_rally()
		_sync_t -= THINK_S
		if _sync_t <= 0.0:
			_broadcast()
	elif boss == null and boss_nid != "":
		boss = m.ents_by_id.get(boss_nid, null) as Mob      # its snapshot lands after the "hr" that names it
	_check_end()

func _direct() -> void:
	var t := m.sess_time()
	match phase:
		P.WAVES:
			if wave < waves_n() and t >= next_wave_t:
				_send_wave()
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
## Sends the marked wave out of its gates: each group's list scaled to the squad and difficulty, up to the cap.
func _send_wave() -> void:
	gates.mark(wave, next_wave_t)
	var cap := int(scale("cap"))
	var made := 0
	for mk in gates.marks:
		var kinds: Array = mk["mobs"]
		var n := int(round(kinds.size() * scale("count")))
		for i in n:
			if foes.size() >= cap:
				break
			var a := TAU * i / n
			var at: Vector3 = mk["at"] + Vector3(cos(a), 0.0, sin(a)) * (SPREAD if n > 1 else 0.0)
			if _spawn_foe(String(kinds[i % kinds.size()]), at, bool(mk["guard"])):
				made += 1
	m.add_feed("Wave %d of %d" % [wave + 1, waves_n()])
	m.sfx("warn", null, -4.0, 0.8)
	if m.hud and m.player and not m.player.out:
		m.hud.toast("WAVE %d" % (wave + 1), COL)
	_note("wave %d: %d monsters" % [wave + 1, made])

func _spawn_foe(kind: String, at: Vector3, guard: bool) -> Mob:
	if at == Vector3.INF or m.world.is_void(at.x, at.z) or not Data.MOBS.has(kind):
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
	if mb.md.has("dmg"):
		mb.md = mb.md.duplicate()
		mb.md["dmg"] = float(mb.md["dmg"]) * float(diff()["dmg"])
	foes.append(mb)
	sent += 1
	return mb

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
		"name": String(bd["name"]), "heart_raid": true, "extra": String(diff().get("boss_extra", ""))}
	var at := m.world.free_spot_near(site + Vector3(3.0, 0.0, 0.0), [site], 2.5, 1.2, 6.0)
	var b := Boss.new()
	b.init_boss(m, m.next_id("b"), String(bd["kind"]), at, tier_k, lair)
	b.md["name"] = String(bd["name"])
	b.md["enrage"] = float(bd["enrage"])
	b.max_hp = float(bd["hp"]) * tier_k * scale("boss_hp")
	b.dmg_mult *= float(diff()["dmg"])
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

## The raid boss for the HUD's boss bar while `p` stands in its square (Lairs.boss_for). A client's boss is a
## plain Mob (hp and max_hp ride the snapshot), so the square comes from the rules, not from the host's lair.
func boss_for(p: Hunter) -> Mob:
	if boss == null or not is_instance_valid(boss) or boss.dead or p == null:
		return null
	var c: Vector3 = m.heart.site
	var hf := float(rules()["boss"]["half"]) + 4.0
	return boss if absf(p.pos.x - c.x) <= hf and absf(p.pos.z - c.z) <= hf else null

## The raid's reward bundle (Heart.pay, the final seat in a raid) and the species of its egg: one of the
## raid's Boki open at this difficulty, by rarity tickets.
static func reward() -> Dictionary:
	return rules()["reward"]

func egg_species() -> String:
	var sp := BokiModes.draw(boki(difficulty), _rng)
	return sp if sp != "" else String(Data.common_kin()[0])

# ------------------------------------------------------------------ the end
## What the results screen shows (Match._finish puts it under r["heart_raid"]).
func summary() -> Dictionary:
	return {"won": m.heart.state == Heart.S.DONE, "wave": wave,
		"waves": waves_n(), "boss": String(rules()["boss"]["name"]), "boss_down": boss_down,
		"squad": squad_n, "t": m.sess_time(), "difficulty": difficulty}

static func result_line(rd: Dictionary) -> String:
	var clock := "%d:%02d" % [int(rd["t"]) / 60, int(rd["t"]) % 60]
	var mode := "Heart Raid (%s)" % diff_name(String(rd.get("difficulty", "normal")))
	if bool(rd["won"]):
		return "%s won: %s fell and your squad held the Heart (%s)." % [mode, rd["boss"], clock]
	if bool(rd["boss_down"]):
		return "%s lost: %s fell, but the Heart ring was not held (%s)." % [mode, rd["boss"], clock]
	return "%s lost on wave %d of %d (%s)." % [mode, int(rd["wave"]), int(rd["waves"]), clock]

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
	next_wave_t = r("first_wave_s") + wave * r("wave_every_s")     # the host's wave clock (fixed timers)
	boss_down = phase == P.HOLD or phase == P.WON
	boss_nid = String(x[3])
	boss = m.ents_by_id.get(boss_nid, null) as Mob
