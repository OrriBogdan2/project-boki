class_name Rolling
extends RefCounted
## Rolling 30-minute sessions (docs/ROADMAP.md §0.6, the owner's call of Oct 31; match option
## "rolling", --rolling, or the toggle on the expedition panel). The fixed-length match stays the
## default until the owner switches it.
##
## A session runs SESSION seconds whatever happens. Squads arrive in drop waves every 2-3 minutes,
## each wave a small group (2-4 squads) on its own skyship pass over the quieter side of the map,
## until CUTOFF before the end. You join whichever wave the matchmaker gives you (offline: a random
## one, or opts "join_wave" / "join_at"); you don't pick when. At 30:00 the session ends for everyone:
## anyone still out there is lost (Match._update_rules).
##
## Late joiners (ROADMAP §0.6 "Levels with late joiners", approved by the owner Nov 1):
##   - level floor: you land at min(FLOOR_MAX, 1 + floor(minutes in / 4)), those levels' points spent
##     in your archetype's order, so a minute-20 arrival isn't a level-1 snack;
##   - catch-up XP: below the lobby's median level your XP counts up to CATCHUP_MAX (x1.6; xp_mult);
##   - bounties: a hunter BOUNTY_GAP+ levels over the median is marked for everyone, and knocking them
##     pays XP and loot by the gap (and any knock on a higher-level hunter pays a little by the gap);
##   - soft landing: waves come down over the less crowded side, onto the calm outer ring of the wide map
##     (WideLayout.widen), and the fresh-lander grace (Bot.fresh, per hunter) and the Blight's ramp
##     (BlightDir.land_at, per squad) both key off each squad's own landing time.
##
## The match clock (Match.time) starts when YOUR wave sets off; the session clock is Match.sess_time()
## (= sess_t0 + time), so everything that ran before you joined lives in negative match time.
## Offline the other squads are bots; the playtest will fill the same waves with people (needs the
## late-join snapshot in the netcode, so rolling sessions are offline-only for now).

const SESSION := 1800.0            # the session: 30 minutes
const CUTOFF := 480.0              # no new squads in the last 8 minutes
const GAP := Vector2(120.0, 180.0) # seconds between drop waves
const WAVE_HUNTERS := Vector2i(6, 12)   # hunters a wave brings: 2-4 trios (solos and duos: the same headcount)
const POP := Vector2i(24, 40)      # the hunter target (see POP_MODE for what it counts)
## What POP counts (open owner question: the brief says "24-40 hunters"):
##   "at_once": hunters on the map at any moment (the roadmap's reading, the default): each wave tops the map up;
##   "total":   hunters who join over the whole session: each wave takes a share of what's left of the budget.
## Overridden per match by opts "rolling_pop" (--rolling-pop=at_once|total).
const POP_MODE := "at_once"
const FLOOR_EVERY := 240.0         # +1 level floor every 4 minutes into the session
const FLOOR_MAX := 5               # ... up to 5, so the R (level 6) is always earned in the run
const CATCHUP_PER_LV := 0.3        # x1.3 one level under the median, x1.6 two or more under (was 0.5 / x2:
const CATCHUP_MAX := 1.6           # --rolling-sim had late squads level in 2 min and +0.9..+1.75 over the median by 6)
const BOUNTY_GAP := 3              # this many levels over the median (and at least BOUNTY_MIN_LV): a bounty
const BOUNTY_MIN_LV := 5
const BOUNTY_CD := 45.0            # after a bounty is claimed, the same hunter can't carry a new one for this long
const BOUNTY_XP := 80.0            # bounty XP: this + BOUNTY_XP_GAP per level over the median
const BOUNTY_XP_GAP := 40.0
const GAP_KNOCK_XP := 25.0         # any knock on a higher-level hunter: this much XP per level of the gap
const STAY := Vector2(480.0, 960.0)     # how long a bot squad means to stay out before heading home (8-16 min)
const WIPE_PER_MIN := 0.03         # (earlier arrivals, simulated) chance a squad is wiped in a minute
const XP_PER_MIN := 200.0          # (earlier arrivals) XP a bot makes in a minute out there. Was a 105 guess; --rolling-sim
                                   # --seed=5 measured a median 243/min on the map, 12.8% of it catch-up: ~215 base, less on a picked-over map
const CAMP_RESPAWN := 240.0        # a cleared monster camp comes back after 4 minutes with nobody near
const METEOR_EVERY := 360.0        # meteor showers (fresh gems) every 6 minutes of the session
const LAND_CROWD_R := 30.0

