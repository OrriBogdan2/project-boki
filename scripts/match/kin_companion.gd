class_name KinCompanion
extends RefCounted
## A Boki as a teammate, not a summon. Every kin that belongs to a hunter (yours, your squad's bots,
## rival squads') carries one of these. It watches the world for its hunter and:
##
##   * calls things out: a rival behind you, a sniper, a monster pack ahead, a boss fight, a Rare Egg,
##     loot, a wild Boki, your low health, the way out. Each callout is a world ping (your squad sees
##     it, and online it goes out as an "ev" event), body language (it turns, points, growls or
##     whines) and a short bark in its own talking level (BokiChatter.line: a hatchling only says its
##     name, with what it's doing in brackets; a grown Boki uses words).
##     Callouts have a priority, a cooldown per kind and a quiet gap between them, so it never
##     chatters over itself; the "Boki chattiness" setting (quiet / normal / chatty) and its
##     personality (timid warns more, bold eggs you on, curious points at loot) shape how often.
##   * cares: flinches when you're hit, frets and nudges you at low health (and once a run, if it
##     trusts you, brings you a tonic it found), stands over you when you're down, cheers knocks,
##     boss kills and extraction with you, and stays close after a loss. The big moments are written
##     to its memory (Kin.note), so back home it brings them up (BokiLines "back_" lines).
##   * keeps close: the spot at your heel or flank it walks to (heel_spot), stepping between you and
##     a threat or covering your back, and leading the way in the tutorial (tut).
##
## Kin owns the body (where it is, how it moves); this decides what it notices and says.

const CATS := {
	# kind: [priority, cooldown (s), group]
	"behind": [100, 9.0, "threat"],
	"sniper": [95, 14.0, "threat"],
	"hunter": [90, 10.0, "threat"],
	"low_hp": [85, 22.0, "care"],
	"collapse": [84, 50.0, "path"],
	"cover": [75, 25.0, "care"],
	"boss": [70, 45.0, "threat"],
	"egg": [66, 30.0, "find"],
	"pack": [60, 18.0, "threat"],
	"exit": [55, 40.0, "path"],
	"wild": [45, 20.0, "find"],
	"loot": [30, 16.0, "find"],
	"goad": [20, 25.0, "care"],
}
## The quiet gap between two callouts, by the chattiness setting (seconds).
const GAP := {"quiet": 9.0, "normal": 4.5, "chatty": 2.6}
## Quiet only speaks up for things that matter.
const MIN_PRI := {"quiet": 80, "normal": 0, "chatty": 0}
const COLS := {"threat": Color("ff7a5c"), "find": Color("ffd56a"), "care": Color("ff9be0"), "path": Color("8fe3c8")}
const LABELS := {"behind": "Behind you!", "sniper": "Sniper", "hunter": "Hunter", "pack": "Monsters", "boss": "Boss fight",
	"egg": "Rare Egg", "loot": "Loot", "wild": "Wild Boki", "exit": "Way out", "collapse": "Way out"}
## What its body does for each callout (KinPuppet reads the pose).
const POSES := {"behind": "growl", "sniper": "alert", "hunter": "growl", "pack": "growl", "boss": "alert", "egg": "point",
	"loot": "point", "wild": "point", "exit": "beckon", "collapse": "beckon", "low_hp": "whine", "cover": "guard", "goad": "cheer"}

var k: Kin
var m
var scan_t := 0.0
var gap_t := 0.0            # until another callout may fire
var last_t := -99.0         # when the last one fired
var cds := {}               # kind -> time it may fire again
var seen := {}              # thing key -> time it was called (or noticed)
var pose := ""              # growl | alert | point | whine | beckon | guard | cheer | flinch | comfort | nudge
var pose_t := 0.0
var look := Vector3.INF     # where its head turns
var look_t := 0.0
var threat: Ent = null      # the nearest foe close to its hunter (who it stands in front of)
var history: Array = []         # every callout and reaction: {t, cat, pri} (tests, debugging)
var tonic_given := false
var yelp_cd := 0.0
var cheer_cd := 0.0
var noted := {}             # memory kinds already written this match
var ping_ref: Dictionary = {}
var ping_follow: Ent = null
var side := 1.0             # which flank it walks on
var guide := {}             # the tutorial step it's cheering you through: {id, to, t, said, demo_t}
var demo := {}              # a little demonstration it's doing: {kind, t}

