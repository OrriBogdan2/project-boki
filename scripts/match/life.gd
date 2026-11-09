class_name Life
## Down, death, revive and respawn, on Supervive's rules tuned for extraction
## (docs/DEATH_AND_REVIVE.md):
##   ALIVE --0 HP--> DOWNED (wisp) --bleeds out / executed / team wiped--> DEAD (deathbox)
##   a teammate standing on your wisp brings you back (4s); a teammate holding interact at your
##   deathbox does too while your soul is there (BoxRevive, loot back); a revive beacon brings back
##   the whole team (Beacons: full health, no loot, resurrection sickness).
## Everything here runs on whichever game owns the hunter (local and bots); remote hunters only
## show what their owner sends.

const R := {
	"bleed_out": 15.0,          # [patch] seconds a wisp lasts on its own
	"revive_radius": 1.6,       # [est] a teammate this close revives you
	"revive_time": 4.0,         # [wiki "a few seconds"] [est]
	"revive_hp": 0.25,          # [design] back on your feet with a quarter of your health
	"extra_reviver": 0.5,       # each extra teammate on you: +50% speed [design]
	"stomp_mult": 2.5,          # [design] an enemy standing on a wisp drains it this much faster and blocks the revive
	"stomp_slow": 0.4,          # [design] ...and pins it: the wisp drifts at this fraction of its normal speed
	"execute_time": 3.0,        # [footage] (old: hold interact on an enemy wisp; now the stomp below)
	"stomp_commit": 0.2,        # [design] hold interact this long on an enemy wisp to start the stomp...
	"stomp_time": 2.4,          # [footage] ...then you're locked in for this long, three stomps and done
	"stomp_cycle": 0.7,         # one foot-lift-and-slam
	"kin_revive_time": 8.0,     # [design] your kin pulling you up (as long as Supervive's Guardian Angel self-revive)
	"box_revive_hp": 0.25,      # [design] same as a wisp revive
	"soul_time": 90.0,          # [design] box revive window
	"loot_time": 1.0,           # [design] bots: hold interact to take everything from a box (you get a loot window)
	"sickness_time": 12.0,      # [patch 1.0] resurrection sickness
	"sickness_dmg": 0.75,       # [patch 1.0] -25% damage dealt
}

const RIVAL_BOX := Color("d0473c")    # a rival's box: red, on the box, the map and its label
const BOX_BODY := Color("5a5560")     # Models.deathbox's body before its owner tint
const OWNER_TINT := 0.6               # how far the body leans to the owner's colour (0..1)
const OWNER_RING_M := 2.4             # metres across the owner's ring round a box

## Box colour by what's inside: grey, blue, purple, gold.
const BOX_TIERS := [[0, Color("b8b4ac")], [12, Color("6ab8ff")], [35, Color("c08aff")], [80, Color("ffb64a")]]

static func trace(m: Match, txt: String) -> void:
	if m.opts.get("autoplay", false):
		print("LIFE %d %s" % [int(m.time), txt])

static func box_value(b: Dictionary) -> int:
	var v := int(b["gems"])
	for s in b["seeds"]: v += int(b["seeds"][s]) * 3
	v += (b["caught"] as Array).size() * 15
	for st in (b.get("belt", []) as Array): v += int(st["n"]) * 4
	for c in Pack._box_things(b):
		v += Loot.value(c["it"]) / 2
	return v

static func box_color(b: Dictionary) -> Color:
	var col: Color = BOX_TIERS[0][1]
	for t in BOX_TIERS:
		if box_value(b) >= int(t[0]): col = t[1]
	return col

## The rarity tier of the best piece of gear or valuable in a box (what its glow shows).
static func box_rarity(b: Dictionary) -> int:
	var best := 0
	for g in b.get("gear", []):
		best = maxi(best, int(g["rar"]))
	for it in b.get("pack", []):
		best = maxi(best, Loot.rar_of(it))
	return best

## Is anyone on this team still in the fight (standing or a wisp)?
static func team_alive(m: Match, team: int) -> bool:
	return m.hunters.any(func(x): return x.team == team and not x.out and not x.extracted)

static func team_standing(m: Match, team: int) -> bool:
	return m.hunters.any(func(x): return x.team == team and not x.out and not x.extracted and not x.downed)