var m: Match
var rng := RandomNumberGenerator.new()
var size := 1                      # hunters per squad
var pop_mode := POP_MODE           # what the POP target counts (POP_MODE)
var pop_budget := 0                # "total" mode: hunters the session brings in all (rolled from POP)
var pop_joined := 0                # "total" mode: hunters who've boarded a wave so far (any wave)
var waves: Array = []              # {i, t (session), n (squads), state, ship, teams, hunters, landed}
var join_i := 0
var t0 := 0.0                      # session time your wave set off
var next_team := 0
var team_land := {}                # team -> match time its first hunter landed
var team_stay := {}                # team -> seconds it means to stay out (bots)
var median := 1.0
var _med_t := 0.0
var _camp_t := 0.0
var camps: Array = []              # {pos, comp, mobs, cleared_at}
var bounty_cd := {}                # hunter nid -> match time it may carry a bounty again
var _names: Array = []
var stats := {"joined": 0, "prepop": 0, "prepop_dead": 0, "landed": 0, "floors": [], "catchup_xp": 0.0, "xp_all": 0.0,
	"bounties_posted": 0, "bounties_claimed": 0, "gap_knock_xp": 0.0, "camp_respawns": 0, "extracts": [], "outs": [],
	"meteors": 0, "pop": []}
var _seen_ext := {}
var _seen_out := {}
var events: Array = []             # what happened, for tests: [session time, text]

func _init(match_node: Match) -> void:
	m = match_node

## Bots: how long they have left out there. A rolling session's squads each mean to stay a while
## (team_time_left); otherwise it's the match's time left.
static func bot_time_left(mt: Match, h: Hunter) -> float:
	if mt.rolling:
		return mt.rolling.team_time_left(h.team)
	return mt.length - mt.time

## Bots: are they past this share of their time out there (the match's, or their squad's planned stay)?
static func bot_past(mt: Match, h: Hunter, k: float) -> bool:
	if mt.rolling:
		return mt.rolling.team_elapsed(h.team) > float(mt.rolling.team_stay.get(h.team, STAY.y)) * k
	return mt.time > mt.length * k

## Aboard a drop wave's skyship: rides it until its jump, then glides to `at`.
func board(h: Hunter, s: Dictionary, at: Vector3) -> void:
	h.set_meta("ship", s)
	h.riding = true
	h.dropping = false
	h.ai["land"] = at
	h.teleport(m.ship_pos_of(s))
	m.plan_jump(h, at)

static func enabled(o: Dictionary) -> bool:
	if o.has("net"):
		return false        # (online sessions need late-join snapshots first: ROADMAP §0.6 build order)
	for k in ["tutorial", "training", "duel", "arena", "sandbox"]:
		if o.get(k, false):
			return false
	return bool(o.get("rolling", false)) and bool(o.get("big", true))

## The level you land at this far into the session.
static func floor_at(sess_t: float) -> int:
	return mini(FLOOR_MAX, 1 + int(floor(maxf(0.0, sess_t) / FLOOR_EVERY)))

## How many hunters the next wave brings, for this many already out there.
static func wave_hunters(pop: int) -> int:
	return clampi(POP.y - 4 - pop, WAVE_HUNTERS.x, WAVE_HUNTERS.y)

static func squads_for(pop: int, squad_size: int) -> int:
	var n := int(round(float(wave_hunters(pop)) / float(maxi(1, squad_size))))
	return clampi(n, 2 if squad_size >= 3 else 3, 12)

## "total" mode: squads for the next wave, sharing what's left of the session's budget over the
## waves still to come (at least one squad a wave).
static func squads_total(budget: int, joined: int, waves_left: int, squad_size: int) -> int:
	var left := maxi(0, budget - joined)
	var n := int(round(float(left) / float(maxi(1, waves_left)) / float(maxi(1, squad_size))))
	return clampi(n, 1, 12)

## Squads for wave i, whichever way POP is read (pop: hunters out there right now).
func wave_squads(i: int, pop: int) -> int:
	var n := squads_total(pop_budget, pop_joined, waves.size() - i, size) if pop_mode == "total" else squads_for(pop, size)
	pop_joined += n * size
	return n

# ------------------------------------------------------------------ the plan
## Rolls the session (once, before anything is built): when the waves come, which one you're in, and
## who's already out there. Sets the match's clock and length and how big your wave is.
func plan(o: Dictionary) -> void:
	rng.seed = int(m.seed_val) * 7919 + 17
	size = maxi(1, int(o.get("squad", 1)))
	pop_mode = String(o.get("rolling_pop", POP_MODE))
	if pop_mode == "total":
		pop_budget = rng.randi_range(POP.x, POP.y)     # (only rolled in this mode: the default's dice stay as they were)
	var t := 0.0
	while t <= SESSION - CUTOFF + 0.01:
		waves.append({"i": waves.size(), "t": t, "n": 0, "state": "planned", "ship": {}, "teams": [], "hunters": 0, "landed": 0})
		t += rng.randf_range(GAP.x, GAP.y)
	if o.has("join_wave"):
		join_i = clampi(int(o["join_wave"]), 0, waves.size() - 1)
	elif o.has("join_at"):
		join_i = 0
		for w in waves:
			if float(w["t"]) <= float(o["join_at"]) + 0.01: join_i = int(w["i"])
	else:
		join_i = rng.randi_range(0, waves.size() - 1)
	t0 = float(waves[join_i]["t"])
	m.sess_t0 = t0
	m.length = SESSION - t0
	_model_before()
	var pop := _model_alive_at(t0)
	var mine: Dictionary = waves[join_i]
	mine["n"] = wave_squads(join_i, pop)
	mine["state"] = "flying"
	o["teams"] = int(mine["n"])
	o["total"] = int(mine["n"]) * size
	next_team = int(mine["n"])
	for i in int(mine["n"]):
		(mine["teams"] as Array).append(i)
	mine["hunters"] = int(mine["n"]) * size
	stats["joined"] += int(mine["hunters"])
	events.append([t0, "plan %d waves, you join wave %d at %s" % [waves.size(), join_i, fmt(t0)]])

