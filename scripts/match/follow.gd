class_name Follow
extends RefCounted
## Follower Boki (owner decision, ROADMAP §2 "Tamed Boki follow you"). A Boki you tame on a run
## walks beside you as a second Boki instead of going into your bag: one at a time; a second tame
## while you already have one goes in the bag as before. It doesn't fight, but it scouts: it pings
## rival hunters it notices near you.
##
## While you're in the map it's yours alone. It can be knocked out (it lies dazed where it fell and
## only you can pick it back up), but nobody else can tame it, not even while you're down or dead and
## waiting on a revive. Extract with it beside you (or riding in your satchel) and it comes home.
##
## Once you've left the map (out for good, or extracted without it: it was knocked out or far away)
## it's a stray. Rivals then get a steal window to tame it, by the run's tier (Data.TIERS
## "follow_steal": the Meadow none, the Dusk Isles 10 s, the Hollow 30 s). Taming a stray is slow
## (the tier's capture_time) and a hit on the tamer starts it over. If nobody manages it, it goes home
## to its hunter. A teammate can't take it: it's coming home anyway.
##
## Online: a follower is owned by its hunter's game (nid "<hunter nid>|f<n>", see Net.owner_of) and
## stays that way as a stray, so the owner's game decides who tamed it. The owner's game stays in the
## match while its stray's window runs (Match._end_soon), with the camera on it.
##
## Bots own followers (they pick a knocked-out one back up) and go after rivals' strays.

const NEAR := 2.4            # where it walks: about this far behind you
const TUCK_AT := 13.0        # further than this (or you're in the air or over the abyss): it rides in your satchel
const HOME_R := 14.0         # extract with it this close (or in the satchel) and it comes with you
const SCOOP_R := 3.8         # extract with it down this close and you scoop it up on the way out
const NET_AT := 23           # where the follower fields start in a Kin snapshot (after KinNet's 19..22)
const SCOUT_R := 13.0        # it calls out rival hunters this close to you
const SCOUT_AGAIN := 15.0

## Seconds rivals get to tame a stray in this match (0: it goes straight home).
static func steal_secs(m) -> float:
	return float(m.T.get("follow_steal", 0.0))

## The hunter's follower, if it has one in the match.
static func of(h) -> Kin:
	if h == null:
		return null
	var f = h.get("follower")
	if f is Kin and is_instance_valid(f) and not (f as Kin).dead and (f as Kin).role == "follow":
		return f
	return null

## Somebody just tamed a Boki. A fresh wild one becomes their follower if they don't have one yet;
## anything else (a second tame, someone's lost Boki, a rival's stray) goes in the bag as before.
## Online, a remote hunter's tame is theirs to decide: their game gets the "caught" event.
static func take(m, h, rec: Dictionary, at: Vector3) -> Kin:
	if h.remote or not can_follow(m, h, rec):
		h.caught.append(rec)
		return null
	return spawn(m, h, rec, at)

static func can_follow(m, h, rec: Dictionary) -> bool:
	if m.opts.get("tutorial", false) or m.opts.get("training", false) or m.opts.get("no_follow", false):
		return false
	if String(rec.get("lost_from", "")) != "":
		return false
	return of(h) == null and not h.out and not h.extracted

## A follower for this hunter, standing at `at`.
static func spawn(m, h, rec: Dictionary, at: Vector3) -> Kin:
	var n := int(h.get_meta("follow_n", 0)) + 1
	h.set_meta("follow_n", n)
	var k := Kin.new()
	k.init_kin(m, "%s|f%d" % [h.nid, n], String(rec["species"]), rec, h)
	k.role = "follow"
	k.state = "follow"
	k.comp = null        # it scouts on its own (_scout); your partner stays the one that talks to you
	m.add_child(k)
	k.teleport(at)
	m.kins.append(k)
	m.ents_by_id[k.nid] = k
	h.follower = k
	m.kstat["follow"] = int(m.kstat.get("follow", 0)) + 1
	if h == m.player:
		m.add_feed("%s follows you now. Keep it safe and extract together." % Data.kin_title(String(rec.get("name", "")), Data.KIN[k.species]["name"]))
		if m.hud:
			m.hud.toast("Your new Boki follows you. Nobody can take it while you're in the map", Color("fff2a0"))
	return k

