class_name LairsFight
extends RefCounted
## Boss wake, waves, deaths and rewards (the egg and loot) for Lairs.

var ls: Lairs
var m: Match

func _init(l: Lairs) -> void:
	ls = l
	m = l.m

func wake(L: Dictionary, by: Ent) -> void:
	var b: Boss = ls.boss_of(L)
	if b == null or not is_instance_valid(b) or b.dead or not b.dormant:
		return
	b.dormant = false
	b.awake_t = 0.0
	b.next_cd = 1.6
	b.st = "chase"
	L["state"] = "awake"
	L["woke_at"] = m.time
	var lbl: Label3D = L["nodes"]["label"]
	lbl.text = "%s\n%s" % [L["name"], b.md["name"]]
	m.sfx("horn", L["c"], 4.0, 0.55)
	m.sfx("v_warden", L["c"], 6.0, 0.45)
	Shake.incoming_big(m, L["c"], 0.6)
	m.fx.burst(b.pos + Vector3(0, 2.0, 0), Lairs.color_of(L), 50, 7.0, 0.8, 0.0, 1.6)
	m.add_feed("%s has woken in %s" % [b.md["name"], L["name"]])
	ls.lock.lock_in(L)
	if m.player and not m.player.out:
		if ls.inside(L, m.player.pos, 6.0):
			if m.hud: m.hud.toast("BOSS AWAKE  ·  %s" % String(b.md["name"]).to_upper(), Lairs.color_of(L))
			m.sfx("ult", null, 0.0, 0.6)
			_music(true)
		else:
			m.ping(L["c"], Lairs.color_of(L))

func _music(on: bool) -> void:
	if on == ls.music_on:
		return
	ls.music_on = on
	# the layered score brings its boss stem in by itself (MusicDir reads music_on)
	if m.music_dir == null or not m.music_dir.started:
		Sfx.play_music("hollow" if on or m.tier >= 2 else "match", 0.8)

## The lair emptied: the boss settles back to sleep in the middle and heals up.
func reset_boss(b: Boss) -> void:
	var L: Dictionary = b.lair
	b._clear_attack()
	b.dormant = true
	b.phase = 0
	b.enraged = false
	b.awake_t = 0.0
	b.tgt = null
	b.st = "idle"
	b.stag_open = 0.0
	b.pos = Vector3(float(L["c"].x), b.pos.y, float(L["c"].z)); b.prev = b.pos
	b.hp = b.max_hp      # it heals up while it sleeps
	for a in L["adds"]:
		if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	L["adds"] = []
	ls.lock.unlock(L)
	L["calm_until"] = m.time + 8.0      # a breather: whoever's still inside can walk out before it stirs again
	L["state"] = "open"
	(L["nodes"]["label"] as Label3D).text = "%s\nOpen" % L["name"]
	m.add_feed("%s settles back to sleep" % b.md["name"])
	_music(false)

func on_boss_phase(b: Boss, p: int) -> void:
	var L: Dictionary = b.lair
	if m.player and ls.inside(L, m.player.pos, 6.0) and m.hud:
		m.hud.toast("PHASE %d  ·  %s grows furious" % [p + 1, b.md["name"]], Lairs.color_of(L))
	m.sfx("warn", b.pos, 2.0, 0.6)
	Juice.boss_phase(m, b)

func on_enrage(b: Boss) -> void:
	if m.player and ls.inside(b.lair, m.player.pos, 6.0) and m.hud:
		m.hud.toast("%s IS ENRAGED" % String(b.md["name"]).to_upper(), Color("ff5a4a"))
	m.add_feed("%s is enraged" % b.md["name"])

## Adds a boss calls up (the Brood Mother's brood); they belong to the lair and stay in it.
func spawn_add(L: Dictionary, kind: String, at: Vector3) -> void:
	if ls.adds_alive(L) >= 9:
		return
	var a := m.spawn_mob(kind, at)
	a.camp = L["c"]
	a.st = "chase"
	var b: Boss = ls.boss_of(L)
	if b and is_instance_valid(b): a.tgt = b.tgt
	L["adds"].append(a)

