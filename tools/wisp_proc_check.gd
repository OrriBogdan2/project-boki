extends RefCounted
## --wisp-proc-check: a carried passive triggering gives its wisp one cue (WispProc): a small flash in the Boki's own
## glow (the shiny colours when shiny) and a thin streak. Each passive kind (heal, shield, damage, speed) plays
## the cue once, only the wisp that carries that passive plays it, the rate limit (one cue per 0.5 s per wisp)
## holds under a flood of triggers, a rival's wisp cues the same way, the two meshes are pooled (no nodes added,
## no particle burst) and a shiny Boki's cue wears the shiny glow. Your own Boki's first cue gives one tip,
## "<Boki>'s <passive>: <what it does>" (Match._tips, once per save), and the wisp flashes again; a later or
## stale cue, a rival's cue or the tutorial match says nothing. With the wisps off, a Boki carried by order cues
## and tells it, one out beside you does not. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const STAT_OF := {"heal": "regen", "shield": "armor", "damage": "damage", "speed": "move_speed"}
const TIPS_AT_S := 20.0    # Match._tip_t past every opening tip's wait
const OPENING_TIPS := ["move", "ability", "throw", "skill", "ult"]   # marked seen: only the proc tip may show

var bad := 0
var m: Match

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Settings.set_v("tips", true, false)
	_start(main, true)
	var k: Kin = m.player.kin
	for kind in STAT_OF:
		_kind(k, kind)
	_rate(k)
	_pooled(k)
	var rival: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x.owner_h.team != m.player.team)[0]
	_kind(rival, "heal")
	_shiny(k)
	_first_tip(k, rival)
	_start(main, false)
	_walking_tip()
	m.queue_free()
	print("WISPPROC %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _start(main: Node, wisps: bool) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true,
		"demo_kin": "cindle", "boki_wisps": wisps})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	_frames(0.3)

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

## The tip lines on screen after Match._tips ran (the opening tips seen, so only the proc tip can show).
func _tip_lines() -> Array[String]:
	for key in OPENING_TIPS:
		Save.d["tutorial"][key] = true
	m._tip_t = TIPS_AT_S
	m._tips()
	m.hud.msgs._process(DT)
	return m.hud.msgs.texts().filter(func(t: String): return t.contains("'s "))

func _proc_tip_text(k: Kin, stat: String) -> String:
	var passive := k.ks.carry_name if k.ks.carry_name != "" else "carry passive"
	var acted := k.ks.carry_passives.filter(func(ps): return String(ps["stat"]) == stat)
	return "%s's %s: %s" % [k.rec.get("name", "Your Boki"), passive, KinText.passives(acted)]

## Your Boki's first cue: one tip naming its passive and the wisp flashes again; never again on this save.
func _first_tip(k: Kin, rival: Kin) -> void:
	var saved: Array = k.ks.carry_passives
	Save.d["tutorial"].erase("proc")
	m.hud.msgs.clear()
	m.time += WispProc.TIP_KEEP_S + 1.0      # the cues of the rows above are stale
	_carry(rival, "regen")
	_trigger(rival.owner_h, "heal")
	ok(_tip_lines().is_empty(), "tip: a rival's cue tells you nothing")
	m.time += 1.0
	_carry(k, "regen")
	_trigger(m.player, "heal")
	m.time += WispProc.TIP_KEEP_S + 0.5
	ok(_tip_lines().is_empty() and not Save.d["tutorial"].has("proc"), "tip: a cue older than TIP_KEEP_S is not told")
	m.opts["tutorial"] = true
	m.time += 1.0
	_trigger(m.player, "heal")
	ok(_tip_lines().is_empty() and not Save.d["tutorial"].has("proc"), "tip: none in the tutorial match")
	m.opts.erase("tutorial")
	var line := _proc_tip_text(k, "regen")
	var n := _proc(k).cues
	var lines := _tip_lines()
	ok(lines.size() == 1 and lines[0].contains(line), "tip: '%s' (%s)" % [line, lines])
	ok(Save.d["tutorial"].get("proc", false) and _proc(k).cues == n + 1, "tip: marked seen, the wisp flashes again")
	m.hud.msgs.clear()
	m.time += 1.0
	_trigger(m.player, "heal")
	ok(_tip_lines().is_empty(), "tip: a later cue says nothing")
	k.ks.carry_passives = saved

## Wisps off: a walking Boki's damage passive cues and tells only while it is carried by order.
func _walking_tip() -> void:
	var k: Kin = m.player.kin
	Save.d["tutorial"].erase("proc")
	m.hud.msgs.clear()
	_carry(k, "damage")
	ok(not k.wisp and not m.player.kin_carry_on(), "wisps off: the Boki walks beside you")
	m.time += 1.0
	_trigger(m.player, "damage")
	ok(_tip_lines().is_empty() and k.get_node_or_null("Proc") == null, "wisps off, not carried: no cue, no tip")
	k.stow()
	_frames(0.5)
	ok(m.player.kin_carry_on(), "wisps off: stowed, carried by order")
	m.time += 1.0
	_trigger(m.player, "damage")
	var lines := _tip_lines()
	var line := _proc_tip_text(k, "damage")
	ok(lines.size() == 1 and lines[0].contains(line), "wisps off, carried: '%s' (%s)" % [line, lines])