func _init(kin: Kin) -> void:
	k = kin
	m = kin.m
	side = 1.0 if absi(kin.nid.hash()) % 2 == 0 else -1.0
	scan_t = float(absi(kin.nid.hash()) % 7) * 0.05

func h() -> Hunter:
	return k.owner_h

# ------------------------------------------------------------------ settings and personality
## quiet | normal | chatty. Only your own Boki follows your setting; everyone else's is normal.
func chatter() -> String:
	if h() == null or not h().is_local():
		return "normal"
	var c := String(Settings.get_v("kin_chatter"))
	return c if GAP.has(c) else "normal"

## timid | bold | curious | loyal | steady: the side of it that shows in a fight.
func nature() -> String:
	if k.t("bravery") < 0.4: return "timid"
	if k.t("bravery") > 0.66: return "bold"
	if k.t("curiosity") > 0.62: return "curious"
	if k.t("loyalty") > 0.66: return "loyal"
	return "steady"

func _cd_of(cat: String) -> float:
	var c: float = float(CATS[cat][1])
	var grp := String(CATS[cat][2])
	match nature():
		"timid": if grp == "threat": c *= 0.7
		"bold": if grp == "threat": c *= 1.25
		"curious": if grp == "find": c *= 0.6
		"loyal": if grp == "care": c *= 0.6
	match chatter():
		"quiet": c *= 1.6
		"chatty": c *= 0.7
	return c

func _pri_of(cat: String) -> int:
	var p := int(CATS[cat][0])
	var grp := String(CATS[cat][2])
	if nature() == "curious" and grp == "find": p += 25
	if nature() == "timid" and grp == "threat": p += 5
	return p

func _gap() -> float:
	var g: float = GAP[chatter()]
	if nature() == "timid": g *= 0.85
	return g

## Which way its hunter is looking (flat, normalized).
func aim_dir() -> Vector2:
	var o := h()
	var a = o.inp.get("aim", Vector3.ZERO) if o.inp else Vector3.ZERO
	var d := Vector2.ZERO
	if a is Vector3 and (a as Vector3) != Vector3.ZERO:
		d = Vector2(a.x - o.pos.x, a.z - o.pos.z)
	if d.length() < 0.3:
		d = Vector2(-sin(o.face), -cos(o.face))
	return d.normalized()

# ------------------------------------------------------------------ every step
## Ticks on the machine that runs this kin (not remote copies).
func tick(dt: float) -> void:
	_decay(dt)
	var o := h()
	if o == null or o.out or o.extracted or o.dropping or o.riding:
		return
	if ping_ref.size() > 0 and ping_follow and is_instance_valid(ping_follow) and not ping_follow.dead:
		ping_ref["pos"] = ping_follow.pos
	scan_t -= dt
	if scan_t > 0.0:
		return
	scan_t = 0.4
	_find_threat()
	if o.downed:
		# standing over you: facing down whoever's close, or nudging you to get up
		if threat and is_instance_valid(threat):
			pose = "guard"; look = threat.pos
		else:
			pose = "nudge"; look = o.pos
		pose_t = 0.6; look_t = 0.6
		return
	if not k.ready_to_fight() or k.state in ["flying", "flying_home"]:
		return
	if guide.size() > 0:
		_tut_tick()
	_almost_home()
	if m.opts.get("arena", false):
		return      # (the Arena's dummies and sparring bot aren't hunters to warn you about)
	var best := _best_callout()
	if best.is_empty():
		return
	callout(String(best["cat"]), best["at"], best.get("follow", null), String(best.get("key", "")))

