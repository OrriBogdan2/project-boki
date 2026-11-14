class_name SkyDeck
## Life aboard a skyship, each tick: the props spin, the shadow keeps to the ground under it, the
## engines drone where the ship is (and the wind blows while you ride), and your squad stands on
## the deck facing the bow with their Boki wisps hovering beside them. Other squads riding the same
## ship are not drawn (a deck for three, not for the lobby). The look itself is SkyshipModel.

const PROP_SPIN := 14.0        # rad/s: the props' turn
const SHADOW_LIFT := 0.25      # m over the ground, so the blob doesn't flicker into it
const ENGINE_SFX := "ab_whirr"
const ENGINE_DB := -8.0        # dB at the ship: under the music, over the wind
const ENGINE_PITCH := 0.45     # a slow low drone, not an ability's whirr
const ENGINE_REACH := 140.0    # m: heard from an island under its line, fading as it sails off
const WIND_SFX := "glider_wind"
const WIND_DB := -15.0         # dB: the rush of air while you ride
const WIND_PITCH := 0.6
const SLOT_GAP := 1.35         # m between riders across the deck
const SLOT_Z := -1.2           # m ahead of the middle: the squad stands before the mast-to-cabin gap
const ROW_GAP := 1.6           # m back for a fourth rider and on
const WISP_AT := Vector3(0.55, 1.15, 0.5)    # m from a rider's feet (to their right, a little behind)

## One ship's tick (match._update_one_ship, after the node is placed along its line).
static func tick(m: Match, s: Dictionary, dt: float) -> void:
	var n: Node3D = s.get("node")
	if n == null or not is_instance_valid(n):
		return
	for pn in ["PropL", "PropR"]:
		(n.get_node(pn) as Node3D).rotation.z += dt * PROP_SPIN
	_shadow(m, n)
	var key := "ship_engine%d" % n.get_instance_id()
	if not Sfx.loop_on(key) and Sfx.ensure(ENGINE_SFX):
		Sfx.loop_start(key, ENGINE_SFX, n.position, ENGINE_DB, ENGINE_REACH)
	Sfx.loop_hold(key, ENGINE_SFX, n.position, ENGINE_DB, ENGINE_PITCH)
	if m.player and m.player.riding and is_same(m.ship_of(m.player), s) and Sfx.ensure(WIND_SFX):
		Sfx.loop_hold("ship_wind", WIND_SFX, null, WIND_DB, WIND_PITCH)
	for h in m.hunters:
		if h.riding and h.rocket == null and not h.remote and is_same(m.ship_of(h), s):
			hold(h)     # (the planning doesn't run the hunters' sim: the squad must stand on deck for it too)
	_wisps(m, s, n)

## A rider's place this tick: on the deck at their slot, still, facing the bow (hunter.sim, riding).
static func hold(h: Hunter) -> void:
	var m: Match = h.m
	var s: Dictionary = m.ship_of(h)
	var n: Node3D = s.get("node")
	if n == null or not is_instance_valid(n):
		h.pos = m.ship_pos_of(s) + Vector3(0, -1.2, 0)
	else:
		var at: Vector2 = slot(m, h)
		h.pos = n.transform * Vector3(at.x, SkyshipModel.DECK_Y, at.y)
		h.face = n.rotation.y
	h.prev = h.pos
	h.vel = Vector3.ZERO
	h.grounded = true

## Whether a hunter is drawn as far as the ship goes: anyone not riding, anyone on a squad rocket, and
## your own squad on deck.
static func drawn(h: Hunter) -> bool:
	return not h.riding or h.rocket != null or shown(h)

## Whether a rider is drawn on the deck: your own squad only.
static func shown(h: Hunter) -> bool:
	return h.m.player != null and h.team == h.m.player.team

## A rider's spot on the deck (x across, y along the keel, ship space): squad order, three abreast.
static func slot(m: Match, h: Hunter) -> Vector2:
	var i := 0
	var s: Dictionary = m.ship_of(h)
	for o in m.hunters:
		if o == h:
			break
		if o.team == h.team and o.riding and o.rocket == null and is_same(m.ship_of(o), s):
			i += 1
	var row := int(i / 3.0)
	var col := i % 3
	return Vector2((col - 1) * SLOT_GAP, SLOT_Z + row * ROW_GAP + (0.3 if col != 1 else 0.0))

## A rider's spot in the world now (the intro aims its camera and name plates at it).
static func world_at(m: Match, h: Hunter) -> Vector3:
	var n: Node3D = m.ship_of(h).get("node")
	if n == null or not is_instance_valid(n):
		return h.pos
	var at: Vector2 = slot(m, h)
	return n.transform * Vector3(at.x, SkyshipModel.DECK_Y, at.y)

static func _shadow(m: Match, n: Node3D) -> void:
	var sh := n.get_node_or_null("Shadow") as Node3D
	if sh == null:
		return
	var p := n.position
	sh.visible = not m.world.is_void(p.x, p.z)
	if sh.visible:
		sh.global_position = Vector3(p.x, m.world.ground_at(p.x, p.z) + SHADOW_LIFT, p.z)
		sh.rotation = Vector3(0, n.rotation.y, 0)

## The squad's Boki wisps on deck beside their hunters (made as they board, gone as they jump).
static func _wisps(m: Match, s: Dictionary, n: Node3D) -> void:
	var have: Dictionary = s.get("wisps", {})
	s["wisps"] = have
	for h in m.hunters:
		var aboard: bool = h.riding and h.rocket == null and shown(h) and h.kin is Kin and is_same(m.ship_of(h), s)
		var w: Node3D = have.get(h.nid)
		if aboard and w == null:
			var k := h.kin as Kin
			w = BokiWispLook.build(k.species, k.rec)
			n.add_child(w)
			have[h.nid] = w
		elif not aboard and w != null:
			w.queue_free()
			have.erase(h.nid)
			continue
		if w != null:
			var at: Vector2 = slot(m, h)
			w.position = Vector3(at.x, SkyshipModel.DECK_Y, at.y) + WISP_AT
			BokiWispLook.pose(w, Time.get_ticks_msec() / 1000.0)