## Every monster death passes through here: bosses, ward stones, guards.
func on_mob_dead(mb: Mob, credit: Ent) -> void:
	if mb is Boss:
		_boss_dead((mb as Boss).lair, mb as Boss, credit)
		return
	if mb.mkind == "ward" and mb.has_meta("lair"):
		var L: Dictionary = ls.list[int(mb.get_meta("lair"))]
		var left: int = (L["wards"] as Array).filter(func(x): return is_instance_valid(x) and not x.dead and x != mb).size()
		m.sfx("boom", mb.pos, 2.0, 0.8)
		m.fx.burst(mb.pos + Vector3(0, 1.5, 0), Color("8fd8ff"), 30, 6.0, 0.6, 3.0)
		var hb: Hunter = credit if credit is Hunter else null
		if left == 0:
			ls.open(L, hb, "wards")
		elif hb == m.player and m.hud:
			m.hud.toast("Ward broken  ·  %d left" % left, Lairs.color_of(L))

## A ward stone was hit for the first time: its guards come out.
func on_ward_hit(mb: Mob, by: Ent) -> void:
	if mb.has_meta("woke"):
		return
	mb.set_meta("woke", true)
	var L: Dictionary = ls.list[int(mb.get_meta("lair"))]
	var hb: Hunter = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else (by as Hunter if by is Hunter else null)
	if hb: ls.lock._loud(L, mb.pos, hb, "A ward stone shrieks at %s" % L["name"])
	ls.lock._call_guards(L, mb.pos, 3)

func _boss_dead(L: Dictionary, b: Boss, credit: Ent) -> void:
	var killer: Hunter = (credit as Kin).owner_h if credit is Kin and (credit as Kin).owner_h else (credit as Hunter if credit is Hunter else null)
	L["state"] = "cleared"
	L["cleared_by"] = killer.pname if killer else ""
	# everyone's Boki who fought it cheers (and remembers it)
	for hh in m.hunters:
		if hh.kin and hh.kin.comp and not hh.out and (hh == killer or hh.flat_dist(b) < 22.0) and hh.kin.state != "downed":
			hh.kin.comp.on_boss_kill(String(b.md.get("name", "the boss")), b.pos)
	(L["nodes"]["label"] as Label3D).text = "%s\nCleared" % L["name"]
	if L.get("locked", false):
		ls.lock._victory(L, b)      # the gate stays shut a moment: the lever, the updraft, or wait it out
	else:
		ls.lock.unlock(L)
	# a small pile, all of it worth having (one Epic or Legendary piece of gear, a Brand upgrade for
	# its killer's weapon, one treasure, sometimes a Rift Key), and the Rare Egg on its own spot a few steps away,
	# under its own beam, so it's never lost in the pile
	var at := _floor_spot(L, b.pos, 0.0)
	# (1.6 m out: at 0.9 their names ran into each other)
	GearDrops.run_table(m, "boss", at, m.rng, {"r": 1.6, "h": killer, "bonus": m.biomes.rarity_bonus_at(at) if m.biomes else 0})
	m.spawn_val(Loot.valuable("crown_shard" if m.rng.randf() < 0.5 else "kin_idol"), at + Vector3(0, 0, -0.8))
	if m.exits and not m.exits.list.is_empty() and m.rng.randf() < 0.5:
		m.exits.drop_key(at + Vector3(0, 0, 1.1))
	# the egg: of the floor spots EGG_APART out from the pile, the one furthest from every pile item
	var pile_at: Array = [at + Vector3(0, 0, -0.8), at + Vector3(0, 0, 1.1)]
	for wp in m.wpicks:      # (the gear just dropped, and anything already lying on the lair's floor)
		if ls.inside(L, wp["pos"], 0.0): pile_at.append(wp["pos"])
	var egg_at := at
	var best := -1.0
	for k in 12:
		var a := TAU * float(k) / 12.0
		var q := _floor_spot(L, at + Vector3(cos(a), 0, sin(a)) * Lairs.EGG_APART, 1.8)
		var near := 1e9
		for pp in pile_at: near = minf(near, Vector2(q.x - pp.x, q.z - pp.z).length())
		if near > best: best = near; egg_at = q
	var sp := String(b.md.get("egg", ""))
	if Data.KIN.has(sp):
		drop_egg(L, Loot.rare_egg(sp, b.mkind), egg_at)
	# XP for everyone who fought it: the most for the killer's squad
	for h in m.hunters:
		if h.out or h.extracted or not ls.inside(L, h.pos, 4.0):
			continue
		var share := 1.0 if killer and h.team == killer.team else (0.5 if float(b.damage_by.get(h.team, 0.0)) > b.max_hp * 0.1 else 0.2)
		h.gain_xp(260.0 * share)
	if killer and not killer.remote:
		killer.add_stat("bosses")
		PerkOrbs.drop(m, "boss", b.pos, 0, killer)      # a fan of three perk orbs
	# the boss's brood scatters
	for a in L["adds"]:
		if is_instance_valid(a) and not a.dead: a.camp = a.pos
	m.add_feed("%s felled %s!" % [killer.pname if killer else "Someone", b.md["name"]])
	m.sfx("horn", null, -2.0, 0.7)
	_music(false)

