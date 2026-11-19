extends RefCounted
## --hearth-lamp-check: the Hearth Lamp belt item sets a revive beacon down that brings a downed
## teammate back with resurrection sickness (12 s, -25% damage and healing), shown as a heart status
## with its seconds on the plate and squad row and carried in the hunter snapshot (HunterNet "sk");
## another game stands the lamp up from the "bcn" "lamp" event; a tonic washes out anti-heal; a
## drink or repair that spills uses nothing.

var bad := 0
var main: Node
var m: Match
var p: Hunter
var ally: Hunter


func ok(cond: bool, what: String) -> void:
	print("LAMP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 7, "no_drop": true})
	m.set_process(false)
	p = m.player
	for h in m.hunters:
		if h != p and h.team == p.team:
			ally = h
	_lamp()
	_snapshot()
	_net()
	_tonic_and_spill()
	m.queue_free()
	print("LAMP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _steps(secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)


func _lamp() -> void:
	ok(UtilityBelt.is_item("hearth_lamp"), "the Hearth Lamp is a belt item")
	p.belt = UtilityBelt.empty()
	UtilityBelt.grant(p, "hearth_lamp", 1)
	ally.out = true
	var n := m.beacons.size()
	ok(UtilityBelt.use_id(p, "hearth_lamp"), "the lamp starts")
	ok(m.beacons.size() == n + 1 and UtilityBelt.count(p, "hearth_lamp") == 0, "a beacon is set; the lamp is used up")
	_steps(Beacons.time_s() + 1.0)
	var sick := ally.sick_t
	ok(not ally.out and sick > 0.0 and sick <= Life.R["sickness_time"], "the revived ally has sickness (%.1f s)" % sick)
	ally.hp = 10.0
	ally.heal(40.0)
	ok(absf(ally.hp - 40.0) < 0.5, "sickness cuts healing by a quarter (10 + 40 gives %.0f)" % ally.hp)
	var st: Array = HudPlate.statuses(ally).filter(func(x): return x[0] == "heart")
	ok(st.size() == 1 and absf(float(st[0][3]) - ally.sick_t) < 0.01, "plate and squad row show a heart and seconds")
	ally.sick_t = 0.0
	st = HudPlate.statuses(ally).filter(func(x): return x[0] == "heart")
	ok(st.is_empty(), "the heart is gone with the sickness")


func _snapshot() -> void:
	ally.sick_t = 7.3
	var row: Array = ["x", 1] + HunterNet.extra(ally)
	ally.sick_t = 0.0
	ally.lvl = 1
	HunterNet.apply(ally, row)
	ok(absf(ally.sick_t - 7.3) < 0.01, "sickness rides the hunter snapshot (%.1f)" % ally.sick_t)
	ally.sick_t = 0.0


func _net() -> void:
	var n := m.beacons.size()
	var at := p.pos + Vector3(9, 0, 0)
	Beacons.net_in(m, ["bcn", n, -1, "lamp", at.x, at.y, at.z])
	ok(m.beacons.size() == n + 1, "another game's lamp event stands a beacon up here")
	Beacons.net_in(m, ["bcn", n, -1, "lamp", at.x, at.y, at.z])
	ok(m.beacons.size() == n + 1, "...once")


func _tonic_and_spill() -> void:
	p.belt = UtilityBelt.empty()
	UtilityBelt.grant(p, "tonic", 2)
	p.hp = p.max_hp * 0.5
	p.blight_t = 30.0
	ok(UtilityBelt.use_id(p, "tonic"), "a tonic starts")
	_steps(UtilityUse.channel("tonic", "time") + 0.3)
	ok(p.blight_t <= 0.0 and p.hp > p.max_hp * 0.5 + 40.0, "it washes out anti-heal and heals whole (%.0f)" % p.hp)
	p.hp = p.max_hp * 0.5
	ok(UtilityBelt.use_id(p, "tonic") and p.drink_t > 0.0, "a second tonic starts")
	p.stun_t = 1.0
	_steps(0.1)
	ok(p.drink_t <= 0.0 and UtilityBelt.count(p, "tonic") == 1, "a stun spills it and nothing is used")
