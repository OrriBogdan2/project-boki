extends RefCounted
## --capture-check: capture by scan and the Field Book (docs/decisions/0002). Prints PASS/FAIL lines.
##   1. gating: only a knocked-out wild Boki can be scanned
##   2. the flow: hold 0.4s commits, then 4s runs on its own (let go), you are rooted and cannot shoot
##   3. one active Boki: the captured one is only a capsule in the box, never in the world
##   4. interruptions: crowd control and a dash cancel it, plain damage does not; the daze timer waits
##   5. the box: capacity 3 from the rules, shown on the HUD, a full box blocks, Release frees a place
##   6. your own Boki does not finish a dazed wild Boki
##   7. the Field Book: logged on sight with a place; the v3 save migration
##   8. the net: rivals see and hear the scan (events, a timeout when nobody confirms)
##   9. bots scan the same way
##  10. mid-scan: a hunter downed, extracted or killed, walking past the cancel range, and the box filling
##      during the scan all clean up (no beam, no hum, the Boki wakes up on its own timer)
##  11. looting a deathbox cannot push your box past its capacity

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("CAPTURE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh() -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle", "cls": "medium", "demo_kin": "cindle"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	P.kin.teleport(P.pos + Vector3(1.0, 0, 0.7))
	for h in m.hunters:
		if h.team != P.team:
			h.ctrl = "idle"
			h.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0))
	for i in 20:
		_tidy()
		m.step(Match.DT)
	return m

func _tidy() -> void:
	for mb in m.mobs.duplicate():
		m.mobs.erase(mb)
		mb.queue_free()

func run_for(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		_tidy()
		m.step(Match.DT); t += Match.DT

## A wild Boki 2 m from the player, knocked out unless `dazed` is false.
func wild(species := "puddlet", dazed := true) -> Kin:
	var P := m.player
	var rec := Save.new_kin(species, "", 77)
	rec["level"] = 3
	var at: Vector3 = P.pos + Vector3(2.0, 0, 0.0)
	var k := m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), dazed)
	run_for(0.2)
	return k

func alive_kin_of(h: Hunter) -> int:
	var n := 0
	for k in m.kins:
		if not k.dead and k.owner_h == h and k.state != "bench":
			n += 1
	return n

