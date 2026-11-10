extends RefCounted
## --wisp-proc-sfx-check: each proc cue of a carried Boki's always-on passive (WispProc: heal, shield, damage,
## speed) also makes one quiet chirp from the species' own voice (KinWispProc). One chirp per cue, at most one per
## 0.8 s per wisp even when the look cues every 0.5 s, the species' own bank (bk_<species>_happy), pitched by
## size, a rival's quieter than yours, both under an ability cast, silent when the Boki walks. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("WISPPROCSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true,
		"demo_kin": "cindle", "boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	_frames(0.3)
	var p: Hunter = m.player
	var k: Kin = p.kin
	ok(k != null and k.wisp, "your Boki rides as a wisp")
	_bank(k)
	for kind in ["heal", "shield", "damage", "speed"]:
		_one_per_cue(k, kind)
	_rate(k)
	_levels(p)
	_pitch(k)
	_rival()
	KinWisp.set_wisp(k, false)
	k.proc_at = -9.0
	ok(KinWispProc.chirp(k) == "", "a walking Boki (not a wisp) stays silent")
	m.queue_free()
	print("WISPPROCSFX %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			h.render(DT, 1.0)

func _proc(k: Kin) -> WispProc:
	return k.get_node_or_null("Proc") as WispProc

## The species' own bank exists and is the one the chirp picks.
func _bank(k: Kin) -> void:
	var own := "bk_%s_happy" % k.species
	ok(Sfx.ensure(own) and KinVoice.cue(k.species, "happy") == own, "%s has its own bank (%s)" % [k.species, own])

## Make the hunter's state do what the kind reads, over two rendered frames (as --wisp-proc-check does).
func _trigger(k: Kin, kind: String) -> void:
	var h := k.owner_h
	var stat: String = {"heal": "regen", "shield": "armor", "damage": "damage", "speed": "move_speed"}[kind]
	k.ks.carry_passives = [{"stat": stat, "amount": 0.1, "category": ""}]
	match kind:
		"heal": h.hp = h.max_hp - 10.0
		"shield": h.armor = 20.0
		"damage": h.muzzle_t = 0.0
		"speed": h.vel = Vector3.ZERO
	m.time += 0.01
	k.render(DT, 1.0)
	match kind:
		"heal": h.hp += 5.0
		"shield": h.armor -= 5.0
		"damage": h.muzzle_t = 0.05
		"speed": h.vel = Vector3(WispProc.RUN_START + 1.0, 0, 0)
	m.time += 0.01
	k.render(DT, 1.0)
	h.vel = Vector3.ZERO

## Every passive kind: one look cue gives exactly one chirp, in the species' voice.
func _one_per_cue(k: Kin, kind: String) -> void:
	m.time += 1.0
	k.proc_at = -9.0
	var cues := _proc(k).cues if _proc(k) else 0
	var n := KinWispProc.played
	_trigger(k, kind)
	var looks := _proc(k).cues - cues
	var chirps := KinWispProc.played - n
	ok(looks == 1 and chirps == 1, "%s: %d look cue, %d chirp" % [kind, looks, chirps])
	ok(KinWispProc.last_cue == KinVoice.cue(k.species, "happy"), "%s chirp uses %s" % [kind, KinWispProc.last_cue])

## The look may cue every 0.5 s; the chirp holds to one per 0.8 s per wisp.
func _rate(k: Kin) -> void:
	m.time += 1.0
	k.proc_at = -9.0
	var n := KinWispProc.played
	var cues := _proc(k).cues
	_trigger(k, "heal")
	m.time += 0.55
	_trigger(k, "heal")
	ok(_proc(k).cues - cues == 2 and KinWispProc.played - n == 1, "two looks 0.55 s apart: one chirp")
	m.time += 0.25              # 0.84 s after the first chirp, still inside the look's own 0.5 s gap
	ok(KinWispProc.chirp(k) != "" and KinWispProc.played - n == 2, "past 0.8 s it chirps again")
	for i in 5:
		KinWispProc.chirp(k)
	ok(KinWispProc.played - n == 2, "a flood in one instant adds nothing")

## Yours over a rival's, and both give way under an ability cast.
func _levels(p: Hunter) -> void:
	var rival: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	p.cast_at = -9.0
	rival.cast_at = -9.0
	ok(KinWispProc.level_db(p) == KinWispProc.OWN_DB and KinWispProc.level_db(rival) == KinWispProc.RIVAL_DB,
		"yours %d dB, a rival's %d dB" % [KinWispProc.OWN_DB, KinWispProc.RIVAL_DB])
	ok(KinWispProc.OWN_DB <= -18.0 and KinWispProc.RIVAL_DB < KinWispProc.OWN_DB, "quiet: under -18 dB, rivals lower")
	p.cast_at = m.time
	rival.cast_at = m.time
	ok(KinWispProc.level_db(p) == KinWispProc.OWN_DB + KinWispProc.DUCK_DB, "your chirp ducks under your ability cast")
	ok(KinWispProc.level_db(rival) < KinWispProc.RIVAL_DB, "a rival's chirp ducks under their cast")
	p.cast_at = -9.0
	rival.cast_at = -9.0

## Small bodies chirp higher than big ones.
func _pitch(k: Kin) -> void:
	var s: Dictionary = KinWispProc.SIZE_PITCH
	ok(float(s["small"]) > float(s["medium"]) and float(s["medium"]) > float(s["large"]), "pitch falls with body size")
	ok(s.has(k.ks.size), "%s's size (%s) has a pitch" % [k.species, k.ks.size])

## A rival's wisp chirps on its own proc, through the same look.
func _rival() -> void:
	var rk: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x.owner_h.team != m.player.team)[0]
	if not rk.wisp:
		KinWisp.set_wisp(rk, true)
	m.time += 1.0
	rk.proc_at = -9.0
	var n := KinWispProc.played
	_trigger(rk, "heal")
	ok(KinWispProc.played - n == 1, "a rival's wisp (%s) chirps on its heal" % rk.species)