# ---- the session before you joined, simulated: squads that came down, stayed a while, left or died
var _model: Array = []        # {wave, t_land, stay, wiped_at, alive (members left), size}

func _model_before() -> void:
	_model.clear()
	for w in waves:
		if int(w["i"]) >= join_i:
			break
		var tw := float(w["t"])
		var n := wave_squads(int(w["i"]), _model_alive_at(tw))
		w["n"] = n; w["hunters"] = n * size; w["landed"] = n * size; w["state"] = "done"
		for _s in n:
			var t_land := tw + rng.randf_range(14.0, 30.0)
			var stay := rng.randf_range(STAY.x, STAY.y)
			# wiped in some minute of their stay, or not
			var wiped_at := INF
			var mins := int(ceil(stay / 60.0))
			for k in mins:
				if rng.randf() < WIPE_PER_MIN:
					wiped_at = t_land + (k + rng.randf()) * 60.0; break
			var alive := size
			for _k in size - 1:
				if rng.randf() < 0.18: alive -= 1      # a squadmate who didn't make it
			_model.append({"wave": int(w["i"]), "t_land": t_land, "stay": stay, "wiped_at": wiped_at, "alive": alive})

func _model_alive_at(t: float) -> int:
	var n := 0
	for q in _model:
		if t >= float(q["t_land"]) - 30.0 and t < float(q["t_land"]) + float(q["stay"]) and t < float(q["wiped_at"]):
			n += int(q["alive"])
	return n

## Earlier arrivals still out there when you join: made as bots already on the ground, as far along
## as their time out there says (level floor when they landed + the XP they've made since, a little
## loot). The ones who died left their things where they fell. (Called from Match._spawn_hunters,
## before your wave boards.)
func populate_before(names: Array) -> void:
	_names = names
	var spots: Array = []
	var W := m.world
	var cands: Array = W.spawns.duplicate()
	for q in _model:
		var in_now: bool = t0 < float(q["t_land"]) + float(q["stay"]) and t0 < float(q["wiped_at"])
		var dead_n := size - int(q["alive"]) if in_now else (size if t0 >= float(q["wiped_at"]) else 0)
		stats["prepop_dead"] += dead_n
		for _d in dead_n:
			_old_fight_loot(float(q["t_land"]))
		if not in_now:
			continue
		var team := next_team
		next_team += 1
		var base := _far_spot(cands, spots)
		spots.append(base)
		var land_local := float(q["t_land"]) - t0
		team_land[team] = land_local
		team_stay[team] = float(q["stay"])
		var mins_out := (t0 - float(q["t_land"])) / 60.0
		for s in int(q["alive"]):
			var at := base
			if s > 0:
				var jq := base + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
				at = W.free_spot_near(jq, spots, 0.8, 0.45, 6.0)
			var h := m.make_bot(team, at, _names)
			h.set_meta("landed_t", land_local)
			h.set_meta("wave", int(q["wave"]))
			h.set_meta("rolled_in", true)      # (already down before you joined: no landing floor to apply)
			h.ai["land"] = at
			set_level(h, floor_at(float(q["t_land"])))
			grant_xp_quiet(h, XP_PER_MIN * mins_out * rng.randf_range(0.6, 1.3))
			h.gems += int(round(mins_out * rng.randf_range(4.0, 9.0)))
			stats["prepop"] += 1

func _far_spot(cands: Array, taken: Array) -> Vector3:
	var best := Vector3.INF; var bs := -1e9
	for p in cands:
		var ii := m.world.island_of(p.x, p.z)
		if ii >= 0 and m.world.islands[ii].get("perch", false):
			continue
		var dmin := 1e9
		for q in taken: dmin = minf(dmin, Vector2(p.x - q.x, p.z - q.z).length())
		var sc := minf(dmin, 60.0) + rng.randf() * 18.0
		if sc > bs: bs = sc; best = p
	return best if best != Vector3.INF else m.world.random_ground()

