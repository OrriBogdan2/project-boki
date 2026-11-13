extends RefCounted
## --wisp-check: a downed Hunter turns into a Wisp (docs/decisions/0019-downed-wisp.md). For every hero,
## a bot teammate and the tutorial: down a hero, the Wisp is on it from the first frame while the hero plays
## the knocked-down beat (HunterFall: its death clip, or a kneel without one; held where it went down and
## facing the way it faced, pushed away from the knocker, fading as the Wisp rises out of it, for its
## weight's time), then the hero model hides, the Wisp hums, it
## hangs back heavily when the hunter moves and settles once they stop, a revive brings the hero back
## (scaled up from the pop), frees the Wisp and stops the hum, and a bleed-out breaks it (mid-beat too). The
## downed gameplay (downed flag, speed, hittable) is read untouched. Also the look data and the outline rule
## (round body with a head, team rim, white core, low hover, no flicker, one mesh in one material): every
## look has all its keys and real sounds, an unknown id gives the default Wisp, a look that lists only a
## few keys builds, and the saved id round-trips. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node
var _spot: Vector3       # each hero cycle starts here: the drift rows walk the Wisp 1.4 m a cycle, toward the abyss

func run(main_node: Node) -> void:
	main = main_node
	_looks()
	_styles()
	_picker()
	_start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	_spot = m.player.pos
	for a in Arch.ids():
		_hero_cycle(a)
	_bleed_out()
	_teammate()
	m.queue_free()
	_tutorial()
	print("WISPCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WISP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(opts: Dictionary) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(opts)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"      # the player too: a crawling bot would hide the Wisp settling
		h.inp["move"] = Vector2.ZERO

func _frames(secs: float, drift := Vector3.ZERO) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			if h == m.player:
				h.pos += drift
				h.prev = h.pos
			h.render(DT, 1.0)
		_sync(m.player)

## Steps the player's Hero clips (WardenGlb's Sync runs in _process, which the checks do not run).
func _sync(h: Hunter) -> void:
	var sync := h.model.get_node_or_null("Warden/Sync") if h.model else null
	if sync:
		sync.set_process(false)
		sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	var sync := h.model.get_node_or_null("Warden/Sync")
	return sync.get("clips") as WardenClips if sync else null

## One hero: up, down (Wisp, hidden hero), moving, revived (hero grows back, Wisp gone).
func _hero_cycle(arch_id: String) -> void:
	var p: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	p.pos = _spot
	p.reclass(Arch.weight(arch_id), arch_id)
	p.hp = p.max_hp
	var tag := "[%s] " % arch_id
	_frames(0.1)
	ok(p.model.visible and HunterWisp.node_of(p) == null, tag + "up: the hero shows, no Wisp")
	var base: Vector3 = p.model.scale
	m.knock(p, foe, {})
	p.down_hp = 1e6
	_frames(DT)
	var wisp := HunterWisp.node_of(p)
	var spawned: bool = wisp != null and wisp.is_inside_tree() and wisp.get_parent() == p
	ok(p.downed and spawned, tag + "downed: the Wisp is on the hunter from the first frame")
	_fall(p, foe, tag)
	ok(not p.model.visible, tag + "after the beat the hero model is hidden")
	ok(HunterWisp.mode_of(p) == HunterWisp.ON, tag + "the beat ends and the Wisp idles")
	ok(p.downed and not p.out, tag + "downed gameplay untouched: still downed, not out")
	ok(Sfx.loop_on(HunterWisp.hum_key(p)), tag + "a downed Wisp hums")
	_frames(0.3, Vector3(0.08, 0, 0))
	ok(wisp.position.x < -0.1, tag + "a moving Wisp hangs back behind the hunter (%.2f m)" % -wisp.position.x)
	ok((wisp.get_node("Body") as Node3D).basis != Basis.IDENTITY, tag + "...and leans")
	_frames(0.15)
	ok(wisp.position.x < -0.05, tag + "it settles heavily: still behind 0.15 s after the stop")
	_frames(1.5)
	ok(absf(wisp.position.x) < 0.02, tag + "...and has caught up after 1.65 s (%.3f m)" % wisp.position.x)
	m.revive_hunter(p, null)
	_frames(0.04)
	var popping: bool = HunterWisp.mode_of(p) == HunterWisp.OUT
	ok(not p.downed and p.model.visible and popping, tag + "revived: the hero is back, the pop-out plays")
	ok(not Sfx.loop_on(HunterWisp.hum_key(p)), tag + "the revive stops the hum")
	ok(p.model.scale.y < base.y * 0.95, tag + "the hero starts small (%.2f of full)" % (p.model.scale.y / base.y))
	_frames(0.5)
	ok(HunterWisp.mode_of(p) == "" and HunterWisp.node_of(p) == null, tag + "the Wisp is gone after the pop-out")
	ok(p.model.scale.is_equal_approx(base), tag + "the hero is back at full size")

## The knocked-down beat, frame by frame while the hunter crawls off and turns: the hero shows and plays its death
## clip (no clip: HunterAnim kneels), the body stays where it went down, pushed away from the knocker, facing the
## way it faced; it fades out as the Wisp rises out of it, and hands over after its weight's time, opaque again.
func _fall(p: Hunter, foe: Hunter, tag: String) -> void:
	var fall := HunterFall.of(p)
	ok(fall != null and p.model.visible, tag + "the beat: the hero still shows, falling")
	if fall == null:
		return
	var away := Vector2(p.pos.x - foe.pos.x, p.pos.z - foe.pos.z).normalized()
	var wisp := HunterWisp.node_of(p)
	var low := wisp.position.y
	var facing0 := p.model.basis.z.normalized()
	var t := DT
	var mid := false
	var last_gone := 0.0
	var rose := 0.0
	while HunterWisp.mode_of(p) == HunterWisp.IN and t < 1.0:
		m.step(DT)
		p.pos = fall.from + Vector3(1.8 * t, 0, 0)       # crawling off, turning away (set: the step may hold it)
		p.prev = p.pos
		p.face = fall.facing + 1.2
		p.render(DT, 1.0)
		_sync(p)
		t += DT
		if HunterWisp.mode_of(p) == HunterWisp.IN:
			last_gone = _faded(fall)
			rose = wisp.position.y
		if not mid and t >= fall.time * 0.5:
			mid = true
			_fall_mid(p, fall, away, facing0, tag)
	var timed := absf(t - fall.time) <= 2.5 * DT
	ok(timed, tag + "the beat lasts its weight's time (%.2f s, %s %.2f s)" % [t, p.cls, fall.time])
	ok(last_gone > 0.6 and fall.landed, tag + "the body lands and fades out (%.2f transparent)" % last_gone)
	ok(rose > low + 0.15, tag + "the Wisp rises out of it (%.2f m -> %.2f m)" % [low, rose])
	var clean: bool = _faded(fall) == 0.0 and is_zero_approx(p.model.position.x) and is_zero_approx(p.model.position.z)
	ok(clean, tag + "after the beat the body is opaque and back on the hunter")

func _fall_mid(p: Hunter, fall: HunterFall, away: Vector2, facing0: Vector3, tag: String) -> void:
	var body := p.model.global_position - fall.from
	var pushed := Vector2(body.x, body.z)
	var crawled := Vector2(p.pos.x - fall.from.x, p.pos.z - fall.from.z).length()
	var held: bool = pushed.length() <= fall.push + 0.02 and crawled > 0.3
	ok(held, tag + "the body stays where it went down (%.2f m off, the hunter %.2f m)" % [pushed.length(), crawled])
	ok(pushed.dot(away) >= 0.6 * fall.push, tag + "pushed away from the knocker (%.2f m)" % pushed.dot(away))
	var faced: bool = p.model.basis.z.normalized().distance_to(facing0) < 0.01
	ok(faced, tag + "facing the way it fell while the hunter turns")
	var clips := _clips(p)
	var states: Dictionary = clips.d.get("states", {}) if clips else {}
	if states.has("dead"):
		ok(clips.cur == String(states["dead"]), tag + "it plays its death clip (%s)" % clips.cur)
	else:
		ok(p.anim.fall_k > 0.2, tag + "no death clip: it kneels (%.2f in)" % p.anim.fall_k)

## The most transparent of the hero's meshes.
func _faded(fall: HunterFall) -> float:
	var most := 0.0
	for mesh in fall.meshes:
		if is_instance_valid(mesh):
			most = maxf(most, (mesh as GeometryInstance3D).transparency)
	return most

## Heavy Hunters fall heavier, light ones crumple: every beat is 0.4-0.5 s, a heavier one longer and further
## behind in its clip at the same share of the beat (it holds, then drops), shoved less, and only heavies thud.
func _styles() -> void:
	var st := HunterFall.STYLE
	for w in st:
		var t := float(st[w]["time"])
		ok(t >= 0.4 and t <= 0.5, "fall '%s': the beat is %.2f s (0.4-0.5)" % [w, t])
	var order: bool = st["light"]["time"] < st["medium"]["time"] and st["medium"]["time"] < st["heavy"]["time"]
	var at := func(w: String) -> float: return pow(0.3, float(st[w]["curve"]))
	var holds: bool = at.call("heavy") < at.call("medium") and at.call("medium") < at.call("light")
	ok(order and holds, "a heavy falls slower and holds, a light one folds at once")
	var shoved: bool = st["heavy"]["push"] < st["medium"]["push"] and st["medium"]["push"] < st["light"]["push"]
	var thuds: bool = int(st["heavy"]["thud"]) > 0 and int(st["light"]["thud"]) == 0
	ok(shoved and thuds, "a heavy is shoved least and lands with a thud of dust")

func _bleed_out() -> void:
	var p: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	p.hp = p.max_hp
	_frames(0.1)
	m.knock(p, foe, {})
	_frames(0.1)
	var fall := HunterFall.of(p)
	m.eliminate(p, foe, "finished")
	_frames(DT)
	var reset: bool = fall != null and HunterFall.of(p) == null and _faded(fall) == 0.0
	ok(reset and is_zero_approx(p.model.position.x) and HunterWisp.node_of(p) == null,
		"out mid-beat: the beat stops, the body is opaque and back on the hunter, the Wisp gone")
	m.revive_hunter(p, null)
	Life.bring_back(m, p, p.pos, 0.5, false)
	_frames(0.1)
	m.knock(p, foe, {})
	_frames(0.4)
	var burst0: int = m.fx.radial
	m.eliminate(p, foe, "finished")
	_frames(0.1)
	var gone: bool = HunterWisp.node_of(p) == null and HunterWisp.mode_of(p) == ""
	ok(gone, "bleed-out or an execute breaks the Wisp (it is freed)")
	ok(not Sfx.loop_on(HunterWisp.hum_key(p)), "...and stops the hum")
	ok(m.fx.radial > burst0, "...with a burst of sparks")
	m.revive_hunter(p, null)
	Life.bring_back(m, p, p.pos, 0.5, false)
	_frames(0.1)
	ok(p.model.visible, "back from the dead: the hero shows")

## A bot or remote teammate has no saved look: it gets the default Wisp, from `downed` alone.
func _teammate() -> void:
	var p: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	m.knock(mate, foe, {})
	_frames(0.6)       # past the knocked-down beat
	ok(HunterWisp.node_of(mate) != null and not mate.model.visible, "a teammate's downed state shows their Wisp")
	var teammates_downed: bool = mate.downed
	m.revive_hunter(mate, null)
	_frames(0.6)
	var back: bool = mate.model.visible and HunterWisp.node_of(mate) == null
	ok(teammates_downed and back, "...and their revive brings the hero back")

func _tutorial() -> void:
	_start({"teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "tutorial": true})
	var p: Hunter = m.player
	var base: Vector3 = p.model.scale
	_frames(0.2)
	m.knock(p, null, {})
	_frames(0.6)       # past the knocked-down beat
	ok(p.downed and HunterWisp.node_of(p) != null and not p.model.visible, "tutorial: downed shows the Wisp")
	var waited := 0.0
	while p.downed and waited < 10.0:       # the tutorial brings you back after about 3 s of its own time
		_frames(0.25)
		waited += 0.25
	_frames(0.5)
	ok(not p.downed and p.model.visible and HunterWisp.node_of(p) == null, "tutorial: the revive brings the hero back")
	ok(p.model.scale.is_equal_approx(base), "tutorial: at full size")
	m.queue_free()

func _looks() -> void:
	var rules := WispLook.rules()
	var default_look := WispLook.get_look("")
	for id in rules["looks"]:
		var look := WispLook.get_look(String(id))
		var same_keys := true
		for key in default_look:
			same_keys = same_keys and look.has(key)
		ok(same_keys, "look '%s' has every key" % id)
		for spec in [look["pop_in"], look["pop_out"], look["snuff"], look["hum"]]:
			ok(String(spec["sfx"]) in Sfx.NAMES, "look '%s': sound '%s' exists" % [id, spec["sfx"]])
		_outline(String(id), look)
	ok(WispLook.get_look("no_such_wisp") == default_look, "an unknown id gives the default Wisp")
	var rules_looks: Dictionary = rules["looks"]
	rules_looks["check_ember"] = {"core": {"rim": "ff6a00"}, "hover": 0.3}      # a new Wisp is data only
	var ember := WispLook.get_look("check_ember")
	var kept: bool = ember["body"]["radius"] == default_look["body"]["radius"]
	ok(ember["core"]["rim"] == "ff6a00" and kept, "a look lists only what it changes")
	var body2 := WispLook.build(ember, Color.RED)
	var mat: ShaderMaterial = body2.get_node("Body").material_override
	ok(mat.get_shader_parameter("rim_col") == Color("ff6a00"), "...and builds with its own rim colour")
	body2.free()
	ok(WispLook.equip("check_ember") and WispLook.equipped() == "check_ember", "the saved Wisp id round-trips")
	rules_looks.erase("check_ember")
	var fell_back: bool = WispLook.equipped() == "default" and not WispLook.equip("check_ember")
	ok(fell_back, "a missing look falls back to the default")

## The outline rule (briefs/DECISIONS.md 2026-11-09): a round body with a head, team colour rim, white
## core, low to the ground, a steady glow, and one mesh in one material so thirty stay cheap.
func _outline(id: String, look: Dictionary) -> void:
	var tag := "look '%s': " % id
	var body := WispLook.build(look, Color.RED)
	var mesh := body.get_node_or_null("Body") as MeshInstance3D
	ok(mesh != null and body.get_child_count() == 1 and mesh.get_child_count() == 0, tag + "one mesh, nothing else")
	if mesh == null:
		body.free()
		return
	var box := mesh.mesh.get_aabb()
	var round_body: bool = absf(box.size.x - box.size.z) < 0.01 and box.size.x > 0.3
	var shape := "%.2f wide, %.2f tall" % [box.size.x, box.size.y]
	ok(round_body and box.size.y > box.size.x * 1.1, tag + "a round body with a head on top (" + shape + ")")
	var mat := mesh.material_override as ShaderMaterial
	ok(mat != null and body.get_meta("mat") == mat, tag + "one material, the one HunterWisp flashes")
	ok(mat.get_shader_parameter("rim_col") == Color.RED, tag + "the rim is the team colour")
	ok(mat.get_shader_parameter("core_col") == Color.WHITE, tag + "the core is white")
	var steady := true
	for uniform in mat.shader.get_shader_uniform_list():
		steady = steady and not String(uniform["name"]).contains("flicker")
	ok(steady, tag + "the glow is steady: the shader has no flicker")
	var low: bool = float(look["hover"]) <= 0.5 and float(look["hover"]) + box.position.y > 0.05
	ok(low, tag + "it floats low, clear of the ground (centre %.2f m)" % float(look["hover"]))
	var heavy: bool = float(look["settle"]) >= 0.3 and float(look["bob_hz"]) <= 0.7
	ok(heavy, tag + "slow and heavy: settle %.1f s, bob %.2f Hz" % [look["settle"], look["bob_hz"]])
	body.free()

## The picker on the Hunters screen (WispPick): a card per look with a live preview, the worn one chosen, a
## locked one greyed with how to unlock it, a click that wears and saves the Wisp (Save.d["look"]["wisp"]).
func _picker() -> void:
	var looks: Dictionary = WispLook.rules()["looks"]
	looks["check_lock"] = {"name": "Check Lock", "unlock": "extracts:999999", "how": "Make it out 999999 times"}
	looks["check_open"] = {"name": "Check Open", "core": {"rim": "00ff88"}}
	WispLook.equip("default")
	var worn := [0]
	var picker := WispPick.make(func(): worn[0] += 1)
	var cards := picker.find_children("*", "VBoxContainer", true, false).filter(func(n): return n.has_meta("wisp"))
	ok(cards.size() == looks.size(), "the picker has a card per look (%d)" % cards.size())
	var open_card: Control = cards.filter(func(n): return n.get_meta("wisp") == "check_open")[0]
	var lock_card: Control = cards.filter(func(n): return n.get_meta("wisp") == "check_lock")[0]
	var open_btn := open_card.get_child(1) as Button
	var lock_btn := lock_card.get_child(1) as Button
	var preview := open_card.get_child(0) as SubViewportContainer
	var built := preview.get_child(0).get_node_or_null("Wisp") as Node3D
	ok(built != null and built.get_child_count() == 1 and built.get_node("Body") is MeshInstance3D,
			"the preview builds the real Wisp body (one round mesh)")
	var mat := built.get_meta("mat") as ShaderMaterial
	ok(mat.get_shader_parameter("rim_col") == Color("00ff88") and mat.get_shader_parameter("core_col") == Color.WHITE,
			"...with the look's own rim and the white core")
	var greyed: bool = lock_btn.disabled and lock_card.modulate.a < 1.0 and not open_btn.disabled
	ok(greyed, "a locked Wisp is greyed, an owned one is not")
	var says_how: bool = lock_btn.tooltip_text.contains("999999") and not WispLook.equip("check_lock")
	ok(says_how, "...it says how to unlock and cannot be worn")
	var first := cards[0].get_child(1) as Button
	ok(not first.disabled and first.theme_type_variation == "Chosen", "the worn Wisp (the default, first) is marked")
	open_btn.pressed.emit()
	ok(WispLook.equipped() == "check_open" and Save.d["look"]["wisp"] == "check_open" and worn[0] == 1,
			"a click wears the Wisp and saves it in look.wisp")
	var again := WispPick.make(func(): pass)
	var buttons := again.find_children("*", "Button", true, false)
	var marked := buttons.filter(func(b): return b.theme_type_variation == "Chosen")
	var marks_new: bool = marked.size() == 1 and marked[0].get_parent().get_meta("wisp") == "check_open"
	ok(marks_new, "a rebuilt picker marks the new one")
	picker.free()
	again.free()
	looks.erase("check_lock")
	looks.erase("check_open")
	WispLook.equip("default")
