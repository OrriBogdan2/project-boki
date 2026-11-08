class_name Arena
extends RefCounted
## The Arena (opts "arena", map content/maps/arena.json) and the Training Grounds's practice tools
## (opts "training": the same controller in its "practice" layout, on the training island).
##
## What it gives you:
## - practice dummies (real hunters, so Marks, carries, wall slams and every ability work on them):
##   one that stands and watches you, one that strafes, a heavy one by a pillar to slam into; each
##   shows its damage per second, last hit and total over its head, and heals up when left alone
## - a sparring bot you can switch Off / Idle / Moving / Fighting (N), and give any archetype
## - a reset (Backspace; X is the hero ultimate), cooldowns off (O: dash, RMB, E, R and the glove), the ultimate unlocked (U)
## - a quick swap without leaving: 2-9 pick one of the first eight archetypes (the loadout lists all); L opens the loadout (archetype, weapon,
##   Boki, glove, toggles), K the kit card
## Nobody dies here: a downed player or bot is back up after a beat.

const KEYS_HINT := "K kit card   ·   L loadout   ·   2-9 first eight Hunters (L: all)   ·   Backspace reset   ·   N bot   ·   O cooldowns   ·   U ultimate"
const BOT_MODES := ["off", "idle", "moving", "fighting"]
const BOT_NAMES := {"off": "Off", "idle": "Idle", "moving": "Moving", "fighting": "Fights back"}
const DUMMY_HP := 3000.0
const TEAM := 7

var m: Match
var layout := "arena"          # "arena" (its own map) | "practice" (the training island)
var home := Vector3.ZERO       # where you start (and reset to)
var dummies: Array = []        # {h: Hunter, kind, at, label: Label3D, hits: [[t, d]], total, last, quiet}
var bot: Hunter = null
var bot_mode := "off"
var bot_arch := "gunslinger"
var bot_at := Vector3.ZERO
var bot_down_t := -1.0
var cd_off := false
var ult_on := true
var gloves := ["", ""]         # the two glove slots, Q and V (item 69)
var hits_all: Array = []       # [[t, d]] everything you dealt (the session DPS meter)
var dealt := 0.0
var _cb: Callable
var layer: CanvasLayer = null
var hint: Label = null
var meter: Label = null
var card_layer: CanvasLayer = null
var menu_layer: CanvasLayer = null
var keys_node: Node = null

func setup(match_node: Match, which: String) -> void:
	m = match_node
	layout = which
	var P: Hunter = m.player
	if P == null:
		return
	if layout == "arena":
		home = _arena_point(Vector3(26.5, 0, 33.5))
		P.teleport(home)
		P.vel = Vector3.ZERO
		P.face = 0.0
		m.cam.snap(P.pos)
	else:
		home = P.pos
	P.unlock_all()
	_apply_ult()
	for i in Gloves.SLOTS:
		gloves[i] = String(P.gear[i].get("id", "")) if not (P.gear[i] as Dictionary).is_empty() else ""
	_spawn_dummies()
	bot_at = _arena_point(Vector3(26.5, 0, 19.5)) if layout == "arena" else _free_near(home + Vector3(0, 0, -7.0))
	_cb = func(by, t, d, tags): _on_hit(by, t, d, tags)
	CombatBus.hit_landed.connect(_cb)
	_build_ui()
	_sign()
	keys_node = ArenaKeys.new(self)
	m.add_child(keys_node)
	if m.hud:
		m.hud.guide_hidden = true
		m.hud.toast(("Arena" if layout == "arena" else "Training") + "  ·  K kit card  ·  L loadout  ·  2-9 first eight Hunters", Color("f3eee2"))

func teardown() -> void:
	if _cb.is_valid() and CombatBus.hit_landed.is_connected(_cb):
		CombatBus.hit_landed.disconnect(_cb)

## A point on the arena floor (map tile coords), on the ground.
func _arena_point(p: Vector3) -> Vector3:
	return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)

func _free_near(p: Vector3) -> Vector3:
	var q: Vector3 = m.world.free_spot_near(p, [m.player.pos], 1.2, 0.5, 6.0)
	q.y = m.world.ground_at(q.x, q.z)
	return q