# ------------------------------------------------------------------ wisps
## Every frame, for each wisp: teammates on it revive it, enemies on it stomp it, otherwise it
## bleeds out.
static func tick_wisps(m: Match, dt: float) -> void:
	var base := Data.MATCH["down_hp"] / R["bleed_out"]
	for o in m.hunters:
		if not o.downed or o.out or o.remote:
			continue
		if CareUtil.carried_tick(m, o):
			continue          # carried by a teammate: no bleed, no stomp
		var allies := 0
		var foes := 0
		var revivers: Array = []
		var stompers: Array = []
		for h in m.hunters:
			if h == o or h.out or h.extracted or h.downed or h.dropping or h.flat_dist(o) > R["revive_radius"] or absf(h.pos.y - o.pos.y) > 1.6:
				continue
			if h.team == o.team:
				allies += 1
				revivers.append(h)
				h.set_hold("revive")
			else:
				foes += 1
				stompers.append(h)
				h.set_meta("standing_on", o)
				h.set_meta("standing_at", m.time)
		o.set_meta("revivers", revivers if foes == 0 else [])
		o.set_meta("stompers", stompers)
		# the crush: a low thud under the wisp while someone's standing on it, heard by both sides
		if foes > 0:
			var st: float = float(o.get_meta("crush_t", 0.0)) - dt
			if st <= 0.0:
				st = 0.42
				m.sfx("thump", o.pos, -6.0)
			o.set_meta("crush_t", st)
		var kin_on := false
		for kk in [o.kin, o.kin2]:
			if kk and not (kk as Kin).dead and (kk as Kin).state == "reviving" and (kk as Kin).flat_dist(o) < 1.4:
				kin_on = true
		if foes > 0 and not o.get_meta("stomped", false) and o == m.player and m.hud:
			m.hud.toast("%s is on you! Drift away" % stompers[0].pname, Color("ff5a4a"))
		o.set_meta("stomped", foes > 0)
		if foes > 0:
			# stomped: drains fast and nobody can pick you up
			o.down_hp -= base * R["stomp_mult"] * dt
			o.revive = maxf(0.0, o.revive - dt * 0.5)
		elif allies > 0:
			o.revive += dt / R["revive_time"] * (1.0 + R["extra_reviver"] * (allies - 1))
			if o.revive >= 1.0:
				trace(m, "wisp revive %s" % o.pname)
				for rv in revivers: (rv as Hunter).revives += 1
				m.revive_hunter(o, null)
				continue
		elif not kin_on:
			o.down_hp -= base * dt
		if o.down_hp <= 0.0:
			trace(m, "%s %s" % [o.pname, "bled out" if foes == 0 else "stomped out"])
			m.eliminate(o, o.last_hit_by, "bled out" if foes == 0 else "finished")

# ------------------------------------------------------------------ the stomp
## Holding interact on an enemy wisp commits you to stomping it out: a fixed animation you can't
## cancel or move out of. You can still be shot, and a stun or a knockback breaks it (the wisp
## lives), and if the wisp drifts away (off a ledge, say) your stomps miss and it gets away.
static func start_stomp(m: Match, h: Hunter, o: Hunter) -> void:
	h.stomp = {"o": o, "t": 0.0, "hits": 0}
	h.finish_t = 0.0
	trace(m, "stomp start %s on %s" % [h.pname, o.pname])
	m.fx.word(h.pos + Vector3(0, 2.3, 0), "STOMP", Color("ff8a6a"), false)
	if o == m.player and m.hud:
		m.hud.toast("%s is stomping you! Drift away or get help" % h.pname, Color("ff6a5a"))

static func end_stomp(m: Match, h: Hunter, why: String) -> void:
	if h.stomp.is_empty():
		return
	trace(m, "stomp end %s (%s)" % [h.pname, why])
	h.stomp = {}
	if why == "broken":
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "INTERRUPTED", Color("cfeaff"), false)
		m.sfx("whoosh", h.pos, -6.0, 1.3)