## Hold the interact key until the scan has committed, then let go.
func begin(P: Hunter) -> void:
	P.inp["interact"] = true
	run_for(float(Capture.rules()["hold_s"]) + 0.15)
	P.inp["interact"] = false

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture-only="): only = a.substr(15)
	for part in ["gating", "flow", "interrupts", "mid_scan", "box", "loot", "own_kin", "book", "net", "bots", "bots_full"]:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	print("CAPTURE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. gating
func _gating() -> void:
	_fresh()
	var P := m.player
	var k := wild("puddlet", false)
	ok(k.state != "dazed" and Capture.block_reason(P, k) != "", "a wild Boki on its feet cannot be scanned (%s)" % Capture.block_reason(P, k))
	P.inp["interact"] = true
	run_for(1.0)
	P.inp["interact"] = false
	ok(Capture.state(P).is_empty() and P.caught.is_empty(), "...holding the key next to it starts nothing")
	k.hp = 0.0
	k._daze()
	run_for(0.1)
	ok(k.state == "dazed" and Capture.block_reason(P, k) == "", "once it is knocked out the scan is allowed")
	ok(CaptureHud.prompt(P, k).contains("scan"), "...and the prompt says to hold the key to scan it (\"%s\")" % CaptureHud.prompt(P, k))

# ------------------------------------------------------------------ 2. flow, 3. one active Boki
func _flow() -> void:
	_fresh()
	var P := m.player
	var k := wild()
	var kin0: Ent = P.kin
	var kin2_0: Ent = P.kin2
	var own0 := alive_kin_of(P)
	var hold_s := float(Capture.rules()["hold_s"])
	var scan_s := float(Capture.rules()["scan_s"])
	var t := 0.0
	var committed_at := -1.0
	P.inp["interact"] = true
	while t < hold_s + 1.0 and committed_at < 0.0:
		_tidy(); m.step(Match.DT); t += Match.DT
		if Capture.active(P): committed_at = t
	ok(committed_at >= hold_s - 0.1 and committed_at <= hold_s + 0.25, "holding the key for %.1fs commits the scan (at %.2fs)" % [hold_s, committed_at])
	P.inp["interact"] = false         # let go: it runs on its own
	P.inp["move"] = Vector2(1, 0)
	P.inp["fire"] = true
	var p0 := P.pos
	run_for(1.0)
	ok(Capture.active(P) and Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length() < 0.2, "...rooted while it runs (moved %.2fm)" % Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length())
	ok(not P.can_fire(), "...and you cannot shoot")
	ok(k.state == "dazed" and k.scan_by == P, "...the Boki is held in its daze by the scan")
	ok(P.caught.is_empty(), "...nothing is in the box yet")
	run_for(scan_s - 1.0 + 0.5)
	P.inp["move"] = Vector2.ZERO
	P.inp["fire"] = false
	ok(not Capture.active(P) and P.caught.size() == 1, "after %.0fs it completes by itself (box %d)" % [scan_s, P.caught.size()])
	ok(k.dead and not k.visible, "the wild Boki is gone from the world")
	ok(own0 == 1 and P.kin == kin0 and P.kin2 == kin2_0 and alive_kin_of(P) == own0, "you still have exactly one active Boki (the same one: %d out)" % alive_kin_of(P))
	var spawned := 0
	for o in m.kins:
		if not o.dead and o.owner_h == null and o.rec.get("uid", "") == k.rec.get("uid", "x") and o.state != "bench":
			spawned += 1
	ok(spawned == 0, "the captured Boki is not alive anywhere in the world; it is only a capsule in the box")
	ok(P.caught.size() == 1 and String(P.caught[0]["species"]) == k.species, "...the capsule is in your box (%s)" % CaptureHud.box_text(P))
	run_for(3.0)
	ok(P.kin == kin0 and alive_kin_of(P) == own0 and P.caught.size() == 1, "...and it never follows you or joins your Boki (still %d out)" % alive_kin_of(P))

# ------------------------------------------------------------------ 4. interruptions
func _interrupts() -> void:
	for why in ["stun", "root", "dash", "damage", "nudge", "knock"]:
		_fresh()
		var P := m.player
		var k := wild()
		begin(P)
		if not Capture.active(P):
			ok(false, "%s: the scan did not start" % why)
			continue
		run_for(0.5)
		match why:
			"stun": P.stun_t = 0.4
			"root": P.root_t = 0.4
			"dash": P.inp["dash"] = true
			"damage": P.hurt(8.0, m.hunters[1])
			"knock": P.impulse(Vector2(Capture.HARD_KNOCK + 4.0, 0) * P.mass())
			"nudge": P.impulse(Vector2(Capture.HARD_KNOCK - 3.0, 0) * P.mass())
		run_for(0.1)
		P.inp["dash"] = false
		if why == "damage" or why == "nudge":
			ok(Capture.active(P) and k.scan_by == P, "%s does not interrupt the scan" % ("a shove under 8 m/s" if why == "nudge" else "plain damage"))
			run_for(float(Capture.rules()["scan_s"]))
			ok(P.caught.size() == 1, "...and it completes")
		else:
			ok(not Capture.active(P) and k.scan_by == null and k.state == "dazed" and P.caught.is_empty(), "%s cancels the scan; the Boki is still there and dazed" % why)
	# the daze timer waits while the scan runs and then resumes
	_fresh()
	var P2 := m.player
	var k2 := wild()
	var d0 := k2.dazed_t
	begin(P2)
	var d1 := k2.dazed_t
	run_for(2.0)
	ok(Capture.active(P2) and absf(k2.dazed_t - d1) < 0.05 and d1 <= d0, "the daze timer waits during the scan (%.2f to %.2f)" % [d1, k2.dazed_t])
	P2.stun_t = 0.3
	run_for(0.5)
	var d2 := k2.dazed_t
	run_for(1.0)
	ok(not Capture.active(P2) and k2.dazed_t < d2 - 0.5, "...and runs again once it is interrupted (%.2f to %.2f)" % [d2, k2.dazed_t])
	if k2.state == "dazed":
		P2.stun_t = 0.0
		begin(P2)
		run_for(float(Capture.rules()["scan_s"]) + 0.3)
		ok(P2.caught.size() == 1, "after an interruption you can try again and finish")

# ------------------------------------------------------------------ 5. the box
func _box() -> void:
	_fresh()
	var P := m.player
	var cap := Capture.box_cap()
	ok(cap == int(Content.rules("capture")["box_capacity"]) and cap == 3, "the box holds %d (from content/rules/capture.json)" % cap)
	for i in cap:
		P.caught.append(Save.new_kin("puddlet", "Filler%d" % i, 10 + i))
	var k := wild()
	ok(Capture.block_reason(P, k).contains("Box full"), "a full box blocks the scan (\"%s\")" % Capture.block_reason(P, k))
	ok(CaptureHud.box_text(P) == "Box 3/3", "the HUD shows the box (%s)" % CaptureHud.box_text(P))
	begin(P)
	ok(not Capture.active(P) and Capture.state(P).is_empty(), "...holding the key does not start one")
	ok(Capture.release(m, P, 0) and P.caught.size() == cap - 1, "Release lets a capsule go (%d left)" % P.caught.size())
	begin(P)
	ok(Capture.active(P), "with a free place the scan starts")
	run_for(float(Capture.rules()["scan_s"]) + 0.3)
	ok(P.caught.size() == cap, "...and fills the box again (%s)" % CaptureHud.box_text(P))

# ------------------------------------------------------------------ 6. your own Boki
func _own_kin() -> void:
	_fresh()
	var P := m.player
	var k := wild()
	var hp0 := k.hp
	var kin: Kin = P.kin
	kin.cmd = "chase"
	kin.chase_target = k
	P.inp["aim"] = k.pos + Vector3(0, 0.5, 0)
	kin.teleport(k.pos + Vector3(-1.0, 0, 0.0))
	run_for(5.0)
	ok(k.state == "dazed" and not k.dead and k.hp >= hp0 - 0.01, "your Boki ordered to chase leaves a knocked-out wild Boki alone (hp %.1f, %s)" % [k.hp, k.state])
	kin.throw_to(k.pos)
	run_for(3.0)
	ok(k.state == "dazed" and not k.dead, "...even when sent at it with a Sic")

# ------------------------------------------------------------------ 7. the Field Book
func _book() -> void:
	_fresh()
	var P := m.player
	Save.d["dex"] = {}
	var k := wild("pebbit", false)
	run_for(1.5)
	FieldBook.scan_sights(m)
	var e: Dictionary = Care.dex_entry("pebbit")
	ok(bool(e.get("seen", false)) and not bool(e.get("caught", false)), "a wild Boki in view is logged as seen, not caught")
	ok(FieldBook.seen_count() >= 1, "...the book counts it (%d seen)" % FieldBook.seen_count())
	ok((e.get("places", []) as Array).size() >= 1, "...with where it was seen (%s)" % str(e.get("places", [])))
	for i in 6:
		Care.dex_mark("pebbit", "place", "Place%d" % i)
	ok((Care.dex_entry("pebbit")["places"] as Array).size() <= int(Content.rules("capture")["sight_places_kept"]), "the list of places is capped")
	Save.d["dex"] = {}
	k.teleport(P.pos + Vector3(60.0, 0, 0))
	FieldBook.scan_sights(m)
	ok(not bool(Care.dex_entry("pebbit").get("seen", false)), "a Boki far out of sight is not logged")
	var old := {"v": 3, "roster": [{"species": "puddlet", "name": "Old"}, {"species": "cindle", "name": "Older"}], "dex": {"puddlet": {"seen": false, "caught": true, "forms": [], "shimmer": false, "mutations": []}}}
	var upgraded: bool = Save.migrate(old)
	ok(upgraded and int(old["v"]) == Save.VERSION and Save.VERSION >= 4, "a v3 save upgrades to v%d" % Save.VERSION)
	var dx: Dictionary = old["dex"]
	ok(bool(dx.get("puddlet", {}).get("seen", false)) and bool(dx.get("cindle", {}).get("seen", false)) and bool(dx.get("cindle", {}).get("caught", false)), "...Boki you own count as seen, and are in the book even with no entry")
	ok(dx["puddlet"].has("places") and dx["cindle"].has("places"), "...and every entry gets its places list")

# ------------------------------------------------------------------ 8. the net
func _net() -> void:
	_fresh()
	var P := m.player
	var rival: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			rival = h; break
	var k := wild()
	rival.teleport(P.pos + Vector3(8.0, 0, 0))
	Capture.on_net(m, rival, "scan_start", "%s|0.25" % k.nid)
	ok(Capture.active(rival) and k.scan_by == rival, "a rival's scan event shows their beam here and holds the Boki's daze")
	ok(Capture.state(rival).get("beam") != null, "...a beam node exists for others to see")
	var d0 := k.dazed_t
	run_for(1.0)
	ok(absf(k.dazed_t - d0) < 0.05, "...and the daze timer waits for it")
	Capture.on_net(m, rival, "scan_stop", "%s|0.00" % k.nid)
	ok(not Capture.active(rival) and k.scan_by == null, "scan_stop ends it")
	Capture.on_net(m, rival, "scan_start", "%s|0.25" % k.nid)
	run_for(Capture.HOLD_OVER + 0.5)
	ok(not Capture.active(rival) and k.scan_by == null, "a scan nobody confirms times out, so the Boki can wake up again")
	ok(BlightDir.LOUD.has("scan"), "the scan is a sound rivals and the Blight react to")
	ok(Net.VERSION.naturalnocasecmp_to("0.11.0") >= 0, "Net.VERSION is %s (at least merge forms' 0.11.0)" % Net.VERSION)

# ------------------------------------------------------------------ 9. bots
func _bots() -> void:
	_fresh()
	var P := m.player
	var bot: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			bot = h; break
	bot.ctrl = "bot"
	bot.teleport(P.pos + Vector3(-6.0, 0, 2.0))
	P.teleport(P.pos + Vector3(30.0, 0, 0))
	var rec := Save.new_kin("puddlet", "", 31)
	rec["level"] = 3
	var at: Vector3 = bot.pos + Vector3(4.0, 0, 0.0)
	var k := m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)
	var scanned := false
	var t := 0.0
	while t < 25.0 and bot.caught.is_empty():
		_tidy(); m.step(Match.DT); t += Match.DT
		if Capture.active(bot): scanned = true
	ok(scanned, "a bot walks to a knocked-out wild Boki and holds a scan")
	ok(bot.caught.size() == 1 and k.dead, "...and the capsule ends up in its box (%.1fs)" % t)