# ------------------------------------------------------------------ dummies
func _spawn_dummies() -> void:
	var spots: Array
	if layout == "arena":
		spots = [["still", Vector3(23.5, 0, 26.5), "light"], ["strafe", Vector3(29.5, 0, 26.0), "medium"], ["heavy", Vector3(30.2, 0, 22.8), "heavy"]]
	else:
		spots = [["still", home + Vector3(-2.5, 0, -4.0), "light"], ["strafe", home + Vector3(2.5, 0, -4.5), "medium"], ["heavy", home + Vector3(0, 0, -6.5), "heavy"]]
	for sp in spots:
		var at: Vector3 = sp[1]
		at = _arena_point(at) if layout == "arena" else _free_near(at)
		var D: Hunter = m.make_hunter(m.next_id("dummy"), TEAM, String(sp[2]), {"still": "Dummy", "strafe": "Strafer", "heavy": "Training dummy"}[sp[0]], "idle", {}, at, {"arch": "none"})
		D.max_hp = DUMMY_HP; D.hp = DUMMY_HP
		D.armor = 0.0; D.max_armor = 0.0
		D.lives = 99
		D.tonics = 0
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.fixed_size = true
		lb.pixel_size = 0.0008
		lb.font_size = 22
		lb.outline_size = 10
		lb.modulate = Color("fff4d6")
		lb.font = UI.big
		lb.position = Vector3(0, 3.4, 0)
		D.add_child(lb)
		dummies.append({"h": D, "kind": sp[0], "at": at, "label": lb, "hits": [], "total": 0.0, "last": 0.0, "quiet": 0.0})

func _on_hit(by, t, d, _tags) -> void:
	var credit = by
	if by is Kin and (by as Kin).owner_h:
		credit = (by as Kin).owner_h
	if credit != m.player:
		return
	for dm in dummies:
		if dm["h"] == t:
			(dm["hits"] as Array).append([m.time, float(d)])
			dm["total"] = float(dm["total"]) + float(d)
			dm["last"] = float(d)
			dm["quiet"] = 0.0
	if t == bot or dummies.any(func(x): return x["h"] == t):
		hits_all.append([m.time, float(d)])
		dealt += float(d)

static func dps_of(hits: Array, now: float, win := 4.0) -> float:
	var s := 0.0
	var first := now
	for hh in hits:
		if now - float(hh[0]) <= win:
			s += float(hh[1]); first = minf(first, float(hh[0]))
	if s <= 0.0:
		return 0.0
	return s / maxf(1.0, now - first + 0.25)

## Runs right after the bots think (Match.step): dummies watch you, the strafer strafes, the bot
## mode trims what the sparring bot may do; heals, revives and cooldowns-off.
func after_think() -> void:
	var P: Hunter = m.player
	if P == null:
		return
	for dm in dummies:
		var D: Hunter = dm["h"]
		if not is_instance_valid(D):
			continue
		# the still and heavy dummies face your start (so you can get behind them: Thief Marks); the
		# strafer watches you
		D.inp["aim"] = (P.pos if dm["kind"] == "strafe" else home) + Vector3(0, 0.9, 0)
		var mv := Vector2.ZERO
		var at: Vector3 = dm["at"]
		if dm["kind"] == "strafe":
			mv = Vector2(sin(m.time * 1.3), 0.0)
		var off := Vector2(at.x - D.pos.x, at.z - D.pos.z)
		if off.length() > (2.4 if dm["kind"] == "strafe" else 0.6) and float(dm["quiet"]) > 1.2:
			mv = off.normalized()       # walk back to its mark once you stop hitting it
		D.inp["move"] = mv
		for k in ["fire", "dash", "jump", "sig", "sec", "ult", "gear1", "gear2", "throw"]:
			D.inp[k] = false
	if bot and is_instance_valid(bot):
		match bot_mode:
			"idle":
				bot.inp["move"] = Vector2.ZERO
				for k in ["fire", "dash", "jump", "sig", "sec", "ult", "gear1", "gear2", "throw"]:
					bot.inp[k] = false
			"moving":
				for k in ["fire", "sig", "sec", "ult", "gear1", "gear2", "throw"]:
					bot.inp[k] = false

