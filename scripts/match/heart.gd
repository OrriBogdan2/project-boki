class_name Heart
extends RefCounted
## The Heart loop (docs/decisions/0023-heartspark.md): every match is a fight over the Heart.
##   1. The Blight's tide closes toward the Heart site (tide_r): outside the ring it is stronger and
##      comes for squads sooner (BlightDir.level / _spawn_tick read tide_boost / tide_heat).
##   2. A Heartspark charges at the Heart for charge_s, with a map marker and a world beam for everyone.
##   3. Charged, anyone can take it (hold interact). The carrier shows on every map and in the world,
##      is carrier_slow slower, and drops it when downed or out (or when leaving by a normal exit).
##   4. The Heart Gate (gate_dist from the Heart) takes only the carrier: hold interact there to leave
##      with it. That pays the reward bundle (rare egg, evolution materials, bond/trust).
##   5. After a delivery the Heart cools for cool_s, then charges a new Heartspark.
##   6. The skiff / hatch / uplink exits are untouched.
## State: charging -> ready -> carried -> cooling -> charging. Numbers: content/rules/heart.json.
## Online the host owns the state and tells everyone with the "ht" event:
##   ["ht","s",state,carrier_nid,charge,cool,x,y,z]  host -> all (a change, and every SYNC_S)
##   ["ht","pick",nid] / ["ht","done",nid] / ["ht","drop",nid,x,y,z]  a game -> host (its own hunter)

const RULES_PATH := "res://content/rules/heart.json"
const COL := Color("ff5d78")        # the Heart's soft pink-red light
const GLASS := Color("b8203f")      # smooth crimson glass: no crack, no gold
const GATE_COL := Color("ff9aa8")
const SYNC_S := 3.0
const BEAM_H := 46.0
const NEAR_LABEL := 7.0
const TIDE_STAGES := 11          # the source's death circle has stages 0-10; our one close is split into as many

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
	if m.heart == null:
		return 0.0
	var t := (m.sess_time() - r("tide_start_s")) / r("tide_close_s")
	if t < 0.0:
		return 0.0
	return lerpf(r("tide_r0"), r("tide_r1"), clampf(t, 0.0, 1.0))

## 0 inside the ring, 1 forty metres past it.
static func tide_out(m: Match, p: Vector3) -> float:
	var tr := tide_r(m)
	if tr <= 0.0:
		return 0.0
	return clampf((Vector2(p.x - m.heart.site.x, p.z - m.heart.site.z).length() - tr) / 40.0, 0.0, 1.0)

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
var state := "charging"        # charging | ready | carried | cooling
var charge := 0.0              # seconds the current Heartspark has charged
var cool := 0.0                # seconds of cooldown left
var carrier: Hunter = null
var spark_pos := Vector3.ZERO  # where a ready Heartspark floats (the Heart, or where a carrier fell)
var deliveries := 0
var drops := 0
var events: Array = []         # every state change, for the check
var _hold := {}                # nid -> seconds of interact held on the spark / the gate
var _sync_t := 0.0
var _tide_t := 0.0             # seconds since the last tide tick
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _spark: Node3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _halo: MeshInstance3D
var _gate_node: Node3D
var _gate_mat: ShaderMaterial
var _gate_beam: MeshInstance3D

func _init(match_node: Match) -> void:
	m = match_node

func host() -> bool:
	return not m.net_on or m.is_host

