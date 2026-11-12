class_name BlightDir
extends RefCounted
## Runs the Blight for a match (docs/TONE_AND_THREATS.md §1, §1b): where Wardens stand, when and
## its nests (BlightNests: the only place Skitters come from), what they hear, and how strong they are.
##
## Pacing (the owner's rule): you drop at level 1 with one ability and level up fast on monster
## camps, so the Blight starts weak and ramps. Its strength (lvl, 0 weakest .. 1 full) comes from:
##   - how long YOUR squad has been down on the islands (per squad, so late arrivals get a soft start)
##   - the region: the outer islands are safer than the core (an island's "danger" 0/1/2)
##   - the raid condition (RaidLook.BLIGHT: night and storms are worse)
## Nothing comes from nowhere (owner, 11-12): Skitters climb out of visible nests at fixed spots, a
## fixed stock each, after a pulse you can see and hear; noise and Wardens' shrieks only wake nests.
## Health and damage: early Blight die fast and hit soft (hp_k, dmg_k); later ones are the real thing.
##
## The host (or the offline game) spawns and runs them; everyone hears them and hides the ones
## out of sight. Their state reaches other players through Match's mob snapshots (Net).

const LVL_MAX := 1.6
const GRACE := 45.0               # seconds after a squad lands before anything comes for it
const RAMP := 420.0               # seconds (per squad) from the soft start to full strength
const CAP_BASE := 5               # Blight alive at once (all squads), on top of the Wardens
const CAP_MAX := 18
const LOUD := {"shot": 15.0, "boom": 24.0, "revive": 9.0, "kin": 8.0, "chest": 13.0, "dash": 7.0, "step": 4.5, "shriek": 16.0, "scan": 12.0}

var m: Match
var rng := RandomNumberGenerator.new()
var raid_k := 1.0
var host := true
var land_at := {}                 # team -> match time its squad landed
var noises: Array = []            # {pos, loud, t, kind} the last few seconds of noise (for tests and the HUD)
var _tick_t := 0.0
var _vis_t := 0.0
var _step_t := 0.0
var _lvl_t := 0.0
var spawned := 0
var shrieks := 0
var wardens: Array = []
var nests: BlightNests

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
	nests = BlightNests.new(self)

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
	var tk := time_k(squad_time(team)) if team >= 0 else time_k(m.sess_time())
	return clampf((0.1 + 0.9 * tk) * region_k(p) * raid_k + Heart.tide_boost(m, p), 0.0, LVL_MAX)

func level_vs(b: Blight, team: int) -> float:
	return level(b.pos, team)

## A Warden or a Skitter between squads: as strong as the match is old, where it stands.
func level_here(p: Vector3) -> float:
	var base := (0.1 + 0.9 * time_k(m.sess_time())) * region_k(p) * raid_k
	return clampf(base + Heart.tide_boost(m, p), 0.0, LVL_MAX)

func on_landed(h: Hunter) -> void:
	if not land_at.has(h.team):
		land_at[h.team] = m.time

# ------------------------------------------------------------------ setup
## Wardens stand on the islands from the start: one or two on the dangerous ones, few on the
## outer islands. Away from camps, exits, lairs and where people drop.
## Nests too (BlightNests.place, on every peer: only the seed and the world pick their spots).
func setup() -> void:
	nests.place()
	if not host:
		return
	var w := m.world
	for ii in w.islands.size():
		var dg := island_danger(ii)
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
	nests.populate()

## An island's danger 0 (outer) .. 2 (core): the hand map says; a generated one goes by region_k.
func island_danger(ii: int) -> int:
	var c: Dictionary = m.world.islands[ii]
	if int(c.get("danger", -1)) >= 0:
		return clampi(int(c["danger"]), 0, 2)
	var k := region_k(Vector3(float(c.get("cx", 0.0)), 0, float(c.get("cz", 0.0))))
	return 2 if k > 1.2 else (1 if k > 0.8 else 0)

