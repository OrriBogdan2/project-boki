class_name PracticeHero
extends RefCounted
## The Hunter picker in the practice areas (J or the bar's Hunters button, or Change Hunter in the Esc
## menu): Hunter cards (HeroGrid) in a panel over the paused game. Every Hunter can be picked here,
## locked ones included. Picking swaps your hunter in place (Hunter.reclass; the Arena's own
## swap when it has one), keeps your Boki, opens every rank, and saves the pick as your expedition class
## like the farm does (unless that Hunter is still locked).

static func toggle(p: Practice) -> void:
	if p.picker != null: close(p)
	else: open(p)

static func open(p: Practice) -> void:
	var body := _show(p, "Relics", 860, func(): close(p), "Done", "heroes")
	UI.subtitle(body, "Who you play here and on expeditions. Your Boki stays. "
			+ "Hover a Hunter for its kit, K for the full kit card.")
	var grid := HeroGrid.build(body, func(ak: String): pick(p, ak), func(ak: String): kit(p, ak),
			func(ak: String): p.hover_arch = ak, false)
	p.picker.set_meta("grid", grid)

static func kit(p: Practice, ak: String) -> void:
	var sp := ""
	if p.m.player and p.m.player.kin and not (p.m.player.kin as Kin).dead:
		sp = String((p.m.player.kin as Kin).species)
	var body := _show(p, "Kit: %s" % Arch.name_of(ak), KitCard.SIZE.x + 40, func(): open(p), "Back", "kit")
	body.add_child(KitCard.make(ak, sp))

static func close(p: Practice) -> void:
	if p.picker == null:
		return
	p.picker.queue_free()
	p.picker = null
	p.picker_page = ""
	p.hover_arch = ""
	p.m.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

## Plays `ak`: saved as your expedition pick, and your hunter here turns into it.
static func pick(p: Practice, ak: String) -> void:
	if not Arch.exists(ak):
		return
	var saved := HeroGrid.save_pick(ak)      # a locked Hunter is only tried here, never saved
	var P: Hunter = p.m.player
	if P != null and ak != P.arch:
		if p.m.arena:
			p.m.arena.set_arch(ak)
		else:
			_swap(p.m, P, ak)
	close(p)
	if not saved and p.m.hud:
		var why := "%s is still locked for expeditions: %s" % [Arch.name_of(ak), ClassUnlock.requirement(ak)]
		p.m.hud.toast(why, Arch.color(ak))

## The swap where there is no Arena (the Duel room, the tutorial): the same steps as Arena.set_arch.
static func _swap(m: Match, P: Hunter, ak: String) -> void:
	P.reclass(Arch.weight(ak), ak)
	P.unlock_all()
	m.fx.ring(P.pos, 1.8, Arch.color(ak), 0.4)
	m.fx.burst(P.pos + Vector3(0, 1.0, 0), Arch.color(ak), 18, 3.5, 0.5)
	m.sfx("unlock", null, -6.0, 1.1)
	if m.hud: m.hud.toast("%s  ·  %s" % [Arch.name_of(ak), String(Arch.def(ak).get("card", {}).get("loop", ""))], Arch.color(ak))

## (Re)builds the picker layer with one titled panel and returns its body to fill.
static func _show(p: Practice, title: String, width: float, on_close: Callable, close_txt: String, page: String) -> VBoxContainer:
	var first := p.picker == null
	if p.picker != null:
		p.picker.queue_free()      # (may be the panel whose button called us)
	p.picker_page = page
	p.picker = CanvasLayer.new()
	p.picker.layer = 40
	p.m.add_child(p.picker)
	p.m.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.picker.add_child(root)
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var pb := UI.scroll_panel(title, width, on_close, close_txt, true)
	center.add_child(pb[0])
	if first: UI.pop_in(pb[0])
	return pb[1]
