class_name YardDrill
extends RefCounted
## Training at the yard: a timing game, three rounds, each a little faster. The session dict stays on
## Home.train (other systems read it to know a drill is running; train["bar"] is its TimingBar); this
## holds the verbs.

var h: Home                    # the Home screen

func _init(home: Home) -> void:
	h = home

## Leave the drill without a result (the menu key).
func quit() -> void:
	var tk: Dictionary = h.train["k"]
	tk["busy"] = false
	h.train["bar"].close()
	h.train = {}

## Start a drill of `stat` for `rec` at the yard.
func start(rec: Dictionary, stat: String) -> void:
	var k := h._kin_entry(rec)
	if k.is_empty():
		return
	if Care.need(rec, "energy") < 20.0 or Care.need(rec, "food") < 12.0:
		h._close_panel()
		var why := "energy" if Care.need(rec, "energy") < 20.0 else "food"
		h._say(k, BokiLines.say(rec, "want_" + why))
		var tired: bool = why == "energy"
		var state := "tired" if tired else "hungry"
		var fix := "Let it nap" if tired else "Feed it"
		h._toast("%s is too %s to train. %s first" % [rec["name"], state, fix])
		return
	if int(rec["stats"][stat]) >= Care.stat_cap(rec):
		h._toast("%s can't train %s any further until it levels up" % [rec["name"], Care.STATS[stat]["name"]])
		return
	if not h._care_start(k):
		return
	k["busy"] = true
	k["pos"] = h.YARD_KIN
	var n: Node3D = k["node"]
	n.position = h.YARD_KIN
	var dummy := h.yard.get_node("Dummy") as Node3D
	var dpos := dummy.global_position
	n.rotation.y = atan2(-(dpos.x - h.YARD_KIN.x), -(dpos.z - h.YARD_KIN.z))
	h.ppos = h.YARD_KIN + Vector3(-0.6, 0, 1.4)
	h.player.position = h.ppos
	h._face(h.YARD_KIN)
	var bar := TimingBar.new()
	bar.open(h.root_ui, "Press %s (or click) when the marker is in the gold" % Settings.key_cap("interact"))
	h.train = {"k": k, "stat": stat, "round": 0, "results": [], "bar": bar, "wait": 0.0}
	_label()
	Sfx.play("whoosh", null, -8.0)

func _label() -> void:
	if h.train.is_empty() or not is_instance_valid(h.train["bar"].lbl):
		return
	var st: Dictionary = Care.STATS[h.train["stat"]]
	var res: Array = h.train["results"]
	var marks := ""
	for r in res:
		marks += {"great": "  ★", "good": "  ●", "miss": "  ✕"}[r]
	var lbl: Label = h.train["bar"].lbl
	lbl.text = "%s  ·  round %d of 3%s" % [st["drill"], mini(int(h.train["round"]) + 1, 3), marks]
	lbl.add_theme_color_override("font_color", st["col"])

func process(d: float) -> void:
	if h.train.is_empty():
		return
	if float(h.train["wait"]) > 0.0:
		h.train["wait"] = float(h.train["wait"]) - d
		if float(h.train["wait"]) <= 0.0 and int(h.train["round"]) >= 3:
			_finish()
		return
	h.train["bar"].step(d)

func hit() -> void:
	if h.train.is_empty() or float(h.train["wait"]) > 0.0:
		return
	var r: String = h.train["bar"].press()
	h.train["results"].append(r)
	if r == "great": h.verbs.play("cheer")
	h.train["round"] = int(h.train["round"]) + 1
	h.train["wait"] = 1.1
	_anim(h.train["k"], String(h.train["stat"]), r)
	_label()