static func tick_stomps(m: Match, dt: float) -> void:
	for h in m.hunters:
		if h.stomp.is_empty() or h.remote:
			continue
		var o: Hunter = h.stomp["o"]
		# a hit that stuns or knocks you breaks it; your own input never does
		if h.downed or h.out or h.stun_t > 0.0 or m.time - h.kb_t < 0.08:
			end_stomp(m, h, "broken")
			continue
		if o == null or o.out or not o.downed:
			end_stomp(m, h, "gone")
			continue
		h.root_t = maxf(h.root_t, 0.12)
		var face := Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z)
		if face.length() > 0.05: h.inp["aim"] = Vector3(o.pos.x, o.pos.y, o.pos.z)
		var t0 := float(h.stomp["t"])
		var t1 := t0 + dt
		h.stomp["t"] = t1
		var cyc: float = R["stomp_cycle"]
		var hit_at := cyc * 0.7
		var near: bool = h.flat_dist(o) <= float(R["revive_radius"]) + 0.5 and absf(h.pos.y - o.pos.y) < 1.6
		if fmod(t0, cyc) < hit_at and fmod(t1, cyc) >= hit_at:
			# a foot comes down
			h.stomp["hits"] = int(h.stomp["hits"]) + 1
			m.fx.dust(h.pos, 10)
			m.fx.ring(h.pos + Vector3(0, 0.05, 0), 1.2, Color(1, 0.8, 0.7, 0.6), 0.25)
			m.sfx("thump", h.pos, -2.0, 0.85)
			if near:
				m.fx.burst(o.pos + Vector3(0, 0.5, 0), Color("ff6a5a"), 10, 3.0, 0.35, -4.0)
				o.down_hp -= Data.MATCH["down_hp"] * 0.12
		if t1 >= float(R["stomp_time"]):
			if near:
				end_stomp(m, h, "done")
				m.eliminate(o, h, "executed")
				m.fx.burst(o.pos + Vector3(0, 0.8, 0), Color("ff6a5a"), 20, 4.0, 0.5, -3.0)
				m.sfx("crit", o.pos, -2.0, 0.7)
			else:
				end_stomp(m, h, "missed")

# ------------------------------------------------------------------ deathboxes
## Where a box goes: where you fell, or the last solid ground before the abyss.
static func box_spot(m: Match, h: Hunter, why: String) -> Vector3:
	var at := h.pos
	if why == "train" and m.world.is_void(at.x, at.z):
		# hit by the sky train over the abyss: the box lands on the nearest ground to where they were hit
		var near: Vector3 = m.world.free_spot_near(at, [], 1.0, 0.4, 14.0)
		if not m.world.is_void(near.x, near.z):
			at = near
	if why == "abyss" or m.world.is_void(at.x, at.z) or at.y < m.world.ground_at(at.x, at.z) - 1.0:
		at = h.safe_pos if h.safe_pos != Vector3.INF else at
		if m.world.is_void(at.x, at.z):
			at = m.world.free_spot_near(at, [], 1.0, 0.4, 40.0)
	if m.world.is_void(at.x, at.z):
		return Vector3.INF
	at.y = m.world.ground_at(at.x, at.z)
	return at

static func drop_box(m: Match, h: Hunter, why: String) -> Dictionary:
	for old in m.boxes:
		if old["owner"] == h: old["soul_until"] = 0.0
	var at := box_spot(m, h, why)
	HeroSfx.voice(m, h, "death")
	KinTrack.drop_carried(m, h, at)       # a Boki you were carrying home drops for its owner
	var b := {"owner": h, "team": h.team, "pos": at, "gems": h.gems, "seeds": h.seeds.duplicate(), "caught": h.caught.duplicate(true),
		"belt": UtilityBelt.clear(h), "soul_until": m.time + R["soul_time"], "prog": {}, "node": null, "empty": false,
		"gear": [], "pack": h.pack.duplicate(true), "keys": h.rift_keys, "chest_keys": h.chest_keys}
	h.pack = []
	h.rift_keys = 0
	h.chest_keys = 0
	Backpacks.into_box(h, b)
	# the gear you wear goes in the box too (Supervive: the box holds everything); your weapon stays with you
	for g in h.gear:
		if not (g as Dictionary).is_empty():
			(b["gear"] as Array).append((g as Dictionary).duplicate())
	h.gear = Gear.empty_slots()
	h.refresh_gear()
	if at == Vector3.INF:
		# nowhere to put it: the abyss keeps it
		return b
	trace(m, "box %s value %d at %s" % [h.pname, box_value(b), at.snapped(Vector3.ONE)])
	var n := Models.deathbox(box_color(b), box_rarity(b))
	n.position = at
	m.add_child(n)
	b["node"] = n
	_mark_owner(m, b)
	m.boxes.append(b)
	return b

