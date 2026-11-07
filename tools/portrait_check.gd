extends RefCounted
## --portrait-check: the Wardens' painted portraits are the faces in the menus and the HUD (Portraits).
##   1. every Hunter resolves to its painted portrait (512 px square) and, where it has one, its splash
##      (16:9); one without a splash shows its portrait there; every one has its framing
##   2. a small frame crops in around the face; every cut stays inside the art
##   3. each place shows the art: the Hunters tiles, the practice picker, the Hunter viewer, the Mantle
##      pick's chips, the expedition chips, the kit card, the unlock reveal (the splash) and the HUD's
##      portrait slot (no model is rendered for it)
##   4. with the art missing, every place falls back to the rendered model
## With --shots-dir=<dir> (needs a renderer: xvfb-run): kit_card, practice_picker, hud and fallback_hud PNGs.
## Prints PORTRAIT lines and "PORTRAIT DONE, n checks, failures: n".

const PORTRAIT_PX := 512
const SPLASH_PX := Vector2i(960, 540)
## Wardens whose splash isn't in yet (or was redrawn away): their portrait stands in.
const NO_SPLASH := []

var main: Node
var fails := 0
var n := 0
var shots := ""

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("PORTRAIT %-66s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
	if shots != "" and main.fade != null:
		main.fade.reveal(0.05)      # (the boot splash would cover the screenshots)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_art()
	_framing()
	await _menus()
	await _hud()
	print("PORTRAIT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ 1. the art
func _art() -> void:
	ok("12 Hunters", Arch.ids().size() == 12, str(Arch.ids()))
	for a in Arch.ids():
		var ak := String(a)
		var path := Portraits.art_path(ak)
		var tex := load(path) as Texture2D if path != "" else null
		var square := tex != null and tex.get_size() == Vector2(PORTRAIT_PX, PORTRAIT_PX)
		ok("%s: its painted portrait" % Arch.name_of(ak), square, path)
		var splash := Portraits.art_path(ak, true)
		if NO_SPLASH.has(ak):
			ok("%s: no splash yet, the portrait stands in" % Arch.name_of(ak), splash == path)
		else:
			var st := load(splash) as Texture2D
			ok("%s: its splash" % Arch.name_of(ak), splash.ends_with("_splash.jpg") and st != null
					and Vector2i(st.get_size()) == SPLASH_PX, splash)
	var names_ok: bool = HeroTitle.base_name("gunslinger") == "Vex" and HeroTitle.base_name("rimewright") == "Nivi"
	var names2: bool = HeroTitle.base_name("tender") == "Meeko" and HeroTitle.base_name("mage") == "Ryzz"
	var names3: bool = HeroTitle.base_name("bulwark") == "Mossy" and HeroTitle.base_name("archer") == "Ravyl"
	var names4: bool = HeroTitle.base_name("juggernaut") == "Kael"
	ok("the new names", names_ok and names2 and names3 and names4)

# ------------------------------------------------------------------ 2. framing
func _framing() -> void:
	var rules = JSON.parse_string(FileAccess.get_file_as_string(Portraits.RULES_PATH))
	var src := Vector2(PORTRAIT_PX, PORTRAIT_PX)
	for a in Arch.ids():
		var ak := String(a)
		var has_face: bool = rules["face"].has(ak)
		var has_splash: bool = NO_SPLASH.has(ak) or rules["splash"].has(ak)
		ok("%s: framing for its face and splash" % Arch.name_of(ak), has_face and has_splash)
		var path := Portraits.art_path(ak)
		var small := Portraits.region(ak, path, src, Vector2(36, 36))
		var face := Vector2(rules["face"].get(ak, [0.5, 0.5])[0], rules["face"].get(ak, [0.5, 0.5])[1]) * src
		var whole := Rect2(Vector2.ZERO, src)
		ok("%s: a small frame crops in on the face" % Arch.name_of(ak), small.size.y < src.y * 0.7
				and small.has_point(face) and whole.encloses(small), str(small))
		var hud := Portraits.region(ak, path, src, Vector2(112, 132))
		ok("%s: the HUD's slot shows the whole bust, inside the art" % Arch.name_of(ak),
				is_equal_approx(hud.size.y, src.y) and whole.encloses(hud), str(hud))
		var sp := Portraits.art_path(ak, true)
		var sp_src := Vector2(SPLASH_PX) if sp.ends_with("_splash.jpg") else src
		var reveal := Portraits.region(ak, sp, sp_src, Vector2(280, 280))
		ok("%s: the reveal's square of the splash stays inside it" % Arch.name_of(ak),
				Rect2(Vector2.ZERO, sp_src).encloses(reveal) and is_equal_approx(reveal.size.y, sp_src.y))

# ------------------------------------------------------------------ 3, 4. the menus
func _menus() -> void:
	var tree := main.get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 50
	main.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UI.theme()
	layer.add_child(host)
	for a in Arch.ids():
		var ak := String(a)
		var tile := ClassCard.portrait(ak, 36.0)
		ok("%s: the Hunters tile shows its portrait" % Arch.name_of(ak), _shows(tile, ak, false))
		ok("%s: the reveal shows its splash" % Arch.name_of(ak), _shows(ClassCard.portrait(ak, 280.0, true), ak, true))
	var grid_box := UI.vbox(0)
	host.add_child(grid_box)
	var grid := HeroGrid.build(grid_box, func(_a): pass, func(_a): pass, func(_a): pass, false)
	var cards := grid.get_children()
	var faces := cards.map(func(c): return _first_pic(c))
	var want := cards.map(func(c): return Portraits.art_path(String(c.get_meta("arch"))))
	ok("the practice picker: every card shows its Warden", cards.size() == 12 and faces == want and not want.has(""))
	await _shot(tree, "practice_picker")
	grid_box.queue_free()
	var viewer := HunterViewer.make("gunslinger", Vector2(250, 300))
	host.add_child(viewer)
	await tree.process_frame
	ok("the Hunter viewer shows Vex's portrait by the name", _first_pic(viewer) == Portraits.art_path("gunslinger"))
	viewer.queue_free()
	var mask_faces: Array = []
	for id in ["gunslinger", "juggernaut", "tender", "ashwick"]:
		var v := HunterViewer.make(id, Vector2.ZERO)
		host.add_child(v)
		await tree.process_frame
		mask_faces.append(_first_pic(v) == Portraits.art_path(id) and Portraits.art_path(id) != "")
		v.queue_free()
	ok("the Relic moments: each Relic shows its Hunter's face (Vex, then Kael, Meeko, Cinder)",
			mask_faces.all(func(f): return f))
	var card := KitCard.make("rimewright", "", func(): pass)
	host.add_child(card)
	await tree.process_frame
	ok("the kit card shows Nivi's portrait", _first_pic(card) == Portraits.art_path("rimewright"))
	await _shot(tree, "kit_card")
	card.queue_free()
	for ak in ["gunslinger", "juggernaut", "tender"]:
		card = KitCard.make(ak, "cindle", func(): pass)
		host.add_child(card)
		await _shot(tree, "kit_card_" + ak)
		card.queue_free()
	_fallback_menus()
	layer.queue_free()
	await tree.process_frame

## With the art missing every menu spot shows the rendered model (a TextureRect over its SubViewport).
func _fallback_menus() -> void:
	Portraits.art_dir = "res://art/no_portraits/"
	var tile := ClassCard.portrait("thief", 36.0)
	ok("no art: the tile renders the model", tile is TextureRect and tile.get_child(0) is SubViewport
			and not Portraits.has_art("thief"))
	var chip := Button.new()
	Portraits.set_icon(chip, "thief", 24)
	ok("no art: the chip is a plain name chip", chip.icon == null and String(chip.get_meta("portrait_art")) == "")
	tile.free()
	chip.free()
	Portraits.art_dir = "res://art/portraits/"

func _shows(c: Control, ak: String, splash: bool) -> bool:
	var want := Portraits.art_path(ak, splash)
	var good := c is Portraits.Pic and String(c.get_meta("portrait_art")) == want and want != ""
	c.free()
	return good

## The art the first painted portrait under `node` shows ("" if none).
func _first_pic(node: Node) -> String:
	if node is Portraits.Pic:
		return String(node.get_meta("portrait_art"))
	for ch in node.get_children():
		var got := _first_pic(ch)
		if got != "":
			return got
	return ""

func _collect(node: Node, key: String, out: Array) -> void:
	if node.has_meta(key):
		out.append(node)
	for ch in node.get_children():
		_collect(ch, key, out)

# ------------------------------------------------------------------ 3, 4. the HUD
func _hud() -> void:
	var tree := main.get_tree()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "gunslinger",
			"cls": Arch.weight("gunslinger"), "weapon": Arch.signature("gunslinger")})
	var P: Hunter = m.player
	var hud = m.hud
	for i in 20:
		await tree.process_frame
	ok("the HUD's portrait slot is Vex's painted face", Portraits.arch_of(P) == "gunslinger"
			and Portraits.has_art("gunslinger"))
	ok("no model is rendered for a face with painted art", hud.portraits.is_empty(), str(hud.portraits.keys()))
	await _shot(tree, "hud", 30)
	Portraits.art_dir = "res://art/no_portraits/"
	for i in 20:
		await tree.process_frame
	ok("no art: the HUD renders your model instead", hud.portraits.has(P.nid))
	await _shot(tree, "fallback_hud", 20)
	Portraits.art_dir = "res://art/portraits/"
	m.queue_free()
	await tree.process_frame

func _shot(tree: SceneTree, file: String, frames := 20) -> void:
	if shots == "":
		return
	for i in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [shots, file])
