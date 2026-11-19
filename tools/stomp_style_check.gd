extends RefCounted
## --stomp-style-check: stomp styles and the stomp slot (StompLook, StompPick, docs/decisions/0062).
## The data loads with every key; an old save (no keys) wears its Hunter's own stomp; a style can't be worn
## unbought, Buy spends its gems once and wears it; the Hunters-screen picker shows the own stomp and the
## style for sale (Buy off without the gems, marked once worn); a worn style takes the stomp off a Hunter's
## clip and onto the rig, a two-footed style lifts both legs alike, and Gil (no clips) stomps his own style.
## Prints STYLE ok/FAIL rows and STOMPSTYLE PASS/FAIL.

const DT := 1.0 / 60.0
const SALE := "thunder_stomp"

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("STYLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_data()
	_slot()
	_picker(main)
	_pose(main)
	print("STOMPSTYLE %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _data() -> void:
	var keys: Array = StompLook.style("").keys()
	for id in StompLook.rules()["styles"]:
		ok(keys.all(func(k): return StompLook.style(String(id)).has(k)), "%s has every key" % id)
		var h := String(StompLook.rules()["styles"][id].get("hunter", ""))
		ok(h == "" or Arch.ids().has(h), "%s's Hunter %s exists" % [id, h])
	ok(StompLook.for_sale(SALE), "%s is for sale" % SALE)
	ok(StompLook.default_for("gil") == "fin_slap", "Gil's own stomp is Fin Slap")
	ok(StompLook.style("nope") == StompLook.style(""), "an unknown style is the base stomp")

func _slot() -> void:
	Save.d.erase("stomps")
	(Save.d.get("look", {}) as Dictionary).erase("stomp")
	ok(StompLook.equipped() == "", "an old save wears its Hunter's own stomp")
	ok(not StompLook.equip(SALE), "an unbought style can't be worn")
	Save.d["gems"] = 299
	ok(not StompLook.buy(SALE) and int(Save.d["gems"]) == 299, "299 gems can't buy it")
	Save.d["gems"] = 300
	ok(StompLook.buy(SALE) and int(Save.d["gems"]) == 0 and StompLook.owned(SALE), "300 gems buy it")
	Save.d["gems"] = 300
	ok(not StompLook.buy(SALE) and int(Save.d["gems"]) == 300, "a second buy spends nothing")
	ok(StompLook.equip(SALE) and StompLook.equipped() == SALE, "bought, it is worn")
	ok(StompLook.equip("") and StompLook.equipped() == "", "back to the own stomp")
	Save.d.erase("stomps")
	Save.d["gems"] = 0

func _picker(main: Node) -> void:
	var p := StompPick.make("gil", func(): pass)
	main.add_child(p)
	var cards := p.find_children("*", "", true, false).filter(func(n): return n.has_meta("stomp"))
	ok(cards.map(func(c): return String(c.get_meta("stomp"))) == ["", SALE], "picker: own stomp and %s" % SALE)
	var buys := (cards[1] as Node).find_children("*", "Button", true, false)
	ok(buys.size() == 1 and (buys[0] as Button).disabled, "picker: Buy is off with 0 gems")
	p.free()
	Save.d["stomps"] = [SALE]
	StompLook.equip(SALE)
	p = StompPick.make("gil", func(): pass)
	main.add_child(p)
	var worn := p.find_children("*", "Button", true, false).filter(func(b): return b.theme_type_variation == "Chosen")
	ok(worn.size() == 1 and (worn[0] as Button).text == "Thunder Stomp", "picker: the worn style is marked")
	p.free()
	Save.d.erase("stomps")
	StompLook.equip("")

## Real models through HunterAnim at the top of a lift (phase 0.35).
func _pose(main: Node) -> void:
	var clip_id := ""
	for a in Arch.ids():
		var st: Dictionary = WardenClips.data(WardenGlb.art(String(a))).get("states", {})
		if st.has("stomp"):
			clip_id = String(a)
			break
	ok(clip_id != "", "a Hunter with a stomp clip (%s)" % clip_id)
	var own := _cur(main, clip_id, {"stomp_own": true})
	var stomp_clip := String(WardenClips.data(WardenGlb.art(clip_id))["states"]["stomp"])
	ok(own == stomp_clip, "%s's own stomp plays its clip (%s)" % [clip_id, own])
	var worn := _cur(main, clip_id, {"stomp_own": false, "stomp_style": SALE})
	ok(worn != stomp_clip and worn != "(no clips)", "a worn style leaves the clip (%s)" % worn)
	var both := _legs(main, "gil", SALE)
	var alike := absf(both.x - both.y) < 0.02 and both.x > 0.25
	ok(alike, "two-footed style lifts both hips alike (%.2f %.2f)" % [both.x, both.y])
	var fin := _legs(main, "gil", "fin_slap")
	ok(fin.x - fin.y > 0.6, "Gil's Fin Slap lifts the left leg (%.2f over %.2f)" % [fin.x, fin.y])

func _model(main: Node, id: String) -> Node3D:
	var m := PreviewBuild.model(id)
	main.add_child(m)
	return m

func _state(extra: Dictionary) -> Dictionary:
	var s := {"fired": 99.0, "face": 0.0, "grounded": true, "stomp": 0.35, "stomp_n": 0}
	s.merge(extra, true)
	return s

## The clip on a clip Hunter's live channel after 20 steps of the stomp state.
func _cur(main: Node, id: String, extra: Dictionary) -> String:
	var m := _model(main, id)
	var anim := HunterAnim.new(m)
	var s := _state(extra)
	s["wid"] = Arch.signature(id)
	var sync := m.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)       # (stepped here: no frame passes in the check)
	for i in 20:
		anim.update(DT, s.duplicate())
		if sync:
			sync.call("_process", DT)
	var cur := String(sync.clips.cur) if sync and sync.clips else "(no clips)"
	m.free()
	return cur

## Vector2(left hip, right hip) rig angles after 30 frames in a style.
func _legs(main: Node, id: String, style: String) -> Vector2:
	var m := _model(main, id)
	var anim := HunterAnim.new(m)
	var s := _state({"stomp_style": style, "stomp_own": false, "wid": Arch.signature(id)})
	for i in 30:
		anim.update(DT, s.duplicate())
	var out := Vector2(anim.leg_l.rotation.x, anim.leg_r.rotation.x)
	m.free()
	return out