## Whose box it is, for you: a teammate's in their squad colour (the map's), a rival's in red.
static func owner_col(m: Match, b: Dictionary) -> Color:
	var o: Hunter = b["owner"]
	if m.player != null and o.team == m.player.team:
		return m.mate_col(o)
	return RIVAL_BOX

## The box's body takes its owner's colour and a ring round it, so whose box it is reads at a glance
## (the beam and trim keep the value colour).
static func _mark_owner(m: Match, b: Dictionary) -> void:
	var n: Node3D = b["node"]
	var col := owner_col(m, b)
	var mats: Array = n.get_meta("mats", [])
	if not mats.is_empty():
		(mats[0] as ShaderMaterial).set_shader_parameter("albedo", BOX_BODY.lerp(col, OWNER_TINT))
	var ring := MeshInstance3D.new()
	ring.name = "OwnerRing"
	ring.mesh = Models.flat_quad(OWNER_RING_M)
	ring.material_override = Models.ring_mat(col, 0.12)
	ring.position.y = 0.05
	n.add_child(ring)

## Your latest box (an earlier one from before a revive can't bring you back any more).
static func box_of(m: Match, h: Hunter) -> Dictionary:
	for i in range(m.boxes.size() - 1, -1, -1):
		if m.boxes[i]["owner"] == h:
			return m.boxes[i]
	return {}

static func soul_here(m: Match, b: Dictionary) -> bool:
	var o: Hunter = b["owner"]
	return o != null and o.out and not o.gone and m.time < float(b["soul_until"])

# ------------------------------------------------------------------ what's in a box, item by item
## Everything in a box as a list for the loot window: [{key, i, name, sub, icon, col, upgrade}].
static func box_items(m: Match, h: Hunter, b: Dictionary) -> Array:
	var out: Array = []
	if int(b["gems"]) > 0:
		out.append({"key": "gems", "name": "%d gems" % int(b["gems"]), "sub": "Treasure", "icon": "gem", "col": Color("ffd36a"), "upgrade": true})
	for s in b["seeds"]:
		var cd: Dictionary = Data.CROPS.get(s, {})
		out.append({"key": "seeds", "i": s, "name": "%d %s seed%s" % [int(b["seeds"][s]), cd.get("name", s), "" if int(b["seeds"][s]) == 1 else "s"], "sub": "Seeds", "icon": "seed", "col": cd.get("color", Color("8fe0a0")), "upgrade": true})
	for i in (b["caught"] as Array).size():
		var rec: Dictionary = b["caught"][i]
		var sp: Dictionary = Data.KIN.get(String(rec.get("species", "")), {})
		out.append({"key": "caught", "i": i, "name": Data.kin_title(String(rec.get("name", "")), String(sp.get("name", "Boki"))), "sub": "Kin", "icon": "paw", "col": sp.get("color", Color("ffb0d0")), "upgrade": true})
	for i in (b.get("belt", []) as Array).size():
		var st: Dictionary = b["belt"][i]
		out.append({"key": "belt", "i": i, "id": String(st["id"]), "name": "%d %s" % [int(st["n"]), UtilityBelt.name_of(String(st["id"])).to_lower()], "sub": "Utility", "icon": UtilityBelt.icon_of(String(st["id"])), "col": UtilityBelt.col_of(String(st["id"])), "upgrade": UtilityBelt.has_room(h, String(st["id"]))})
	if int(b.get("keys", 0)) > 0:
		out.append({"key": "keys", "name": "%d Rift Key%s" % [int(b["keys"]), "" if int(b["keys"]) == 1 else "s"], "sub": "Opens a rift hatch", "icon": "gem", "col": ExitModels.HATCH, "upgrade": true})
	if int(b.get("chest_keys", 0)) > 0:
		var n_keys := int(b["chest_keys"])
		var key_label := "%d key%s" % [n_keys, "" if n_keys == 1 else "s"]
		out.append({"key": "chest_keys", "name": key_label, "sub": "Opens one chest each", "icon": "key",
			"col": KeyModels.BRASS, "upgrade": true})
	for i in (b.get("gear", []) as Array).size():
		var g: Dictionary = b["gear"][i]
		var gd: Dictionary = Gear.ALL.get(String(g["id"]), {})
		var r: Dictionary = Data.RARITY[clampi(int(g["rar"]), 0, Data.RARITY.size() - 1)]
		var slot := Gear.slot_on(h, String(g["id"]))
		var cur: Dictionary = h.gear[slot]
		var up := cur.is_empty() or Loot.value(Loot.gear(String(g["id"]), int(g["rar"]))) > Loot.value(Loot.gear(String(cur["id"]), int(cur["rar"])))
		out.append({"key": "gear", "i": i, "name": "%s%s" % [(String(r["name"]) + " ") if int(g["rar"]) > 1 else "", gd.get("name", g["id"])],
			"sub": Gear.WORN_NAMES[slot] + "  ·  " + Gear.stat_text(String(g["id"]), int(g["rar"])),
			"icon": Gear.icon_of(String(g["id"])), "col": r["color"], "upgrade": up})
	var pack_row := Backpacks.box_row(h, b)
	if not pack_row.is_empty():
		out.append(pack_row)
	# gear and treasure for the backpack (worth taking if there's room, or it beats the worst thing in it)
	for i in (b.get("pack", []) as Array).size():
		var it: Dictionary = b["pack"][i]
		out.append({"key": "pack", "i": i, "name": Loot.name_of(it), "sub": Loot.sub_of(it), "icon": Loot.icon_of(it), "col": Loot.col_of(it),
			"upgrade": Pack.wants(h, it), "value": Loot.value(it), "el": String(it.get("el", "")), "full": not Pack.room(h)})
	return out

