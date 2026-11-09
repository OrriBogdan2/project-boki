class_name BlightDir
extends RefCounted
## Runs the Blight for a match (docs/TONE_AND_THREATS.md §1, §1b): where Wardens stand, when and
## where Skitters claw out of the ground, what they hear, and how strong they are.
##
## Pacing (the owner's rule): you drop at level 1 with one ability and level up fast on monster
## camps, so the Blight starts weak and ramps. Its strength (lvl, 0 weakest .. 1 full) comes from:
##   - how long YOUR squad has been down on the islands (per squad, so late arrivals get a soft start)
##   - the region: the outer islands are safer than the core (an island's "danger" 0/1/2)
##   - the raid condition (RaidLook.BLIGHT: night and storms are worse)
## and how many come depends on that and on noise: gunfire, blasts, opened chests, dashing and
## running add "heat" to your squad, and enough heat brings Skitters out near you, hunting the
## noise. Early on that's a lone Skitter now and then; Wardens' shrieks are only warnings.
## Health and damage: early Blight die fast and hit soft (hp_k, dmg_k); later ones are the real thing.
##
## The host (or the offline game) spawns and runs them; everyone hears them and hides the ones
## out of sight. Their state reaches other players through Match's mob snapshots (Net).

const LVL_MAX := 1.6
const GRACE := 45.0               # seconds after a squad lands before anything comes for it
const RAMP := 420.0               # seconds (per squad) from the soft start to full strength
const HEAT_SPAWN := 1.0
const CAP_BASE := 5               # Blight alive at once (all squads), on top of the Wardens
const CAP_MAX := 18
const LOUD := {"shot": 15.0, "boom": 24.0, "revive": 9.0, "kin": 8.0, "chest": 13.0, "dash": 7.0, "step": 4.5, "shriek": 16.0}
const HEAT := {"shot": 0.04, "boom": 0.15, "revive": 0.05, "kin": 0.02, "chest": 0.12, "dash": 0.03, "step": 0.0, "shriek": 0.25}

var m: Match
var rng := RandomNumberGenerator.new()
var raid_k := 1.0
var host := true
var land_at := {}                 # team -> match time its squad landed
var heat := {}                    # team -> spawn heat
var noises: Array = []            # {pos, loud, t, kind} the last few seconds of noise (for tests and the HUD)
var _src_t := {}                  # noise source -> last time it added heat (rate limit)
var _tick_t := 0.0
var _vis_t := 0.0
var _step_t := 0.0
var _lvl_t := 0.0
var spawned := 0
var shrieks := 0
var wardens: Array = []

static func enabled(opts: Dictionary) -> bool:
	if "--no-blight" in OS.get_cmdline_user_args():
		return false
	for k in ["tutorial", "training", "duel", "arena", "sandbox"]:
		if opts.get(k, false):
			return false
	return bool(opts.get("blight", opts.get("big", true)))

## Health and damage multipliers for a strength level: soft early, the full numbers at 1.
static func hp_k(l: float) -> float:
	return 0.45 + 0.65 * l

static func dmg_k(l: float) -> float:
	return 0.4 + 0.7 * l

func _init(match_node: Match) -> void:
	m = match_node
	raid_k = float(RaidLook.BLIGHT.get(m.raid, 1.0))
	host = not m.net_on or m.is_host
	rng.seed = int(m.seed_val) * 31 + 977

# ------------------------------------------------------------------ strength
## How dangerous a spot is: 0.55 on the outer islands, 1 in between, 1.45 in the core.
func region_k(p: Vector3) -> float:
	var w := m.world
	var ii := w.island_of(p.x, p.z)
	if ii >= 0 and ii < w.islands.size() and (w.islands[ii] as Dictionary).has("danger"):
		return [0.55, 1.0, 1.45][clampi(int(w.islands[ii]["danger"]), 0, 2)]
	# a generated map: by distance from the middle
	var c := Vector2(w.w * 0.5, w.h * 0.5)
	var k := clampf(Vector2(p.x, p.z).distance_to(c) / (minf(w.w, w.h) * 0.5), 0.0, 1.0)
	return lerpf(1.45, 0.55, k)