# ------------------------------------------------------------------ simulation (the owner's game)
static func sim_follow(k: Kin, dt: float) -> void:
	var h: Hunter = k.owner_h
	if h == null:
		return
	if k.state == "shoulder":
		# it came round (KinDowned.come_round hops a Boki onto the shoulder): back to walking beside you
		k.state = "follow"
		k.tucked = true
		k.hp = maxf(k.hp, 1.0)
	if h.out or h.extracted:
		# you're down for the count (or gone): it waits where it is
		k.tucked = false
		k._ground_move(Vector2.ZERO, dt)
		return
	var air: bool = h.dropping or h.riding or h.gliding or h.over_void() or (not h.grounded and h.pos.y - k.pos.y > 3.0)
	var far := k.flat_dist(h) > TUCK_AT or absf(h.pos.y - k.pos.y) > 2.6
	if air or far:
		if not k.tucked:
			k.tucked = true
			k.vel = Vector3.ZERO
		k.pos = h.pos + Vector3(0, 1.2, 0)
		k.prev = k.pos
		return
	if k.tucked:
		# out of the satchel, beside you
		k.tucked = false
		var back := Vector3(sin(h.face), 0, cos(h.face)) * 1.2
		var at: Vector3 = h.pos + back
		if m_void(k, at): at = h.pos
		k.teleport(Vector3(at.x, k.m.world.ground_at(at.x, at.z), at.z))
		k.vel = Vector3.ZERO
	# trot along a little behind you, a touch faster than you so it never falls behind for long
	var behind := Vector3(sin(h.face), 0, cos(h.face)) * NEAR
	var goal: Vector3 = h.pos + behind
	if m_void(k, goal) or not k.walkable_to(goal):
		goal = h.pos
	var to := Vector2(goal.x - k.pos.x, goal.z - k.pos.z)
	var wish := Vector2.ZERO
	if to.length() > 0.6:
		wish = to.normalized() * maxf(k.speed, h.base_speed * 1.15) * clampf(to.length() / 2.0, 0.35, 1.25)
	k._ground_move(wish, dt)
	if k.bark_cd <= 0.0 and h.is_local():
		_scout(k, h)

static func m_void(k: Kin, p: Vector3) -> bool:
	return k.m.world.is_void(p.x, p.z) or k.m.world.is_block(p.x, p.z)

## It doesn't fight, but it watches: a rival hunter close to you gets a ping and a word.
static func _scout(k: Kin, h: Hunter) -> void:
	for f in k.m.hunters:
		if f.team == h.team or not f.targetable() or f.flat_dist(h) > SCOUT_R:
			continue
		if k.callout_seen.has(f.nid) and k.m.time - float(k.callout_seen[f.nid]) < SCOUT_AGAIN:
			continue
		k.callout_seen[f.nid] = k.m.time
		k.bark_cd = 3.0
		k.m.ping(f.pos, Color("ffcf8a"))
		k.m.add_feed("%s spotted %s %s" % [k.rec.get("name", "Your follower"), f.pname, k.m.direction_word(h.pos, f.pos)])
		return

## A follower goes down like any Boki (KinDowned: it stays where it fell, you run into it to scoop it
## up, or it comes round on its own). This only keeps the books for the results.
static func on_down(k: Kin) -> void:
	k.m.kstat["follow_ko"] = int(k.m.kstat.get("follow_ko", 0)) + 1