## Where someone went down before you joined: a few gems and sometimes a piece of their gear, out on the ground.
func _old_fight_loot(_t_land: float) -> void:
	var at: Vector3 = m.world.spawns[rng.randi_range(0, m.world.spawns.size() - 1)] if not m.world.spawns.is_empty() else m.world.random_ground()
	at = m.world.free_spot_near(at + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), [], 1.0, 0.45, 8.0)
	if m.world.is_void(at.x, at.z):
		return
	for _i in rng.randi_range(2, 5):
		m.drop("gem", at + Vector3(0, 0.5, 0), maxi(1, int(round(3 * float(m.T.get("loot", 1.0))))))
	if rng.randf() < 0.45:
		var gg := GearDrops.roll_gear(rng, 1, 0, -1)
		m.spawn_gear(String(gg["id"]), int(gg["rar"]), at + Vector3(0.8, 0, 0.3), "", false)

## After the world, monsters, chests and the Blight are in: the map as picked over as the session is old,
## the Blight told when the earlier squads landed, and the session's events lined up.
func after_setup() -> void:
	var frac := clampf(t0 / 1300.0, 0.0, 0.6)
	var opened := 0
	for c in m.chests:
		if c.has("ride"):
			continue
		if rng.randf() < frac:
			_empty_chest(c); opened += 1
	var cleared := 0
	for cp in camps:
		if rng.randf() < frac:
			for mb in cp["mobs"]:
				if is_instance_valid(mb) and not mb.dead:
					mb.hp = 0.0; mb.dead = true; mb.visible = false
			# cleared some time ago: some come back soon after you land
			cp["cleared_at"] = -rng.randf_range(0.0, CAMP_RESPAWN)
			cleared += 1
	if m.blight:
		for team in team_land:
			m.blight.land_at[team] = float(team_land[team])
	events.append([t0, "picked over: %d chests open, %d camps cleared, %d hunters already out there" % [opened, cleared, stats["prepop"]]])

func _empty_chest(c: Dictionary) -> void:
	c["open"] = true
	var lid: Node3D = c["node"].get_node_or_null("Body/Lid")
	if lid:
		if lid.has_meta("hinged"): lid.rotation.x = 1.9
		else:
			lid.rotation.x = -1.1; lid.position.y = 0.62; lid.position.z = 0.2
	var beacon: Node3D = c["node"].get_node_or_null("Beacon")
	if beacon: beacon.visible = false

## A monster camp, so it can come back once cleared (Match._spawn_mobs).
func note_camp(pos: Vector3, comp: Array, mobs: Array) -> void:
	camps.append({"pos": pos, "comp": comp.duplicate(), "mobs": mobs, "cleared_at": -1e9})

# ------------------------------------------------------------------ the skyships
## A new wave's skyship, flying over the less crowded side of the map. t_start is match time.
func new_ship(t_start: float) -> Dictionary:
	var W := m.world
	var ctr := Vector2(W.w / 2.0, W.h / 2.0)
	var half := W.w * 0.6
	var others: Array = []
	for h in m.hunters:
		if not h.out and not h.extracted:
			var q: Vector3 = h.ai.get("land", h.pos) if (h.riding or h.dropping) and h.ai.has("land") else h.pos
			others.append(Vector2(q.x, q.z))
	var best_a := rng.randf() * TAU; var best_o := 0.0; var bs := 1e18
	for ai in 12:
		var ang := TAU * ai / 12.0 + rng.randf_range(-0.12, 0.12)
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		for off in [-0.24, -0.1, 0.1, 0.24]:
			var c := ctr + side * float(off) * W.w
			var a := c - dir * half; var b := c + dir * half
			var sc := 0.0
			for q: Vector2 in others:
				var d := (Geometry2D.get_closest_point_to_segment(q, a, b) - q).length()
				sc += exp(-d * d / (2.0 * 28.0 * 28.0))
			# rather over land you can drop onto
			var land := 0
			for sp in W.spawns:
				var p2 := Vector2(sp.x, sp.z)
				if (Geometry2D.get_closest_point_to_segment(p2, a, b) - p2).length() < 22.0: land += 1
			sc -= 0.25 * land
			sc += rng.randf() * 0.6
			if sc < bs: bs = sc; best_a = ang; best_o = float(off)
	var dir3 := Vector3(cos(best_a), 0, sin(best_a))
	var side3 := Vector3(-dir3.z, 0, dir3.x)
	var cc := Vector3(ctr.x, Match.SHIP_Y, ctr.y) + side3 * best_o * W.w
	var s := {"a": cc - dir3 * half, "b": cc + dir3 * half, "dur": 2.0 * half / Match.SHIP_SPEED, "ride": (half + 34.0) / Match.SHIP_SPEED, "dir": dir3, "t0": t_start}
	var n := Models.skyship()
	n.rotation.y = atan2(-dir3.x, -dir3.z)
	n.position = s["a"]
	m.add_child(n)
	s["node"] = n
	return s

