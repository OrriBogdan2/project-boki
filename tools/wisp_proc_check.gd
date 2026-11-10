extends RefCounted
## --wisp-proc-check: a carried passive triggering gives its wisp one cue (WispProc): a small flash in the Boki's own
## glow (the shiny colours when shiny) and a thin streak. Each passive kind (heal, shield, damage, speed) plays
## the cue once, only the wisp that carries that passive plays it, the rate limit (one cue per 0.5 s per wisp)
## holds under a flood of triggers, a rival's wisp cues the same way, the two meshes are pooled (no nodes added,
## no particle burst) and a shiny Boki's cue wears the shiny glow. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const STAT_OF := {"heal": "regen", "shield": "armor", "damage": "damage", "speed": "move_speed"}

var bad := 0
var m: Match

func run(main: Node) -> void:
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
	var k: Kin = m.player.kin
	for kind in STAT_OF:
		_kind(k, kind)
	_rate(k)
	_pooled(k)
	var rival: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x.owner_h.team != m.player.team)[0]
	_kind(rival, "heal")
	_shiny(k)
	m.queue_free()
	print("WISPPROC %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WISPPROC %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			h.render(DT, 1.0)

## The wisp carries only this stat, as a lone carry passive.
func _carry(k: Kin, stat: String) -> void:
	k.ks.carry_passives = [{"stat": stat, "amount": 0.1, "category": ""}] if stat != "" else []

## Make the hunter's state do what the kind reads (a heal, a shield soak, a shot, a run start), over one frame.
func _trigger(h: Hunter, kind: String) -> void:
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
	h.kin.render(DT, 1.0)
	match kind:
		"heal":
			h.hp += 5.0
		"shield":
			h.armor -= 5.0
		"damage":
			h.muzzle_t = 0.05
		"speed":
			h.vel = Vector3(WispProc.RUN_START + 1.0, 0, 0)
	m.time += 0.01
	h.kin.render(DT, 1.0)

func _proc(k: Kin) -> WispProc:
	return k.get_node("Proc") as WispProc

func _kind(k: Kin, kind: String) -> void:
	var h := k.owner_h
	var saved: Array = k.ks.carry_passives
	var tag := "%s%s" % ["rival " if h.team != m.player.team else "", kind]
	m.time += 1.0
	_carry(k, "")
	_trigger(h, kind)
	var before := _proc(k).cues
	ok(before == 0 or _proc(k).last_kind != kind, tag + ": no cue without the passive")
	m.time += 1.0
	_carry(k, STAT_OF[kind])
	_trigger(h, kind)
	var p := _proc(k)
	ok(p.cues == before + 1 and p.last_kind == kind, "%s: one cue (%d)" % [tag, p.cues - before])
	ok(p._flash.visible and p._streak.visible, tag + ": a flash and a streak show")
	_carry(k, "damage" if kind != "damage" else "regen")
	m.time += 1.0
	var n := p.cues
	_trigger(h, kind)
	ok(p.cues == n, tag + ": another passive's wisp does not cue it")
	k.ks.carry_passives = saved

func _rate(k: Kin) -> void:
	var h := k.owner_h
	_carry(k, "regen")
	m.time += 2.0
	_trigger(h, "heal")
	var n := _proc(k).cues
	for i in 12:
		_trigger(h, "heal")        # 12 triggers 0.02 s apart: all inside one RATE_S
	ok(_proc(k).cues == n, "rate: a flood inside 0.5 s plays no second cue")
	m.time += WispProc.RATE_S
	_trigger(h, "heal")
	ok(_proc(k).cues == n + 1, "rate: one more once 0.5 s have passed")
	var span := m.time
	var seen := _proc(k).cues
	for i in 60:
		m.time += 0.05
		_trigger(h, "heal")
	var allowed := int(ceil((m.time - span) / WispProc.RATE_S)) + 1
	var got := _proc(k).cues - seen
	var what := "rate: 60 triggers over %.1f s give %d cues (at most %d)"
	ok(got > 0 and got <= allowed, what % [m.time - span, got, allowed])

func _pooled(k: Kin) -> void:
	var kids := k.get_child_count()
	var proc_kids := _proc(k).get_child_count()
	for i in 10:
		m.time += 1.0
		_trigger(k.owner_h, "heal")
	var parts := k.find_children("*", "CPUParticles3D", true, false).size()
	ok(k.get_child_count() == kids and _proc(k).get_child_count() == proc_kids, "pooled: no node added by cues")
	ok(parts <= 1, "no burst: the cue adds no particles (%d on the wisp)" % parts)

func _shiny(k: Kin) -> void:
	var plain: Color = Shiny.col(k.species, {}, "glow")
	var shiny: Color = Shiny.col(k.species, {"shimmer": true}, "glow")
	ok(not plain.is_equal_approx(shiny), "shiny: the species has a different shiny glow")
	k.rec["shimmer"] = true
	k.get_node("Proc").free()
	_carry(k, "regen")
	m.time += 2.0
	_trigger(k.owner_h, "heal")
	var mat := _proc(k)._flash.material_override as StandardMaterial3D
	var got := mat.albedo_color
	ok(is_equal_approx(got.r, shiny.r) and is_equal_approx(got.b, shiny.b), "shiny: the flash wears the shiny glow")
	ok(not (is_equal_approx(got.r, plain.r) and is_equal_approx(got.b, plain.b)), "shiny: and not the plain one")
