class_name Heart
extends RefCounted
## The Heart's two seats out of the match (docs/decisions/0051-limited-ways-out.md; 0023 for the look and the tide).
## Limited Ways Out: four seats, one squad each, each used once. The Heart owns two of them:
##   - the early seat: from wake_s one Heartspark charges for charge_s in plain sight. Anyone takes it (hold
##     interact), carries it revealed and carrier_slow slower (dropped when downed or out) to the Heart Gate,
##     holds there gate_hold_s, and every member of that squad within gate_take_r of the Gate leaves: MINOR.
##   - the final seat: at final_s (or at once, rush_k faster, when one squad is left) the Heart ring opens.
##     A squad holding it alone fills it (faster with more of them, Exits.crew_rate); a standing rival stalls
##     it; an empty ring drains. Full: that squad's members in the ring leave, MAJOR, the islands fall soon.
##   The Blight's tide closes on the Heart all match (tide_r; read by BlightDir.level / _spawn_tick).
## One explicit state (briefs/STATE_MACHINES.md): S, with the legal edges in NEXT; only go() moves it (a
## refused edge is counted, never applied), and only the host does. _force() is the mirror for clients and demos.
## An early seat nobody used by final_s stays open in FINAL (early_team < 0): the spark can still be taken out.
## Numbers: content/rules/heart.json. Online the host owns the state and tells everyone with the "ht" event:
##   ["ht","s",state,carrier_nid,charge,early_team,final_team,final_prog,rush,x,y,z]  host -> all (change, SYNC_S)
##   ["ht","take",seat,team]  host -> all: a seat fired; each game takes its own Hunters of that squad
##   ["ht","pick",nid] / ["ht","done",nid] / ["ht","drop",nid,x,y,z]  a game -> host (its own hunter)

enum S {ASLEEP, CHARGING, READY, CARRIED, WAITING, FINAL, DONE}
const NEXT := {
	S.ASLEEP: [S.CHARGING, S.FINAL],
	S.CHARGING: [S.READY, S.FINAL],
	S.READY: [S.CARRIED, S.FINAL],
	S.CARRIED: [S.READY, S.WAITING, S.FINAL],
	S.WAITING: [S.FINAL],
	S.FINAL: [S.DONE],
	S.DONE: [],
}
const HOW_EARLY := "heart_early"    # the `how` of a Hunter who left by the Heart Gate
const HOW_FINAL := "heart_final"    # ...and by the Heart ring
const RULES_PATH := "res://content/rules/heart.json"
const COL := Color("ff5d78")        # the Heart's soft pink-red light
const GLASS := Color("b8203f")      # smooth crimson glass: no crack, no gold
const GATE_COL := Color("ff9aa8")
const SYNC_S := 3.0
const BEAM_H := 46.0
const NEAR_LABEL := 7.0
const TIDE_STAGES := 11          # the source's death circle has stages 0-10; our one close is split into as many
const RING_DY := 3.0                # metres above or below the Heart that still count as in the ring

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

static func r(k: String) -> float:
	return float(rules()[k])

## A Heart in this match? Real matches only; tests with an endless clock opt in with opts["heart"].
static func enabled(opts: Dictionary) -> bool:
	for k in ["training", "tutorial", "duel", "arena"]:
		if opts.get(k, false):
			return false
	return bool(opts.get("heart", float(opts.get("length", 360.0)) < 1.0e8)) and not opts.get("no_heart", false)

# ------------------------------------------------------------------ the tide (read by BlightDir)
## The tide ring's radius in metres at this match time (0 before it starts: no ring).
static func tide_r(m: Match) -> float:
	if m.heart == null or m.sess_time() < r("tide_start_s"):
		return 0.0
	return ring_at(m.sess_time(), m.heart.ways_scale)

## The tide ring's radius t seconds into a match on a map of ways_scale k (the radius it starts at
## before the tide moves).
static func ring_at(t: float, k: float) -> float:
	var f := clampf((t - r("tide_start_s")) / r("tide_close_s"), 0.0, 1.0)
	return lerpf(r("tide_r0"), r("tide_r1"), f) * k

## 0 inside the ring, 1 forty metres past it.
static func tide_out(m: Match, p: Vector3) -> float:
	var tr := tide_r(m)
	if tr <= 0.0:
		return 0.0
	return clampf((Vector2(p.x - m.heart.site.x, p.z - m.heart.site.z).length() - tr) / 40.0, 0.0, 1.0)