## Landing spots for n squads off a ship: spawn spots near its line (within a glide), the least
## crowded first and spread apart.
func spots_along(s: Dictionary, n: int) -> Array:
	var W := m.world
	var a := Vector2(s["a"].x, s["a"].z); var b := Vector2(s["b"].x, s["b"].z)
	var near: Array = []
	for sp in W.spawns:
		var ii := W.island_of(sp.x, sp.z)
		if ii >= 0 and W.islands[ii].get("perch", false):
			continue
		var p2 := Vector2(sp.x, sp.z)
		if (Geometry2D.get_closest_point_to_segment(p2, a, b) - p2).length() < 30.0:
			near.append(sp)
	if near.size() < n:
		near = W.spawns.duplicate()
	var out: Array = []
	for _k in n:
		var best := Vector3.INF; var bs := 1e18
		for sp in near:
			if out.has(sp):
				continue
			var crowd := 0.0
			for h in m.hunters:
				if h.out or h.extracted:
					continue
				var q: Vector3 = h.ai.get("land", h.pos) if (h.riding or h.dropping) and h.ai.has("land") else h.pos
				var d := Vector2(q.x - sp.x, q.z - sp.z).length()
				if d < LAND_CROWD_R: crowd += 1.0 - d / LAND_CROWD_R
			for q in out:
				var d2 := Vector2(q.x - sp.x, q.z - sp.z).length()
				if d2 < 26.0: crowd += 2.0 * (1.0 - d2 / 26.0)
			crowd += rng.randf() * 0.3
			if crowd < bs: bs = crowd; best = sp
		if best == Vector3.INF:
			best = W.random_ground()
		out.append(best)
	return out

# ------------------------------------------------------------------ during the session
func tick(dt: float) -> void:
	var st := m.sess_time()
	# the next wave sets off when its time comes (never inside the last CUTOFF)
	for w in waves:
		if String(w["state"]) == "planned" and int(w["i"]) > join_i and st >= float(w["t"]) and float(w["t"]) <= SESSION - CUTOFF + 0.01:
			_launch(w)
	for w in waves:
		if String(w["state"]) == "flying":
			var s: Dictionary = w["ship"]
			# incoming until the ship has passed and its squads are all down (the HUD's WAVE INCOMING)
			if not s.is_empty() and m.time > float(s.get("t0", 0.0)) + float(s["ride"]) + 1.0 and not _wave_in_air(w):
				w["state"] = "done"
	# a drop that ended early (an ability mid-air, a fall below the islands) never reaches
	# Match.on_drop_landed: the floor still applies the moment they're down on the ground
	for h in m.hunters:
		if h.grounded and not h.riding and not h.dropping and not h.out and not h.has_meta("rolled_in") and m.time > 0.0:
			on_landed(h)
	_med_t -= dt
	if _med_t <= 0.0:
		_med_t = 1.0
		_update_median()
		_update_bounties()
		_track()
	_camp_t -= dt
	if _camp_t <= 0.0:
		_camp_t = 5.0
		_camp_respawns()

func _wave_in_air(w: Dictionary) -> bool:
	var teams: Array = w["teams"]
	for h in m.hunters:
		if (h.riding or h.dropping) and not h.out and teams.has(h.team):
			return true
	return false

func _launch(w: Dictionary) -> void:
	var pop := alive_count()
	var n := wave_squads(int(w["i"]), pop)
	var s := new_ship(m.time)
	s["wave"] = int(w["i"])
	m.ships.append(s)
	w["ship"] = s
	w["n"] = n
	w["state"] = "flying"
	var spots := spots_along(s, n)
	for k in n:
		var team := next_team
		next_team += 1
		(w["teams"] as Array).append(team)
		var mem: Array = []
		for j in size:
			var at: Vector3 = spots[k]
			if j > 0:
				at = m.world.free_spot_near(at + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), [], 0.8, 0.45, 6.0)
			var h := m.make_bot(team, at, _names)
			h.set_meta("wave", int(w["i"]))
			board(h, s, at)
			mem.append(h)
		if m.skydrop:
			m.skydrop.add_squad(mem)
		team_stay[team] = rng.randf_range(STAY.x, STAY.y)
	w["hunters"] = n * size
	stats["joined"] += n * size
	events.append([m.sess_time(), "wave %d: %d squads (%d hunters) set off, %d already out there" % [int(w["i"]), n, n * size, pop]])
	m.add_feed("A skyship is coming in with %d squad%s" % [n, "" if n == 1 else "s"])
	if m.hud and m.player and not m.player.out and not m.player.extracted:
		m.hud.toast_small("Drop wave incoming  ·  %d squad%s" % [n, "" if n == 1 else "s"], Color("ffd27a"))

## Hunters out on the map or on their way down (not out, not extracted).
func alive_count() -> int:
	var n := 0
	for h in m.hunters:
		if not h.out and not h.extracted: n += 1
	return n

