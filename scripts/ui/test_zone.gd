class_name TestZone
extends RefCounted
## The owner's Test Zone (admin only, AdminGate): the sandbox map (the training island with the practice
## dummies and loadout, Arena "practice" layout) plus the tools to try anything early. Opened from the top of
## Admin tools, or the title screen. Its page (Overlay.open_test_zone): god mode, any of the Hunters, a Boki
## partner of any species (with a search), any monster spawned in front of you, the dummies reset, and home.

const MOB_AHEAD := 7.0  # m: how far in front of you a spawned monster lands
const PICK_W := 120.0  # px: one Hunter, Boki or monster button


## The match options: the --sandbox map (quiet: no lairs, rivals or Blight) with the practice tools on it.
static func opts() -> Dictionary:
	return {
		"training": true,
		"sandbox": true,
		"practice": true,
		"test_zone": true,
		"teams": 1,
		"squad": 1,
		"tier": 0,
		"length": 1e9,
		"seed": 4242,
		"no_drop": true,
		"weapon": "rifle",
	}


static func start() -> void:
	Overlay.close()
	Game.start_match(opts())


## The Test Zone match on screen, or null.
static func current() -> Match:
	var s = Game.main.screen_node() if Game.main else null
	if s is Match and (s as Match).opts.get("test_zone", false) and (s as Match).arena:
		return s
	return null


## Fills the Test Zone page; `again` rebuilds it (after a pick, so the chosen button lights up).
static func fill(v: VBoxContainer, m: Match, again: Callable) -> void:
	var me: Hunter = m.player
	var god := CheckButton.new()
	god.text = "God mode: can't be hurt or fall, no cooldowns, endless ammo"
	god.button_pressed = Game.god
	god.toggled.connect(func(on): Game.god = on)
	v.add_child(god)
	var row := UI.hbox(8)
	row.add_child(UI.button("Reset dummies", m.arena.reset, 160, "back"))
	row.add_child(
		UI.button(
			"Gloves, bot, toggles (L)",
			func():
				Overlay.close()
				m.arena.open_menu(),
			220
		)
	)
	row.add_child(
		UI.button(
			"Return home",
			func():
				Overlay.close()
				Practice.leave(m, true),
			160,
			"home"
		)
	)
	v.add_child(row)
	v.add_child(UI.section("Hunter"))
	var hg := _grid(v)
	for a in Arch.ids():
		var aa: String = a
		hg.add_child(
			UI.choice(HeroTitle.base_name(aa), me.arch == aa, _then.bind(m.arena.set_arch.bind(aa), again), PICK_W)
		)
	v.add_child(UI.section("Spawn a monster  (in front of you)"))
	var mg := _grid(v)
	for k in Data.MOBS:
		mg.add_child(UI.button(String(Data.MOBS[k]["name"]), spawn_mob.bind(m, String(k)), PICK_W))
	v.add_child(UI.section("Boki partner"))
	var search := LineEdit.new()
	search.placeholder_text = "Search the Field Book…"
	search.clear_button_enabled = true
	v.add_child(search)
	var kg := _grid(v)
	_fill_kin(kg, m, "", again)
	search.text_changed.connect(func(t: String): _fill_kin(kg, m, t, again))


## A monster of kind `kind` a few metres in front of you, on the ground.
static func spawn_mob(m: Match, kind: String) -> Mob:
	var me: Hunter = m.player
	var ahead := me.pos - Vector3(sin(me.face), 0.0, cos(me.face)) * MOB_AHEAD  # (a Hunter faces -(sin, cos))
	var at: Vector3 = m.world.free_spot_near(ahead, [me.pos], 1.2, 0.5, 6.0)
	at.y = m.world.ground_at(at.x, at.z)
	m.sfx("unlock", null, -8.0)
	return m.spawn_mob(kind, at)


## The Boki buttons whose name or id holds `q` ("None" first), rebuilt as the search changes.
static func _fill_kin(kg: GridContainer, m: Match, q: String, again: Callable) -> void:
	for ch in kg.get_children():
		ch.queue_free()
	var me: Hunter = m.player
	var cur := String((me.kin as Kin).species) if me.kin and not (me.kin as Kin).dead else ""
	if q == "":
		kg.add_child(UI.choice("None", cur == "", _then.bind(m.arena.set_kin.bind(""), again), PICK_W))
	for sp in KinLib.kin_ids():
		if not Data.KIN.has(sp):
			continue
		var nm := String(Data.KIN[sp]["name"])
		if q != "" and not (nm.containsn(q) or String(sp).containsn(q)):
			continue
		var b := UI.choice(nm, cur == sp, _then.bind(m.arena.set_kin.bind(String(sp)), again), PICK_W)
		b.add_theme_color_override("font_color", Data.KIN[sp]["color"])
		kg.add_child(b)


static func _grid(v: VBoxContainer) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	return g


static func _then(f: Callable, again: Callable) -> void:
	f.call()
	again.call()
