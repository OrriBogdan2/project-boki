extends RefCounted
## --status-look-check: one body look per crowd control status, whoever puts it there (docs/STATUS_LOOKS.md, the
## crowd control table in docs/KIT_PARITY.md). Every row of that table lands its status on a Hunter from a caster
## of that kit, the way the kit lands it (an ability hit carrying stun, root or slow; KitStatus for Grounded and
## Daze), and a Boki and a monster land theirs too. For each: the status's look comes up, the same rig (look,
## meshes, colours) whatever the source, sized to the body's hitbox (a Hunter and a monster), up for exactly the
## status's time, nothing flat on the ground (the look or a ring as it lands: a ground ring means gameplay), and
## a game that does not own the body shows it from the owner's snapshot (stun, root, slow) or event (Grounded, Daze).

## [source, status, seconds]: the table's numbers (KIT_PARITY "Crowd control"); a kit's caster is a Hunter of it.
const ROWS := [
	["gunslinger", "daze", 1.4], ["gunslinger", "stun", 0.7], ["gunslinger", "slow", 0.6],
	["juggernaut", "stun", 0.8], ["juggernaut", "slow", 1.5],
	["archer", "stun", 1.2], ["archer", "slow", 0.8],
	["ashwick", "slow", 1.5],
	["tender", "root", 1.1],
	["dolm", "stun", 0.9], ["dolm", "slow", 1.0],
	["dredge", "stun", 1.1], ["dredge", "gnd", 1.0],
	["rimewright", "stun", 0.75], ["rimewright", "slow", 0.8],
	["ostra", "stun", 0.8], ["ostra", "slow", 1.5],
	["bulwark", "stun", 1.0],
	["mage", "stun", 0.8], ["mage", "gnd", 1.5],
	["thief", "gnd", 1.5], ["thief", "slow", 2.5], ["thief", "stun", 0.9],
	["boki", "stun", 0.6], ["boki", "root", 1.0], ["boki", "slow", 1.2],
	["mob", "stun", 0.5], ["mob", "root", 0.8], ["mob", "slow", 1.0],
]
const KST := {"gnd": "gnd", "daze": "rat"}      # status -> KitStatus kind
const TIMER := {"stun": "stun_t", "root": "root_t", "slow": "slow_t"}      # status -> the body's timer
const SRC := {"boki": "kin", "mob": "mob"}      # a hit's "src" by its source (a kit's: "abil")
const DT := 1.0 / 30.0                            # s a step while timing a look
const FLAT := 0.25                                # a mesh this flat (height over width) is a disc or a ring

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("STATUSLOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var m: Match = flow._match(main, "juggernaut")
	await main.get_tree().process_frame
	var P: Hunter = m.player
	var L := StatusLooks.of(m)
	Sfx.listener = P.pos
	var T: Hunter = _hunter(m, "dolm", 1, P.pos + Vector3(3, 0, 0))
	var proxy: Hunter = _hunter(m, "dolm", 1, P.pos + Vector3(-3, 0, 0))
	proxy.remote = true
	var mob: Mob = m.spawn_mob("brute", P.pos + Vector3(0, 0, 4))
	mob.set_physics_process(false)
	var casters := {"boki": P.kin if P.kin else m.give_kin(P, Save.new_kin("zapple", "Pip")), "mob": mob}
	var sigs := {}            # status -> the rig's signature the first source showed
	for row: Array in ROWS:
		var src := String(row[0])
		if not casters.has(src):
			casters[src] = _hunter(m, src, P.team, P.pos + Vector3(0, 0, -4))
		var sig := await _row(m, L, T, casters[src], String(row[1]), float(row[2]), "%s %s" % [src, row[1]])
		if not sigs.has(row[1]):
			sigs[row[1]] = sig
		ok(sig == sigs[row[1]], "%s %s: the same look as every other %s" % [src, row[1], row[1]])
		_remote(m, L, T, proxy, String(row[1]), float(row[2]), "%s %s" % [src, row[1]])
	var looks := {}
	for st: String in sigs:
		looks[String(StatusLooks.rules()[st]["look"])] = true
	ok(sigs.size() == 5 and looks.size() == 5, "stun, root, Ground, slow and Daze: five looks of their own")
	_mob_body(m, L, mob, P)
	print("STATUSLOOK %s" % ("OK" if bad == 0 else "%d failed" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(m: Match, arch: String, team: int, at: Vector3) -> Hunter:
	var h := m.make_hunter(m.next_id("h"), team, Arch.weight(arch), arch, "idle", {}, at,
		{"arch": arch, "weapon": Arch.signature(arch)})
	h.ctrl = "idle"
	return h

## Lands `st` for `secs` on T from `by`, then times the look against the status. Returns the rig's signature.
func _row(m: Match, L: StatusLooks, T: Hunter, by: Ent, st: String, secs: float, what: String) -> Array:
	T.hp = T.max_hp
	T.cc_immune_t = 0.0
	T.dr_stun = false
	T.dr = {}
	var rings := m.fx.rings.size()
	if KST.has(st):
		KitStatus.apply(T, String(KST[st]), secs)
	else:
		T.hurt(0.1, by, {"src": SRC.get(what.get_slice(" ", 0), "abil"), "ab": "utility", st: secs,
			"slow_k": 0.3, "dr": by is Hunter})
	var left := _left(T, st)
	ok(absf(left - secs) < 0.02, "%s: lands for %.2f s (%.2f)" % [what, secs, left])
	ok(_rings_at(m, rings, T) == 0, "%s: no ring on the ground as it lands" % what)
	ok(L.showing(T, st), "%s: its look comes up" % what)
	var r: Dictionary = L.rigs.get("%d/%s" % [T.get_instance_id(), st], {})
	var sig := _sig(r)
	ok(not r.is_empty() and is_equal_approx((r["n"] as Node3D).scale.x, T.r / StatusLooks.BODY_R),
		"%s: sized to the hitbox" % what)
	ok(_flat_low(r, T) == "", "%s: nothing flat on the ground %s" % [what, _flat_low(r, T)])
	var steps_on := 0
	var steps_up := 0
	var alone := 0
	var pre := "%d/" % T.get_instance_id()
	while _left(T, st) > 0.0 and steps_on < 400:
		steps_on += 1
		steps_up += 1 if L.showing(T, st) else 0
		alone += 1 if L.rigs.keys().filter(func(key): return String(key).begins_with(pre)).size() == 1 else 0
		T.tick_status(DT)
		Oomph.render_hit(T, DT)        # the stagger clock (Hunter.render runs it)
		m.time += DT
	ok(steps_on > 0 and steps_up == steps_on and not L.showing(T, st),
		"%s: up all %d steps the status runs, gone when it ends" % [what, steps_on])
	ok(alone == steps_on, "%s: no other look with it (a stun hit's stagger is not a slow), %d of %d steps"
		% [what, alone, steps_on])
	await m.get_tree().process_frame
	return sig

## The time `st` has left on `e` (its own game's timers).
func _left(e: Ent, st: String) -> float:
	match st:
		"stun": return maxf(e.stun_t, 0.0)
		"root": return maxf(e.root_t, 0.0)
		"slow": return maxf(e.slow_t, 0.0)
		"gnd": return KitStatus.grounded_left(e)
		"daze": return KitStatus.rattled_left(e)
	return 0.0

## Another game: T's status reaches a remote copy of T through T's snapshot (stun, root, slow) or the kit's Net
## event (Grounded, Daze), and goes when T's own game ends it.
func _remote(m: Match, L: StatusLooks, T: Hunter, proxy: Hunter, st: String, secs: float, what: String) -> void:
	L.told.clear()
	if KST.has(st):
		KitStatus.from_net(m, ["kst", proxy.nid, String(KST[st]), secs])
		ok(L.showing(proxy, st), "%s: another game shows it from the Net event" % what)
		m.time += secs + 0.01
		ok(not L.showing(proxy, st), "%s: ... for its length" % what)
		return
	T.set(String(TIMER[st]), secs)
	m._net_apply(proxy, m._ser(T))
	ok(L.showing(proxy, st), "%s: another game shows it from the owner's snapshot" % what)
	var mine: Array = _sig(L.rigs.get("%d/%s" % [T.get_instance_id(), st], {}))
	ok(_sig(L.rigs.get("%d/%s" % [proxy.get_instance_id(), st], {})) == mine, "%s: ... the same look" % what)
	T.set(String(TIMER[st]), 0.0)
	m._net_apply(proxy, m._ser(T))
	ok(not L.showing(proxy, st), "%s: ... gone with the owner's next snapshot" % what)

## A monster's body: each status sized to its hitbox, and another game sees it from the host's snapshot.
func _mob_body(m: Match, L: StatusLooks, mob: Mob, P: Hunter) -> void:
	var copy: Mob = m.spawn_mob("brute", P.pos + Vector3(-4, 0, 4))
	copy.remote = true
	for st: String in ["stun", "root", "slow"]:
		mob.set(String(TIMER[st]), 1.0)
		var r: Dictionary = L.rigs.get("%d/%s" % [mob.get_instance_id(), st], {}) if L.showing(mob, st) else {}
		ok(not r.is_empty() and is_equal_approx((r["n"] as Node3D).scale.x, mob.r / StatusLooks.BODY_R),
			"monster %s: sized to its hitbox (r %.2f)" % [st, mob.r])
		m._net_apply(copy, m._ser(mob))
		ok(L.showing(copy, st), "monster %s: another game shows it from the host's snapshot" % st)
		mob.set(String(TIMER[st]), 0.0)
		m._net_apply(copy, m._ser(mob))
		ok(not L.showing(mob, st) and not L.showing(copy, st), "monster %s: gone with it" % st)

## What a rig is made of: its look and each mesh's kind and colour, in order.
func _sig(r: Dictionary) -> Array:
	if r.is_empty():
		return []
	var out: Array = [String(r["look"])]
	for mi: MeshInstance3D in (r["n"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		out.append("%s %s" % [mi.mesh.get_class(), _albedo(mi.material_override)])
	return out

## A part's colour: the toon shader's albedo (cel-lit parts) or a see-through part's.
func _albedo(mat: Material) -> String:
	if mat is ShaderMaterial:
		return Color((mat as ShaderMaterial).get_shader_parameter("albedo")).to_html()
	return (mat as StandardMaterial3D).albedo_color.to_html() if mat is StandardMaterial3D else ""

## A flat mesh (a disc or a ring) of the rig lying lower than an ankle on `e`; "" when there is none.
func _flat_low(r: Dictionary, e: Ent) -> String:
	if r.is_empty():
		return ""
	var floor_y := e.pos.y + StatusLooks.ANKLE * StatusLooks.body_k(e).y * 0.9
	for mi: MeshInstance3D in (r["n"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.y < FLAT * maxf(box.size.x, box.size.z) and box.get_center().y < floor_y:
			return "(%s at %.2f m)" % [mi.name, box.get_center().y - e.pos.y]
	return ""

## The rings Fx has made since `from` that lie at `e`'s feet.
func _rings_at(m: Match, from: int, e: Ent) -> int:
	var n := 0
	for i in range(from, m.fx.rings.size()):
		var at: Vector3 = (m.fx.rings[i]["node"] as Node3D).global_position
		if at.y < e.pos.y + 0.5 and Vector2(at.x - e.pos.x, at.z - e.pos.z).length() < 2.0:
			n += 1
	return n