## On the ground now: floor level, the squad's landing time (Blight, stay), stats.
func on_landed(h: Hunter) -> void:
	if not team_land.has(h.team):
		team_land[h.team] = m.time
	if not team_stay.has(h.team):
		team_stay[h.team] = rng.randf_range(STAY.x, STAY.y)
	if h.has_meta("rolled_in"):
		return
	h.set_meta("rolled_in", true)
	stats["landed"] += 1
	for w in waves:
		if int(w["i"]) == int(h.get_meta("wave", join_i)): w["landed"] = int(w["landed"]) + 1
	var fl := floor_at(m.sess_time())
	var before := h.lvl
	set_level(h, fl)
	(stats["floors"] as Array).append([snappedf(m.sess_time(), 1.0), fl])
	h.set_meta("land_sess", m.sess_time())
	h.set_meta("lvl_land", h.lvl)
	h.set_meta("xp_land", h.xp)
	if h == m.player and m.hud:
		if fl > before:
			m.hud.toast("Joined at %s  ·  level floor %d  ·  abilities unlocked" % [fmt(t0), fl], Color("ffd27a"))
		else:
			m.hud.toast("Joined at %s  ·  %s left in the session" % [fmt(t0), fmt(SESSION - m.sess_time())], Color("cfeaff"))

## Raise a hunter to at least this level, with the points spent (abilities open), quietly.
func set_level(h: Hunter, lv: int) -> void:
	lv = clampi(lv, 1, Hunter.XP_TO.size())
	if h.lvl >= lv:
		return
	h.xp = maxf(h.xp, float(Hunter.XP_TO[lv - 1]))
	while h.lvl < lv:
		h.lvl += 1
		h.skill_pts += 1
	h._bot_spend()

## XP without the level-up show (for squads that were out there before you came).
func grant_xp_quiet(h: Hunter, x: float) -> void:
	h.xp += x
	while h.lvl < Hunter.XP_TO.size() and h.xp >= float(Hunter.XP_TO[h.lvl]):
		h.lvl += 1
		h.skill_pts += 1
	h._bot_spend()

## Catch-up XP: below the median level of everyone out there, XP counts up to CATCHUP_MAX (x1.6).
func xp_mult(h: Hunter) -> float:
	var gap := median - float(h.lvl)
	if gap <= 0.0:
		return 1.0
	return minf(CATCHUP_MAX, 1.0 + gap * CATCHUP_PER_LV)

func scale_xp(h: Hunter, x: float) -> float:
	var k := xp_mult(h)
	stats["xp_all"] = float(stats["xp_all"]) + x * k
	if k > 1.0:
		stats["catchup_xp"] = float(stats["catchup_xp"]) + x * (k - 1.0)
	return x * k

func on_map(h: Hunter) -> bool:
	return not (h.out or h.extracted or h.riding or h.dropping)

func _update_median() -> void:
	var lv: Array = []
	for h in m.hunters:
		if on_map(h): lv.append(h.lvl)
	if lv.size() < 3:
		median = 1.0
		return
	lv.sort()
	var n := lv.size()
	median = float(lv[n / 2]) if n % 2 == 1 else 0.5 * float(lv[n / 2 - 1] + lv[n / 2])

# ---- bounties
func bounty_of(h: Hunter) -> int:
	return int(h.get_meta("bounty", 0))

func _update_bounties() -> void:
	for h: Hunter in m.hunters:
		var gap := float(h.lvl) - median
		var has := h.has_meta("bounty")
		if not on_map(h):
			if has and (h.out or h.extracted): h.remove_meta("bounty")
			continue
		if not has and gap >= BOUNTY_GAP and h.lvl >= BOUNTY_MIN_LV and m.time >= float(bounty_cd.get(h.nid, -1e9)):
			h.set_meta("bounty", int(gap))
			stats["bounties_posted"] += 1
			events.append([m.sess_time(), "bounty on %s (level %d, median %.1f)" % [h.pname, h.lvl, median]])
			m.add_feed("Bounty on %s (level %d)" % [h.pname, h.lvl])
			if m.hud and m.player and not m.player.out:
				if h == m.player:
					m.hud.toast("You have a bounty on you  ·  everyone can see you on the map", Color("ffb64a"))
				else:
					m.hud.toast_small("Bounty on %s  ·  level %d" % [h.pname, h.lvl], Color("ffb64a"))
		elif has:
			if gap < BOUNTY_GAP - 1.0:
				h.remove_meta("bounty")      # the lobby caught up
			else:
				h.set_meta("bounty", maxi(int(h.get_meta("bounty")), int(gap)))