## Seconds this squad has been down on the islands (0 until its first hunter lands).
func squad_time(team: int) -> float:
	if not land_at.has(team):
		return 0.0
	return maxf(0.0, m.time - float(land_at[team]))

func time_k(t: float) -> float:
	return clampf((t - 20.0) / RAMP, 0.0, 1.0)

## The Blight's strength at a spot, against a squad.
func level(p: Vector3, team: int) -> float:
	var tk := time_k(squad_time(team)) if team >= 0 else time_k(m.time)
	return clampf((0.1 + 0.9 * tk) * region_k(p) * raid_k, 0.0, LVL_MAX)

func level_vs(b: Blight, team: int) -> float:
	return level(b.pos, team)

## A Warden or a Skitter between squads: as strong as the match is old, where it stands.
func level_here(p: Vector3) -> float:
	return clampf((0.1 + 0.9 * time_k(m.time)) * region_k(p) * raid_k, 0.0, LVL_MAX)

func on_landed(h: Hunter) -> void:
	if not land_at.has(h.team):
		land_at[h.team] = m.time

# ------------------------------------------------------------------ setup
## Wardens stand on the islands from the start: one or two on the dangerous ones, few on the
## outer islands. Away from camps, exits, lairs and where people drop.
func setup() -> void:
	if not host:
		return
	var w := m.world
	for ii in w.islands.size():
		var dg := int((w.islands[ii] as Dictionary).get("danger", -1))
		if dg < 0:
			var c: Dictionary = w.islands[ii]
			dg = 2 if region_k(Vector3(float(c.get("cx", 0.0)), 0, float(c.get("cz", 0.0)))) > 1.2 else (1 if region_k(Vector3(float(c.get("cx", 0.0)), 0, float(c.get("cz", 0.0)))) > 0.8 else 0)
		var n := 0
		match dg:
			2: n = 1 + (1 if rng.randf() < 0.5 * raid_k else 0)
			1: n = 1 if rng.randf() < 0.8 else 0
			_: n = 1 if rng.randf() < 0.22 * raid_k else 0
		for _i in n:
			var at := _warden_spot(ii)
			if at != Vector3.INF:
				var b := spawn("bl_warden", at, level_here(at))
				wardens.append(b)

func _warden_spot(ii: int) -> Vector3:
	var w := m.world
	for _t in 24:
		var p := _rand_ground(ii)
		if p == Vector3.INF or w.is_void(p.x, p.z) or w.is_block(p.x, p.z):
			continue
		if not w.roomy(int(p.x), int(p.z), 30):
			continue
		if _near_any(p, w.camp_spots.map(func(c): return c["pos"]), 9.0) or _near_any(p, w.spawns, 8.0):
			continue
		if m.exits and _near_any(p, m.exits.list.map(func(x): return x["pos"]), 9.0):
			continue
		if m.lairs and not m.lairs.lair_of(p, 6.0).is_empty():
			continue
		if _near_any(p, wardens.map(func(b): return b.pos), 14.0):
			continue
		return p
	return Vector3.INF

## A random ground tile on an island, from the Blight's own dice (World.random_ground rolls the
## world's, and the rest of the match shouldn't shift because the Blight is on).
func _rand_ground(ii: int) -> Vector3:
	var w := m.world
	for _t in 500:
		var x := rng.randi_range(0, w.w - 1); var z := rng.randi_range(0, w.h - 1)
		var i := w.idx(x, z)
		if w.kind[i] == World.T_GROUND and w.island[i] == ii:
			return Vector3(x + 0.5, w.level[i] * World.LEVEL, z + 0.5)
	return Vector3.INF

func _near_any(p: Vector3, pts: Array, d: float) -> bool:
	for q in pts:
		if q is Vector3 and Vector2(p.x - q.x, p.z - q.z).length() < d:
			return true
	return false

func spawn(kind: String, at: Vector3, l: float) -> Blight:
	at = m._clear_spot(at)
	var b := Blight.new()
	b.init_blight(m, m.next_id("m"), kind, at, l, self)
	m.add_child(b)
	if m.time > 0.0: m._draw_range(b)
	m.mobs.append(b)
	m.ents_by_id[b.nid] = b
	spawned += 1
	return b