## Picks the Heart site (one of the biggest islands, by the match seed), puts the gate near it and
## builds the nodes.
func setup() -> void:
	var w := m.world
	if w.islands.is_empty():
		return
	_rng.seed = int(m.seed_val) * 17 + 4242
	var isl: Array = []
	for i in w.islands.size():
		isl.append(i)
	isl.sort_custom(func(a, b): return float(w.islands[a]["r"]) > float(w.islands[b]["r"]))
	var ii: int = isl[_rng.randi() % mini(3, isl.size())]
	var c: Vector2 = w.islands[ii]["c"]
	site = w.free_spot_near(Vector3(c.x, 0.0, c.y), [], 1.0, 0.9, 10.0)
	spark_pos = site
	var best := Vector3.INF
	var a0 := _rng.randf() * TAU
	for k in 16:
		var a := a0 + TAU * k / 16.0
		var want := site + Vector3(cos(a), 0.0, sin(a)) * r("gate_dist")
		var p := w.free_spot_near(want, [site], 8.0, 0.9, 3.0)
		if Vector2(p.x - want.x, p.z - want.z).length() < 3.5 and w.island_of(p.x, p.z) == ii:
			best = p
			break
		if best == Vector3.INF:
			best = p
	gate = best
	_build()

# ------------------------------------------------------------------ tick
func tick(dt: float) -> void:
	if site == Vector3.INF:
		return
	if host():
		match state:
			"charging":
				charge += dt
				if charge >= r("charge_s"):
					spark_pos = site
					_enter("ready")
			"cooling":
				cool -= dt
				if cool <= 0.0:
					charge = 0.0
					_enter("charging")
			"carried":
				if carrier == null or carrier.downed or carrier.out or carrier.extracted:
					_drop(carrier.pos if carrier else spark_pos)
		_sync_t -= dt
		if _sync_t <= 0.0:
			_sync_t = SYNC_S
			_broadcast()
	else:
		if state == "charging":
			charge = minf(charge + dt, r("charge_s"))
		elif state == "cooling":
			cool = maxf(cool - dt, 0.0)
	_tide_tick(dt)
	_apply_carrier()
	_update_nodes()

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

## The slow and the reveal on whoever holds it (each game sets it on the Hunters it plays).
func _apply_carrier() -> void:
	for h in m.hunters:
		var on: bool = state == "carried" and h == carrier
		h.set_meta("heart_slow", r("carrier_slow") if on else 0.0)
		if on and bool(rules()["carrier_reveal"]):
			h.reveal_t = maxf(h.reveal_t, 0.3)

func carrier_pos() -> Vector3:
	return carrier.pos if state == "carried" and carrier else spark_pos

func _enter(s: String) -> void:
	state = s
	events.append(s)
	if s == "ready" and carrier == null and spark_pos == site:
		m.add_feed("The Heartspark is charged")
		m.sfx("portal", site, 2.0, 0.7)
		m.fx.ring(site + Vector3(0, 0.3, 0), 6.0, COL, 0.8)
	if s == "charging":
		m.add_feed("The Heart wakes: a new Heartspark is charging")
	_broadcast()

func _broadcast() -> void:
	if m.net_on and m.is_host:
		var cn: String = carrier.nid if carrier else ""
		m.net_event(["ht", "s", state, cn, charge, cool, spark_pos.x, spark_pos.y, spark_pos.z])

# ------------------------------------------------------------------ taking it, dropping it, delivering it
func _pick(h: Hunter) -> void:
	if state != "ready" or h == null or h.downed or h.out or h.extracted:
		return
	carrier = h
	_enter("carried")
	m.add_feed("%s took the Heartspark" % h.pname)
	m.sfx("ping", h.pos, 0.0, 0.6)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), COL, 24, 4.0, 0.7, -3.0)

func _drop(at: Vector3) -> void:
	if state != "carried":
		return
	var who := carrier.pname if carrier else "The carrier"
	spark_pos = m.world.free_spot_near(at, [], 1.0, 0.45, 8.0)
	carrier = null
	drops += 1
	_enter("ready")
	m.add_feed("%s dropped the Heartspark" % who)

## The carrier left through the Heart Gate (the host's bookkeeping).
func _delivered(h: Hunter) -> void:
	if state != "carried" or carrier != h:
		return
	carrier = null
	deliveries += 1
	cool = r("cool_s")
	_enter("cooling")