## A knock (Match.knock): a bounty pays out, and any higher-level hunter is worth a little XP by the gap.
func on_knock(h: Hunter, credit) -> void:
	if not (credit is Hunter) or credit == h or (credit as Hunter).team == h.team:
		return
	var c: Hunter = credit
	if h.lvl > c.lvl:
		var gx := GAP_KNOCK_XP * float(h.lvl - c.lvl)
		stats["gap_knock_xp"] = float(stats["gap_knock_xp"]) + gx
		c.gain_xp(gx)
	if not h.has_meta("bounty"):
		return
	var gap := maxi(1, bounty_of(h))
	h.remove_meta("bounty")
	bounty_cd[h.nid] = m.time + BOUNTY_CD
	stats["bounties_claimed"] += 1
	c.gain_xp(BOUNTY_XP + BOUNTY_XP_GAP * gap)
	# the loot: gems by the gap and a piece of treasure, at the knocked hunter's feet
	var at := h.pos
	if not m.world.is_void(at.x, at.z):
		for _i in 4 + 2 * gap:
			m.drop("gem", at + Vector3(0, 0.6, 0), maxi(1, int(round(3 * float(m.T.get("loot", 1.0))))))
		m.spawn_val(Loot.valuable(Loot.roll_valuable(rng, mini(2, 1 + gap / 3))), at + Vector3(0.7, 0, -0.4))
	events.append([m.sess_time(), "%s claimed the bounty on %s (gap %d)" % [c.pname, h.pname, gap]])
	m.add_feed("%s claimed the bounty on %s" % [c.pname, h.pname])
	if m.hud and c == m.player:
		m.hud.toast("BOUNTY CLAIMED  ·  +%d XP" % int(BOUNTY_XP + BOUNTY_XP_GAP * gap), Color("ffb64a"))

# ---- monster camps come back
func _camp_respawns() -> void:
	if m.net_on and not m.is_host:
		return
	for cp in camps:
		var all_dead := true
		for mb in cp["mobs"]:
			if is_instance_valid(mb) and not mb.dead: all_dead = false; break
		if not all_dead:
			continue
		if float(cp["cleared_at"]) <= -1e8:
			cp["cleared_at"] = m.time
			continue
		if m.time - float(cp["cleared_at"]) < CAMP_RESPAWN:
			continue
		var p: Vector3 = cp["pos"]
		var near := false
		for h in m.hunters:
			if not h.out and not h.extracted and Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < 22.0:
				near = true; break
		if near:
			continue
		var made: Array = []
		for kk in cp["comp"]:
			var q := p + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z):
				q = p
			q.y = m.world.ground_at(q.x, q.z)
			var smb := m.spawn_mob(String(kk), q)
			if m.biomes: m.biomes.dress(smb)
			made.append(smb)
		cp["mobs"] = made
		cp["cleared_at"] = -1e9
		stats["camp_respawns"] += 1

# ---- session events
## The next meteor shower after this match time (local), or a huge number if none is left.
func next_meteor(after: float) -> float:
	var k := 1
	while k * METEOR_EVERY < SESSION - 60.0:
		var lt := k * METEOR_EVERY - t0
		if lt > after + 20.0:
			return lt
		k += 1
	return 1e9

## The next wave still to come: {t (session), n} or {}.
func next_wave() -> Dictionary:
	for w in waves:
		if int(w["i"]) > join_i and String(w["state"]) == "planned":
			return w
	return {}

func waves_left() -> int:
	return waves.filter(func(w): return int(w["i"]) > join_i and String(w["state"]) == "planned").size()

func flying_waves() -> Array:
	return waves.filter(func(w): return int(w["i"]) != join_i and String(w["state"]) == "flying")

# ---- bots: how long they mean to stay (Bot uses these in place of the match clock)
func team_elapsed(team: int) -> float:
	return m.time - float(team_land.get(team, m.time))

func team_time_left(team: int) -> float:
	var left := float(team_stay.get(team, STAY.y)) - team_elapsed(team)
	return minf(left, m.length - m.time)

# ---- screenshots (--rolling-demo=wave|bounty|map with --rolling-shot=<png>)
var _demo := {}