## The ring's radius `tide_next_s` seconds on: where the tide closes to next (the first ring before the
## tide starts, so the drop map shows it; tide_r1 once the ring holds). `ahead` 2: two such steps on (bots).
static func next_r(m: Match, ahead := 1) -> float:
	if m.heart == null:
		return 0.0
	return ring_at(m.sess_time() + r("tide_next_s") * ahead, m.heart.ways_scale)

## Added to the Blight's strength out in the tide.
static func tide_boost(m: Match, p: Vector3) -> float:
	return r("tide_boost") * tide_out(m, p) if m.heart else 0.0

## Extra Skitter spawn heat per second for a squad out in the tide.
static func tide_heat(m: Match, p: Vector3) -> float:
	return r("tide_heat") * tide_out(m, p) if m.heart else 0.0

## The source's death-circle stage now: the close split into TIDE_STAGES equal stages, the last one
## holding once the ring is closed (-1 before the tide starts).
static func tide_stage(m: Match) -> int:
	var t := (m.sess_time() - r("tide_start_s")) / r("tide_close_s")
	if m.heart == null or t < 0.0:
		return -1
	return mini(int(t * TIDE_STAGES), TIDE_STAGES - 1)

## Flat damage a tide tick deals at this stage, in our Hunter health (tide_dmg keys, linear between).
static func tide_dmg(stage: int) -> float:
	var keys: Array = rules()["tide_dmg"]
	var v := float(keys[-1][1])
	for i in range(1, keys.size()):
		if stage <= int(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			v = lerpf(float(a[1]), float(b[1]), float(stage - int(a[0])) / float(int(b[0]) - int(a[0])))
			break
	return v * float(Data.CLASSES["medium"]["hp"]) / r("tide_src_hp")

# ------------------------------------------------------------------ state
var m: Match
var site := Vector3.INF
var gate := Vector3.INF
var ways_scale := 1.0          # the map's "ways_scale": tide radii and gate_dist stretch with it (1.412 on the 2x map)
var state := S.ASLEEP
var trail: Array[String] = []    # "time from>to why", every move of the state (the checks read it)
var refused := 0               # edges NEXT turned down: always 0 in a sane run
var charge := 0.0              # seconds the Heartspark has charged
var carrier: Hunter = null
var spark_pos := Vector3.ZERO  # where a lying Heartspark floats (the Heart, or where a carrier fell)
var early_team := -1           # the squad that took the early seat
var final_team := -1           # the squad whose progress the Heart ring holds
var final_prog := 0.0          # 0..1
var rush := false              # one squad left: the final seat is open and faster
var drops := 0
var audio: HeartSfx            # the hum, stings, heartbeat, gate cues and the Ways Out calls
var _hold := {}                # nid -> seconds of interact held on the spark / the gate
var _sync_t := 0.0
var _tide_t := 0.0             # seconds since the last tide tick
var hit_t := -99.0             # match time the tide last hurt the local player (the HUD's red pulse)
var wall: BlightWall
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _spark: Node3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _halo: MeshInstance3D

func _init(match_node: Match) -> void:
	m = match_node
	audio = HeartSfx.new(self)

func host() -> bool:
	return not m.net_on or m.is_host

## Puts the Heart on the map's authored "heart" site (else one of the biggest islands, by the match seed),
## the Gate gate_dist from it at a seeded angle clear of the uplink outposts, and builds the nodes.
func setup(layout: Dictionary) -> void:
	var w := m.world
	if w.islands.is_empty():
		return
	_rng.seed = int(m.seed_val) * 17 + 4242
	ways_scale = float(layout.get("ways_scale", 1.0))
	var c: Vector2
	if layout.has("heart"):
		c = Vector2(float(layout["heart"][0]) + 0.5, float(layout["heart"][1]) + 0.5)
	else:
		var isl: Array = range(w.islands.size())
		isl.sort_custom(func(a, b): return float(w.islands[a]["r"]) > float(w.islands[b]["r"]))
		c = w.islands[isl[_rng.randi() % mini(3, isl.size())]]["c"]
	site = w.free_spot_near(Vector3(c.x, 0.0, c.y), [], 1.0, 0.9, 10.0)
	spark_pos = site
	gate = _pick_gate(w)
	_build()

## The first of 16 angles from a seeded start whose spot is on the Heart's island and gate_clear from
## every uplink outpost; failing that, the first one on that island, then the first spot found.
func _pick_gate(w: World) -> Vector3:
	var ii := w.island_of(site.x, site.z)
	var clear := float(rules()["map"]["gate_clear"]) * ways_scale
	var outposts := w.exit_defs.filter(func(ed): return ed["kind"] == "outpost")
	var near := Vector3.INF
	var any := Vector3.INF
	var a0 := _rng.randf() * TAU
	for k in 16:
		var a := a0 + TAU * k / 16.0
		var want := site + Vector3(cos(a), 0.0, sin(a)) * r("gate_dist") * ways_scale
		var p := w.free_spot_near(want, [site], 8.0, 0.9, 3.0)
		if any == Vector3.INF:
			any = p
		if Vector2(p.x - want.x, p.z - want.z).length() >= 3.5 or w.island_of(p.x, p.z) != ii:
			continue
		if outposts.all(func(ed): return Vector2(p.x - ed["pos"].x, p.z - ed["pos"].z).length() >= clear):
			return p
		if near == Vector3.INF:
			near = p
	return near if near != Vector3.INF else any

# ------------------------------------------------------------------ the state
func go(to: S, why: String) -> bool:
	if not (to in NEXT[state]):
		refused += 1
		trail.append("%7.2f refused %s>%s %s" % [m.time, S.keys()[state], S.keys()[to], why])
		return false
	_force(to, why)
	return true

## Sets the state without the table: a client mirroring the host, or a demo. Everything else uses go().
func _force(to: S, why: String) -> void:
	trail.append("%7.2f %s>%s %s" % [m.time, S.keys()[state], S.keys()[to], why])
	state = to
	match to:
		S.CHARGING:
			m.add_feed("The Heart wakes: its one Heartspark is charging")
		S.READY:
			if carrier == null and spark_pos == site and why == "charged":
				m.add_feed("The Heartspark is charged")
				m.sfx("portal", site, 2.0, 0.7)
				m.fx.ring(site + Vector3(0, 0.3, 0), 6.0, COL, 0.8)
		S.FINAL:
			m.add_feed("The Heart opens: hold its ring to leave")
			m.sfx("portal", site, 3.0, 0.5)
			m.fx.ring(site + Vector3(0, 0.3, 0), r("final_r"), COL, 1.0)
	_broadcast()

## Is the early seat's Heartspark charged, unused and out there (lying or carried)?
func spark_live() -> bool:
	return early_team < 0 and charge >= r("charge_s") and state in [S.READY, S.CARRIED, S.FINAL]

# ------------------------------------------------------------------ tick
func tick(dt: float) -> void:
	if site == Vector3.INF:
		return
	if host():
		_host_tick(dt)
		_sync_t -= dt
		if _sync_t <= 0.0:
			_sync_t = SYNC_S
			_broadcast()
	elif state == S.CHARGING:
		charge = minf(charge + dt, r("charge_s"))
	_tide_tick(dt)
	_apply_carrier()
	_update_nodes()
	audio.update()

func _host_tick(dt: float) -> void:
	var t := m.sess_time()
	if state == S.ASLEEP and t >= r("wake_s"):
		go(S.CHARGING, "wake")
	if state == S.CHARGING:
		charge += dt
		if charge >= r("charge_s"):
			charge = r("charge_s")
			spark_pos = site
			go(S.READY, "charged")
	if carrier != null and (carrier.downed or carrier.out or carrier.extracted):
		_drop(carrier.pos)
	if t >= r("final_s") and state < S.FINAL:
		go(S.FINAL, "time")
	if state == S.FINAL:
		_ring_tick(dt)

## Only one squad is left (Match._check_last): the final seat opens for them at once, faster.
func on_last_team() -> void:
	if site == Vector3.INF or not host() or state == S.DONE:
		return
	rush = true
	if state != S.FINAL:
		go(S.FINAL, "last squad")

## Each game hits the Hunters it plays that stand outside the ring, once a tide tick. Environment
## damage ("heat"): armor doesn't take it and it doesn't drain a glider.
func _tide_tick(dt: float) -> void:
	var st := tide_stage(m)
	if st < 0:
		return
	_tide_t += dt
	if _tide_t < r("tide_tick_s"):
		return
	_tide_t -= r("tide_tick_s")
	var tr := tide_r(m)
	var d := tide_dmg(st)
	for h in m.hunters:
		if h.remote or h.downed or h.out or h.extracted:
			continue
		if Vector2(h.pos.x - site.x, h.pos.z - site.z).length() > tr:
			h.hurt(d, null, {"src": "heat", "tags": ["tide"]})
			if h == m.player:
				hit_t = m.time
				Sfx.play("thump", null, -8.0, 0.0, 0.7)

## The slow and the reveal on whoever holds it (each game sets it on the Hunters it plays).
func _apply_carrier() -> void:
	for h in m.hunters:
		var on: bool = h == carrier
		h.set_meta("heart_slow", r("carrier_slow") if on else 0.0)
		if on and bool(rules()["carrier_reveal"]):
			h.reveal_t = maxf(h.reveal_t, 0.3)

func carrier_pos() -> Vector3:
	return carrier.pos if carrier else spark_pos

func _broadcast() -> void:
	if m.net_on and m.is_host:
		var cn: String = carrier.nid if carrier else ""
		m.net_event(["ht", "s", state, cn, charge, early_team, final_team, final_prog, 1 if rush else 0,
			spark_pos.x, spark_pos.y, spark_pos.z])

# ------------------------------------------------------------------ the final seat: the Heart ring
func in_ring(h: Hunter) -> bool:
	return not h.out and not h.extracted and h.flat_dist(site) <= r("final_r") and absf(h.pos.y - site.y) < RING_DY

## Standing Hunters in the ring, by squad.
func _ring_crews() -> Dictionary:
	var crews := {}
	for h in m.hunters:
		if not h.downed and in_ring(h):
			crews[h.team] = int(crews.get(h.team, 0)) + 1
	return crews

func _ring_tick(dt: float) -> void:
	var crews := _ring_crews()
	if final_team < 0 and crews.size() == 1:
		final_team = int(crews.keys()[0])
		audio.call_out("start", "final", final_team)
	if final_team < 0:
		return
	var own := int(crews.get(final_team, 0))
	if own == 0:
		final_prog = maxf(0.0, final_prog - dt / r("final_drain_s"))
		if final_prog <= 0.0:
			final_team = -1
		return
	if crews.size() > 1:
		return
	var k := r("rush_k") if rush else 1.0
	final_prog += dt * Exits.crew_rate(own) * k / r("final_hold_s")
	if final_prog >= 1.0:
		final_prog = 1.0
		_take(HOW_FINAL, final_team)

# ------------------------------------------------------------------ a seat fires
## The host: the seat is used; every game then takes its own Hunters of that squad.
func _take(seat: String, team: int) -> void:
	if seat == HOW_EARLY:
		early_team = team
		carrier = null
		if state == S.FINAL:
			_broadcast()
		else:
			go(S.WAITING, "gate")
	else:
		go(S.DONE, "ring")
		m.length = minf(m.length, m.time + r("end_after_final_s"))
	if m.net_on and m.is_host:
		m.net_event(["ht", "take", seat, team])
	_leave(seat, team)

## This game's own Hunters of the squad at the seat leave (downed ones too): the Gate takes those within
## gate_take_r of it, the ring those inside it.
func _leave(seat: String, team: int) -> void:
	audio.call_out("taken", "early" if seat == HOW_EARLY else "final", team)
	if seat == HOW_EARLY:
		early_team = team
		carrier = null
	for h in m.hunters:
		if h.team != team or h.remote or h.out or h.extracted:
			continue
		var here: bool = in_ring(h) if seat == HOW_FINAL else h.flat_dist(gate) <= r("gate_take_r")
		if here:
			m._extract(h, seat, "Heart Gate" if seat == HOW_EARLY else "the Heart")

# ------------------------------------------------------------------ taking the spark, dropping it
func _pick(h: Hunter) -> void:
	if not spark_live() or carrier != null or h == null or h.downed or h.out or h.extracted:
		return
	carrier = h
	if state == S.READY:
		go(S.CARRIED, "pick")
	else:
		_broadcast()
	m.add_feed("%s took the Heartspark" % h.pname)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), COL, 24, 4.0, 0.7, -3.0)