func tick(dt: float) -> void:
	var P: Hunter = m.player
	if P == null:
		return
	for dm in dummies:
		var D: Hunter = dm["h"]
		if not is_instance_valid(D):
			continue
		dm["quiet"] = float(dm["quiet"]) + dt
		if D.downed or D.hp < DUMMY_HP * 0.25 or float(dm["quiet"]) > 3.0:
			if D.downed:
				m.revive_hunter(D, null)
			D.hp = DUMMY_HP
		var hs: Array = dm["hits"]
		while not hs.is_empty() and m.time - float(hs[0][0]) > 6.0:
			hs.pop_front()
		var lb: Label3D = dm["label"]
		var dps := dps_of(hs, m.time)
		lb.text = "DPS %d   ·   last %d\ntotal %d" % [int(round(dps)), int(round(float(dm["last"]))), int(round(float(dm["total"])))] if float(dm["total"]) > 0.0 else {"still": "DUMMY", "strafe": "STRAFER", "heavy": "TRAINING DUMMY  ·  slam me into the pillar"}[dm["kind"]]
	while not hits_all.is_empty() and m.time - float(hits_all[0][0]) > 6.0:
		hits_all.pop_front()
	# the sparring bot and you always see each other (the view cone never hides a sparring partner)
	if bot and is_instance_valid(bot):
		bot.reveal_t = maxf(bot.reveal_t, 0.3)
		P.reveal_t = maxf(P.reveal_t, 0.3)
	# the sparring bot: back up after a beat
	if bot and is_instance_valid(bot) and bot.downed:
		if bot_down_t < 0.0: bot_down_t = 1.5
		bot_down_t -= dt
		if bot_down_t <= 0.0:
			bot_down_t = -1.0
			m.revive_hunter(bot, null)
			bot.hp = bot.max_hp
			bot.teleport(bot_at)
	# practice toggles
	if P.ak:
		P.ak.cd_off = cd_off
	if cd_off:
		P.gear_cd[0] = 0.0; P.gear_cd[1] = 0.0
		P.dashes = P.max_dashes(); P.ex_cd = 0.0
		P.sig_cd = 0.0
		if P.ammo < int(P.wpn["mag"]) and P.reload_t <= 0.0 and not P.wpn.get("melee", false): P.ammo = int(P.wpn["mag"])
	if ult_on and int(P.slot_lv.get("ult", 0)) <= 0:
		_apply_ult()
	if P.downed and layout == "arena":
		P.set_meta("arena_down", float(P.get_meta("arena_down", 0.0)) + dt)
		if float(P.get_meta("arena_down", 0.0)) > 1.6:
			P.remove_meta("arena_down")
			m.revive_hunter(P, null)
			P.hp = P.max_hp
	_update_ui()
	ArenaDemo.tick(self, dt)      # (screenshot tooling only, --arena-demo)

func _apply_ult() -> void:
	var P: Hunter = m.player
	if ult_on:
		P.lvl = maxi(P.lvl, 6)
		P.xp = maxf(P.xp, float(Hunter.XP_TO[5]))
		P.slot_lv["ult"] = maxi(1, int(P.slot_lv["ult"]))
	else:
		P.slot_lv["ult"] = 0
		P.lvl = mini(P.lvl, 5)

