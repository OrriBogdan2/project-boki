class_name KinLoss
extends RefCounted
## Losing a Boki (docs/decisions/0008). Numbers: content/rules/boki_system.json "loss".
##   - Tiers below loss_min_tier are safe: when you die your Boki keeps out of sight and goes home with you ("away").
##   - From loss_min_tier up, when you die your Boki drops dazed and GUARDS the spot, with no box, no teleport:
##     one that was on you stands beside your deathbox, one that was out fighting stays where it stood. Revived,
##     you run into it for the usual 3.5s cradle (KinDowned) and it is yours again. An enemy can scan it
##     like any knocked-out Boki (Capture); a teammate cannot. A scanned Boki sits in the captor's box (KinTrack).
##   - At the end of the match the Boki's fate is written to the save by after_match(): "home", "ransom" (nobody took
##     it) or "captured_by:<name>". A flagged Boki cannot be brought into a match until the market clears it.
## A guarding Boki is a Kin in state "dazed" that has an owner (a wild dazed Boki has none), so it needs no flag
## of its own and the other games see it through the ordinary kin snapshot.

static func rules() -> Dictionary:
	return KinCommand.rules()["loss"]

## Can a Boki be lost in this tier?
static func at_risk(tier: int) -> bool:
	return tier >= int(rules()["loss_min_tier"])

## This match puts Boki at risk (not practice or the tutorial).
static func risky_match(m) -> bool:
	return at_risk(m.tier) and not m.opts.get("training", false) and not m.opts.get("tutorial", false)

# ------------------------------------------------------------------ in the match: the guarding Boki
static func guarding(k: Kin) -> bool:
	return k.state == "dazed" and k.owner_h != null and not k.dead

## Can this hunter scan that knocked-out Boki? A wild one, or a rival's guard; never your own or a teammate's.
static func scannable_by(h: Hunter, k: Kin) -> bool:
	return k.state == "dazed" and not k.dead and (k.owner_h == null or k.owner_h.team != h.team)

const STALE_S := 2.0     # s: a proxy's cradle progress older than this (its owner's game went quiet) no longer counts

## Is its owner carrying it (or just starting to)? A proxy copy counts only while its owner is in the match and the
## snapshots are fresh, so a disconnect mid-carry cannot leave a Boki unscannable.
static func cradled(k: Kin) -> bool:
	if not (k.rescue_on or k.rescue_t > 0.0):
		return false
	var h := k.owner_h
	if h == null or h.out or h.extracted:
		return false
	return not k.remote or k.m.time - k.net_t < STALE_S

## The hunter died: safe tiers send the Boki home with them, the others drop it to guard. box_pos is
## where the deathbox went (Vector3.INF when there is none).
static func on_owner_out(m, h: Hunter, k: Kin, box_pos: Vector3) -> void:
	if guarding(k):
		return                       # still guarding from an earlier death: nothing new is lost
	m.giant_free(k)
	if not risky_match(m):
		k.state = "away"            # never lost: it keeps out of sight and comes back if you are revived
		k.rescue_on = false
		k.rescue_t = 0.0
		return
	if h.remote:
		return                       # (their own game drops it and the snapshot tells us)
	var on_you: bool = k.state in ["shoulder", "bench", "away"] or k.with_owner()
	var at := k.pos
	if on_you:
		at = box_pos if box_pos != Vector3.INF else h.pos
		var a := float(m.kins.find(k) % 7) * 2.1
		at += Vector3(cos(a), 0.0, sin(a)) * float(rules()["guard_r"])
	at = ground(m, at)
	var rec: Dictionary = k.rec.duplicate(true)
	if at == Vector3.INF:
		# no ground to stand on (the abyss): it is swept away and nobody can take it
		k.dead = true
		k.visible = false
		if h == m.player:
			m.player_lost.append({"uid": String(rec.get("uid", "")), "kin": null, "holder": null, "rec": rec})
			m.add_feed("%s was lost with you to the abyss" % rec.get("name", "Your Boki"))
		return
	k.teleport(at)
	_stand_guard(m, h, k)
	m.kstat["left"] += 1
	if h == m.player:
		for L in m.player_lost.duplicate():
			if String(L["uid"]) == String(rec.get("uid", "")):
				m.player_lost.erase(L)
		m.player_lost.append({"uid": String(rec.get("uid", "")), "kin": k, "holder": null, "rec": rec})
		var shown := String(rec.get("name", "Your Boki"))
		m.add_feed("%s is guarding your box: get revived and run into it, or a rival can scan it" % shown)