## A Hunter this game plays leaves by a normal exit while carrying: the spark stays behind.
func on_leave(h: Hunter, how: String) -> void:
	if how == "" or how == "heart" or state != "carried" or carrier != h:
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
	match state:
		"ready":
			if h.flat_dist(spark_pos) <= r("pickup_r") and absf(h.pos.y - spark_pos.y) < 3.0:
				var need := r("pickup_hold_s")
				var slow := int(r("carrier_slow") * 100.0)
				var prog := float(_hold.get(h.nid, 0.0)) / need
				return {"kind": "heart", "act": "pick", "need": need, "col": COL, "prog": prog,
					"label": "Hold %s to take the Heartspark  ·  %d%% slower and everyone sees you" % [key, slow]}
		"charging":
			if h.flat_dist(site) <= NEAR_LABEL:
				var pct := int(charge / r("charge_s") * 100.0)
				var say := "The Heartspark is charging  ·  %d%%  ·  everyone can see it" % pct
				return {"kind": "heart", "col": COL, "label": say}
		"carried":
			if h.flat_dist(gate) <= r("gate_r") + 1.0:
				if h == carrier:
					var gneed := r("gate_hold_s")
					var gprog := float(_hold.get(h.nid, 0.0)) / gneed
					return {"kind": "heart", "act": "leave", "need": gneed, "col": GATE_COL, "prog": gprog,
						"label": "Hold %s to leave through the Heart Gate with the Heartspark" % key}
				var shut := "The Heart Gate only opens for the Heartspark's bearer"
				return {"kind": "heart", "col": GATE_COL, "label": shut}
		"cooling":
			if h.flat_dist(site) <= NEAR_LABEL:
				var secs := int(ceil(cool))
				return {"kind": "heart", "col": COL, "label": "The Heart is cooling  ·  a new Heartspark in %ds" % secs}
	return {}

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
			if state != "carried" or carrier != h:
				return
			m._extract(h, "heart", "Heart Gate")
			if host():
				_delivered(h)
			else:
				m.net_event(["ht", "done", h.nid])

# ------------------------------------------------------------------ the reward
## The bundle for a Hunter who just delivered: evolution foods, gems and bond/trust now, and the
## rare egg and materials in the returned dict (Game.apply_result settles them at home).
func pay(h: Hunter) -> Dictionary:
	var rw: Dictionary = rules()["reward"]
	var sp := _egg_species()
	var out := {"egg": {"sp": sp, "boss": String(Data.KIN.get(sp, {}).get("boss", ""))},
		"goods": (rw["goods"] as Dictionary).duplicate(), "seeds": (rw["seeds"] as Dictionary).duplicate(),
		"gems": int(rw["gems"]), "trust": float(rw["trust"])}
	for s in out["seeds"]:
		h.seeds[s] = int(h.seeds.get(s, 0)) + int(out["seeds"][s])
	h.gems += int(out["gems"])
	for k in [h.kin, h.kin2]:
		if k != null and is_instance_valid(k):
			(k as Kin).note("heart", "carried the Heartspark out of the Heart Gate with you", float(out["trust"]))
	m.add_feed("%s brought the Heartspark home" % h.pname)
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
			if host() or x.size() < 9:
				return
			state = String(x[2])
			carrier = m.ents_by_id.get(String(x[3]), null) as Hunter if String(x[3]) != "" else null
			charge = float(x[4])
			cool = float(x[5])
			spark_pos = Vector3(float(x[6]), float(x[7]), float(x[8]))
		"pick":
			if host() and x.size() >= 3:
				_pick(m.ents_by_id.get(String(x[2]), null) as Hunter)
		"done":
			if host() and x.size() >= 3:
				_delivered(m.ents_by_id.get(String(x[2]), null) as Hunter)
		"drop":
			if host() and x.size() >= 6 and carrier != null and carrier.nid == String(x[2]):
				_drop(Vector3(float(x[3]), float(x[4]), float(x[5])))