# ------------------------------------------------------------------ the owner leaves the map
## Its hunter left the map: out for good ("gone") or extracted ("extract"). Runs on the owner's game.
static func owner_left(m, h: Hunter, how: String) -> void:
	if h.remote:
		return
	var k := of(h)
	if k == null:
		return
	# beside you (or in your satchel) it comes too; knocked out right at your feet, you scoop it up
	var with_you: bool = how == "extract" and ((k.state == "follow" and (k.tucked or k.flat_dist(h) <= HOME_R)) or (k.state == "downed" and not k.down_void and k.flat_dist(h) <= SCOOP_R))
	var secs := steal_secs(m)
	if with_you or secs <= 0.0:
		_go_home(m, k, "extracted with you" if with_you else "found its way home")
		return
	# a stray: rivals get the window
	k.role = "stray"
	k.state = "dazed"
	k.tucked = false
	k.down_void = false
	k.down_t = 0.0
	k.dazed_t = 1e9
	k.hp = maxf(k.hp, 1.0)
	k.catch_prog = 0.0
	k.steal_t = secs
	k.steal_from = h.pname
	k.steal_owner = h
	k.steal_owner_nid = h.nid
	k.steal_team = h.team
	k.lost_from = h.pname
	k.lost_uid = String(k.rec.get("uid", ""))
	# whoever tames it takes it home as someone else's Boki (Game.apply_result: "taken")
	k.rec["lost_from"] = h.pname
	k.rec["prev_trust"] = float(k.rec.get("trust", 20.0))
	k.owner_h = null
	k.team = -1
	h.follower = null
	h.set_meta("stray", k)
	m.kstat["stray"] = int(m.kstat.get("stray", 0)) + 1
	m.fx.ring(k.pos, 2.2, Color("fff2a0"), 0.5)
	if h == m.player:
		m.add_feed("%s is on its own. Rivals have %d s to tame it" % [k.rec.get("name", "Your follower"), int(secs)])
		if m.hud: m.hud.toast("%s is on its own: rivals have %d s to tame it" % [k.rec.get("name", "Your follower"), int(secs)], Color("ffd23f"))
	elif m.player and not m.player.out and not m.player.extracted and m.player.team != h.team:
		m.add_feed("%s left a Boki behind %s. Tame it in %d s!" % [h.pname, m.direction_word(m.player.pos, k.pos), int(secs)])
		m.ping(k.pos, Color("fff2a0"))

static func _go_home(m, k: Kin, why: String) -> void:
	var h: Hunter = k.owner_h if k.owner_h else k.steal_owner
	if h == m.player and h:
		m.set_meta("follow_fate", {"rec": k.rec.duplicate(true), "fate": "home", "why": why})
	k.dead = true
	k.visible = false
	if h: h.follower = null
	m.kstat["follow_home"] = int(m.kstat.get("follow_home", 0)) + 1
	if m.net_on: m.net_event(["fgone", k.nid])

## Strays count down; when the window closes they go home. Runs every step (owner's game only).
static func tick(m, dt: float) -> void:
	for k in m.kins:
		if k.dead or k.role != "stray" or k.remote:
			continue
		k.steal_t -= dt
		if k.steal_t <= 0.0:
			if k.steal_owner == m.player and m.player:
				m.add_feed("Nobody tamed %s. It's on its way home" % k.rec.get("name", "your follower"))
			_go_home(m, k, "waited out the rivals and went home")

## A rival tamed the stray (from Match._catch, on the owner's game).
static func stolen(m, k: Kin, by: Hunter) -> void:
	m.kstat["stolen"] = int(m.kstat.get("stolen", 0)) + 1
	if by: by.stolen_carry = true      # it struggles a little: the thief is slower
	if k.steal_owner == m.player and m.player:
		m.set_meta("follow_fate", {"rec": k.rec.duplicate(true), "fate": "stolen", "holder": by.pname if by else ""})
		m.add_feed("%s tamed %s!" % [by.pname if by else "A rival", k.rec.get("name", "your follower")])

## Can this hunter tame this stray? (Its own squad can't: it's going home anyway.)
static func can_steal(h: Hunter, k: Kin) -> bool:
	return k.role != "stray" or (h.team != k.steal_team and h.nid != k.steal_owner_nid)

## How far a tame of a stray gets: a hit on the tamer starts it over.
static func steal_progress(m, h: Hunter, k: Kin, dt: float) -> void:
	if m.time - h.hurt_at < 0.25:
		k.catch_prog = 0.0
		return
	k.catch_prog += dt / float(m.T.get("capture_time", 3.0))

## The player's stray, while its window runs (the camera and the HUD watch it), or null.
static func watch(m) -> Kin:
	if m.player == null:
		return null
	if not m.player.has_meta("stray"):
		return null
	var k = m.player.get_meta("stray")
	if k is Kin and is_instance_valid(k) and not (k as Kin).dead and (k as Kin).role == "stray":
		return k
	return null