# ------------------------------------------------------------------ actions
## Back to your marks: you, the dummies and the bot, all healed, cooldowns and resources cleared.
func reset() -> void:
	var P: Hunter = m.player
	for h in [P, bot]:
		if h == null or not is_instance_valid(h):
			continue
		if h.downed: m.revive_hunter(h, null)
		h.hp = h.max_hp; h.armor = h.max_armor
		h.stun_t = 0.0; h.root_t = 0.0; h.slow_t = 0.0; h.burn_t = 0.0
		h.vel = Vector3.ZERO
		h.dashes = h.max_dashes(); h.ex_cd = 0.0
		h.teleport(home if h == P else bot_at)
		if h.ak:
			for k in h.ak.cd.keys(): h.ak.cd[k] = 0.0
			h.ak.ch_rmb = float(h.ak.rmb_charges())
			h.ak.res = 0.0
		h.gear_cd[0] = 0.0; h.gear_cd[1] = 0.0
	for dm in dummies:
		var D: Hunter = dm["h"]
		if not is_instance_valid(D): continue
		if D.downed: m.revive_hunter(D, null)
		D.hp = DUMMY_HP; D.vel = Vector3.ZERO; D.stun_t = 0.0; D.root_t = 0.0; D.slow_t = 0.0
		D.teleport(dm["at"])
		D.set_meta("marks", {})
		dm["hits"] = []; dm["total"] = 0.0; dm["last"] = 0.0
	hits_all.clear(); dealt = 0.0
	m.fx.ring(home, 1.6, Color("8fe3c8"), 0.35)
	m.sfx("revive", null, -8.0, 1.2)

## Become another archetype on the spot (its weight class comes with it); your Boki stays.
func set_arch(a: String, w := "") -> void:
	var P: Hunter = m.player
	if not Arch.exists(a):
		return
	P.reclass(Arch.weight(a), a, w)
	P.unlock_all()
	_apply_ult()
	for i in Gloves.SLOTS:
		if gloves[i] != "": give_glove(String(gloves[i]), i)
	m.fx.ring(P.pos, 1.8, Arch.color(a), 0.4)
	m.fx.burst(P.pos + Vector3(0, 1.0, 0), Arch.color(a), 18, 3.5, 0.5)
	m.sfx("unlock", null, -6.0, 1.1)
	if m.hud: m.hud.toast("%s  ·  %s" % [Arch.name_of(a), String(Arch.def(a).get("card", {}).get("loop", ""))], Arch.color(a))
	if card_layer: _open_card()

## Bring another Boki (one of yours, or a loaner of any kind); "" for none.
func set_kin(sp: String) -> void:
	var P: Hunter = m.player
	if P.kin:
		var o: Kin = P.kin
		if KinMerge.active(P): KinMerge.end(P, "broken")
		o.dead = true; m.kins.erase(o); o.queue_free(); P.kin = null
		P.apply_kin_bonus()
	if sp == "":
		return
	var rec := {}
	for r in Save.d.get("roster", []):
		if String(r.get("species", "")) == sp:
			rec = (r as Dictionary).duplicate(true); break
	if rec.is_empty():
		rec = Save.new_kin(sp)
		rec["trust"] = 90.0
		rec["level"] = 8
	var k: Kin = m.give_kin(P, rec)
	k.stow()
	if card_layer: _open_card()

## Wear any glove in a slot (0 = Q, 1 = V; -1 = where Gloves.slot_for puts it: its twin's slot, a free one, the
## weaker). Two of the same glove can't be worn, so a glove picked for one slot leaves the other. Actives and
## passives go in either slot; cooldowns-off covers both.
func give_glove(gid: String, slot := -1) -> void:
	var P: Hunter = m.player
	if not Gear.ALL.has(gid) or not Gear.is_glove(gid):
		return
	if slot < 0 or slot > 1:
		slot = Gloves.slot_for(P, gid)
	var other := 1 - slot
	if String(gloves[other]) == gid:
		clear_glove(other)
	gloves[slot] = gid
	P.gear[slot] = {"id": gid, "rar": 2}
	P.gear_cd[slot] = 0.0
	P.refresh_gear()

func clear_glove(slot: int) -> void:
	var P: Hunter = m.player
	gloves[slot] = ""
	P.gear[slot] = {}
	P.gear_cd[slot] = 0.0
	P.refresh_gear()

func cycle_bot(step := 1) -> void:
	bot_mode = BOT_MODES[(BOT_MODES.find(bot_mode) + step + BOT_MODES.size()) % BOT_MODES.size()]
	_spawn_bot()
	if m.hud: m.hud.toast_small("Sparring bot: %s" % BOT_NAMES[bot_mode], Color("ff9a8a"))

func set_bot_arch(a: String) -> void:
	bot_arch = a
	_spawn_bot()