## Cosmetic timers only (remote copies tick this too).
func _decay(dt: float) -> void:
	pose_t = maxf(0.0, pose_t - dt)
	if pose_t <= 0.0: pose = ""
	look_t = maxf(0.0, look_t - dt)
	if look_t <= 0.0: look = Vector3.INF
	gap_t = maxf(0.0, gap_t - dt)
	yelp_cd = maxf(0.0, yelp_cd - dt)
	cheer_cd = maxf(0.0, cheer_cd - dt)
	if demo.size() > 0:
		demo["t"] = float(demo["t"]) + dt
		if float(demo["t"]) > 0.9: demo = {}

func _find_threat() -> void:
	threat = null
	var o := h()
	var bd := 10.0
	for f in m.foes_of(o.team):
		if f == k or (f is Kin and (f as Kin).owner_h == o) or Shrubling.hidden(f):
			continue
		if f is Mob and not ((f as Mob).tgt == o or (f as Mob).tgt == k or o.flat_dist(f) < 5.0):
			continue
		var d: float = o.flat_dist(f)
		if d < bd:
			bd = d; threat = f

## What's worth saying right now, if anything: {cat, at, follow, key}.
func _best_callout() -> Dictionary:
	var o := h()
	var now: float = m.time
	var cands: Array = []
	var fwd := aim_dir()
	var timid := nature() == "timid"
	var curious := nature() == "curious"
	var reach := 15.0 + k.t("curiosity") * 5.0 + (4.0 if timid else 0.0)
	# rival hunters
	for f in m.hunters:
		if f.team == o.team or not f.targetable():
			continue
		var d: float = o.flat_dist(f)
		if d > reach:
			continue
		var key: String = "h" + f.nid
		if _seen_recent(key, 14.0):
			continue
		var to := Vector2(f.pos.x - o.pos.x, f.pos.z - o.pos.z).normalized()
		if o.is_local() and m.cam and m.cam.on_screen(f.pos) and d < 7.0:
			seen[key] = now       # right in front of you: nothing to add
			continue
		var cat := "hunter"
		if to.dot(fwd) < -0.35:
			cat = "behind"
		elif float(f.wpn.get("range", 0.0)) >= 14.0 and d > 11.0:
			cat = "sniper"
		cands.append({"cat": cat, "at": f.pos, "follow": f, "key": key})
	# a monster pack ahead that isn't on you yet
	var near_mobs: Array = []
	for mb in m.mobs:
		if not mb.dead and o.flat_dist(mb) < 16.0 and not (mb is Boss):
			near_mobs.append(mb)
	if near_mobs.size() >= 3:
		for mb in near_mobs:
			if mb.tgt == o or mb.tgt == k:
				continue
			var n := 0
			var c := Vector3.ZERO
			for mb2 in near_mobs:
				if mb.flat_dist(mb2) < 5.5:
					n += 1; c += mb2.pos
			if n >= 3:
				c /= n
				var key: String = "p%d_%d" % [int(c.x / 8.0), int(c.z / 8.0)]
				if not _seen_recent(key, 45.0) and Vector2(c.x - o.pos.x, c.z - o.pos.z).normalized().dot(fwd) > -0.2:
					cands.append({"cat": "pack", "at": c, "key": key})
				break
	# a boss fight close by
	if m.lairs:
		for L in m.lairs.list:
			if String(L.get("state", "")) in ["awake"] and L.has("c"):
				var lc: Vector3 = L["c"]
				var key: String = "L" + String(L.get("name", ""))
				if o.flat_dist(lc) < 34.0 and not _seen_recent(key, 90.0):
					cands.append({"cat": "boss", "at": lc, "key": key})
	# Rare Eggs and good loot
	var lr := 9.0 + (5.0 if curious else 0.0) + k.t("curiosity") * 2.0
	for wp in m.wpicks:
		var wpos: Vector3 = wp["pos"]
		var key: String = "w" + String(wp["id"])
		if seen.has(key):
			continue
		if wp.get("egg", false) and o.flat_dist(wpos) < 22.0:
			cands.append({"cat": "egg", "at": wpos, "key": key})
		elif int(wp.get("rar", 0)) >= 3 and o.flat_dist(wpos) < lr:
			cands.append({"cat": "loot", "at": wpos, "key": key})
	for i in m.chests.size():
		var c: Dictionary = m.chests[i]
		if c["open"] or c.has("ride"):
			continue
		var key: String = "c%d" % i
		if not seen.has(key) and o.flat_dist(c["pos"]) < lr:
			cands.append({"cat": "loot", "at": c["pos"], "key": key})
	# wild Boki
	for wk in m.kins:
		if wk.is_wild() and not wk.dead and wk.state == "wild" and not seen.has("k" + wk.nid) and o.flat_dist(wk) < reach * 0.8:
			cands.append({"cat": "wild", "at": wk.pos, "follow": wk, "key": "k" + wk.nid})
	# the way out
	if m.exits and not m.opts.get("tutorial", false):
		var left: float = m.length - m.time
		var best_x: Dictionary = {}
		var bxd := 1e9
		for x in m.exits.list:
			var usable: bool = m.exits.callable(x) or m.exits.startable(x) or (String(x["state"]) == "open" and int(x.get("team", -1)) == o.team)
			if usable and o.flat_dist(x["pos"]) < bxd:
				bxd = o.flat_dist(x["pos"]); best_x = x
		if not best_x.is_empty():
			var xp: Vector3 = best_x["pos"]
			if left < 45.0:
				cands.append({"cat": "collapse", "at": xp, "key": "collapse"})
			elif bxd < 30.0 and not seen.has("x%d" % m.exits.list.find(best_x)):
				cands.append({"cat": "exit", "at": xp, "key": "x%d" % m.exits.list.find(best_x)})
	# looking after you
	if not o.downed and o.hp < o.max_hp * 0.35:
		cands.append({"cat": "low_hp", "at": o.pos, "key": ""})
	if not o.downed and not o.wpn.get("melee", false) and o.reload_t > 0.0 and threat is Hunter:
		cands.append({"cat": "cover", "at": threat.pos, "key": ""})
	if nature() == "bold" and threat is Hunter and threat.hp < threat.max_hp * 0.4 and not (threat as Hunter).downed:
		cands.append({"cat": "goad", "at": threat.pos, "key": ""})
	# the most important one that's allowed
	var best: Dictionary = {}
	var bp := -1
	for c in cands:
		var cat := String(c["cat"])
		var p := _pri_of(cat)
		if p <= bp or p < int(MIN_PRI[chatter()]):
			continue
		if now < float(cds.get(cat, -1.0)):
			continue
		best = c; bp = p
	if best.is_empty():
		return {}
	# the quiet gap: only something urgent cuts in (and never right on top of the last line)
	if gap_t > 0.0 and not (bp >= 95 and now - last_t > 1.5):
		return {}
	best["pri"] = bp
	return best