func _warden_spot(ii: int) -> Vector3:
	var w := m.world
	if w.hand:
		# a hand-made map says where Wardens may stand (World.warden_posts): the dice only pick which
		var posts: Array = w.warden_posts.filter(func(wp): return int(wp["island"]) == ii)
		for k in range(posts.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = posts[k]; posts[k] = posts[j]; posts[j] = tmp
		for wp in posts:
			var q: Vector3 = wp["pos"]
			if _near_any(q, wardens.map(func(b): return b.pos), 6.0):
				continue
			if m.lairs and not m.lairs.lair_of(q, 6.0).is_empty():
				continue
			if _near_any(q, w.camp_spots.map(func(c): return c["pos"]), 9.0) or _near_any(q, w.spawns, 8.0):
				continue
			if m.exits and _near_any(q, m.exits.list.map(func(x): return x["pos"]), 9.0):
				continue
			return q
		return Vector3.INF
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
		if _near_any(p, wardens.map(func(b): return b.pos), 14.0) or _near_any(p, nests.list.map(func(n): return n["pos"]), 9.0):
			continue
		return p
	return Vector3.INF

## A random ground tile on an island, from the Blight's own dice (World.random_ground rolls the
## world's, and the rest of the match shouldn't shift because the Blight is on).
func _rand_ground(ii: int, r: RandomNumberGenerator = null) -> Vector3:
	var w := m.world
	if r == null:
		r = rng
	for _t in 500:
		var x := r.randi_range(0, w.w - 1); var z := r.randi_range(0, w.h - 1)
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
## come to look, and a loud one wakes a nest close by (BlightNests.on_noise).
func noise(at: Vector3, kind: String, by = null) -> void:
	var loud: float = float(LOUD.get(kind, 10.0))
	noises.append({"pos": at, "loud": loud, "t": m.time, "kind": kind})
	if noises.size() > 48:
		noises.pop_front()
	if not host:
		return
	nests.on_noise(at, loud)
	for b in m.mobs:
		if b is Blight and not b.dead and b.mkind != "bl_nest":
			var bb: Blight = b
			var reach := loud * (0.7 if bb.mkind == "bl_warden" else 1.0)
			if bb.flat_dist(at) < reach:
				bb.hear(at, loud)

## A Warden shrieked at someone: every Blight nearby comes, and nests close by give up what they
## hold (BlightNests.on_shriek). A shriek never makes Skitters of its own.
func on_shriek(w: Blight, at_h: Ent) -> void:
	shrieks += 1
	var tp: Vector3 = at_h.pos if at_h else w.pos
	var team: int = at_h.team if at_h is Hunter else -1
	var rad := 10.0 + 8.0 * minf(level(w.pos, team), 1.0)
	for b in m.mobs:
		if b is Blight and not b.dead and b != w and b.flat_dist(w) < rad:
			(b as Blight).hear(tp, rad)
	if host:
		nests.on_shriek(w.pos, tp)

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
	nests.tick(dt)
	_lvl_t -= dt
	if _lvl_t <= 0.0:
		_lvl_t = 3.0
		_relevel()
	_tick_t -= dt
	if _tick_t > 0.0:
		return
	_tick_t = 1.0
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

## Idle Skitters far from everyone burrow home (back into their nest's stock, BlightNests.home).
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
			nests.home(bb)
			bb.burrow()

# ------------------------------------------------------------------ the local player's view
## Skitters out of your sight aren't drawn (you hear them first). A Warden's lamp and a nest show from afar.
func _update_seen() -> void:
	var p := m.player
	var looking := p != null and not p.out and not p.extracted and not p.dropping and not p.riding
	for b in m.mobs:
		if not (b is Blight) or b.dead:
			continue
		var bb: Blight = b
		if not looking or bb.mkind != "bl_skitter":
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
		if not (b is Blight) or b.dead or played >= 2 or b.mkind == "bl_nest":
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
	if mode == "nest":
		nests.demo()
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
