extends RefCounted
## --mood-bubbles-check: the happy and sad bubbles over Boki at home (scripts/home/kin_wants.gd), on a stub screen.
## A Boki whose mood is very low shows a sad face (a mildly low one keeps the heart, or the ball for a fetch lover)
## and its line says it is sad. A content Boki smiles when you walk up, for HAPPY_S, then not again for a while.
## One far away, one with a want, one with a middling need or on a visit does not smile, and a want always wins.


class StubFx:
	extends RefCounted

	func burst(_at: Vector3, _col: Color, _n: int, _speed: float) -> void:
		pass


class Stub:
	extends Node3D
	var kins: Array = []
	var visit := {}
	var ppos := Vector3.ZERO
	var cam := Camera3D.new()
	var fx := StubFx.new()

	func _emote(_k: Dictionary, _s: String, _force := false) -> void:
		pass


var bad := 0


func ok(cond: bool, what: String) -> void:
	print("MOODBUB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var s := Stub.new()
	main.add_child(s)
	s.add_child(s.cam)
	s.cam.position = Vector3(0, 3, 6)
	# a very low mood: the sad face, and the line says so
	var k := _boki(s, Vector3(1, 0, 0))
	_needs(k, 90.0)
	k["rec"]["needs"]["joy"] = KinWants.URGENT_BELOW - 5.0
	ok(KinWants.icon(k["rec"]) == "sad", "a very low mood is a sad face: %s" % KinWants.icon(k["rec"]))
	ok(KinWants.line(k["rec"], false).contains("is sad"), "its line: %s" % KinWants.line(k["rec"], false))
	_tick(s, 0.5)
	ok(_shown(k) == "sad", "the sad bubble shows over it: %s" % _shown(k))
	k["rec"]["needs"]["joy"] = KinWants.WANT_BELOW - 5.0
	k["rec"]["likes"]["play"] = "fetch"
	ok(KinWants.icon(k["rec"]) == "ball", "a mildly low mood keeps the ball for a fetch lover")
	k["rec"]["likes"]["play"] = "chase"
	ok(KinWants.icon(k["rec"]) == "heart", "and the heart for the rest")
	# content and near: one smile, then a rest
	_needs(k, 90.0)
	k["want_was"] = ""
	ok(KinWants.content(k["rec"]), "every need high is content")
	_tick(s, 0.5)
	ok(_shown(k) == "happy", "a content Boki near you smiles: %s" % _shown(k))
	var size_k := float(k["bubble_k"])
	ok(size_k < 1.0, "the smile is smaller than a want's bubble: %.2f" % size_k)
	_tick(s, KinWants.HAPPY_S + 0.5)
	ok(_shown(k) == "", "the smile goes after HAPPY_S: %s" % _shown(k))
	_tick(s, 5.0)
	ok(_shown(k) == "", "and does not come back while you stand there")
	_tick(s, KinWants.HAPPY_AGAIN_S - 8.0)  # (8.5 s gone since the first smile)
	ok(_shown(k) == "happy", "it smiles again after HAPPY_AGAIN_S")
	# not when far, not when a need is middling, not on a visit
	var far := _boki(s, Vector3(KinWants.HAPPY_RANGE + 3.0, 0, 0))
	_needs(far, 90.0)
	var mid := _boki(s, Vector3(-1.5, 0, 0))
	_needs(mid, 90.0)
	mid["rec"]["needs"]["clean"] = KinWants.HAPPY_ABOVE - 10.0
	_tick(s, 0.5)
	ok(_shown(far) == "", "one far from you does not smile")
	ok(not KinWants.content(mid["rec"]) and _shown(mid) == "", "one with a middling need does not smile")
	var guest := _boki(s, Vector3(0, 0, 2.5))
	_needs(guest, 90.0)
	s.visit = {"who": "friend"}
	_tick(s, 0.5)
	ok(_shown(guest) == "", "no smiles on a visit")
	s.visit = {}
	# a want wins over a smile
	_tick(s, 0.5)
	guest["rec"]["needs"]["food"] = 10.0
	_tick(s, 0.5)
	ok(_shown(guest) == "bowl", "a want replaces the smile: %s" % _shown(guest))
	print("MOODBUB DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _boki(s: Stub, at: Vector3) -> Dictionary:
	var rec := Save.new_kin("cindle", "Test")
	Care.ensure(rec)
	var n := Node3D.new()
	s.add_child(n)
	n.position = at
	var k := {"rec": rec, "node": n, "pos": at}
	s.kins.append(k)
	return k


func _needs(k: Dictionary, v: float) -> void:
	for n in Care.NEEDS:
		k["rec"]["needs"][n] = v


## Runs the bubbles for secs, in 0.1 s frames (needs only change where the test sets them: no decay here).
func _tick(s: Stub, secs: float) -> void:
	var t := 0.0
	while t < secs:
		KinWants.update(s, 0.1, t)
		t += 0.1


## The icon its bubble shows ("" when the bubble is down).
func _shown(k: Dictionary) -> String:
	var bub: Node3D = k.get("bubble")
	if bub == null or not bub.visible:
		return ""
	for nm in KinWants.ICONS:
		if (bub.get_node(nm) as Node3D).visible:
			return nm
	return "?"