func _spawn_bot() -> void:
	if bot and is_instance_valid(bot):
		m.hunters.erase(bot)
		if bot.kin:
			m.kins.erase(bot.kin); bot.kin.queue_free()
		bot.queue_free()
	bot = null
	if bot_mode == "off":
		return
	var diff := "medium"
	bot = m.make_hunter(m.next_id("spar"), TEAM, Arch.weight(bot_arch), "Sparring " + Arch.name_of(bot_arch), "bot", m.bot_kin_record(), bot_at, {"arch": bot_arch, "weapon": Arch.signature(bot_arch)})
	bot.ai = m.bot_brain.new_mind(m.rng, float(Data.BOT_DIFF[diff]["skill"]), Data.BOT_DIFF[diff])
	bot.lives = 99
	bot.tonics = 0
	bot.unlock_all()

func toggle_cd() -> void:
	cd_off = not cd_off
	if m.hud: m.hud.toast_small("Cooldowns %s" % ("OFF" if cd_off else "on"), Color("9ff0e0"))

func toggle_ult() -> void:
	ult_on = not ult_on
	_apply_ult()
	if m.hud: m.hud.toast_small("Ultimate %s" % ("unlocked (level 6)" if ult_on else "locked (under level 6)"), Color("ffd27a"))

# ------------------------------------------------------------------ on screen
func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 6
	m.add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	hint = UI.label(KEYS_HINT, 13, Color(1, 1, 1, 0.8), UI.big)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position.y = 10 if layout == "arena" else 70     # (the Training Grounds's banner sits at the top)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(hint)
	meter = UI.label("", 15, UI.INK, UI.big)
	meter.autowrap_mode = TextServer.AUTOWRAP_OFF
	meter.add_theme_constant_override("outline_size", 6)
	meter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	meter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter.position = Vector2(-330, 120)
	meter.custom_minimum_size = Vector2(310, 0)
	root.add_child(meter)

func _update_ui() -> void:
	if meter == null:
		return
	var P: Hunter = m.player
	var lines := "%s   DPS %d   ·   dealt %d" % [Arch.name_of(P.arch).to_upper() if P.ak else "", int(round(dps_of(hits_all, m.time))), int(round(dealt))]
	lines += "\nBot: %s   ·   Cooldowns: %s   ·   Ult: %s" % [BOT_NAMES[bot_mode], "OFF" if cd_off else "on", "on" if ult_on else "locked"]
	if meter.text != lines:
		meter.text = lines

## A sign by your start: where the kit card and the loadout are.
func _sign() -> void:
	var lb := Label3D.new()
	lb.text = "K  ·  KIT CARD\nL  ·  LOADOUT (Hunter, Boki, 2 gloves)\nBACKSPACE  ·  RESET"
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font = UI.big
	lb.font_size = 44
	lb.outline_size = 12
	lb.pixel_size = 0.008
	lb.modulate = Color("ffe9b8")
	var at := home + Vector3(-3.2, 2.2, 1.2)
	lb.position = at
	m.add_child(lb)
	var post := MeshInstance3D.new()
	post.mesh = Models.box(0.14, 1.6, 0.14)
	post.material_override = Models.toon(Color("7a5a3a"))
	post.position = Vector3(at.x, home.y + 0.8, at.z)
	m.add_child(post)