## Tooling: skips your drop, then sets up the moment to show and saves the screenshot itself.
##   wave:   the next drop wave gliding down onto the island you're on
##   bounty: a rival with a bounty on them a few metres away (nameplate, minimap, session row)
##   map:    the full map with a drop wave in the air and a bounty marked
func demo(mode: String) -> void:
	var P := m.player
	if P == null or (m.skydrop and m.skydrop.planning):
		return
	if not _demo.has("down"):
		if P.riding:
			# skip your own drop: straight onto a quiet spot under your ship's line
			var sp: Array = spots_along(m.ship, 1)
			P.riding = false
			P.teleport(m.world.free_spot_near(sp[0], [], 1.0, 0.45, 8.0))
			m.on_drop_landed(P)
		if P.riding or P.dropping:
			return
		_demo["down"] = true
		_demo["t"] = m.time
		P.ctrl = "idle"
		Game.god = true
		Settings.v["tips"] = false
		if m.hud: m.hud.guide_hidden = true
	var nw := next_wave()
	if mode in ["wave", "map"] and not _demo.has("warp") and not nw.is_empty() and m.time - float(_demo["t"]) > 0.5:
		_demo["warp"] = true
		m.time = maxf(m.time, float(nw["t"]) - m.sess_t0 - 0.05)     # (the clock skips to the wave)
	if mode in ["wave", "map"] and _demo.has("warp") and not _demo.has("wave") and not m.ships.is_empty():
		_demo["wave"] = m.ships[-1]
		# stand where its first squad means to land; they come down onto you
		var lead: Hunter = null
		for h in m.hunters:
			if h.riding and is_same(m.ship_of(h), _demo["wave"]): lead = h; break
		if lead:
			_demo["lead"] = lead
			var at: Vector3 = lead.ai.get("land", lead.pos)
			P.teleport(m.world.free_spot_near(at + Vector3(4.0, 0, 3.0), [at], 2.0, 0.45, 10.0))
	if mode in ["bounty", "map"] and not _demo.has("bounty") and m.time - float(_demo["t"]) > 0.3:
		var rv: Hunter = null; var bd := 1e9
		for h in m.hunters:
			if h.team != P.team and on_map(h) and P.flat_dist(h) < bd: bd = P.flat_dist(h); rv = h
		if rv:
			_demo["bounty"] = rv
			set_level(rv, 9)
			_update_median()
			_update_bounties()
			if mode == "bounty":
				rv.teleport(m.world.free_spot_near(P.pos + Vector3(4.5, 0, -2.0), [P.pos], 2.5, 0.45, 8.0))
				rv.ctrl = "idle"
	if mode == "bounty" and _demo.has("bounty"):
		var rv2: Hunter = _demo["bounty"]
		P.inp["aim"] = rv2.pos + Vector3(0, 0.9, 0)
		if m.time - float(_demo["t"]) > 1.6: _shoot()
	if mode == "wave" and _demo.has("lead"):
		var ld: Hunter = _demo["lead"]
		var gy := m.world.ground_at(ld.pos.x, ld.pos.z) if not m.world.is_void(ld.pos.x, ld.pos.z) else ld.pos.y - 20.0
		# (armed while they're still well up, so they're mid-descent when the frames have drawn)
		if not _demo.has("armed") and ((ld.dropping and ld.pos.y - gy < 22.0) or (not ld.riding and not ld.dropping)):
			_demo["armed"] = true
			# stand just under where they are now, so the camera has them gliding in overhead
			var under := Vector3(ld.pos.x, 0, ld.pos.z)
			P.teleport(m.world.free_spot_near(under + Vector3(2.5, 0, 3.5), [under], 1.5, 0.45, 12.0))
			# a calm frame: your squad up and beside you, nobody else's fight on screen
			for h in m.hunters:
				if h != P and h.team == P.team:
					h.downed = false; h.hp = h.max_hp
					h.teleport(m.world.free_spot_near(P.pos + Vector3(-1.5, 0, 1.0), [P.pos], 0.8, 0.45, 6.0))
					h.ctrl = "idle"
				elif not h.riding and not h.dropping and not h.out and h.flat_dist(P) < 26.0:
					h.teleport(m.world.free_spot_near(h.pos + (h.pos - P.pos).normalized() * 30.0, [], 1.0, 0.45, 20.0))
			if m.hud:
				m.hud.msgs.clear()
	if _demo.has("armed"):
		_shoot()
	if mode == "map" and _demo.has("wave") and _demo.has("bounty"):
		if not _demo.has("open") and m.hud:
			_demo["open"] = true
			_demo["t_open"] = m.time
			m.hud.open_map(false)
		elif _demo.has("open") and m.time - float(_demo["t_open"]) > 4.0:
			_shoot()

func _shoot() -> void:
	if _demo.has("shot"):
		return
	_demo["n"] = int(_demo.get("n", 0)) + 1
	if int(_demo["n"]) < 20:
		return        # (a few frames for everything to draw)
	_demo["shot"] = true
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rolling-shot="): path = a.substr(15)
	if path != "":
		m.get_viewport().get_texture().get_image().save_png(path)
		print("ROLLING SHOT ", path, " at ", fmt(m.sess_time()))
	m.get_tree().quit()

# ---- bookkeeping for the sim
func _track() -> void:
	for h in m.hunters:
		if h.extracted and not _seen_ext.has(h.nid):
			_seen_ext[h.nid] = true
			(stats["extracts"] as Array).append([snappedf(m.sess_time(), 1.0), h.lvl, int(h.get_meta("wave", join_i))])
		elif h.out and not h.extracted and not _seen_out.has(h.nid) and (h.gone or not Life.team_alive(m, h.team)):
			_seen_out[h.nid] = true
			(stats["outs"] as Array).append([snappedf(m.sess_time(), 1.0), h.lvl, int(h.get_meta("wave", join_i))])

static func fmt(t: float) -> String:
	var s := int(maxf(0.0, t))
	return "%d:%02d" % [s / 60, s % 60]