func _seen_recent(key: String, ttl: float) -> bool:
	return seen.has(key) and m.time - float(seen[key]) < ttl

# ------------------------------------------------------------------ doing it
## Says and shows one callout: a ping for its squad, its body turning to it, and a bark.
func callout(cat: String, at: Vector3, follow = null, key := "") -> void:
	var now: float = m.time
	if key != "": seen[key] = now
	cds[cat] = now + _cd_of(cat)
	gap_t = _gap()
	last_t = now
	history.append({"t": now, "cat": cat, "pri": _pri_of(cat) if CATS.has(cat) else 0})
	if cat == "low_hp":
		_care_low_hp()
	_show(cat, at, follow)
	if m.net_on and h() and not h().remote:
		m.net_event(["kc", k.nid, cat, snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)])

## The visible part of a callout (also what a remote copy does when it hears one online).
func _show(cat: String, at: Vector3, follow = null) -> void:
	pose = String(POSES.get(cat, "alert"))
	pose_t = 1.8
	if cat != "low_hp" and cat != "goad":
		look = at; look_t = 2.2
	else:
		look = h().pos if h() else at; look_t = 1.5
	var grp := String(CATS[cat][2]) if CATS.has(cat) else "find"
	if LABELS.has(cat) and m.player and h() and h().team == m.player.team:
		ping_ref = m.kin_ping(k, at, COLS[grp], String(LABELS[cat]))
		ping_follow = follow if follow is Ent else null
	var txt := BokiChatter.line(k, cat)
	if txt != "":
		m.kin_bark(k, txt, cat)
	if grp == "threat" and m.fx:
		m.fx.ring(k.position if k.is_inside_tree() else k.pos, 0.9, Color(COLS["threat"], 0.7), 0.3)