## A free Boki id for this hunter: their own slot id ("<nid>k") when it is free, because online only ids shaped like
## that are simulated and snapshotted by the hunter's own game (Net.owner_of). Only a hunter whose slot still holds a
## living Boki gets another id, and then the Boki is simulated by the host.
static func kin_id(m, h: Hunter) -> String:
	var e = m.ents_by_id.get(h.nid + "k", null)
	if not (e is Kin) or not is_instance_valid(e) or (e as Kin).dead:
		return h.nid + "k"
	return m.next_id(h.nid + "k")

## A captor was knocked or killed (the "gdrop" event, every game): the Boki leaves their box everywhere, and the owner's
## own game stands it up again, dazed, on `at`. It reuses the Kin the scan took when it still exists (same id and slot).
static func on_gdrop(m, owner_nid: String, rec: Dictionary, at: Vector3) -> void:
	var uid := String(rec.get("uid", ""))
	for c in m.hunters:
		KinTrack.forget(c, uid)
		for i in range(c.caught.size() - 1, -1, -1):
			if String(c.caught[i].get("uid", "")) == uid:
				c.caught.remove_at(i)
	var found = m.ents_by_id.get(owner_nid, null)
	if not (found is Hunter) or (found as Hunter).remote or (found as Hunter).extracted:
		return                       # (a remote owner's game does it; we see it in the kin snapshot)
	var owner_hunter: Hunter = found
	var g: Kin = null
	for k in m.kins:
		if k.dead and k.owner_h == owner_hunter and String(k.rec.get("uid", "")) == uid and is_instance_valid(k):
			g = k
	if g == null:
		g = spawn_guard(m, owner_hunter, rec, at)
	else:
		var gp := ground(m, at)
		if gp == Vector3.INF:
			g = null
		else:
			g.teleport(gp)
			_stand_guard(m, owner_hunter, g)
	_note_dropped(m, owner_hunter, uid, g, rec)

## The owner's list of lost Boki after a drop: on the ground again (g), or gone for good (null); held by nobody.
static func _note_dropped(m, owner_hunter: Hunter, uid: String, g: Kin, rec: Dictionary) -> void:
	if owner_hunter != m.player:
		return
	for L in m.player_lost:
		if String(L["uid"]) == uid:
			L["kin"] = g
			L["holder"] = null
			return
	m.player_lost.append({"uid": uid, "kin": g, "holder": null, "rec": rec})

## A Boki a captor had in their box drops where they fell, dazed, guarding for its owner.
static func spawn_guard(m, owner_hunter: Hunter, rec: Dictionary, at: Vector3) -> Kin:
	at = ground(m, at)
	if at == Vector3.INF:
		return null
	var k := Kin.new()
	k.init_kin(m, kin_id(m, owner_hunter), rec["species"], rec, owner_hunter)
	m.add_child(k)
	m.kins.append(k)
	m.ents_by_id[k.nid] = k
	k.teleport(at)
	_stand_guard(m, owner_hunter, k)
	if owner_hunter.kin == null or (owner_hunter.kin as Kin).dead:
		owner_hunter.kin = k
	return k

static func _stand_guard(m, owner_hunter: Hunter, k: Kin) -> void:
	k.state = "dazed"
	k.hp = 1.0
	k.dazed_t = 1e9                      # it waits as long as it takes
	k.fly = {}
	k.target = null
	k.chase_target = null
	k.hold_at = Vector3.INF
	k.pend_skill = Vector3.INF
	k.pend_slot = ""
	k.vel = Vector3.ZERO
	k.scan_by = null
	k.rescue_t = 0.0
	k.rescue_on = false
	k.rescue_block = 0.0
	k.catch_prog = 0.0
	k.down_t = 0.0
	k.down_void = false
	k.dead = false
	k.visible = true
	k.lost_from = "you" if (owner_hunter == m.player or k.lost_from == "you") else owner_hunter.pname
	k.lost_uid = String(k.rec.get("uid", ""))
	k.lost_owner = owner_hunter
	m.fx.burst(k.pos + Vector3(0, 0.6, 0), Color("fff2a0"), 10, 2.0)
	if m.net_on:
		m.net_event(["guard", k.nid, owner_hunter.nid, k.rec])

## The "guard" event (a client's Boki now guards): the other games' copy of it learns whose it is and its real record,
## so a scan by the host takes the right Boki and starts the bond. A copy that does not exist yet is filled in when it
## is made (apply_pending).
static func on_guard_net(m, x: Array) -> void:
	if x.size() < 4 or typeof(x[3]) != TYPE_DICTIONARY:
		return
	var nid := String(x[1])
	var k = m.ents_by_id.get(nid, null)
	if k is Kin:
		_adopt(k, m.ents_by_id.get(String(x[2]), null), x[3])
	else:
		var pending: Dictionary = m.get_meta("guards", {})
		pending[nid] = x
		m.set_meta("guards", pending)