# ------------------------------------------------------------------ 10. what happens mid-scan
func _mid_scan() -> void:
	for why in ["downed", "extracted", "killed", "range"]:
		_fresh()
		var P := m.player
		var k := wild()
		begin(P)
		if not Capture.active(P):
			ok(false, "%s: the scan did not start" % why)
			continue
		var hum := "scanhum" + P.nid
		run_for(0.5)
		match why:
			"downed": P.downed = true
			"extracted": P.extracted = true
			"killed": P.out = true
			"range": k.teleport(P.pos + Vector3(float(Capture.rules()["cancel_range"]) + 3.0, 0, 0))      # (knocked away, or you were: past the range)
		run_for(0.2)
		ok(Capture.state(P).is_empty() and k.scan_by == null and not Sfx.loop_on(hum) and k.state == "dazed" and P.caught.is_empty(), "%s mid-scan: the scan is gone, no hum, the Boki is free and still dazed" % why)
	# the match ending mid-scan stops the hum (loop keys outlive the node)
	_fresh()
	var P2 := m.player
	var k2 := wild()
	begin(P2)
	run_for(0.3)
	var hum2 := "scanhum" + P2.nid
	var had_hum := Sfx.loop_on(hum2)
	Capture.teardown(m)
	ok(Capture.state(P2).is_empty() and not Sfx.loop_on(hum2), "tearing the match down stops the scan hum (it was %s)" % ("on" if had_hum else "never started here"))
	# the box fills while the scan runs: it lets go, nothing is added past the cap
	_fresh()
	var P3 := m.player
	var k3 := wild()
	begin(P3)
	run_for(1.0)
	for i in Capture.box_cap():
		P3.caught.append(Save.new_kin("puddlet", "Filler%d" % i, 10 + i))
	run_for(float(Capture.rules()["scan_s"]) + 0.3)
	ok(P3.caught.size() == Capture.box_cap() and not k3.dead and k3.state == "dazed" and k3.scan_by == null and Capture.state(P3).is_empty(), "the box filling during the scan: it lets go, the box stays at %d and the Boki is not taken" % P3.caught.size())