## A callout heard over the network (Match._net_ev "kc").
func heard(cat: String, at: Vector3) -> void:
	if not CATS.has(cat):
		return
	history.append({"t": m.time, "cat": cat, "pri": int(CATS[cat][0]), "net": true})
	_show(cat, at)

func _care_low_hp() -> void:
	var o := h()
	# once a run, a Boki that trusts you turns up a tonic it sniffed out (only when it's calm enough to look)
	if not tonic_given and not o.remote and k.trust >= 60.0 and (threat == null or o.flat_dist(threat) > 9.0):
		tonic_given = true
		UtilityBelt.grant(o, "tonic", 1, true)       # a found one: used first, never taken home
		history.append({"t": m.time, "cat": "tonic", "pri": 0})
		pose = "nudge"; pose_t = 2.0
		if m.fx: m.fx.burst(o.pos + Vector3(0, 1.0, 0), Color("ff9be0"), 10, 2.0, 0.5)
		var txt := BokiChatter.line(k, "tonic")
		if txt != "":
			m.kin_bark(k, txt, "tonic")
		gap_t = maxf(gap_t, 2.6)

## The memory of something that happened, written once a match (Kin.note -> its memories at home).
func remember(kind: String, text: String, trust_d := 0.0, extra := {}) -> void:
	if noted.has(kind) or h() == null:
		return
	noted[kind] = true
	k.note(kind, text, trust_d)
	if k.events.size() > 0:
		(k.events[-1] as Dictionary).merge(extra, true)

## Where something happened, the way it would say it: "Frostkeep", "the Ember Quarry"...
func place(p: Vector3) -> String:
	var w: Dictionary = m.where_at(p)
	if w.has("island"): return String(w["island"])
	if String(w.get("map", "")) != "": return String(w["map"])
	if w.has("biome"): return String(w["biome"]).capitalize()
	return "the islands"

# ------------------------------------------------------------------ caring (reactions)
func _react(kind: String, p: String, secs: float, bark_cat := "", at := Vector3.INF) -> void:
	history.append({"t": m.time, "cat": kind, "pri": 0})
	pose = p; pose_t = secs
	if at != Vector3.INF:
		look = at; look_t = secs
	if bark_cat != "":
		var txt := BokiChatter.line(k, bark_cat)
		if txt != "":
			m.kin_bark(k, txt, bark_cat)

## Its hunter got hit: a flinch every time, a yelp on a big one.
func on_owner_hit(d: float, by: Ent) -> void:
	var o := h()
	if o == null or k.dead or not k.ready_to_fight():
		return
	pose = "flinch"; pose_t = 0.35
	if by and is_instance_valid(by):
		look = by.pos; look_t = 1.2
	if d >= o.max_hp * 0.12 and yelp_cd <= 0.0 and not o.downed:
		yelp_cd = 7.0
		history.append({"t": m.time, "cat": "yelp", "pri": 0})
		var txt := BokiChatter.line(k, "yelp")
		if txt != "":
			m.kin_bark(k, txt, "yelp")

func on_owner_down() -> void:
	_react("guard", "guard", 3.0)
	var pl := place(h().pos)
	remember("stood_over", "stood over you when you went down at %s" % pl, 1.0, {"place": pl})

func on_owner_up() -> void:
	_react("relief", "cheer", 1.2, "relief")

## Its hunter (or it) knocked someone.
func on_knock(at: Vector3) -> void:
	if cheer_cd > 0.0:
		return
	cheer_cd = 3.0
	_react("cheer", "cheer", 1.3, "", at)
	var pl := place(at)
	remember("knock_together", "knocked down a rival hunter with you at %s" % pl, 1.0, {"place": pl})

func on_boss_kill(boss_name: String, at: Vector3) -> void:
	cheer_cd = 3.0
	_react("boss_kill", "cheer", 2.2, "boss_kill", at)
	var pl := place(at)
	remember("boss_kill", "beat %s with you at %s" % [boss_name, pl], 3.0, {"place": pl, "boss": boss_name})