## Takes one thing out of a box. Swapping gear leaves yours in the box in its place.
static func take_item(m: Match, h: Hunter, b: Dictionary, it: Dictionary) -> void:
	match String(it["key"]):
		"gems":
			h.gems += int(b["gems"]); b["gems"] = 0
		"seeds":
			var s: String = it["i"]
			h.seeds[s] = int(h.seeds.get(s, 0)) + int(b["seeds"].get(s, 0))
			(b["seeds"] as Dictionary).erase(s)
		"caught":
			var i := int(it["i"])
			if i < (b["caught"] as Array).size():
				var rec: Dictionary = b["caught"][i]
				if not (h == m.player and String(rec.get("lost_from", "")) == "you") and not Capture.room(h):
					Capture.full_note(m, h)         # no room in your box: the capsule stays in the deathbox
					return
				(b["caught"] as Array).remove_at(i)
				if h == m.player and String(rec.get("lost_from", "")) == "you":
					m.give_kin(h, rec)
					m.add_feed("%s is back with you!" % rec.get("name", "Your Boki"))
				else:
					h.caught.append(rec)
					if String(rec.get("lost_from", "")) != "" and String(rec.get("lost_from", "")) != h.pname:
						h.stolen_carry = true
		"belt":
			for bi in (b["belt"] as Array).size():
				var st: Dictionary = b["belt"][bi]
				if String(st["id"]) != String(it.get("id", "")):
					continue
				st["n"] = int(st["n"]) - UtilityBelt.grant(h, String(st["id"]), int(st["n"]))
				if int(st["n"]) <= 0:
					(b["belt"] as Array).remove_at(bi)
				break
		"keys":
			b["keys"] = int(b.get("keys", 0)) - BeltKeys.give(h, "rift_key", int(b.get("keys", 0)))
		"backpack":
			Backpacks.take_from_box(m, h, b)
		"chest_keys":
			b["chest_keys"] = int(b.get("chest_keys", 0)) - BeltKeys.give(h, "chest_key", int(b.get("chest_keys", 0)))
		"gear":
			var gi := int(it["i"])
			if gi < (b["gear"] as Array).size():
				var g: Dictionary = b["gear"][gi]
				(b["gear"] as Array).remove_at(gi)
				var slot := Gear.slot_on(h, String(g["id"]))
				var old: Dictionary = h.gear[slot]
				h.gear[slot] = g.duplicate()
				h.gear_cd[slot] = 0.0
				h.refresh_gear()
				if not old.is_empty():
					(b["gear"] as Array).append(old)
		"pack":
			# into your backpack; a full one swaps out its least valuable thing (that goes in the box)
			var pi := int(it["i"])
			if pi < (b["pack"] as Array).size():
				var pit: Dictionary = b["pack"][pi]
				if Pack.room(h):
					(b["pack"] as Array).remove_at(pi)
					h.pack.append(pit)
				elif Loot.value(pit) > Pack.lowest_value(h):
					(b["pack"] as Array).remove_at(pi)
					var li := Pack.lowest(h)
					(b["pack"] as Array).append(h.pack[li])
					h.pack.remove_at(li)
					h.pack.append(pit)
				elif h == m.player and m.hud:
					m.hud.toast_small("Pack full", Color("ffb0a0"))
	m.sfx("pickup", b["pos"], -4.0, 0.9)
	_settle_box(b)