func alive() -> Array:
	return m.mobs.filter(func(x): return x is Blight and not x.dead)

func skitters_alive() -> int:
	var n := 0
	for x in m.mobs:
		if x is Blight and not x.dead and x.mkind == "bl_skitter":
			n += 1
	return n

# ------------------------------------------------------------------ noise
## Something loud happened (Match.note_sound, chests, dashes, running). The Blight in earshot
## come to look, and the squad that made it gets closer to drawing more.
func noise(at: Vector3, kind: String, by = null) -> void:
	var loud: float = float(LOUD.get(kind, 10.0))
	noises.append({"pos": at, "loud": loud, "t": m.time, "kind": kind})
	if noises.size() > 48:
		noises.pop_front()
	if not host:
		return
	var src := ""
	var team := -1
	if by is Kin and (by as Kin).owner_h:
		by = (by as Kin).owner_h
	if by is Hunter:
		team = (by as Hunter).team
		src = (by as Hunter).nid + kind
	if team >= 0 and m.time - float(_src_t.get(src, -9.0)) >= 0.5:
		_src_t[src] = m.time
		if squad_time(team) > GRACE:
			heat[team] = float(heat.get(team, 0.0)) + float(HEAT.get(kind, 0.03)) * (0.6 + 0.6 * level(at, team))
	for b in m.mobs:
		if b is Blight and not b.dead:
			var bb: Blight = b
			var reach := loud * (0.7 if bb.mkind == "bl_warden" else 1.0)
			if bb.flat_dist(at) < reach:
				bb.hear(at, loud)

## A Warden shrieked at someone: every Blight nearby comes, and from mid-strength on new Skitters
## claw out of the ground round it. Early on it's only a warning.
func on_shriek(w: Blight, at_h: Ent) -> void:
	shrieks += 1
	var tp: Vector3 = at_h.pos if at_h else w.pos
	var team: int = at_h.team if at_h is Hunter else -1
	var l := level(w.pos, team)
	var rad := 10.0 + 8.0 * minf(l, 1.0)
	for b in m.mobs:
		if b is Blight and not b.dead and b != w and b.flat_dist(w) < rad:
			(b as Blight).hear(tp, rad)
	if not host or l < 0.35:
		return
	var n := 1 + int(round(minf(l, 1.4) * 1.5)) + (1 if m.raid == "night" and l > 0.6 else 0)
	n = mini(n, cap() - skitters_alive())
	for i in n:
		var a := TAU * float(i) / maxf(1.0, float(n)) + rng.randf() * 0.6
		var p := w.pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.6, 3.0)
		if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
			p = w.pos
		var s := spawn("bl_skitter", Vector3(p.x, m.world.ground_at(p.x, p.z), p.z), l)
		s.hear(tp, rad)
		m.fx.dust(s.pos, 10)

# ------------------------------------------------------------------ tick
func cap() -> int:
	return clampi(CAP_BASE + int(round(10.0 * level_here(Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)) / LVL_MAX * raid_k)), CAP_BASE, CAP_MAX)

func tick(dt: float) -> void:
	_vis_t -= dt
	if _vis_t <= 0.0:
		_vis_t = 0.1
		_update_seen()
		_cues()
	if not host:
		return
	_step_t -= dt
	if _step_t <= 0.0:
		_step_t = 0.5
		for h in m.hunters:
			if not land_at.has(h.team) and h.grounded and not h.dropping and not h.riding and not h.out:
				land_at[h.team] = m.time       # (matches without a skydrop start on the ground)
			# running (not sneaking) is a little noise of its own; Blight right by you hear it
			if h.grounded and not h.crouch and not h.out and not h.extracted and not h.downed and Vector2(h.vel.x, h.vel.z).length() > 3.6:
				noise(h.pos, "step", h)
	_lvl_t -= dt
	if _lvl_t <= 0.0:
		_lvl_t = 3.0
		_relevel()
	_tick_t -= dt
	if _tick_t > 0.0:
		return
	_tick_t = 1.0
	_spawn_tick(1.0)
	_despawn_tick()