func _drop(at: Vector3) -> void:
	if carrier == null:
		return
	var who := carrier.pname
	spark_pos = m.world.free_spot_near(at, [], 1.0, 0.45, 8.0)
	carrier = null
	drops += 1
	if state == S.CARRIED:
		go(S.READY, "drop")
	else:
		_broadcast()
	m.add_feed("%s dropped the Heartspark" % who)

## The carrier finished the hold at the Gate (the host's side).
func _gate_done(h: Hunter) -> void:
	if h != null and h == carrier and spark_live():
		_take(HOW_EARLY, h.team)

## A Hunter this game plays leaves by another seat while carrying: the spark stays behind.
func on_leave(h: Hunter, how: String) -> void:
	if how == "" or how == HOW_EARLY or how == HOW_FINAL or carrier != h:
		return
	if host():
		_drop(h.pos)
	else:
		m.net_event(["ht", "drop", h.nid, h.pos.x, h.pos.y, h.pos.z])

# ------------------------------------------------------------------ interact
## What holding interact near the Heart or the Gate does for this Hunter (Match._update_interact).
func interact_for(h: Hunter) -> Dictionary:
	if site == Vector3.INF:
		return {}
	var key := Settings.key_cap("interact")
	if not bool(h.inp.get("interact", false)):
		_hold.erase(h.nid)
	var at_spark := h.flat_dist(spark_pos) <= r("pickup_r") and absf(h.pos.y - spark_pos.y) < 3.0
	if spark_live() and carrier == null and at_spark:
		var need := r("pickup_hold_s")
		var slow := int(r("carrier_slow") * 100.0)
		return {"kind": "heart", "act": "pick", "need": need, "col": COL, "prog": float(_hold.get(h.nid, 0.0)) / need,
			"label": "Hold %s to take the Heartspark  ·  %d%% slower and everyone sees you" % [key, slow]}
	if spark_live() and carrier != null and h.flat_dist(gate) <= r("gate_r") + 1.0:
		if h == carrier:
			var gneed := r("gate_hold_s")
			return {"kind": "heart", "act": "leave", "need": gneed, "col": GATE_COL,
				"prog": float(_hold.get(h.nid, 0.0)) / gneed,
				"label": "Hold %s: leave now, small reward" % key}
		return {"kind": "heart", "col": GATE_COL, "label": "The Heart Gate only opens for the Heartspark's bearer"}
	if h.flat_dist(site) > NEAR_LABEL:
		return {}
	var say := ""
	match state:
		S.ASLEEP:
			say = "The Heart is asleep  ·  it wakes in %ds" % int(ceil(r("wake_s") - m.sess_time()))
		S.CHARGING:
			say = "The Heartspark is charging  ·  %d%%  ·  everyone can see it" % int(charge / r("charge_s") * 100.0)
		S.WAITING:
			say = "The Heart opens in %ds" % int(ceil(r("final_s") - m.sess_time()))
		S.FINAL:
			say = "Hold the Heart ring to leave  ·  %d%%" % int(final_prog * 100.0)
	return {} if say == "" else {"kind": "heart", "col": COL, "label": say}