# ------------------------------------------------------------------ 11. looting
func _loot() -> void:
	_fresh()
	var P := m.player
	var cap := Capture.box_cap()
	var b := {"caught": [Save.new_kin("cindle", "Spare", 5)], "kin": [], "owner": null, "pos": P.pos, "gems": 0, "seeds": {}, "tonics": 0, "kits": 0, "keys": 0,
		"node": null, "empty": false, "gear": [], "weapon": {}, "pack": []}
	for i in cap:
		P.caught.append(Save.new_kin("puddlet", "Filler%d" % i, 10 + i))
	Life.take_item(m, P, b, {"key": "caught", "i": 0})
	ok(P.caught.size() == cap and (b["caught"] as Array).size() == 1, "a deathbox capsule you cannot fit stays in the box (yours %d/%d)" % [P.caught.size(), cap])
	P.caught.pop_back()
	Life.take_item(m, P, b, {"key": "caught", "i": 0})
	ok(P.caught.size() == cap and (b["caught"] as Array).is_empty(), "...and with a free place it comes across")

func _bots_full() -> void:
	_fresh()
	var P := m.player
	var bot: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			bot = h; break
	bot.ctrl = "bot"
	bot.teleport(P.pos + Vector3(-6.0, 0, 2.0))
	P.teleport(P.pos + Vector3(30.0, 0, 0))
	for i in Capture.box_cap():
		bot.caught.append(Save.new_kin("puddlet", "Filler%d" % i, 10 + i))
	var rec := Save.new_kin("puddlet", "", 31)
	var at: Vector3 = bot.pos + Vector3(4.0, 0, 0.0)
	var k := m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)
	var chose := false
	var scanned := false
	var t := 0.0
	while t < 8.0:
		_tidy(); m.step(Match.DT); t += Match.DT
		if String(bot.ai.get("goal_kind", "")) == "catch": chose = true
		if not Capture.state(bot).is_empty(): scanned = true
	ok(not chose and not scanned and not k.dead, "a bot with a full box does not walk to a knocked-out Boki or scan it")