## Blight on the map grow with the match (Wardens, and Skitters between fights).
func _relevel() -> void:
	for b in m.mobs:
		if b is Blight and not b.dead and (b as Blight).tgt == null:
			var bb: Blight = b
			var l := level_here(bb.pos)
			if l > bb.lvl + 0.04:
				bb.set_level(l)

func _squads() -> Dictionary:
	var out := {}
	for h in m.hunters:
		if h.out or h.extracted or h.dropping or h.riding or h.downed:
			continue
		if not out.has(h.team):
			out[h.team] = []
		out[h.team].append(h)
	return out

func _spawn_tick(dt: float) -> void:
	var sq := _squads()
	var n_alive := skitters_alive()
	var cp := cap()
	for team in sq:
		var t := squad_time(team)
		if t < GRACE:
			continue
		var hs: Array = sq[team]
		var anchor: Hunter = hs[0]
		if not anchor.grounded or anchor.over_void():
			continue
		if m.lairs and not m.lairs.lair_of(anchor.pos, 2.0).is_empty():
			continue
		var l := level(anchor.pos, team)
		# a slow trickle on its own, much faster with noise (noise())
		heat[team] = float(heat.get(team, 0.0)) + dt * (0.012 + 0.05 * l)
		if float(heat[team]) < HEAT_SPAWN:
			continue
		var near := 0
		for b in m.mobs:
			if b is Blight and not b.dead and b.mkind == "bl_skitter" and anchor.flat_dist(b) < 26.0:
				near += 1
		var near_cap := 1 + int(round(4.0 * minf(l, 1.2)))
		if near >= near_cap or n_alive >= cp:
			heat[team] = minf(float(heat[team]), HEAT_SPAWN * 1.5)
			continue
		heat[team] = float(heat[team]) - HEAT_SPAWN
		var pack := 1 if l < 0.3 else (2 if l < 0.7 else 3)
		if m.raid == "night" and l > 0.5: pack += 1
		pack = mini(pack, mini(near_cap - near, cp - n_alive))
		var at := _burrow_spot(anchor, team)
		if at == Vector3.INF:
			continue
		for i in pack:
			var p := at + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
				p = at
			var s := spawn("bl_skitter", Vector3(p.x, m.world.ground_at(p.x, p.z), p.z), l)
			s.hear(anchor.pos, 20.0)
			n_alive += 1
		m.fx.dust(at, 12)

## Where Skitters claw out of the ground: out of the squad's sight, 13-20 tiles off, on solid
## ground (preferably their island), never in a lair.
func _burrow_spot(anchor: Hunter, team: int) -> Vector3:
	var w := m.world
	var isl := w.island_of(anchor.pos.x, anchor.pos.z)
	var fallback := Vector3.INF
	for _t in 18:
		var a := rng.randf() * TAU
		var d := rng.randf_range(13.0, 20.0)
		var p := anchor.pos + Vector3(cos(a), 0, sin(a)) * d
		if w.is_void(p.x, p.z) or w.is_block(p.x, p.z) or w.in_bush(p.x, p.z):
			continue
		p.y = w.ground_at(p.x, p.z)
		if absf(p.y - anchor.pos.y) > 3.0:
			continue
		if m.lairs and not m.lairs.lair_of(p, 3.0).is_empty():
			continue
		if m.sees(team, p):
			continue
		if w.island_of(p.x, p.z) == isl:
			return p
		if fallback == Vector3.INF:
			fallback = p
	return fallback

## Idle Skitters far from everyone burrow away, so the map doesn't fill up.
func _despawn_tick() -> void:
	for b in m.mobs:
		if not (b is Blight) or b.dead or b.mkind != "bl_skitter":
			continue
		var bb: Blight = b
		if bb.st != "idle" or bb.heard != Vector3.INF or bb.idle_t < 20.0:
			continue
		var far := true
		for h in m.hunters:
			if not h.out and not h.extracted and bb.flat_dist(h) < 30.0:
				far = false; break
		if far:
			bb.burrow()