func hold(h: Hunter, it: Dictionary, dt: float) -> void:
	if not it.has("act"):
		return
	if m.time - h.hurt_at < 0.1:
		_hold[h.nid] = 0.0
		return
	_hold[h.nid] = float(_hold.get(h.nid, 0.0)) + dt
	if float(_hold[h.nid]) < float(it["need"]):
		return
	_hold.erase(h.nid)
	act(String(it["act"]), h)

func act(what: String, h: Hunter) -> void:
	match what:
		"pick":
			if host():
				_pick(h)
			else:
				m.net_event(["ht", "pick", h.nid])
		"leave":
			if host():
				_gate_done(h)
			else:
				m.net_event(["ht", "done", h.nid])

# ------------------------------------------------------------------ the reward
## The bundle for a Hunter who just left by a Heart seat (how = HOW_EARLY: minor, HOW_FINAL: major): evolution
## foods, gems and bond/trust now, and the rare egg and materials in the returned dict (Game.apply_result
## settles them at home).
func pay(h: Hunter, how: String) -> Dictionary:
	var rw: Dictionary = rules()["reward"]["major" if how == HOW_FINAL else "minor"]
	var out := {"egg": {}, "goods": (rw["goods"] as Dictionary).duplicate(),
		"seeds": (rw["seeds"] as Dictionary).duplicate(), "gems": int(rw["gems"]), "trust": float(rw["trust"])}
	if bool(rw["egg"]):
		var sp := _egg_species()
		out["egg"] = {"sp": sp, "boss": String(Data.KIN.get(sp, {}).get("boss", ""))}
	for s in out["seeds"]:
		h.seeds[s] = int(h.seeds.get(s, 0)) + int(out["seeds"][s])
	h.gems += int(out["gems"])
	for k in [h.kin, h.kin2]:
		if k != null and is_instance_valid(k):
			(k as Kin).note("heart", "left through the Heart with you", float(out["trust"]))
	m.add_feed("%s left through the Heart" % h.pname)
	return out