## What the kin does each round.
func _anim(k: Dictionary, stat: String, r: String) -> void:
	var n: Node3D = k["node"]
	var body: Node3D = n.get_node("Body")
	var dummy := h.yard.get_node("Dummy") as Node3D
	var tw := h.create_tween()
	var col: Color = Care.STATS[stat]["col"]
	match stat:
		"power":
			var to := h.YARD_KIN.lerp(dummy.global_position, 0.55)
			tw.tween_property(n, "position", to, 0.12)
			tw.tween_callback(func():
				if r != "miss":
					var sparks := 12 if r == "great" else 6
					h.fx.burst(dummy.global_position + Vector3(0, 1.0, 0), Color("e2c47a"), sparks, 3.0, 0.4)
					Sfx.play("kinhit", dummy.global_position, -6.0)
					var dt := h.create_tween()
					dt.tween_property(dummy, "rotation:z", 0.35 if r == "great" else 0.18, 0.08)
					dt.tween_property(dummy, "rotation:z", 0.0, 0.3)
				else:
					Sfx.play("whoosh", null, -10.0))
			tw.tween_property(n, "position", h.YARD_KIN, 0.2)
		"guard":
			tw.tween_property(body, "scale", Vector3(1.2, 0.72, 1.2), 0.12)
			tw.tween_callback(func():
				if r != "miss":
					h.fx.ring(h.YARD_KIN, 1.2, col, 0.3)
					Sfx.play("shield", null, -10.0))
			tw.tween_interval(0.3)
			tw.tween_property(body, "scale", Vector3.ONE, 0.15)
		"speed":
			var hoop := h.yard.global_position + Vector3(-1.4, 0, 0.2)
			tw.tween_property(n, "position", hoop, 0.18 if r != "miss" else 0.35)
			tw.tween_callback(func(): if r != "miss": h.fx.burst(hoop + Vector3(0, 0.4, 0), col, 8, 2.5, 0.3))
			tw.tween_property(n, "position", h.YARD_KIN, 0.18 if r != "miss" else 0.35)
		"focus":
			tw.tween_property(n, "rotation:y", n.rotation.y + TAU, 0.6)
			var puff := 14 if r == "great" else 7
			tw.tween_callback(func():
				if r != "miss":
					h.fx.burst(h.YARD_KIN + Vector3(0, 0.5, 0), col, puff, 1.6, 0.6, -3.0))
	h._emote(k, {"great": "★", "good": "♪", "miss": "?"}[r])

func _finish() -> void:
	var k: Dictionary = h.train["k"]
	var rec: Dictionary = k["rec"]
	var stat: String = h.train["stat"]
	var pts := 0
	for r in h.train["results"]:
		pts += {"great": 3, "good": 2, "miss": 0}[r]
		if r != "miss" and Save.has_building("dojo"):
			pts += 1
	var mult := 1.0
	if Care.need(rec, "joy") >= 60.0: mult *= 1.25
	if Care.need(rec, "energy") < 35.0: mult *= 0.7
	var gained := Care.add_stat(rec, stat, int(round(pts * mult)))
	Care.change(rec, "energy", -18.0)
	Care.change(rec, "food", -6.0)
	Care.change(rec, "joy", 4.0 if (h.train["results"] as Array).has("great") else -2.0)
	var aff: String = {"power": "fierce", "guard": "steadfast", "speed": "swift", "focus": "curious"}[stat]
	Evo.add(rec, aff, 2.0)
	h._garden_xp(rec, "drill", false, pts)
	var sname := String(Care.STATS[stat]["name"]).to_lower()
	if gained > 0:
		CareJournal.note(rec, "trained %s at the yard: +%d" % [sname, gained])
	if Care.care_day(rec, "trained"):
		Save.remember(rec, "trained", "trained %s with you at the yard" % sname, 1.0)
	Save.save_game()
	var shown := int(rec["stats"][stat])
	var msg := "No gain this time. Try again after a rest"
	if gained > 0:
		msg = "+%d %s  (%d of %d)" % [gained, Care.STATS[stat]["name"], shown, Care.stat_cap(rec)]
	h._toast(msg)
	h._say(k, BokiLines.say(rec, "trained" if gained > 0 else "train_miss"))
	k["busy"] = false
	k["t"] = 1.5
	h.train["bar"].close()
	h.train = {}