## Smart loot (press interact again with a box open): every gem, seed, kin and consumable, and the
## gear only where it beats what you have. Returns how many things it took.
static func smart_loot(m: Match, h: Hunter, b: Dictionary) -> int:
	return Pack.smart_loot(m, h, b)

static func _settle_box(b: Dictionary) -> void:
	b["empty"] = int(b["gems"]) <= 0 and (b["seeds"] as Dictionary).is_empty() and (b["caught"] as Array).is_empty() \
		and (b.get("belt", []) as Array).is_empty() and int(b.get("keys", 0)) <= 0 and int(b.get("chest_keys", 0)) <= 0 and (b.get("gear", []) as Array).is_empty() \
		and (b.get("pack", []) as Array).is_empty() \
		and int(b.get("backpack", Backpacks.POUCH)) <= Backpacks.POUCH
	_refresh_box(b)

## Takes everything in a box.
static func loot_box(m: Match, h: Hunter, b: Dictionary) -> void:
	Backpacks.take_from_box(m, h, b)       # first: a bigger backpack makes room for the rest
	# worn gear: the owner gets theirs back; anyone else only takes upgrades
	if (b["owner"] as Hunter) == h:
		for g in (b.get("gear", []) as Array).duplicate():
			take_item(m, h, b, {"key": "gear", "i": (b["gear"] as Array).find(g)})
		for pit in (b.get("pack", []) as Array):
			h.pack.append(pit)
		b["pack"] = []
	else:
		# anything worth packing, best first, while there's room
		var things: Array = (b.get("pack", []) as Array).duplicate()
		things.sort_custom(func(a, c): return Loot.value(a) > Loot.value(c))
		for pit in things:
			if not Pack.room(h): break
			h.pack.append(pit)
			(b["pack"] as Array).erase(pit)
		for it in box_items(m, h, b):
			if it["key"] == "gear" and it["upgrade"]:
				take_item(m, h, b, it)
				break
	h.gems += int(b["gems"])
	for s in b["seeds"]:
		h.seeds[s] = int(h.seeds.get(s, 0)) + int(b["seeds"][s])
	var left: Array = []
	for rec in b["caught"]:
		if h == m.player and String(rec.get("lost_from", "")) == "you":
			# one of yours the dead hunter had taken: it's straight back at your side
			m.give_kin(h, rec)
			m.add_feed("%s is back with you!" % rec.get("name", "Your Boki"))
			continue
		if not Capture.room(h):
			left.append(rec)               # the box is full: this capsule stays in the deathbox
			continue
		h.caught.append(rec)
		if String(rec.get("lost_from", "")) != "" and String(rec.get("lost_from", "")) != h.pname:
			h.stolen_carry = true
	if not left.is_empty():
		Capture.full_note(m, h)
	b["caught"] = left
	var belt_left: Array = []
	for st in (b.get("belt", []) as Array):
		st["n"] = int(st["n"]) - UtilityBelt.grant(h, String(st["id"]), int(st["n"]))
		if int(st["n"]) > 0: belt_left.append(st)
	b["belt"] = belt_left
	var rift_left := int(b.get("keys", 0)) - BeltKeys.give(h, "rift_key", int(b.get("keys", 0)))
	var box_keys := int(b.get("chest_keys", 0))
	var keys_left := box_keys - BeltKeys.give(h, "chest_key", box_keys)
	var got := int(b["gems"])
	b["gems"] = 0
	b["seeds"] = {}
	b["keys"] = rift_left
	b["chest_keys"] = keys_left
	_settle_box(b)
	m.sfx("pickup", b["pos"], -2.0, 0.9)
	m.fx.burst(b["pos"] + Vector3(0, 0.6, 0), Color("ffd36a"), 14, 3.0, 0.4)
	if h == m.player and m.hud:
		if got > 0: m.hud.toast_small("+%d gems" % got, Color("ffd36a"))