func on_extract() -> void:
	_react("extract", "cheer", 2.5)
	var where := place(h().pos)
	if k.events.any(func(e): return e["kind"] == "fainted") or k.hp < k.max_hp * 0.4:
		remember("carried_out", "was carried out of %s by you" % where, 2.0, {"place": where})
	else:
		remember("escaped", "got out of %s with you" % where, 1.0, {"place": where})

## The run's over and you didn't make it out: it stays close.
func on_loss() -> void:
	if noted.has("comforted"):
		return
	_react("comfort", "comfort", 3.0, "comfort")
	var pl := place(h().pos if h() else k.pos)
	remember("comforted", "stayed close after you lost a run at %s" % pl, 0.5, {"place": pl})

## The way out is open and you're at it: it cheers before you go (once a run), while you can still see it.
func _almost_home() -> void:
	if noted.has("almost_home") or m.exits == null:
		return
	var x: Dictionary = m.exits.active_for(h().team)
	if x.is_empty() or not String(x["state"]) in ["open", "boarding"] or h().flat_dist(x["pos"]) > 7.0:
		return
	noted["almost_home"] = true
	cheer_cd = 3.0
	_react("almost_home", "cheer", 3.0, "extract", x["pos"])

# ------------------------------------------------------------------ demos (screenshots, video)
## --teammate-demo=callout|downed: sets up a moment and holds it (Match.step calls this).
static func demo_tick(m, mode: String) -> void:
	var p: Hunter = m.player
	if p == null or p.dropping or p.kin == null:
		return
	var k: Kin = p.kin
	var st: Dictionary = m.get_meta("tmdemo", {})
	if st.is_empty():
		st = {"t0": m.time}
		m.set_meta("tmdemo", st)
		for h in m.hunters:
			if h != p:
				h.ctrl = "idle"
				h.inp["move"] = Vector2.ZERO
				h.teleport(m.world.random_ground())
		for mb in m.mobs:
			mb.dead = true
			mb.visible = false
		p.max_hp = 5000.0
		p.hp = 5000.0
		p.inp["aim"] = p.pos + Vector3(4, 0.9, 1)
		m.cam.zoom_to = 0.6
		st["pin"] = p.pos
		print("TMDEMO start t=%.1f at %s" % [m.time, str(p.pos)])
		var foe: Hunter = null
		for h in m.hunters:
			if h.team != p.team:
				foe = h
				break
		if foe == null:
			foe = m.make_hunter("R", 7, "medium", "Rival", "idle", {}, p.pos + Vector3(-8, 0, 3))
		foe.max_hp = 1e5
		foe.hp = 1e5
		st["foe"] = foe
		var want := p.pos + (Vector3(-6.5, 0, 2.5) if mode == "callout" else Vector3(4.5, 0, -1.5))
		var at: Vector3 = m.world.free_spot_near(want, [p.pos], 1.0, 0.5, 4.0)
		at.y = m.world.ground_at(at.x, at.z)
		foe.teleport(at)
		st["fpin"] = foe.pos
	var t: float = m.time - float(st["t0"])
	var foe2: Hunter = st["foe"]
	if not p.downed:
		p.teleport(st["pin"])
		p.vel = Vector3.ZERO
	foe2.teleport(st["fpin"])
	foe2.vel = Vector3.ZERO
	foe2.inp["aim"] = p.pos + Vector3(0, 0.9, 0)
	match mode:
		"callout":
			p.inp["aim"] = p.pos + Vector3(4, 0.9, 1)
			if t > 1.0 and not st.has("said"):
				st["said"] = true
				k.comp.callout("behind", foe2.pos, foe2, "h" + foe2.nid)
				print("TMDEMO callout at t=%.1f foe %s" % [m.time, str(foe2.pos)])
			if st.has("said"):
				k.comp.pose = "growl"
				k.comp.pose_t = 1.0
				k.comp.look = foe2.pos
				k.comp.look_t = 1.0
				_hold_bubble(m, k)
				for pg in m.pings:
					if pg.get("kin") == k:
						pg["t"] = minf(float(pg["t"]), 1.5)
		"downed":
			if t > 0.6 and not st.has("down"):
				st["down"] = true
				m.knock(p, foe2, {})
				p.down_hp = 1e6
			if p.downed:
				p.revive = minf(p.revive, 0.35)
				if k.state in ["reviving", "active"]:
					if not m.bubbles.any(func(b): return b["ent"] == k):
						m.kin_bark(k, BokiChatter.line(k, "owner_down"), "owner_down")
					_hold_bubble(m, k)