# ------------------------------------------------------------------ the look
func _build() -> void:
	_root = Node3D.new()
	_root.name = "Heart"
	m.add_child(_root)
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
	# the Heart Gate: two pale pillars and a disc of light, dark until the Heartspark is carried
	_gate_node = Node3D.new()
	_gate_node.position = gate
	_root.add_child(_gate_node)
	var stone := Models.toon(Color("cfc6c8"))
	for sgn in [-1.0, 1.0]:
		Models.part(_gate_node, Models.cyl(0.32, 0.4, 3.2, 10), stone, Vector3(sgn * r("gate_r") * 0.8, 1.6, 0))
		var knob := Vector3(sgn * r("gate_r") * 0.8, 3.4, 0)
		Models.part(_gate_node, Models.sphere(0.34, 10), Models.toon(GLASS, false, 0.5), knob)
	_gate_mat = Models.ring_mat(GATE_COL, 0.08)
	var gr := MeshInstance3D.new()
	gr.mesh = Models.flat_quad(r("gate_r") * 2.2)
	gr.material_override = _gate_mat
	gr.position = Vector3(0, 0.12, 0)
	_gate_node.add_child(gr)
	_gate_beam = MeshInstance3D.new()
	_gate_beam.mesh = Models.cyl(0.2, 0.5, 14.0, 10)
	_gate_beam.material_override = Models.glow_mat(Color(GATE_COL, 0.2))
	_gate_beam.position = Vector3(0, 7.0, 0)
	_gate_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate_node.add_child(_gate_beam)

func _update_nodes() -> void:
	if _root == null:
		return
	var f := clampf(charge / r("charge_s"), 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	_spark.visible = state != "cooling"
	var at := carrier_pos()
	if state == "carried" and carrier:
		_spark.position = at + Vector3(0, 2.7 + sin(t * 4.0) * 0.1, 0)
		_spark.scale = Vector3.ONE * 0.9
	else:
		var sf := 1.0 if state == "ready" else clampf(0.15 + f * 0.85, 0.15, 1.0)
		_spark.position = (site if state == "charging" else at) + Vector3(0, 2.7 + sin(t * 2.0) * 0.12, 0)
		_spark.scale = Vector3.ONE * sf * (1.0 + (pulse * 0.12 if state == "ready" else 0.0))
	var live := state in ["charging", "ready", "carried"]
	_beam.visible = live
	var bp := site if state == "charging" else at
	_beam.position = bp + Vector3(0, BEAM_H * 0.5, 0)
	var a := 0.3 + 0.1 * pulse
	if state == "charging":
		a = 0.07 + 0.2 * f
	_beam_mat.set_shader_parameter("color", Color(COL, a))
	var hs := 0.0
	if state == "charging":
		hs = f
	elif state == "ready":
		hs = 1.0
	_halo.scale = Vector3.ONE * (0.8 + 0.4 * hs)
	var open := state == "carried"
	_gate_mat.set_shader_parameter("color", Color(GATE_COL, 0.9 if open else 0.18))
	_gate_beam.visible = open

func stop() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()

# ------------------------------------------------------------------ the demo (--heart-demo=ready|carry|gate|cool)
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
	m.time = maxf(m.time, 120.0)       # the tide is part-way in
	var near := m.world.free_spot_near(site + Vector3(5.0, 0, 1.5), [site], 1.0, 0.45, 6.0)
	match mode:
		"carry", "gate":
			charge = r("charge_s")
			spark_pos = site
			carrier = p
			state = "carried"
			var off := Vector3(-6.0, 0, 0) if mode == "carry" else Vector3(0.6, 0, 1.0)
			near = m.world.free_spot_near(gate + off, [], 1.0, 0.45, 6.0)
		"cool":
			state = "cooling"
			cool = r("cool_s") * 0.7
			deliveries = 1
		"charging":
			state = "charging"
			charge = r("charge_s") * r("demo_charge") * 0.6
		_:
			charge = r("charge_s") * r("demo_charge")
			state = "ready"
			spark_pos = site
	p.teleport(near)
	p.vel = Vector3.ZERO
	m.set_meta("heart_demo", near)
	_broadcast()