# ------------------------------------------------------------------ the local player's view
## Skitters out of your sight aren't drawn (you hear them first). A Warden's lamp shows from afar.
func _update_seen() -> void:
	var p := m.player
	var looking := p != null and not p.out and not p.extracted and not p.dropping and not p.riding
	for b in m.mobs:
		if not (b is Blight) or b.dead:
			continue
		var bb: Blight = b
		if not looking or bb.mkind == "bl_warden":
			bb.unseen = false
			continue
		bb.unseen = p.flat_dist(bb) > 2.6 and not m.sees(p.team, bb.pos + Vector3(0, 0.3, 0))

## A sound before they're seen: a dry chitter from Skitters you can't see yet, a low drone from
## a Warden, and a mark on the minimap.
func _cues() -> void:
	var p := m.player
	if p == null or p.out or p.extracted or p.riding:
		return
	var played := 0
	for b in m.mobs:
		if not (b is Blight) or b.dead or played >= 2:
			continue
		var bb: Blight = b
		var d := p.flat_dist(bb)
		if d > 22.0:
			continue
		bb.cue_t -= 0.1
		if bb.cue_t > 0.0:
			continue
		if bb.mkind == "bl_skitter":
			bb.cue_t = rng.randf_range(2.2, 4.0) if bb.unseen else rng.randf_range(4.0, 7.0)
			m.sfx("v_skitter", bb.pos, -12.0 if bb.unseen else -16.0, rng.randf_range(0.5, 0.66))
			if bb.unseen:
				m.blight_ping(bb.pos)
		else:
			bb.cue_t = rng.randf_range(4.5, 7.0)
			m.sfx("hover", bb.pos, -14.0, 0.45)
		played += 1

# ------------------------------------------------------------------ screenshots
## --blight-demo[=skitters|warden]: a Warden sweeping its light beside you and a pack of Skitters
## coming in (screenshots). You don't take damage while it runs.
var _demo := {}
func demo(mode: String) -> void:
	var P := m.player
	if P == null:
		return
	P.hp = P.max_hp
	if _demo.is_empty():
		_demo["t0"] = m.time
		Settings.v["tips"] = false
		if m.hud: m.hud.guide_hidden = true
		var wspot := m.demo_clear_spot(7.0)
		for b in alive():
			if b.flat_dist(P) < 30.0: (b as Blight).burrow()
		if mode != "skitters":
			var wd := spawn("bl_warden", Vector3(wspot.x, m.world.ground_at(wspot.x, wspot.z), wspot.z), 0.4)
			wd.sweep0 = atan2(P.pos.x - wd.pos.x, P.pos.z - wd.pos.z) + 0.55
			wd.cone_a = wd.sweep0
			wd.shriek_cd = 999.0
			_demo["warden"] = wd
		if mode != "warden":
			var sk: Array = []
			for i in 3:
				var a := PI * 0.75 + float(i) * 0.4
				var q := m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * 4.5, [P.pos], 0.8, 0.4, 4.0)
				var s := spawn("bl_skitter", Vector3(q.x, m.world.ground_at(q.x, q.z), q.z), 0.3)
				s.tgt = P; s.st = "chase"; s.cd = 9.0
				sk.append(s)
			_demo["skitters"] = sk
	P.inp["move"] = Vector2.ZERO
	var near: Blight = null; var nd := 1e9
	for s in _demo.get("skitters", []):
		var sb: Blight = s
		if not sb.dead and P.flat_dist(sb) < nd: nd = P.flat_dist(sb); near = sb
		sb.cd = maxf(sb.cd, 1.0)          # (they close in and circle, but hold the bite for the shot)
		if sb.flat_dist(P) < 3.2:
			var back := -sb.dir_to(P) * (3.2 - sb.flat_dist(P))
			sb.pos += Vector3(back.x, 0, back.y)
	var wd2: Blight = _demo.get("warden", null)
	if near:
		P.inp["aim"] = near.pos + Vector3(0, 0.6, 0)
	elif wd2:
		P.inp["aim"] = wd2.pos + Vector3(0, 1.5, 0)
	if wd2 and not wd2.dead:
		wd2.spot = clampf((m.time - float(_demo["t0"])) / 3.0, 0.0, 0.85)
		wd2.sense_t = 99.0          # (the light keeps sweeping; it doesn't shriek for the shot)
