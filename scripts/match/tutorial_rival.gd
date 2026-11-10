class_name TutorialRival
extends RefCounted
## The tutorial's rival Hunter and the two wisps it teaches (briefs/boki-art/TUTORIAL_COMBAT_V2.md, beats 7 and 8).
## The rival (a bot) glides onto your island at part health with its own Boki wisp, enemy-coloured, and fights
## back at tutorial damage. When it is knocked it pops into the round Hunter Wisp (HunterWisp), its Boki wisp breaks
## loose, and time slows for a moment. Then the two are taught side by side: the Hunter can't be taken, the Boki
## can, with a short hold. A grabbed wisp joins your orbit with a ring and a tether. Local to the tutorial: no
## Net, and the loose wisp never times out. Tutorial owns one; numbers are content/rules/tutorial.json "rival".

enum Phase { IDLE, FIGHT, LOOSE, CARRIED, GONE }

const BOB_HZ := 2.4           # 1/s: how fast the Boki wisp bobs
const ORBIT_RATE := 1.8       # rad/s: the Boki wisp circling its Hunter, or you
const BREAK_S := 0.5          # s the Boki wisp takes to fly loose from the knocked Hunter
const SNUFF_S := 1.0          # s the rival's wisp spends snuffing before it is removed

var t: Tutorial
var m: Match
var cfg: Dictionary = Content.rules("tutorial")["rival"]
var phase := Phase.IDLE
var h: Hunter = null
var wisp: Node3D = null       # the rival's Boki wisp: a small critter glow
var loose_at := Vector3.ZERO  # where the Boki wisp floats once loose
var fight_t := 0.0
var hold := 0.0               # s the player has held interact on the loose wisp
var carried_t := 0.0
var told := false             # the "that's the Hunter" toast has shown
var _break_t := 0.0
var _from := Vector3.ZERO
var _labels: Array[Label3D] = []
var _tether: MeshInstance3D = null

func _init(tut: Tutorial) -> void:
	t = tut
	m = tut.m

## True once the rival has been knocked (beat 7 is done); grabbed() once the Boki wisp is yours (beat 8).
func knocked() -> bool:
	return phase >= Phase.LOOSE

func grabbed() -> bool:
	return phase >= Phase.CARRIED

## Where the Hunter Wisp is, and where the loose Boki wisp floats (INF before the knock).
func hunter_at() -> Vector3:
	return h.pos if h else Vector3.INF

func boki_at() -> Vector3:
	return loose_at if phase == Phase.LOOSE else Vector3.INF

## The rival glides in above the range island, a little way off.
func start() -> void:
	var at := t.spot(float(cfg["dist_m"]), randf() * TAU)
	if at == Vector3.INF:
		return
	var diff: Dictionary = (Data.BOT_DIFF["medium"] as Dictionary).duplicate()
	diff["dmg"] = float(cfg["dmg"])
	h = m.make_hunter(m.next_id("tr"), 1, "medium", String(cfg["name"]), "bot", {}, at, m.bot_kit(), {})
	h.ai = m.bot_brain.new_mind(m.rng, float(diff["skill"]), diff)
	h.ai["land"] = at
	h.tonics = 0
	h.hp = h.max_hp * float(cfg["hp"])
	m._start_drop(h, at)
	wisp = _make_wisp(SideColor.of(m, h))
	phase = Phase.FIGHT

func tick(dt: float) -> void:
	match phase:
		Phase.FIGHT: _fight(dt)
		Phase.LOOSE: _loose(dt)
		Phase.CARRIED: _carried(dt)
		Phase.GONE: pass

func _fight(dt: float) -> void:
	fight_t += dt
	_ride()
	if fight_t >= float(cfg["late_s"]) and h.hp > h.max_hp * float(cfg["late_hp"]):
		h.hp = h.max_hp * float(cfg["late_hp"])      # a long fight: nearly spent, and it stops dodging
		h.ai["skill"] = 0.15
	if h.downed:
		_break_loose()

## The Boki wisp circles its Hunter.
func _ride() -> void:
	var a := m.time * ORBIT_RATE
	wisp.position = h.pos + Vector3(cos(a) * 1.1, 1.5 + 0.15 * sin(m.time * BOB_HZ), sin(a) * 1.1)

func _break_loose() -> void:
	phase = Phase.LOOSE
	_from = wisp.position
	loose_at = _loose_spot()
	m._slow(float(cfg["slow_s"]), float(cfg["slow_k"]))
	m.shake(float(cfg["shake"]), h.pos)
	m.fx.burst(wisp.position, SideColor.of(m, h), 18, 4.0, 0.5)
	m.sfx("unlock", h.pos, -6.0, 1.3)
	_labels.append(_label(String(cfg["hunter_label"]), SideColor.of(m, h)))
	_labels.append(_label(String(cfg["boki_label"]), Color("ffe08a")))