## What happened to the player's follower, for the results (and the save): {} if there wasn't one.
## A window still running when the match ends is settled by who was close enough to take it.
static func result(m) -> Dictionary:
	if m.player == null:
		return {}
	var f := of(m.player)
	if f and m.player.extracted and (f.tucked or f.flat_dist(m.player) <= HOME_R):
		return {"rec": f.rec.duplicate(true), "fate": "home", "why": "extracted with you"}
	if f:
		# the match ended with it still at your side, but you never made it out: it found its way home
		# in the Meadow; in the deeper tiers the owner left the map, so it was a stray that nobody saw
		return {"rec": f.rec.duplicate(true), "fate": "home", "why": "found its way home"}
	var w := watch(m)
	if w:
		var best: Hunter = null; var bd := 10.0
		for o in m.hunters:
			if o.out or o.extracted or o.team == int(w.steal_team): continue
			var d: float = o.flat_dist(w)
			if d < bd: bd = d; best = o
		if best and m.rng.randf() < 0.85 * (1.0 - bd / 10.0) * clampf(w.steal_t / 10.0, 0.3, 1.0):
			return {"rec": w.rec.duplicate(true), "fate": "stolen", "holder": best.pname}
		return {"rec": w.rec.duplicate(true), "fate": "home", "why": "waited out the rivals and went home"}
	return m.get_meta("follow_fate", {})

# ------------------------------------------------------------------ bots
## The one hook bot.gd calls: our knocked-out follower first, then a rival's stray. [pos, kind] or [].
static func bot_goals(m, h: Hunter) -> Array:
	var g := bot_goal(m, h)
	return g if not g.is_empty() else bot_steal(m, h)

## A bot's goal for its follower: run into it when it's down nearby, like BotKin.rescue_goal. [pos, kind] or [].
static func bot_goal(m, h: Hunter) -> Array:
	var f = h.get("follower")
	if f is Kin and is_instance_valid(f) and not (f as Kin).dead and (f as Kin).state == "downed" and not (f as Kin).down_void and not h.downed and h.flat_dist(f) < 40.0:
		return [(f as Kin).pos, "boki"]
	return []

## A rival's stray in reach: worth the walk while the window's open. [pos, kind] or [].
static func bot_steal(m, h: Hunter) -> Array:
	var best: Kin = null; var bd := 40.0
	for k in m.kins:
		if k.dead or k.role != "stray" or not can_steal(h, k):
			continue
		var d := h.flat_dist(k)
		# only if we can get there before the window closes (about 5 m a second, plus the tame)
		if d < bd and d / 5.0 + float(m.T.get("capture_time", 3.0)) < k.steal_t + 1.0:
			bd = d; best = k
	return [best.pos, "catch"] if best else []

## Your follower's steal window keeps the match going for you (watching it) until it's settled.
static func finish_later(m: Match) -> void:
	if m.over:
		return
	var w: Kin = watch(m)
	if w and not m._finish_now and m.is_inside_tree() and m.time < m.length + 2.0:
		m.get_tree().create_timer(0.25).timeout.connect(finish_later.bind(m))
		return
	m._finish()

# ------------------------------------------------------------------ the network
## The follower's own snapshot fields, after KinNet's: [role, in the satchel, steal seconds left, its hunter's nid, its name, its team].
static func net_extra(k: Kin) -> Array:
	return [Match.KIN_ROLES.find(k.role), 1 if k.tucked else 0, snappedf(k.steal_t, 0.01), k.steal_owner_nid, k.steal_from, k.steal_team]

static func net_role(it: Array) -> int:
	return int(it[NET_AT]) if it.size() > NET_AT + 5 else 0

static func net_apply(k: Kin, it: Array) -> void:
	if it.size() <= NET_AT + 5:
		return
	var ri := int(it[NET_AT])
	k.role = String(Match.KIN_ROLES[ri]) if ri >= 0 and ri < Match.KIN_ROLES.size() else ""
	k.tucked = int(it[NET_AT + 1]) == 1
	k.steal_t = float(it[NET_AT + 2]); k.steal_owner_nid = String(it[NET_AT + 3]); k.steal_from = String(it[NET_AT + 4]); k.steal_team = int(it[NET_AT + 5])
	if k.role == "stray" and k.owner_h:
		k.owner_h.follower = null
		k.owner_h = null
		k.team = -1