static func _hold_bubble(m, k: Kin) -> void:
	for b in m.bubbles:
		if b["ent"] == k:
			b["t"] = minf(float(b["t"]), 1.0)

# ------------------------------------------------------------------ keeping close
## The spot it walks to beside its hunter: on its flank and a little behind, between you and a
## close threat, covering your back if the threat is behind, or out ahead leading in the tutorial.
## Vector3.INF if there's no good ground there.
func heel_spot() -> Vector3:
	var o := h()
	if o == null:
		return Vector3.INF
	var fwd := aim_dir()
	var sd := Vector2(-fwd.y, fwd.x) * side
	var offs: Array = []
	if threat and is_instance_valid(threat) and not threat.dead:
		var to := Vector2(threat.pos.x - o.pos.x, threat.pos.z - o.pos.z)
		if to.length() > 0.5:
			to = to.normalized()
			offs.append(to * 1.25 + Vector2(-to.y, to.x) * 0.25 * side)
	offs.append(sd * 1.0 - fwd * 0.5)
	offs.append(-sd * 1.0 - fwd * 0.5)
	offs.append(-fwd * 1.1)
	for off in offs:
		var p: Vector3 = o.pos + Vector3(off.x, 0, off.y)
		if _ground_ok(p, o.pos.y):
			p.y = m.world.ground_at(p.x, p.z)
			return p
	return Vector3.INF

func _ground_ok(p: Vector3, y0: float) -> bool:
	var w = m.world
	if w.is_void(p.x, p.z) or w.is_block(p.x, p.z):
		return false
	return absf(w.ground_at(p.x, p.z) - y0) < 0.75

# ------------------------------------------------------------------ the tutorial guide
## Tutorial.update tells it every step what the step is about and where it wants you (Pell leads the way;
## the Boki says it in its own voice, looks there and shows you the moves).
func tut(id: String, to: Vector3) -> void:
	if guide.get("id", "") != id:
		guide = {"id": id, "to": to, "t": 0.0, "said": false, "demo_t": 0.4}
	guide["to"] = to

## Stalled: it says the step again (the card and marker pulse too).
func nag() -> void:
	if guide.size() == 0:
		return
	guide["said"] = false
	pose = "beckon"
	pose_t = 2.0

func _tut_tick() -> void:
	var id := String(guide["id"])
	var to: Vector3 = guide["to"]
	guide["t"] = float(guide["t"]) + 0.4
	# a hint in its own voice when the step starts, and again if you seem stuck
	var t := float(guide["t"])
	if not guide["said"] and not (m.tut and m.tut.card_up()):
		guide["said"] = true
		var txt := BokiChatter.tut_hint(k, id)
		if txt != "":
			history.append({"t": m.time, "cat": "tut_" + id, "pri": 0})
			m.kin_bark(k, txt, "tut", 4.0 if txt.length() < 60 else 7.0)
		if to != Vector3.INF:
			look = to; look_t = 2.0
			pose = "growl" if id in ["shoot", "throw", "fight"] else "point"
			pose_t = 1.6
	# showing you how: a dash, a jump
	guide["demo_t"] = float(guide["demo_t"]) - 0.4
	if float(guide["demo_t"]) <= 0.0:
		guide["demo_t"] = 3.6
		match id:
			"dash": demo = {"kind": "dash", "t": 0.0, "dir": aim_dir()}
			"glide": demo = {"kind": "jump", "t": 0.0, "dir": aim_dir()}
			"move": demo = {"kind": "hop", "t": 0.0, "dir": aim_dir()}
		if demo.size() > 0:
			history.append({"t": m.time, "cat": "demo_" + String(demo["kind"]), "pri": 0})