func _egg_species() -> String:
	var pool: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	pool.sort()
	if pool.is_empty():
		return String(Data.common_kin()[0])
	return pool[_rng.randi() % pool.size()]

## Applies the bundle's home half to the save (Game.apply_result, on an extract).
static func settle(res: Dictionary, out: Dictionary) -> void:
	var hb: Dictionary = res.get("heart", {})
	if hb.is_empty():
		return
	var egg: Dictionary = hb.get("egg", {})
	if not egg.is_empty():
		Incubator.add(String(egg.get("sp", "")), String(egg.get("boss", "")))
	for g in hb.get("goods", {}):
		for i in int(hb["goods"][g]):
			Goods.give("good:" + String(g))
	out["heart"] = hb

# ------------------------------------------------------------------ online
func net_in(x: Array) -> void:
	if x.size() < 2:
		return
	match String(x[1]):
		"s":
			if not host() and x.size() >= 12:
				_mirror(x)
		"take":
			if not host() and x.size() >= 4:
				if String(x[2]) == HOW_FINAL and state != S.DONE:
					_force(S.DONE, "host")
				_leave(String(x[2]), int(x[3]))
		"pick":
			if host() and x.size() >= 3:
				_pick(m.ents_by_id.get(String(x[2]), null) as Hunter)
		"done":
			if host() and x.size() >= 3:
				_gate_done(m.ents_by_id.get(String(x[2]), null) as Hunter)
		"drop":
			if host() and x.size() >= 6 and carrier != null and carrier.nid == String(x[2]):
				_drop(Vector3(float(x[3]), float(x[4]), float(x[5])))

