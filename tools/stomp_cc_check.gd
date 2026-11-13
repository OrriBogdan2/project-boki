extends RefCounted
## --stomp-cc-check: a stomp (Stomp.start, docs/decisions/0061) is uncancellable except by its TIME running out
## or the stomper being hard-CC'd (Stomp.breaks; briefs/DECISIONS.md 2026-11-11). Every hard CC in
## docs/KIT_PARITY.md "Crowd control" (stuns, Ground, roots, wall stuns, the Nightwell pull, Snap, Rimelock,
## the Bola pair, Anchor, a reel, a hard knock) lands on a stomper a second in and must cancel it with the
## wisp alive; slows, Daze and a hit's small shove must not. A CC is checked by the channel it travels
## (hurt opts, KitStatus, a Displace tow, a knock), with the kit's real numbers.
## Prints STOMP ok/FAIL and a STOMPCCCHECK PASS/FAIL line. --stomp-check covers the lock itself.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node
var s: Hunter        # the stomper
var o: Hunter        # the wisp under its feet
var f: Hunter        # a foe of the stomper, who lands the CC

func ok(cond: bool, what: String) -> void:
	print("STOMP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		for kk in [h.kin, h.kin2]:
			if kk:
				m.kins.erase(kk)
				kk.queue_free()
		h.kin = null
		h.kin2 = null
	o = m.player
	s = m.hunters.filter(func(x): return x.team != o.team)[0]
	f = m.hunters.filter(func(x): return x.team == o.team and x != o)[0]
	var home := o.pos
	for h in m.hunters:
		if h != o and h != s:
			h.teleport(Vector3(home.x + 60.0, m.world.ground_at(home.x + 60.0, home.z), home.z))
	_baseline()
	for row in _hard():
		_row(row[0], row[1], true)
	for row in _soft():
		_row(row[0], row[1], false)
	_finish()
	print("STOMPCCCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## [name, Callable(): the CC as the kit puts it on the stomper]. Numbers from KIT_PARITY "Crowd control".
func _hard() -> Array:
	var stun := func(sec: float) -> Callable: return func(): s.hurt(1.0, f, {"src": "abil", "stun": sec})
	var tow := func(stun_s: float) -> Callable:
		return func():
			m.displace.tow(s, null, {"mode": "glide", "to": [s.pos.x + 9.0, s.pos.y, s.pos.z], "spd": 6.0, "gap": 0.5,
				"dur": 1.5, "stun": stun_s})
	return [
		["Vex wall slam stun 0.7", stun.call(0.7)], ["Zedran Meteor core stun 0.8", stun.call(0.8)],
		["Zedran Chain Lunge stun 0.35", stun.call(0.35)], ["Zedran Haul Slam stun 0.6", stun.call(0.6)],
		["Hem Heartpiercer wall stun 1.2", stun.call(1.2)], ["Tarek punch wall stun 0.9", stun.call(0.9)],
		["Tarek Volcano slam stun 1.2", stun.call(1.2)], ["Claire Rimelock stun 0.75", stun.call(0.75)],
		["Ostra Snap stun 1.8", stun.call(1.8)], ["Albert Crush stun 1.0", stun.call(1.0)],
		["Albert Shield Slam stun 0.6", stun.call(0.6)], ["Albert Crushing Blow stun 0.4", stun.call(0.4)],
		["Ryzz Storm Rod wall stun 0.8", stun.call(0.8)], ["Sable Bola pair stun 0.9", stun.call(0.9)],
		["Grimble Anchor stun 1.1", stun.call(1.1)],
		["Pip Burrseed root 1.1", func(): s.hurt(1.0, f, {"src": "abil", "root": 1.1})],
		["Pip Burrseed root 1.4 (rank 3)", func(): s.hurt(1.0, f, {"src": "abil", "root": 1.4})],
		["Sable Bola Grounded 1.5", func(): KitStatus.apply(s, "gnd", 1.5)],
		["Ryzz Skycall Grounded 1.5", func(): KitStatus.apply(s, "gnd", 1.5)],
		["Grimble Anchor Grounded", func(): KitStatus.apply(s, "gnd", 1.0)],
		["Ostra Nightwell stun and pull 3.5", func():
			s.hurt(1.0, f, {"src": "abil", "stun": 3.5})
			tow.call(0.0).call()],
		["Grimble hook reel (stun 0.2 and a haul)", func():
			s.hurt(1.0, f, {"src": "abil", "stun": 0.2})],
		["a pull with no stun (a bare tow)", tow.call(0.0)],
		["a hard knockback", func(): s.impulse(Vector2(14.0 * s.mass(), 0.0), -1.0)],      # Capture.HARD_KNOCK
	]

func _soft() -> Array:
	var slow := func(k: float, sec: float) -> Callable:
		return func(): s.hurt(1.0, f, {"src": "abil", "slow": sec, "slow_k": k})
	return [
		["a hit's small shove", func(): s.impulse(Vector2(4.0 * s.mass(), 0.0), -1.0)],
		["Vex Cinderfall slow 30%", slow.call(0.3, 0.6)], ["Zedran Meteor ring slow 40%", slow.call(0.4, 1.5)],
		["Zedran Fireblast slow 30%", slow.call(0.3, 1.0)], ["Hem Rain of Arrows slow 35%", slow.call(0.35, 0.8)],
		["Cinder Shot slow 30%", slow.call(0.3, 1.5)], ["Tarek Basalt Spine slow 35%", slow.call(0.35, 1.0)],
		["Claire Ice Spear slow 35%", slow.call(0.35, 0.8)], ["Claire Rimelock build to 55%", slow.call(0.55, 1.5)],
		["Ostra orb slow 10%", slow.call(0.1, 1.5)], ["Sable Shadow Knife slow 50%", slow.call(0.5, 2.5)],
		["Sable Bola slow 30%", slow.call(0.3, 1.5)],
		["Ostra Trade Disoriented", func(): KitStatus.apply(s, "dsr", 1.5, 0.4)],
		["Vex Burr Charge Daze 1.4", func(): KitStatus.apply(s, "rat", 1.4)],
		["Daze and a slow together", func():
			KitStatus.apply(s, "rat", 1.4)
			s.hurt(1.0, f, {"src": "abil", "slow": 1.0, "slow_k": 0.3})],
	]

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## Resets both bodies (no CC left over, a full wisp), then the stomper starts on the wisp.
func _stage() -> void:
	if not s.stomp.is_empty(): Stomp.end(m, s, "gone")
	var at := Vector3(o.pos.x, m.world.ground_at(o.pos.x, o.pos.z), o.pos.z)
	s.teleport(at + Vector3(0.6, 0, 0))
	for h in [s, o]:
		h.stun_t = 0.0
		h.root_t = 0.0
		h.slow_t = 0.0
		h.knock_t = 0.0
		h.kb_t = -9.0
		h.launched_at = -9.0
		h.vel = Vector3.ZERO
		for key in ["gnd_until", "rat_until", "dsr_until"]:
			h.set_meta(key, 0.0)
	for t in m.displace.tows.duplicate():
		m.displace.stop(t)
	if not o.downed:
		m.knock(o, f, {})
	o.down_hp = float(Data.MATCH["down_hp"])
	s.hp = s.max_hp
	Stomp.start(m, s, o)
	_step(1.0)         # a second in: the animation is under way, the first foot has come down

func _baseline() -> void:
	_stage()
	ok(not s.stomp.is_empty() and Stomp.beat(s) >= Stomp.SLAM, "a stomp a second in is running with a foot down")

## Last, since it kills the wisp: with no CC the animation finishes.
func _finish() -> void:
	_stage()
	_step(Stomp.TIME)
	ok(s.stomp.is_empty() and o.out, "with no CC the animation finishes and the wisp dies")

func _row(what: String, cc: Callable, cancels: bool) -> void:
	_stage()
	cc.call()
	_step(0.25)
	var running := not s.stomp.is_empty()
	var alive := o.downed and not o.out
	if cancels:
		ok(not running and alive, "%s cancels the stomp and the wisp lives" % what)
	else:
		ok(running and alive, "%s does not cancel the stomp" % what)
