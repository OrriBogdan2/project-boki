extends RefCounted
## --wisp-proc-check: a carried Boki's always-on passive acting (heal, shield, damage, speed) makes one quiet chirp
## from the wisp (KinWispProc): one chirp per cue in the species' own voice, at most one per 0.8 s per wisp, yours
## over a rival's, both under an ability cast, silent when the Boki walks; your first cue names the passive once
## (the tip, Match._tips). Prints PASS/FAIL. Never touches the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("WISPPROC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 2,
			"tier": 0,
			"length": 1e9,
			"seed": 78,
			"no_drop": true,
			"demo_kin": "cindle",
			"boki_wisps": true
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	for i in 18:
		m.step(DT)
		m.player.kin.render(DT, 1.0)
	var k: Kin = m.player.kin
	ok(k != null and k.wisp, "your Boki rides as a wisp")
	ok(KinWispProc.tip(k) == "", "no cue yet: no tip")
	for kind in ["heal", "shield", "damage", "speed"]:
		_one_per_cue(k, kind)
	_rate(k)
	_levels(m.player)
	_tip(k)
	_rival()
	KinWisp.set_wisp(k, false)
	var n := KinWispProc.played
	_trigger(k, "heal")
	ok(KinWispProc.played == n, "a walking Boki (not a wisp) stays silent")
	m.queue_free()
	print("WISPPROCCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## Make the hunter's state do what the kind reads, over two rendered frames.
func _trigger(k: Kin, kind: String) -> void:
	var h := k.owner_h
	var stat: String = {"heal": "regen", "shield": "armor", "damage": "damage", "speed": "move_speed"}[kind]
	k.ks.carry_passives = [{"stat": stat, "amount": 0.1, "category": ""}]
	match kind:
		"heal":
			h.hp = h.max_hp - 10.0
		"shield":
			h.armor = 20.0
		"damage":
			h.muzzle_t = 0.0
		"speed":
			h.vel = Vector3.ZERO
	m.time += 0.01
	k.render(DT, 1.0)
	match kind:
		"heal":
			h.hp += 5.0
		"shield":
			h.armor -= 5.0
		"damage":
			h.muzzle_t = 0.05
		"speed":
			h.vel = Vector3(KinWispProc.RUN_START + 1.0, 0, 0)
	m.time += 0.01
	k.render(DT, 1.0)
	h.vel = Vector3.ZERO


## Every passive kind: one cue gives exactly one chirp, and it is the species' own voice.
func _one_per_cue(k: Kin, kind: String) -> void:
	m.time += 1.0
	var n := KinWispProc.played
	_trigger(k, kind)
	ok(KinWispProc.played - n == 1 and k.proc.last_kind == kind, "%s: one chirp (%d)" % [kind, KinWispProc.played - n])
	var own := "bk_%s_happy" % k.species
	ok(KinVoice.cue(k.species, "happy") == own or not Sfx.ensure(own), "%s chirps in its species voice" % k.species)


## Two cues 0.55 s apart give one chirp; past 0.8 s it chirps again.
func _rate(k: Kin) -> void:
	m.time += 1.0
	var n := KinWispProc.played
	_trigger(k, "heal")
	m.time += 0.55
	_trigger(k, "heal")
	ok(KinWispProc.played - n == 1, "two cues 0.55 s apart: one chirp")
	m.time += 0.4
	_trigger(k, "heal")
	ok(KinWispProc.played - n == 2, "past 0.8 s it chirps again")


## Yours over a rival's, and both give way under an ability cast.
func _levels(p: Hunter) -> void:
	var rival: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	p.cast_at = -9.0
	rival.cast_at = -9.0
	ok(
		KinWispProc.level_db(p) == KinWispProc.OWN_DB and KinWispProc.level_db(rival) == KinWispProc.RIVAL_DB,
		"yours %d dB, a rival's %d dB" % [KinWispProc.OWN_DB, KinWispProc.RIVAL_DB]
	)
	ok(KinWispProc.OWN_DB <= -18.0 and KinWispProc.RIVAL_DB < KinWispProc.OWN_DB, "quiet: under -18 dB, rivals lower")
	p.cast_at = m.time
	ok(KinWispProc.level_db(p) == KinWispProc.OWN_DB + KinWispProc.DUCK_DB, "your chirp ducks under your cast")
	p.cast_at = -9.0


## The tip names the passive right after a cue, and only then.
func _tip(k: Kin) -> void:
	_trigger(k, "heal")
	var t := KinWispProc.tip(k)
	ok(t.begins_with("%s's carry passive: " % k.rec.get("name", "Your Boki")) and t.length() > 30, "the tip: '%s'" % t)
	m.time += KinWispProc.TIP_KEEP_S + 1.0
	ok(KinWispProc.tip(k) == "", "...and it lapses when the cue is old")
	m.time -= KinWispProc.TIP_KEEP_S + 1.0
	ok(m.tip_once("proc") and not m.tip_once("proc"), "Match._tip's once-per-save gate holds the tip to one showing")


## A rival's wisp chirps on its own proc too.
func _rival() -> void:
	var rk: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x.owner_h.team != m.player.team)[0]
	if not rk.wisp:
		KinWisp.set_wisp(rk, true)
	m.time += 1.0
	var n := KinWispProc.played
	_trigger(rk, "damage")
	ok(KinWispProc.played - n == 1, "a rival's wisp chirps on its own proc")