## A copy made after its guard event arrived.
static func apply_pending(m, k: Kin) -> void:
	var pending: Dictionary = m.get_meta("guards", {})
	if pending.has(k.nid):
		var x: Array = pending[k.nid]
		pending.erase(k.nid)
		_adopt(k, m.ents_by_id.get(String(x[2]), null), x[3])

static func _adopt(k: Kin, owner_hunter, rec: Dictionary) -> void:
	if not (owner_hunter is Hunter):
		return
	k.rec = rec.duplicate(true)
	k.owner_h = owner_hunter
	k.catch_prog = 0.0
	k.lost_from = (owner_hunter as Hunter).pname
	k.lost_uid = String(rec.get("uid", ""))
	k.lost_owner = owner_hunter

static func ground(m, at: Vector3) -> Vector3:
	if m.world.is_void(at.x, at.z):
		at = m.world.free_spot_near(at, [], 1.0, 0.4, 40.0)
	if m.world.is_void(at.x, at.z):
		return Vector3.INF
	at.y = m.world.ground_at(at.x, at.z)
	return at

## Each step while it guards (Kin._sim_dazed): its owner, once up, can cradle it.
static func tick_guard(k: Kin, dt: float) -> void:
	var h := k.owner_h
	if h == null:
		return
	if h.out or h.extracted or k.scan_by != null:       # (an enemy is scanning it: no cradle starts)
		if k.rescue_on:
			KinDowned.stop(k, h, "gone")
		k.rescue_t = 0.0
		return
	KinDowned.step_rescue(k, h, dt)

## The Boki a hunter is carrying right now, if any (a guard may sit outside their kin slots).
static func rescuing(h: Hunter) -> Kin:
	if not h.has_meta("carry"):       # (set when the carry starts: no scan of every Boki each step)
		return null
	var k = h.get_meta("carry")
	if is_instance_valid(k) and k.rescue_on and k.owner_h == h and (k.state == "downed" or guarding(k)):
		return k
	return null

## The cradle finished (KinDowned.come_round): it is the owner's again, in a slot.
static func reclaimed(k: Kin) -> void:
	if k.lost_owner == null:
		return
	var h := k.owner_h
	var uid := k.lost_uid
	k.lost_from = ""
	k.lost_uid = ""
	k.lost_owner = null
	for L in k.m.player_lost.duplicate():
		if String(L["uid"]) == uid:
			k.m.player_lost.erase(L)
	if h == null:
		return
	if h.kin != k and h.kin2 != k:
		if h.kin == null or (h.kin as Kin).dead:
			h.kin = k
			h.apply_kin_bonus()
		else:
			h.kin2 = k
	if h.kin2 == k:
		k.bench()

## Where each of your lost Boki ends up when the match is over: [{uid, fate, holder, rec}]. fate is "ransom" (nobody
## took it, or its taker is out), "rival" (a rival who is still in has it), "squad" or "self".
static func resolve(m) -> Array:
	var out: Array = []
	for L in m.player_lost:
		var fate := "ransom"
		var who := ""
		var holder = L.get("holder")
		if holder is Hunter:
			var hh: Hunter = holder
			if hh == m.player:
				fate = "self"
			elif hh.team == m.player.team:
				fate = "squad" if not hh.out else "ransom"
				who = hh.pname
			elif not hh.out:
				fate = "rival"
				who = hh.pname
		out.append({"uid": L["uid"], "fate": fate, "holder": who, "rec": L["rec"]})
	return out

# ------------------------------------------------------------------ after the match: the save
## The outcome string for a resolved fate.
static func outcome_of(fate: String, holder: String) -> String:
	match fate:
		"rival":
			return "captured_by:" + holder
		"ransom":
			return "ransom"
	return "home"

## Writes what became of a Boki into the save. boki is its roster record; outcome is "home" (clears any
## flag), "ransom" (at the Ransom House, waiting) or "captured_by:<player name>" (lost to that player).
## The flags are plain optional fields: a save without them is a Boki that is fine.
static func after_match(save: Dictionary, boki: Dictionary, outcome: String) -> void:
	clear(boki)
	var stamp := {"match": int(save.get("matches", 0)), "t": int(Time.get_unix_time_from_system())}
	if outcome == "ransom":
		boki["ransom"] = stamp
	elif outcome.begins_with("captured_by:"):
		stamp["by"] = outcome.substr("captured_by:".length())
		boki["lost_to"] = stamp
	elif outcome != "home":
		push_warning("KinLoss.after_match: unknown outcome '%s'" % outcome)

## Resolved (bought back, won back): the flags come off.
static func clear(boki: Dictionary) -> void:
	boki.erase("ransom")
	boki.erase("lost_to")

## Waiting at the Ransom House or lost to a player.
static func held(boki: Dictionary) -> bool:
	return boki.has("ransom") or boki.has("lost_to")

## Can it be brought into a match?
static func selectable(boki: Dictionary) -> bool:
	return not held(boki)