## Open ground the loose wisp's distance from the Hunter Wisp, on the side away from you: the stomp
## reach (Life) must not cover both, so a hold on the critter is never a hold on the Hunter.
func _loose_spot() -> Vector3:
	var away := Vector2(h.pos.x - m.player.pos.x, h.pos.z - m.player.pos.z).normalized()
	var base := atan2(away.y, away.x)
	var w := m.world
	for i in 12:
		var a := base + ((i + 1) >> 1) * 0.6 * (1 if i % 2 == 0 else -1)
		var x: float = h.pos.x + cos(a) * float(cfg["apart_m"])
		var z: float = h.pos.z + sin(a) * float(cfg["apart_m"])
		var same_island: bool = w.island_of(x, z) == w.island_of(h.pos.x, h.pos.z)
		if same_island and not w.is_block(x, z) and w.edge_dist(int(x), int(z), 1) >= 1:
			return Vector3(x, w.ground_at(x, z) + 1.0, z)
	return h.pos + Vector3(float(cfg["apart_m"]), 1.0, 0.0)

func _loose(dt: float) -> void:
	h.down_hp = 1e6      # (the Hunter Wisp waits: it neither bleeds out nor can be stomped out)
	_break_t = minf(_break_t + dt, BREAK_S)
	var k := _break_t / BREAK_S
	var arc := Vector3(0, 1.6 * 4.0 * k * (1.0 - k), 0)
	var bob := Vector3(0, 0.12 * sin(m.time * BOB_HZ), 0)
	wisp.position = _from.lerp(loose_at, k) + arc + bob
	_labels[0].position = h.pos + Vector3(0, 2.2, 0)
	_labels[1].position = wisp.position + Vector3(0, 0.9, 0)
	var p := m.player
	if not told and not p.downed and p.flat_dist(h) < float(cfg["warn_m"]):
		told = true
		m.hud.toast(String(cfg["hunter_toast"]), Color("ffe08a"))
	var reach := Vector2(p.pos.x - loose_at.x, p.pos.z - loose_at.z).length()
	var near: bool = not p.downed and reach < float(cfg["grab_m"])
	hold = hold + dt if near and p.inp.get("interact", false) else maxf(0.0, hold - dt * 2.0)
	wisp.scale = Vector3.ONE * (1.0 + 0.6 * hold / float(cfg["hold_s"]))
	if hold >= float(cfg["hold_s"]):
		_grab()

func _grab() -> void:
	phase = Phase.CARRIED
	for lb in _labels:
		lb.queue_free()
	_labels.clear()
	wisp.scale = Vector3.ONE
	var mine := SideColor.of(m, m.player)
	var halo := MeshInstance3D.new()
	halo.mesh = Models.flat_quad(1.1)
	halo.material_override = Models.ring_mat(mine, 0.1)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wisp.add_child(halo)
	_tether = _make_tether(mine)
	m.fx.ring(wisp.position, 2.0, mine, 0.4)
	m.fx.burst(wisp.position, mine, 16, 3.5, 0.5)
	m.sfx("revive", null, -6.0)
	m.hud.toast(String(cfg["grab_toast"]), mine)
	if m.player.kin:
		m.kin_bark(m.player.kin, String(cfg["grab_bubble"]), "happy", 2.0)

## Orbits you with its ring and tether; the downed rival is gone a few seconds after the grab.
func _carried(dt: float) -> void:
	carried_t += dt
	var p := m.player
	var a := m.time * ORBIT_RATE
	wisp.position = p.pos + Vector3(cos(a) * 1.3, 1.6 + 0.12 * sin(m.time * BOB_HZ), sin(a) * 1.3)
	var from := p.pos + Vector3(0, 1.1, 0)
	_tether.position = from.lerp(wisp.position, 0.5)
	_tether.scale = Vector3(1, 1, maxf(0.01, from.distance_to(wisp.position)))
	_tether.look_at(wisp.position)
	if h and carried_t >= float(cfg["gone_s"]):
		h.out = true       # (HunterWisp snuffs it)
	if h and carried_t >= float(cfg["gone_s"]) + SNUFF_S:
		_remove_rival()

func _remove_rival() -> void:
	m.hunters.erase(h)
	m.ents_by_id.erase(h.nid)
	h.queue_free()
	h = null
	phase = Phase.GONE

## The Boki wisp: a small critter glow (a ball with two ears) in the Hunter's colour, quick and bouncy.
func _make_wisp(col: Color) -> Node3D:
	var n := Node3D.new()
	var mat := Models.glow_mat(col)
	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.44
	Models.part(n, body, mat)
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.07
	ear.height = 0.24
	for side in [-1.0, 1.0]:
		Models.part(n, ear, mat, Vector3(0.13 * side, 0.27, 0), Vector3.ONE, Vector3(0, 0, -0.35 * side))
	m.add_child(n)
	return n

func _make_tether(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.04, 0.04, 1.0)
	mi.mesh = bx
	mi.material_override = Models.glow_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	return mi

func _label(txt: String, col: Color) -> Label3D:
	var lb := Label3D.new()
	lb.text = TutorialText.fill(txt, m.player)
	lb.font_size = 72
	lb.pixel_size = 0.01
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = col
	lb.no_depth_test = true
	m.add_child(lb)
	return lb