func _mirror(x: Array) -> void:
	carrier = m.ents_by_id.get(String(x[3]), null) as Hunter if String(x[3]) != "" else null
	charge = float(x[4])
	early_team = int(x[5])
	final_team = int(x[6])
	final_prog = float(x[7])
	rush = int(x[8]) == 1
	spark_pos = Vector3(float(x[9]), float(x[10]), float(x[11]))
	if int(x[2]) != state:
		_force(int(x[2]) as S, "host")

# ------------------------------------------------------------------ the look
func _build() -> void:
	_root = Node3D.new()
	_root.name = "Heart"
	m.add_child(_root)
	wall = BlightWall.new(_root)
	# the Heart: smooth crimson glass on a pale stone plinth, a soft pink-red halo
	var h := Node3D.new()
	h.position = site
	_root.add_child(h)
	Models.part(h, Models.cyl(1.5, 1.7, 0.3, 14), Models.toon(Color("cfc6c8")), Vector3(0, 0.15, 0))
	Models.part(h, Models.cyl(1.1, 1.25, 0.2, 14), Models.toon(Color("e6dde0")), Vector3(0, 0.4, 0))
	var glass := Models.toon(GLASS, false, 0.45)
	Models.part(h, Models.sphere(0.8, 20), glass, Vector3(0, 1.6, 0), Vector3(0.95, 1.25, 0.95))
	Models.part(h, Models.sphere(0.5, 14), Models.toon(Color("e04a68"), false, 0.8), Vector3(0, 1.8, 0.0))
	_halo = Models.part(h, Models.sphere(1.5, 16), Models.glow_mat(Color(COL, 0.1)), Vector3(0, 1.6, 0))
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(7.0)
	ring.material_override = Models.ring_mat(COL, 0.04)
	ring.position = Vector3(0, 0.35, 0)
	h.add_child(ring)
	# the Heartspark: a small bright mote that grows as it charges
	_spark = Node3D.new()
	_root.add_child(_spark)
	Models.part(_spark, Models.sphere(0.32, 12), Models.toon(Color("ffd0d8"), false, 1.0))
	var sh := Models.part(_spark, Models.sphere(0.62, 12), Models.glow_mat(Color(COL, 0.35)))
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the world beam
	_beam_mat = Models.glow_mat(Color(COL, 0.2))
	_beam = MeshInstance3D.new()
	_beam.mesh = Models.cyl(0.25, 0.6, BEAM_H, 12)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_beam)
	# the Heart Gate: two pale pillars (its light and the Heart ring are WaysOutVfx seats)
	var gate_node := Node3D.new()
	gate_node.position = gate
	_root.add_child(gate_node)
	var stone := Models.toon(Color("cfc6c8"))
	for sgn in [-1.0, 1.0]:
		Models.part(gate_node, Models.cyl(0.32, 0.4, 3.2, 10), stone, Vector3(sgn * r("gate_r") * 0.8, 1.6, 0))
		var knob := Vector3(sgn * r("gate_r") * 0.8, 3.4, 0)
		Models.part(gate_node, Models.sphere(0.34, 10), Models.toon(GLASS, false, 0.5), knob)