static func _refresh_box(b: Dictionary) -> void:
	var n: Node3D = b["node"]
	if n == null:
		return
	var lid: Node3D = n.get_node_or_null("Body/Lid")
	if lid and b["empty"]:
		lid.rotation.x = -1.1
	var glow: Node3D = n.get_node_or_null("Glow")
	if glow: glow.visible = not b["empty"]

## A teammate brought you back at your box: half health, and whatever's still in it.
static func box_revive(m: Match, b: Dictionary, by: Hunter) -> void:
	var o: Hunter = b["owner"]
	bring_back(m, o, b["pos"], R["box_revive_hp"], false)
	loot_box(m, o, b)
	m.add_feed("%s brought %s back at their box" % [by.pname, o.pname])
	trace(m, "box revive %s by %s" % [o.pname, by.pname])

# ------------------------------------------------------------------ coming back
## Back from the dead (or a wisp) at a spot, with some health.
static func bring_back(m: Match, o: Hunter, at: Vector3, hp_frac: float, sick: bool) -> void:
	o.out = false
	o.gone = false
	o.downed = false
	o.down_hp = 0.0
	o.revive = 0.0
	o.hp = o.max_hp * hp_frac
	o.armor = 0.0
	o.inv_t = 1.5
	o.vel = Vector3.ZERO
	o.stun_t = 0.0
	o.grap = {}; o.pad = {}; o.charge = {}; o.roll_t = 0.0
	o.gliding = false; o.glide_fuel = 1.0
	o.sick_t = R["sickness_time"] if sick else 0.0
	o.teleport(m.world.free_spot_near(at, [], 1.0, 0.4, 6.0) if not m.world.is_void(at.x, at.z) else at)
	o.prev = o.pos
	for kk in [o.kin, o.kin2]:
		# your kin was keeping out of sight; it comes straight back to you
		if kk and not (kk as Kin).dead and (kk as Kin).state == "away":
			var k: Kin = kk
			k.teleport(o.pos + Vector3(1.0, 0, 0.7))
			k.state = "bench" if k == o.kin2 else "active"        # it walks back out at your side
	if o.ctrl == "bot":
		o.ai = m.bot_brain.new_mind(m.rng, float(m.opts.get("bot_skill", m.bot_cfg.get("skill", 0.6))), m.bot_cfg)
	m.sfx("revive", o.pos, 0.0)
	m.fx.ring(o.pos, 2.2, Color("9ee2a0"), 0.5)
	m.fx.burst(o.pos + Vector3(0, 1.0, 0), Color("cff6e0"), 26, 5.0, 0.6, -2.0)
	if o == m.player:
		m.killcam_text = ""
		if m.hud:
			m.hud.flash(Color("9ee2a0"), 0.3)
			m.hud.toast("You're back" + ("  ·  resurrection sickness: -25% damage for 12s" if sick else ""), Color("9ee2a0"))

## Someone died for good: no box revive any more, and no beacon either.
static func make_gone(m: Match, h: Hunter) -> void:
	if h.gone:
		return
	h.gone = true
	# kin that were keeping out of sight flee home: they're never lost that way

# ------------------------------------------------------------------ kin at risk (by run tier)
## When you die, what happens to your Boki depends on the tier (docs/decisions/0008, KinLoss): below
## loss_min_tier it keeps out of sight and goes home with you; from it up it drops dazed and guards
## your deathbox, to be cradled once you are revived or scanned by an enemy.
static func kin_on_death(m: Match, h: Hunter, b: Dictionary) -> void:
	for kk in [h.kin, h.kin2]:
		if kk == null or (kk as Kin).dead:
			continue
		KinLoss.on_owner_out(m, h, kk, b["pos"])
