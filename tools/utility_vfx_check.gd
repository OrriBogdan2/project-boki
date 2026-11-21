extends RefCounted
## --utility-vfx-check: the belt items that change a fight each spawn their readable look, and clean
## it up when the item runs out (UtilityLook):
##  Skyfall Charge: a fuse ring over the blast; Blight Flask: the patch edge; Twin Gate: two portals and
##  the link; Thorn Wall: spikes on the wall; Warp Seed: the anomaly.
## Prints UVFX ok/FAIL lines and "UVFX DONE, failures: N". Never touches the save file.

var bad := 0
var main: Node
var m: Match
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("UVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	P = m.player
	for h in m.hunters:
		if h != P:
			h.teleport(P.pos + Vector3(-40.0, 0, 0))
	await _skyfall()
	await _blight()
	await _gate()
	await _seed()
	await _thorn()
	print("UVFX DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _looks(prefix: String) -> Array:
	var all := main.get_tree().get_nodes_in_group(UtilityLook.GROUP)
	return all.filter(func(n): return String(n.name).begins_with(prefix))

## Uses `id`, aimed along the first free direction, with a fresh belt and a healthy caster.
func _use(id: String) -> bool:
	P.out = false
	P.downed = false
	P.dead = false
	P.hp = P.max_hp
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, id, 1)
	for k in 8:
		var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * float(k) / 8.0)
		P.inp["aim"] = P.pos + dir * 20.0
		if UtilityMore._spot(P, 9.0) != P.pos:
			break
	return UtilityBelt.use_id(P, id)

func _steps(secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)
	await main.get_tree().process_frame
	await main.get_tree().process_frame

func _skyfall() -> void:
	ok(_use("skyfall_charge"), "a Skyfall Charge is called")
	var fuse := _looks("SkyfallFuse")
	ok(fuse.size() == 1, "...its fuse ring is drawn")
	if fuse.size() == 1:
		var parts: Array = fuse[0].get_children()
		ok(parts.size() == 3, "...ring, filling disc and warhead (%d parts)" % parts.size())
	await _steps(4.0)
	ok(_looks("SkyfallFuse").size() == 1, "...the ring stays up for the whole 5 s fuse")
	await _steps(1.6)
	ok(_looks("SkyfallFuse").is_empty(), "...and is gone after the blast")
	await _steps(3.5)

func _blight() -> void:
	ok(_use("blight_flask"), "a Blight Flask is thrown")
	var edge := _looks("BlightEdge")
	ok(edge.size() == 1, "...the patch edge is drawn")
	if edge.size() == 1:
		ok(edge[0].get_parent() == m.fields.list.back()["node"], "...on the patch itself")
	await _steps(39.0)
	ok(_looks("BlightEdge").size() == 1, "...it stays for the 40 s")
	await _steps(2.0)
	ok(_looks("BlightEdge").is_empty(), "...and goes with the patch")

func _gate() -> void:
	ok(_use("twin_gate"), "a Twin Gate is opened")
	ok(_looks("GatePortal").size() == 2, "...two portals")
	ok(_looks("GateLink").size() == 1, "...and the link between them")
	await _steps(7.0)
	ok(_looks("GatePortal").size() == 2, "...they stay for the 8 s")
	await _steps(1.7)
	ok(_looks("GatePortal").is_empty() and _looks("GateLink").is_empty(), "...and close together")

func _seed() -> void:
	ok(_use("warp_seed"), "a Warp Seed is planted")
	ok(_looks("WarpAnomaly").size() == 1, "...the anomaly is drawn")
	await _steps(29.0)
	ok(_looks("WarpAnomaly").size() == 1, "...it stays for the 30 s")
	await _steps(2.0)
	ok(_looks("WarpAnomaly").is_empty(), "...and fades with the seed")

func _thorn() -> void:
	ok(_use("thorn_wall"), "a Thorn Wall goes up")
	var sp := _looks("ThornSpikes")
	ok(sp.size() == 1, "...its spikes are drawn")
	if sp.size() == 1:
		ok(sp[0].get_parent() == m.verbs.walls.back()["node"], "...on the wall itself")
		ok(sp[0].get_child_count() >= 30, "...along the top and both faces (%d)" % sp[0].get_child_count())
	await _steps(19.0)
	ok(_looks("ThornSpikes").size() == 1, "...they stay for the 20 s")
	await _steps(2.0)
	ok(_looks("ThornSpikes").is_empty() and m.verbs.walls.is_empty(), "...and go with the wall")