## A clear spot on a lair's floor near `p`, at least `margin` in from the walls.
func _floor_spot(L: Dictionary, p: Vector3, margin: float) -> Vector3:
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 1.6 - margin
	var q := Vector3(clampf(p.x, c.x - hf, c.x + hf), p.y, clampf(p.z, c.z - hf, c.z + hf))
	q = m.world.free_spot_near(q, [], 0.8, 0.5, 4.0)
	q.y = m.world.ground_at(q.x, q.z)
	return q

## Puts a Rare Egg on the ground (a boss's, or one spilled from a pack), loud.
func drop_egg(L: Dictionary, item: Dictionary, at: Vector3) -> Dictionary:
	m.spawn_val(item, at)
	var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
	var old: Node3D = wp["node"]
	if is_instance_valid(old): old.queue_free()
	var n := BossModels.rare_egg(Data.KIN[String(item["sp"])]["glow"] if Data.KIN.has(String(item["sp"])) else Color("ffd36a"))
	n.position = at
	m.add_child(n)
	wp["node"] = n
	wp["egg"] = true
	L["egg_wp"] = wp
	L["egg_uid"] = String(item["uid"])
	L["egg_told"] = false
	ls.egg_pings.append({"pos": at, "until": m.time + Lairs.EGG_PING_T, "follow": null, "text": "Rare Egg"})
	m.add_feed("A Rare Egg dropped at %s" % L["name"])
	m.sfx("unlock", at, 4.0, 0.6)
	if m.player and not m.player.out:
		m.ping(at, Color("ffd36a"))
		if m.hud: m.hud.toast("A RARE EGG DROPPED AT %s" % String(L["name"]).to_upper(), Color("ffd36a"))
	return wp

## Who has the egg now: the first time someone picks it up, everyone hears about it.
func _tick_egg(L: Dictionary) -> void:
	var wp = L.get("egg_wp")
	if wp == null or L.get("egg_told", true):
		return
	if m.wpicks.has(wp):
		return
	L["egg_told"] = true
	var uid := String(L.get("egg_uid", ""))
	for h in m.hunters:
		for it in h.pack:
			if String(it.get("uid", "")) == uid:
				ls.egg_pings.append({"pos": h.pos, "until": m.time + Lairs.CARRY_PING_T, "follow": h, "text": "Egg carrier"})
				m.add_feed("%s took the Rare Egg" % h.pname)
				if h == m.player and m.hud:
					m.hud.toast("You have the Rare Egg  ·  get it home", Color("ffd36a"))
				elif m.player and not m.player.out:
					m.ping(h.pos, Color("ffd36a"))
				return