func _open_card() -> void:
	_close_card()
	var P: Hunter = m.player
	card_layer = CanvasLayer.new()
	card_layer.layer = 41
	m.add_child(card_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_layer.add_child(root)
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var sp := String((P.kin as Kin).species) if P.kin and not (P.kin as Kin).dead else ""
	var card := KitCard.make(P.arch, sp, _close_card)
	center.add_child(card)
	m.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_card() -> void:
	if card_layer:
		card_layer.queue_free()
		card_layer = null
		if menu_layer == null:
			m.paused = false
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func toggle_card() -> void:
	if card_layer: _close_card()
	else: _open_card()

# ---- the loadout panel (L): picks apply on the spot; the panel never changes size
const MENU := Vector2(1040, 640)

func open_menu() -> void:
	close_menu()
	m.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 40
	m.add_child(menu_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pn := PanelContainer.new()
	pn.custom_minimum_size = MENU
	pn.add_theme_stylebox_override("panel", UI.frame(UI.SURFACE, UI.R_PANEL, Color(1, 1, 1, 0.12), 1, 18, 14))
	center.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pn.add_child(v)
	_fill_menu(v)
	UI.pop_in(pn)

func _fill_menu(v: VBoxContainer) -> void:
	for ch in v.get_children():
		ch.queue_free()
	var P: Hunter = m.player
	var hd := HBoxContainer.new()
	hd.add_child(UI.label("Loadout", 26, UI.INK, UI.big))
	hd.add_child(UI.label("   Everything applies at once. Esc or L closes.", 14, UI.MUTED))
	hd.add_child(UI.fill())
	hd.add_child(UI.ghost("Kit card", func(): close_menu(); _open_card(), 120))
	hd.add_child(UI.primary("Done", close_menu, 110))
	v.add_child(hd)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	# left: archetype, weapon, Boki
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(470, 0)
	cols.add_child(left)
	left.add_child(UI.section("Hunter  (keys 2-9 pick the first eight)"))
	var ag := GridContainer.new(); ag.columns = 3
	ag.add_theme_constant_override("h_separation", 6); ag.add_theme_constant_override("v_separation", 6)
	for a in Arch.ids():
		var aa: String = a
		var b := UI.choice(Arch.name_of(a), P.arch == a, func(): set_arch(aa); _fill_menu(v), 150)
		b.tooltip_text = String(Arch.def(a).get("card", {}).get("loop", ""))
		ag.add_child(b)
	left.add_child(ag)
	var ll := UI.label(String(Arch.def(P.arch).get("card", {}).get("loop", "")), 13, Arch.color(P.arch))
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll.custom_minimum_size = Vector2(460, 36)
	left.add_child(ll)
	left.add_child(UI.section("Boki"))
	var kg := GridContainer.new(); kg.columns = 3
	kg.add_theme_constant_override("h_separation", 6); kg.add_theme_constant_override("v_separation", 6)
	var cur := String((P.kin as Kin).species) if P.kin and not (P.kin as Kin).dead else ""
	for sp in _kin_choices():
		var ss: String = sp
		var nm := "None" if sp == "" else String(Data.KIN.get(sp, {}).get("name", sp))
		var b := UI.choice(nm, cur == sp, func(): set_kin(ss); _fill_menu(v), 150)
		if sp != "" and KinLib.kin(sp):
			var ks := KinLib.kin(sp)
			b.tooltip_text = "%s  ·  %s" % [String(ks.theme).capitalize(), "   ".join(KitCard.infusion_lines(P.arch, ks))]
		kg.add_child(b)
	left.add_child(kg)
	# right: glove, practice toggles, the bot
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var gl: Array = Gear.ALL.keys().filter(func(g): return Gear.is_glove(String(g)))
	gl.sort_custom(func(x, y): return (1 if Gear.active(x) else 0) > (1 if Gear.active(y) else 0) or (Gear.active(x) == Gear.active(y) and String(x) < String(y)))
	for si in Gloves.SLOTS:
		var slot: int = si
		right.add_child(UI.section("Glove %d  (%s)" % [slot + 1, Gloves.key_cap(slot)]))
		var gg := GridContainer.new()
		gg.columns = 5
		gg.add_theme_constant_override("h_separation", 4)
		gg.add_theme_constant_override("v_separation", 4)
		var nb := UI.choice("None", String(gloves[slot]) == "", func(): clear_glove(slot); _fill_menu(v), 60)
		nb.add_theme_font_size_override("font_size", 12)
		gg.add_child(nb)
		for g in gl:
			var gid: String = g
			var nm2 := String(Gear.ALL[g].get("name", g))
			var b := UI.choice(nm2.substr(0, 11), String(gloves[slot]) == gid, func(): give_glove(gid, slot); _fill_menu(v), 90, Gear.icon_of(gid))
			b.tooltip_text = "%s%s  ·  %s\n%s" % [nm2, ("  ·  %ss" % KinText.n(Gear.cd_of(gid, 2))) if Gear.active(gid) else "  ·  passive", Gloves.key_cap(slot), Gear.desc_of(gid, 2)]
			b.add_theme_font_size_override("font_size", 12)
			gg.add_child(b)
		right.add_child(gg)
		var gd := UI.label(_glove_line(slot), 13, UI.MUTED)
		gd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gd.custom_minimum_size = Vector2(480, 20)
		right.add_child(gd)
	right.add_child(UI.section("Practice"))
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 6)
	tr.add_child(UI.choice("Cooldowns off  (O)", cd_off, func(): toggle_cd(); _fill_menu(v), 170))
	tr.add_child(UI.choice("Ultimate unlocked  (U)", ult_on, func(): toggle_ult(); _fill_menu(v), 200))
	tr.add_child(UI.button("Reset  (Backspace)", func(): reset(), 110))
	right.add_child(tr)
	var br := HBoxContainer.new(); br.add_theme_constant_override("separation", 6)
	br.add_child(UI.label("Bot (N)", 14, UI.MUTED))
	for md in BOT_MODES:
		var mm: String = md
		br.add_child(UI.choice(BOT_NAMES[md], bot_mode == md, func(): bot_mode = mm; _spawn_bot(); _fill_menu(v), 96))
	right.add_child(br)
	var ba := HBoxContainer.new(); ba.add_theme_constant_override("separation", 6)
	ba.add_child(UI.label("Bot Hunter", 14, UI.MUTED))
	var ids := Arch.ids()
	ba.add_child(UI.button("‹", func(): set_bot_arch(String(ids[(ids.find(bot_arch) - 1 + ids.size()) % ids.size()])); _fill_menu(v), 44))
	var bl := UI.label(Arch.name_of(bot_arch), 16, Arch.color(bot_arch), UI.big)
	bl.custom_minimum_size = Vector2(150, 0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ba.add_child(bl)
	ba.add_child(UI.button("›", func(): set_bot_arch(String(ids[(ids.find(bot_arch) + 1) % ids.size()])); _fill_menu(v), 44))
	right.add_child(ba)

func _glove_line(slot: int) -> String:
	var g := String(gloves[slot])
	if g == "" or not Gear.ALL.has(g):
		return "%s: no glove. Pick any to wear it here." % Gloves.key_cap(slot)
	return "%s: %s%s: %s" % [Gloves.key_cap(slot), String(Gear.ALL[g].get("name", g)), ("  ·  %ss" % KinText.n(Gear.cd_of(g, 2))) if Gear.active(g) else "  ·  passive", Gear.desc_of(g, 2)]

func _kin_choices() -> Array:
	var out: Array = []
	for r in Save.d.get("roster", []):
		var sp := String(r.get("species", ""))
		if sp != "" and not out.has(sp) and KinLib.kin(sp): out.append(sp)
	for sp in KinLib.kin_ids():
		if not out.has(sp) and Data.KIN.has(sp): out.append(sp)
	out.append("")      # every species, however many there are (the grid scrolls with the menu)
	return out

func close_menu() -> void:
	if menu_layer:
		menu_layer.queue_free()
		menu_layer = null
	if card_layer == null:
		m.paused = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

## The keys (a little node so they work while the menu has the game paused).
class ArenaKeys extends Node:
	var a: Arena
	func _init(owner_arena: Arena) -> void:
		a = owner_arena
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _unhandled_input(e: InputEvent) -> void:
		if not (e is InputEventKey and e.pressed and not e.echo):
			return
		var k := (e as InputEventKey).physical_keycode
		var handled := true
		match k:
			KEY_K: a.toggle_card()
			KEY_L:
				if a.menu_layer: a.close_menu()
				elif not Overlay.is_open(): a.open_menu()
			KEY_ESCAPE:
				if a.card_layer: a._close_card()
				elif a.menu_layer: a.close_menu()
				else: handled = false
			KEY_BACKSPACE:
				if not a.m.paused: a.reset()
			KEY_N: a.cycle_bot()
			KEY_O: a.toggle_cd()
			KEY_U: a.toggle_ult()
			KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var ids := Arch.ids()
				var i := int(k - KEY_2)
				if i < ids.size(): a.set_arch(String(ids[i]))
			_: handled = false
		if handled:
			get_viewport().set_input_as_handled()
