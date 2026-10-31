class_name HomeIncubator
extends RefCounted
## The Incubator on the home island, beside the Nesting Nook (the rules are Incubator's,
## scripts/core/incubator.gd). Puts each Rare Egg in its own cradle and the rest on the shelf,
## lights each cradle's ember pebbles as its egg warms, shows unbought cradles behind an iron grate,
## glows brighter (and sparks) while an Ember kin or Ember Coals warm it, and wobbles ready eggs.
## home.gd calls build(), tick(d), refresh(), prompt() and nearest_ready().

var h                                   # the Home screen
var node: Node3D = null
var label: Label3D = null
var egg_nodes := {}                     # egg id -> Node3D in its cradle
var shelf_eggs: Array = []
var lit_mat: Material = null
var gold_mat: Material = null
var dark_mat: Material = null
var acc := 0.0
var ready_ids := {}                     # eggs we've already told you are ready

func _init(home) -> void:
	h = home

func at() -> Vector3:
	return h.INCUB_AT

## Where an Ember kin sits to warm it: in front of the cradles, facing the brazier.
func warm_spot() -> Vector3:
	return h.INCUB_AT + Vector3(0.15, 0, 1.25)

## Where a cradle is in the world.
func slot_pos(i: int) -> Vector3:
	if node == null:
		return at()
	return (node.get_node("C%d" % i) as Node3D).global_position

func build() -> void:
	Incubator.ensure()
	Incubator.catch_up()
	node = Models.incubator()
	node.position = at()
	h.add_child(node)
	label = Label3D.new()
	label.font = UI.big; label.font_size = 34; label.pixel_size = 0.008; label.outline_size = 10
	label.modulate = Color("ffc98a"); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at() + Vector3(0, 2.4, -0.4)
	h.add_child(label)
	lit_mat = Models.toon(Color("ffb04a"), false, 1.6)
	gold_mat = Models.toon(Color("ffe08a"), false, 1.8)
	dark_mat = Models.toon(Color("4a3a36"))
	for e in Incubator.ready_eggs(): ready_ids[String(e["id"])] = true
	refresh()

## Re-places every egg (cradles and shelf), the locks on unbought cradles, and relights the pebbles.
func refresh() -> void:
	if node == null:
		return
	for id in egg_nodes:
		if is_instance_valid(egg_nodes[id]): (egg_nodes[id] as Node).queue_free()
	egg_nodes.clear()
	for e in shelf_eggs:
		if is_instance_valid(e): (e as Node).queue_free()
	shelf_eggs.clear()
	for i in Incubator.MAX_SLOTS:
		var c: Node3D = node.get_node("C%d" % i)
		var open := i < Incubator.slots()
		(c.get_node("Lock") as Node3D).visible = not open
		(c.get_node("Nest") as Node3D).visible = open
		for j in 6: (c.get_node("P%d" % j) as Node3D).visible = open
	for e in Incubator.eggs():
		var en := Models.rare_egg_small(Incubator.spot_col(e), 0.55)
		en.rotation.y = float(int(e.get("slot", 0))) * 0.9
		(node.get_node("C%d/Egg" % int(e.get("slot", 0))) as Node3D).add_child(en)
		egg_nodes[String(e["id"])] = en
	var shelf: Node3D = node.get_node("Shelf")
	var q := Incubator.shelf()
	for i in mini(6, q.size()):
		var eg := Models.rare_egg_small(Incubator.spot_col(q[i]), 0.48)
		eg.position = (shelf.get_node("S%d" % i) as Node3D).position
		eg.rotation.y = 0.4 * i
		shelf.add_child(eg)
		shelf_eggs.append(eg)
	_light()
	_label()

func _label() -> void:
	var rd := Incubator.ready_eggs().size()
	label.text = "Incubator" + ("  ·  %d ready" % rd if rd > 0 else ("  ·  %d/%d" % [Incubator.eggs().size(), Incubator.slots()] if Incubator.count() > 0 else ""))
	label.modulate = Color("ffe08a") if rd > 0 else Color("ffc98a")

## Lights each cradle's six pebbles as far as its egg has warmed (gold when it's ready).
func _light() -> void:
	for i in Incubator.slots():
		var e := Incubator.in_slot(i)
		var lit := int(floor(Incubator.progress(e) * 6.0 + 0.001))
		var c: Node3D = node.get_node("C%d" % i)
		for j in 6:
			(c.get_node("P%d" % j) as MeshInstance3D).material_override = (gold_mat if Incubator.egg_ready(e) else lit_mat) if j < lit else dark_mat

## Is an Ember kin at work by the brazier right now?
func warmed() -> bool:
	for k in h.kins:
		if k.has("job") and String(k["job"]["kind"]) == "warm" and String(k["job"]["phase"]) == "work":
			return true
	return false

func tick(d: float) -> void:
	if node == null:
		return
	var warm := warmed()
	Incubator.tick(d, warm)
	acc += d
	var tt := Time.get_ticks_msec() / 1000.0
	var hot := Incubator.rate(warm)
	var gl: OmniLight3D = node.get_node("Glow")
	gl.light_energy = (0.0 if Incubator.eggs().is_empty() else 0.4 + 0.5 * hot) + sin(tt * 3.1) * 0.12
	if hot > 1.0 and randf() < d * 3.0 * hot:
		h.fx.burst(at() + Vector3(randf_range(-0.25, 0.25), 0.9, -0.38 + randf_range(-0.25, 0.25)), Color("ff9a3a"), 2, 1.2, 0.3)
	for e in Incubator.eggs():
		var en: Node3D = egg_nodes.get(String(e["id"]), null)
		if en == null or not is_instance_valid(en): continue
		var sh: Node3D = en.get_node("Shell")
		var ph := float(int(e.get("slot", 0))) * 0.7
		if Incubator.egg_ready(e):
			sh.rotation.z = sin(tt * 11.0 + ph) * 0.15 * (1.0 if fmod(tt + ph, 2.6) < 0.7 else 0.0)
		else:
			sh.rotation.z = sin(tt * 1.3 + ph) * 0.03
	if acc >= 0.5:
		acc = 0.0
		_light()
		_label()
		for e in Incubator.ready_eggs():
			var id := String(e["id"])
			if ready_ids.has(id): continue
			ready_ids[id] = true
			h.fx.burst(slot_pos(int(e.get("slot", 0))) + Vector3(0, 0.4, 0), Color("ffd36a"), 18, 2.4)
			h._toast("A %s in the Incubator is ready to hatch!" % Incubator.egg_name(e))

## The ready egg nearest to p ({} if none).
func nearest_ready(p: Vector3) -> Dictionary:
	var best := {}; var bd := 99.0
	for e in Incubator.ready_eggs():
		var sp := slot_pos(int(e.get("slot", 0)))
		var dd := Vector2(sp.x - p.x, sp.z - p.z).length()
		if dd < bd: bd = dd; best = e
	return best

## What walking up to it says.
func prompt() -> String:
	var rd := Incubator.ready_eggs()
	if not rd.is_empty():
		return "Hatch the %s!" % Incubator.egg_name(nearest_ready(h.ppos))
	if Incubator.count() == 0:
		return "Incubator (empty: Rare Eggs from boss lairs hatch here)"
	return "Incubator: %d warming%s" % [Incubator.eggs().size(), (", %d on the shelf" % Incubator.shelf().size()) if not Incubator.shelf().is_empty() else ""]