func _update_nodes() -> void:
	if _root == null:
		return
	wall.update(site, tide_r(m), m.player.pos if m.player else site)
	var f := clampf(charge / r("charge_s"), 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var lying := spark_live() and carrier == null
	_spark.visible = state == S.CHARGING or spark_live()
	if carrier:
		_spark.position = carrier.pos + Vector3(0, 2.7 + sin(t * 4.0) * 0.1, 0)
		_spark.scale = Vector3.ONE * 0.9
	else:
		var sf := 1.0 if lying else clampf(0.15 + f * 0.85, 0.15, 1.0)
		_spark.position = (spark_pos if lying else site) + Vector3(0, 2.7 + sin(t * 2.0) * 0.12, 0)
		_spark.scale = Vector3.ONE * sf * (1.0 + (pulse * 0.12 if lying else 0.0))
	_beam.visible = _spark.visible or state == S.FINAL
	var bp := carrier_pos() if spark_live() else site
	_beam.position = bp + Vector3(0, BEAM_H * 0.5, 0)
	var a := 0.3 + 0.1 * pulse
	if state == S.CHARGING:
		a = 0.07 + 0.2 * f
	_beam_mat.set_shader_parameter("color", Color(COL, a))
	var hs := 1.0 if lying or state == S.FINAL else 0.0
	if state == S.CHARGING:
		hs = f
	_halo.scale = Vector3.ONE * (0.8 + 0.4 * hs)

func stop() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()

# ------------------------------------------------------------------ the demo
## --heart-demo=ready|carry|gate|charging|final
func demo(mode: String) -> void:
	var p := m.player
	if p == null or site == Vector3.INF:
		return
	if m.has_meta("heart_demo"):
		var pin: Vector3 = m.get_meta("heart_demo")
		p.teleport(pin)
		p.vel = Vector3.ZERO     # hold the moment: a screenshot takes a varying time to render
		p.hp = p.max_hp
		return
	for h in m.hunters:
		if h != p:
			h.ctrl = "idle"
			h.inp["move"] = Vector2.ZERO
			h.teleport(m.world.random_ground())
	m.time = maxf(m.time, r("wake_s"))       # the tide is part-way in
	var near := m.world.free_spot_near(site + Vector3(5.0, 0, 1.5), [site], 1.0, 0.45, 6.0)
	charge = r("charge_s")
	spark_pos = site
	match mode:
		"carry", "gate":
			carrier = p
			_force(S.CARRIED, "demo")
			var off := Vector3(-6.0, 0, 0) if mode == "carry" else Vector3(0.6, 0, 1.0)
			near = m.world.free_spot_near(gate + off, [], 1.0, 0.45, 6.0)
		"final":
			early_team = p.team + 1
			final_team = p.team
			final_prog = 0.4
			_force(S.FINAL, "demo")
			near = m.world.free_spot_near(site + Vector3(2.0, 0, 1.0), [site], 1.0, 0.45, 4.0)
		"charging":
			charge = r("charge_s") * r("demo_charge") * 0.6
			_force(S.CHARGING, "demo")
		_:
			_force(S.READY, "demo")
	p.teleport(near)
	p.vel = Vector3.ZERO
	m.set_meta("heart_demo", near)
