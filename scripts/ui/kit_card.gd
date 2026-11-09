class_name KitCard
extends PanelContainer
## One archetype's whole kit on one page (docs/ARCHETYPES.md), simple and visual: a header (portrait,
## name, weight), then one row per ability (Passive, LMB, RMB, E, Dash, the hunter's ultimate, the Boki
## Fusion), each with its key cap, a big icon, its name and one short line. A row's "Details" opens that
## ability's page (preview, every rule) in the same frame (no scroll, no resizing: the card is always
## SIZE). Used in the Arena / training (K) and on the expedition loadout (KitCard.strip, a compact row
## that opens the full card).

const SIZE := Vector2(800, 620)
const BODY_H := 468.0
const ROW_H := 54.0
const MAX_LINE := 74    # chars: a row's one line
const PORTRAIT := Vector2(76, 76)    # px: the Hunter's portrait in the header
const SLOTS := ["dash", "passive", "lmb", "rmb", "e", "r", "x"]
## The order the card lists them in: the kit as it is played, then the ultimate and the Fusion.
const ROWS := ["passive", "lmb", "rmb", "e", "dash", "x", "r"]
## Icons the kits name that the icon set draws under another id (weapons and four stray names).
const ICON_FIX := {"quill_rifle": "rifle", "coilcaster": "burst_rifle", "longbow": "sniper", "flamethrower": "fireball",
	"tower_shield": "bulwark", "rubble_fists": "haymaker", "tether_lantern": "tether", "hoar_fan": "wave",
	"lantern_crook": "mend", "earthshatter": "quake", "bolt": "fireball", "shield": "bulwark", "dash2": "dash"}
## (The ultimate tiles have no fixed key: _cap reads them from Settings.)
const KEYS := {"dash": "Shift", "passive": "", "lmb": "LMB", "rmb": "RMB", "e": "E", "r": "", "x": ""}
## The key cap on a slot's tile: the Merge tile unless the class ultimates are on, the hunter's own
## ultimate on its "x" tile.
static func _cap(slot: String) -> String:
	if slot == "x":
		return Settings.key_cap("hunter_ult")
	if slot == "r":
		return Settings.key_cap("ultimate")
	return String(KEYS[slot])

const LABEL := {"dash": "Dash", "passive": "Passive", "lmb": "Attack", "rmb": "Right click", "e": "Utility", "r": "Ultimate",
	"x": "Ultimate"}
## Which looping preview each archetype's abilities get (KitPreview kinds).
const PREVIEW := {
	"thief": {"dash": "dash", "passive": "marks", "rmb": "projectile", "e": "knife", "x": "lines"},
	"archer": {"dash": "grapple", "passive": "meter", "rmb": "heavy", "e": "rainwall", "x": "arrows3"},
	"mage": {"dash": "dash2", "passive": "marks", "rmb": "heavy", "e": "zone", "x": "leap"},
	"gunslinger": {"dash": "dash", "passive": "pips", "rmb": "projectile", "e": "lines", "x": "zone"},
	"juggernaut": {"dash": "dash2", "passive": "meter", "rmb": "charge", "e": "grapple", "x": "leap"},
	"bulwark": {"dash": "charge", "passive": "meter", "rmb": "shield", "e": "zone", "x": "fissure"},
	"dredge": {"dash": "dash2", "passive": "meter", "rmb": "grapple", "e": "charge", "x": "shots"},
	"ashwick": {"dash": "dash", "passive": "meter", "rmb": "projectile", "e": "zone", "x": "steer"},
	"tender": {"dash": "dash", "passive": "marks", "rmb": "projectile", "e": "zone"},
	"rimewright": {"dash": "charge", "passive": "marks", "rmb": "projectile", "e": "shield"},
	"dolm": {"dash": "dash2", "passive": "meter", "rmb": "heavy", "e": "zone", "x": "fissure"},
	"ostra": {"dash": "blink", "passive": "meter", "rmb": "projectile", "e": "zone", "x": "zone"},
}

var arch := ""
var kin_sp := ""
var body: Control = null
var grid: VBoxContainer = null
var page := ""                 # "" = the grid, or the slot whose detail page is open
var on_close: Callable

## The full card for an archetype (and the Boki you bring, "" for none).
static func make(arch_id: String, kin_species := "", close_cb := Callable()) -> KitCard:
	var c := KitCard.new()
	c.arch = arch_id
	c.kin_sp = kin_species
	c.on_close = close_cb
	c._build()
	return c

func _build() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	var frame := UiFrame.raised(UI.SURFACE, UI.R_PANEL, 30, UI.RIM)
	frame.edge = Color(Arch.color(arch), 0.55)
	frame.edge_w = 2
	add_theme_stylebox_override("panel", frame.padded(16, 14))
	var col := Arch.color(arch)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	# header: portrait, name, weight and weapons; the close button
	var hd := HBoxContainer.new()
	hd.add_theme_constant_override("separation", 14)
	v.add_child(hd)
	hd.add_child(Portraits.Pic.new(arch, PORTRAIT, col))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(UI.label(Arch.name_of(arch), 34, col, UI.big))
	var wn: Array = Arch.weapons(arch).map(func(w): return String(Data.weapon_stats(w).get("name", w)))
	var wt := Arch.weight(arch).capitalize() if Arch.weight(arch) != "" else "Support"
	tv.add_child(UI.label("  ·  ".join([wt] + wn), 16, UI.MUTED, UI.big))
	hd.add_child(tv)
	hd.add_child(UI.fill())
	if on_close.is_valid():
		var cb := UI.ghost("Close  (K)", on_close, 120)
		cb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hd.add_child(cb)
	# the body: one row per ability, or one ability's detail page
	body = Control.new()
	body.custom_minimum_size = Vector2(SIZE.x - 32, BODY_H)
	body.clip_contents = true
	v.add_child(body)
	_show_grid()

func _show_grid() -> void:
	page = ""
	for ch in body.get_children():
		ch.queue_free()
	grid = VBoxContainer.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("separation", 5)
	body.add_child(grid)
	for s in card_slots(arch):
		grid.add_child(_row(s))

## One ability: key cap, a big icon, its name (and how it is pressed) and one short line, then Details.
func _row(slot: String) -> Control:
	var info := slot_text(arch, slot)
	var col: Color = info["col"]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, ROW_H)
	p.add_theme_stylebox_override("panel", UI.frame(Color(1, 1, 1, 0.045), UI.R_CARD, Color(col, 0.3), 1, 12, 3))
	p.set_meta("slot", slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var kc_box := CenterContainer.new()
	kc_box.custom_minimum_size = Vector2(64, 0)
	var cap := _cap(slot)
	kc_box.add_child(UI.keycap(cap, 14) if cap != "" else UI.label("PASSIVE", 12, UI.MUTED, UI.big))
	row.add_child(kc_box)
	var dot := UI.IconDot.new(String(info["icon"]), col, 40.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := HBoxContainer.new()
	top.add_child(UI.label(String(info["name"]), 18, UI.INK, UI.big))
	if String(info.get("how", "")) != "":
		var hw := UI.label("   " + String(info["how"]), 13, Color(col.lightened(0.2), 0.95), UI.big)
		hw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(hw)
	tv.add_child(top)
	var line := String(info["line"])
	if slot == "r" and kin_sp != "":
		var bn := String(Data.KIN.get(kin_sp, {}).get("name", kin_sp))
		line = "Fuse with your %s: its colour and type change your abilities." % bn
	var ln := UI.label(short_line(line, String(info["name"])), 13, UI.MUTED)
	tv.add_child(ln)
	row.add_child(tv)
	var db := UI.ghost("Details", func(): _show_detail(slot), 84)
	db.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(db)
	return p

## An ability's page: everything about it, in the same frame as the grid.
func _show_detail(slot: String) -> void:
	page = slot
	for ch in body.get_children():
		ch.queue_free()
	grid = null
	var info := slot_text(arch, slot)
	var col: Color = info["col"]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(250, 0)
	var pv := KitPreview.new(preview_kind(arch, slot), col)
	pv.custom_minimum_size = Vector2(250, 190)
	left.add_child(pv)
	left.add_child(UI.button("‹  Back to the kit", _show_grid, 250))
	h.add_child(left)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.IconDot.new(String(info["icon"]), col, 30.0))
	top.add_child(UI.label(String(info["name"]), 24, UI.INK, UI.big))
	if _cap(slot) != "":
		var kc := UI.keycap(_cap(slot), 13)
		kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(kc)
	v.add_child(top)
	v.add_child(UI.label(String(info["tag"]), 13, col, UI.big))
	var fs := 15 if (info["detail"] as Array).size() <= 5 else 13      # (a long kit still fits, ranks included)
	for para in info["detail"]:
		var p := UI.label(String(para[1]) if para[0] == "" else "%s:  %s" % [para[0], para[1]], fs, UI.INK if para[0] == "" else (Color("ffd98a") if para[0] == "Ranks" else UI.MUTED))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(p)

# ------------------------------------------------------------------ data → text
## Name, icon, colour, a short tag, the one line, and the detail page's paragraphs for one slot.
## The slots an archetype has (no R tile for the heroes whose R is the Boki Merge; an X tile for a hero ultimate).
static func slots_of(a: String) -> Array:
	return SLOTS.filter(func(s): return not s in ["r", "x"] or Arch.def(a).has(s))

## The rows the card lists: the kit, the hunter's ultimate if it has one, and the Boki Fusion always.
static func card_slots(a: String) -> Array:
	return ROWS.filter(func(s): return s == "r" or s in slots_of(a))

static func slot_text(a: String, slot: String) -> Dictionary:
	var d := Arch.def(a)
	var cd: Dictionary = d.get("card", {})
	var col := Arch.color(a)
	var out := {"name": "", "icon": "dash", "col": col, "tag": "", "line": "", "detail": []}
	match slot:
		"dash":
			var sd: Dictionary = d["dash"]
			out.merge({"name": String(sd["name"]), "icon": String(sd.get("icon", "dash")), "col": Color(String(sd.get("col", "#ffffff"))),
				"tag": "%s charge%s · %ss" % [_charges(a), "" if _charges(a) == "1" else "s", KinText.n(float(sd.get("cd", 9.0)))], "line": String(cd.get("dash", sd.get("desc", "")))}, true)
			out["detail"] = [["", String(sd.get("desc", ""))]] + _ranks(a, "dash")
		"passive":
			var rd: Dictionary = d.get("resource", {})
			out.merge({"name": String(d["passive"]["name"]), "icon": String({"thief": "satchel", "archer": "scanner", "mage": "blaze_mantle", "gunslinger": "barrage", "juggernaut": "haymaker", "bulwark": "fortify"}.get(a, "burst")), "col": Color(String(rd.get("col", "#ffffff"))),
				"tag": "no key · always on" if String(rd.get("kind", "")) == "none" else "no key · builds as you fight", "line": String(cd.get("passive", ""))}, true)
			var tl: Dictionary = d.get("tells", {})
			out["detail"] = [["", String(d["passive"]["desc"])]]
			if tl.has("half"):
				var seen := "%s; full: %s." % [String(tl["half"]), String(tl.get("full", ""))]
				out["detail"].append(["What enemies see", seen])
			if d.has("jackpot"):
				out["detail"].append([String(d["jackpot"]["name"]), String(d["jackpot"]["desc"])])
		"lmb":
			var wl: Dictionary = cd.get("weapons", {})
			var ws: Array = Arch.weapons(a)
			var w0 := String(ws[0]) if not ws.is_empty() else ""
			out.merge({"name": String(Data.weapon_stats(w0).get("name", w0)), "icon": w0, "tag": "signature weapon", "line": String(wl.get(w0, Data.weapon_stats(w0).get("desc", "")))}, true)
			var det: Array = []
			for w in ws:
				var st: Dictionary = Data.weapon_stats(w)
				det.append([String(st.get("name", w)), "%s  %s" % [String(wl.get(w, "")), _wstat(st)]])
			out["detail"] = det
		"rmb":
			var sd: Dictionary = d["rmb"]
			var vs: Dictionary = sd.get("variants", {})
			var keys: Array = []
			for v in ["tap", "hold", "air", "during_e", "full"]:
				if vs.has(v): keys.append({"tap": "tap", "hold": "hold", "air": "air", "during_e": "in E", "full": "full"}[v])
			out.merge({"name": String(sd["name"]), "icon": String(sd.get("icon", "")), "col": Color(String(sd.get("col", "#ffffff"))),
				"tag": "%ss · %s" % [KinText.n(float(sd.get("cooldown", 8.0))), " / ".join(keys)], "line": String(cd.get("rmb", "")),
				"how": _how(keys)}, true)
			var det: Array = []
			for v in ["tap", "hold", "air", "during_e", "full"]:
				if vs.has(v): det.append([{"tap": "Tap", "hold": "Hold", "air": "In the air", "during_e": "During E", "full": "Resource full"}[v], String(vs[v])])
			det.append_array(_ranks(a, "sec"))
			out["detail"] = det
		"e":
			var sd: Dictionary = d["e"]
			out.merge({"name": String(sd["name"]), "icon": String(sd.get("icon", "")), "col": Color(String(sd.get("col", "#ffffff"))),
				"tag": "%ss" % KinText.n(float(sd.get("cooldown", 14.0))), "line": String(cd.get("e", ""))}, true)
			out["detail"] = [["", String(sd.get("desc", ""))]] + _ranks(a, "kin")
		"x":
			var xd: Dictionary = d["x"]
			var tag := "level %d · %ss" % [int(xd.get("unlock", 6)), KinText.n(float(xd.get("cooldown", 30.0)))]
			var xcol := Color(String(xd.get("col", "#ffffff")))
			out.merge({"name": String(xd["name"]), "icon": String(xd.get("icon", "")), "col": xcol,
				"tag": tag, "line": String(cd.get("x", ""))}, true)
			out["detail"] = [["", String(xd.get("desc", ""))],
				["Bond", "Landing it on a hunter fills your Boki bond a long way, ready for the Fusion on %s."
					% Settings.key_cap("ultimate")]]
		"r" when not d.has("r"):
			# no hero ultimate: the Merge key is the Boki's Merge
			out.merge({"name": "Boki Fusion", "icon": "bond", "col": Color("ffd27a"), "tag": "Boki system", "line": "Your Boki fuses with you; its kind decides the form."}, true)
			out["detail"] = [["", "%s is not a Hunter ability here: it is the Boki Fusion. Your Boki fuses with you and its kind sets the Fusion form." % Settings.key_cap("ultimate")]]
		"r":
			# the Merge key is the Merge for every class
			out.merge({"name": "Fusion", "icon": "bond", "col": Color("ffd27a"), "tag": "level 6 · full bond meter", "line": "You and your Boki become one: its colour, its type, your abilities changed."}, true)
			out["detail"] = [["Fusion", "Press %s with a full bond meter (it fills as your Boki lands hits, as you hit what it marked, and on combos). You take the Boki's colour and silhouette, and every ability of yours changes for the Fusion by its type and power." % Settings.key_cap("ultimate")],
				["Boki out?", "It leaps back through anything in its way and fuses you in mid-air."],
				["No Boki", "A downed or lost Boki: only a weak 3 second surge."],
				]
	out["icon"] = ICON_FIX.get(out["icon"], out["icon"])
	return out

## The ranks to come, in order (rank 2's concrete change first, then rank 3's special), as one row
## so the detail page never clips the second.
static func _ranks(a: String, slot: String) -> Array:
	var nr := Arch.next_ranks(a, slot, -1)
	if nr.is_empty():
		return []
	var parts: Array = []
	for r in nr: parts.append("%s: %s" % [String(r[0]), String(r[1])])
	return [["Ranks", "   ".join(parts)]]

static func preview_kind(a: String, slot: String) -> String:
	if slot == "lmb":
		var ws: Array = Arch.weapons(a)
		return "melee" if not ws.is_empty() and Data.weapon_stats(String(ws[0])).get("melee", false) else "shots"
	return String(PREVIEW.get(a, {}).get(slot, "projectile"))

## What a Boki's type does to this archetype's RMB, E and R, one short phrase each.
static func infusion_lines(a: String, ks: KinSpec) -> Array:
	var out: Array = []
	var inf := Arch.infusion(ks)
	var d := Arch.def(a)
	for slot in ["rmb", "e", "r"]:
		var sd: Dictionary = d.get(slot, {})
		if sd.is_empty(): continue
		var f := Arch.fill(sd.get("sockets", {}), inf, slot, String(sd.get("delivery", "projectile" if slot == "rmb" else "burst")))
		var notes: Array = (f.get("notes", []) as Array).filter(func(x): return not String(x).contains("fallback")).map(func(x):
			var s := String(x)
			for pre in ["ctrl add: ", "hit: ", "guard: ", "util: ", "mod: "]:
				s = s.replace(pre, "+")
			return s.replace("ctrl swap: ", "→ "))
		var txt := ", ".join(notes.slice(0, 2)) if not notes.is_empty() else "+10% power"
		out.append("%s: %s" % [String(sd.get("name", slot)), txt])
	return out

## One short line from a card text: the first sentence, without a leading "Name: ", cut at a clause
## so it fits a row.
static func short_line(t: String, nm := "") -> String:
	var s := t.strip_edges()
	var colon := s.find(": ")
	if nm != "" and s.begins_with(nm) and colon > 0 and colon < 46:
		s = s.substr(colon + 2).strip_edges()
	for sep in [". ", "; "]:
		var i := s.find(sep)
		if i >= 24:
			s = s.substr(0, i)
	s = s.trim_suffix(".")
	if s.length() > MAX_LINE:
		var cut := s.rfind(", ", MAX_LINE)
		if cut < 28:
			cut = s.rfind(" ", MAX_LINE)
		s = s.substr(0, cut)
	return s.substr(0, 1).to_upper() + s.substr(1) + "."

## How a right click is pressed, from its variants: "Tap only", "Hold only", "Tap / Hold / Air".
static func _how(variants: Array) -> String:
	var ways := variants.filter(func(k): return k in ["tap", "hold", "air"]).map(func(k): return String(k).capitalize())
	return " / ".join(ways) + (" only" if ways.size() == 1 else "")

static func _charges(a: String) -> String:
	return str(int(Data.CLASSES.get(Arch.weight(a), {}).get("dashes", 1)))

static func _wstat(st: Dictionary) -> String:
	if st.get("melee", false):
		return "(%s per hit, reach %sm)" % [KinText.n(float(st["dmg"])), KinText.n(float(st["range"]))]
	var per := 1.0 / maxf(0.05, float(st["rate"]))
	return "(%s%s damage, %s shots/s, %sm)" % [KinText.n(float(st["dmg"])), (" x%d" % int(st["pellets"])) if st.has("pellets") else "", KinText.n(snappedf(per, 0.1)), KinText.n(float(st["range"]))]

static func _first(t: String, n: int) -> String:
	var s := t.split(". ")[0]
	return s if s.length() <= n else s.substr(0, n - 1) + "…"

# ------------------------------------------------------------------ the compact row (loadout)
## A one-row summary for the expedition loadout: six small tiles (icon, key, name) and the kit's
## one-line loop; clicking anywhere calls open_cb (which shows the full card).
static func strip(a: String, open_cb: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for s in slots_of(a):
		var info := slot_text(a, s)
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 70)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s: %s" % [String(info["name"]), String(info["line"])]
		var lit_box := UI.frame(Color(1, 1, 1, 0.1), UI.R_CTRL, Color(info["col"], 0.85), 2, 4, 4)
		var rest_box := UI.frame(Color(1, 1, 1, 0.05), UI.R_CTRL, Color(info["col"], 0.35), 1, 4, 4)
		b.add_theme_stylebox_override("normal", rest_box)
		b.add_theme_stylebox_override("hover", lit_box)
		b.add_theme_stylebox_override("pressed", lit_box)
		b.pressed.connect(open_cb)
		b.set_meta("slot", s)
		var bv := VBoxContainer.new()
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 2)
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := UI.IconDot.new(String(info["icon"]), info["col"], 26.0)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(dot)
		var k := _cap(s) if _cap(s) != "" else "passive"
		var kl := UI.label(k, 10, UI.MUTED, UI.big)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(kl)
		var nl := UI.label(String(info["name"]).split(" ")[0], 11, UI.INK, UI.big)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(nl)
		b.add_child(bv)
		row.add_child(b)
	var ll := UI.label(String(Arch.def(a).get("card", {}).get("loop", "")), UI.T_SMALL, Arch.color(a))
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ll)
	return v


## A tiny looping schematic of an ability: you (the white dot), a target (red), and what the ability
## does between you, drawn every frame from a 1.6s clock.
class KitPreview extends Control:
	var kind := ""
	var col := Color.WHITE
	var t0 := 0.0
	func _init(k := "", c := Color.WHITE) -> void:
		kind = k; col = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		t0 = randf() * 1.6
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.32), true)
		var T := 1.6
		var t := fmod(Time.get_ticks_msec() / 1000.0 + t0, T) / T
		var me := Vector2(w * 0.22, h * 0.62)
		var foe := Vector2(w * 0.78, h * 0.62)
		var R := minf(w, h) * 0.075
		var white := Color(0.95, 0.97, 1.0)
		var red := Color("ff6a5a")
		var hit := false
		match kind:
			"shots", "projectile", "knife":
				var n := 3 if kind == "shots" else 1
				for i in n:
					var k := fmod(t * (1.6 if kind == "shots" else 1.0) + i * 0.33, 1.0)
					if k < 0.7:
						var p := me.lerp(foe, k / 0.7)
						draw_line(p - Vector2(10 if kind != "knife" else 6, 0), p, Color(col, 0.55), 3.0)
						draw_circle(p, R * (0.55 if kind == "shots" else 0.8), col)
					elif k < 0.85: hit = true
				if kind == "knife" and t > 0.75:
					draw_circle(foe + Vector2(R * 2.4, 0), R, Color(white, 0.9))       # the Shadow Step behind
			"melee":
				foe = Vector2(w * 0.5, h * 0.62)
				var a := lerpf(-1.4, 1.4, clampf(t * 2.0, 0.0, 1.0))
				if t < 0.5:
					draw_arc(me, w * 0.24, a - 0.7, a, 16, col, 4.0, true)
				hit = t > 0.3 and t < 0.5
			"marks":
				for i in 3:
					var lit := t > 0.2 + i * 0.2
					draw_circle(foe + Vector2((i - 1) * R * 2.2, -R * 3.4), R * 0.6, Color("ffd23f") if lit else Color(1, 1, 1, 0.2))
				if t > 0.85:
					draw_circle(foe + Vector2(0, -R * 3.4), R * (1.2 + (t - 0.85) * 8.0), Color("ffd23f", 1.0 - (t - 0.85) * 6.0))
					hit = true
				me = foe + Vector2(R * 2.6, 0)
			"meter", "pips":
				var f := clampf(t / 0.8, 0.0, 1.0)
				var bar := Rect2(Vector2(w * 0.12, h * 0.2), Vector2(w * 0.76, h * 0.12))
				draw_rect(bar, Color(1, 1, 1, 0.12), true)
				if kind == "pips":
					for i in 6: draw_rect(Rect2(bar.position + Vector2(i * bar.size.x / 6.0, 0), Vector2(bar.size.x / 6.0 - 2, bar.size.y)), col if f * 6.0 > i else Color(1, 1, 1, 0.12), true)
				else:
					draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), col, true)
				if f >= 1.0:
					draw_circle(me, R * (1.6 + sin(t * 40.0) * 0.3), Color(col, 0.45))
			"zone":
				var zr := w * 0.2 * clampf(t * 3.0, 0.0, 1.0)
				draw_circle(foe, zr, Color(col, 0.25))
				draw_arc(foe, zr, 0, TAU, 24, Color(col, 0.8), 2.0, true)
			"burst":
				draw_arc(me + Vector2(w * 0.18, 0), w * 0.36 * t, 0, TAU, 28, Color(col, 1.0 - t), 4.0, true)
				me += Vector2(w * 0.18, 0)
				hit = t > 0.45 and t < 0.6
				foe = Vector2(w * 0.86, h * 0.62)
			"buff":
				for i in 2:
					var k2 := fmod(t + i * 0.5, 1.0)
					draw_arc(me, R * (1.2 + k2 * 2.6), 0, TAU, 20, Color(col, 1.0 - k2), 2.5, true)
			"dash", "dash2", "charge":
				var steps := 2 if kind == "dash2" else 1
				var k3 := clampf(t / 0.5, 0.0, 1.0)
				var to := Vector2(w * (0.62 if kind != "charge" else 0.7), h * 0.62)
				if kind == "charge" and t < 0.35:
					draw_line(me, me.lerp(to, t / 0.35), Color(col, 0.5), 6.0)
					k3 = 0.0
				elif kind == "charge":
					k3 = clampf((t - 0.35) / 0.25, 0.0, 1.0)
				var p2 := me.lerp(to, k3) if steps == 1 else (me.lerp(me.lerp(to, 0.5) + Vector2(0, -h * 0.2), clampf(k3 * 2.0, 0.0, 1.0)) if k3 < 0.5 else (me.lerp(to, 0.5) + Vector2(0, -h * 0.2)).lerp(to, (k3 - 0.5) * 2.0))
				for g in 3:
					draw_circle(me.lerp(p2, g / 3.0), R * 0.8, Color(white, 0.12 + g * 0.08))
				me = p2
				hit = kind == "charge" and t > 0.6 and t < 0.75
				if kind == "charge": foe = Vector2(w * 0.8, h * 0.62)
			"blink", "grapple":
				var to2 := Vector2(w * 0.6, h * (0.62 if kind == "blink" else 0.3))
				if kind == "grapple": draw_line(me, me.lerp(to2, clampf(t * 3.0, 0.0, 1.0)), Color(col, 0.8), 2.0)
				if t > 0.4: me = to2 if kind == "blink" else me.lerp(to2, clampf((t - 0.4) * 3.0, 0.0, 1.0))
				draw_arc(to2, R * 1.4, 0, TAU, 16, Color(col, 0.7), 2.0, true)
			"leap":
				var k4 := clampf(t / 0.6, 0.0, 1.0)
				var land := foe - Vector2(R * 2.2, 0)
				draw_arc(land, R * 2.6, 0, TAU, 20, Color(col, 0.35 + 0.4 * k4), 2.0, true)
				me = me.lerp(land, k4) + Vector2(0, -sin(k4 * PI) * h * 0.35)
				if t > 0.6 and t < 0.9:
					draw_arc(land, R * 2.6 + (t - 0.6) * w * 0.4, 0, TAU, 24, Color(col, 1.0 - (t - 0.6) * 3.0), 4.0, true)
					hit = true
			"lines":
				var foes := [Vector2(w * 0.7, h * 0.3), Vector2(w * 0.82, h * 0.62), Vector2(w * 0.66, h * 0.85)]
				for i in foes.size():
					draw_circle(foes[i], R, red)
					if t < 0.4: draw_line(me, foes[i], Color(col, 0.75), 2.0)
					elif t < 0.4 + (i + 1) * 0.15: draw_circle(foes[i], R * 1.8, Color(col, 0.5))
				foe = Vector2(-99, -99)
			"rain":
				draw_arc(foe, w * 0.18, 0, TAU, 24, Color(col, 0.7), 2.0, true)
				for i in 5:
					var k5 := fmod(t * 2.0 + i * 0.2, 1.0)
					draw_line(foe + Vector2((i - 2) * w * 0.06, -h * 0.6 + k5 * h * 0.6), foe + Vector2((i - 2) * w * 0.06, -h * 0.5 + k5 * h * 0.6), col, 2.0)
				hit = fmod(t * 2.0, 1.0) > 0.8
			"shield":
				draw_arc(me, R * 2.2, -0.9, 0.9, 12, col, 4.0, true)
				var k6 := fmod(t, 1.0)
				if k6 < 0.6:
					draw_circle(foe.lerp(me + Vector2(R * 2.2, 0), k6 / 0.6), R * 0.5, red)
			"heavy":
				# a held draw (a growing ring), then a heavy shot that knocks the foe back into a wall
				var wx := w * 0.92
				draw_line(Vector2(wx, h * 0.3), Vector2(wx, h * 0.95), Color(0.7, 0.62, 0.5), 5.0)
				if t < 0.45:
					draw_arc(me, R * (2.6 - t * 3.0), 0, TAU * (t / 0.45), 20, Color(col, 0.9), 3.0, true)
				else:
					var k8 := clampf((t - 0.45) / 0.2, 0.0, 1.0)
					draw_line(me, me.lerp(foe, k8), Color(col, 0.9), 5.0)
					if k8 >= 1.0:
						foe = foe.lerp(Vector2(wx - R * 1.2, foe.y), clampf((t - 0.65) / 0.15, 0.0, 1.0))
						hit = true
			"rainwall":
				# a line of arrows falling across the foe's path
				var c0 := foe + Vector2(0, -h * 0.28)
				var c1 := foe + Vector2(0, h * 0.28)
				draw_line(c0, c1, Color(col, 0.35), R * 2.4)
				for i in 6:
					var k9 := fmod(t * 2.2 + i * 0.17, 1.0)
					var x0 := c0.lerp(c1, (i + 0.5) / 6.0)
					draw_line(x0 + Vector2(-R * 0.5, -h * 0.25 * (1.0 - k9)), x0 + Vector2(0, -h * 0.25 * (1.0 - k9) + R), col, 2.0)
				hit = fmod(t * 2.2, 1.0) > 0.85
			"arrows3":
				# three big arrows, the third the biggest
				for i in 3:
					var k10 := clampf((t - i * 0.25) / 0.2, 0.0, 1.0)
					if k10 > 0.0 and k10 < 1.0:
						var p3 := me.lerp(foe, k10)
						draw_line(p3 - Vector2(R * (2.0 + i), 0), p3, col, 3.0 + i * 2.0)
					if k10 >= 1.0 and t < i * 0.25 + 0.3: hit = true
			"steer":
				# a bolt that bends round a pillar onto the foe
				draw_rect(Rect2(Vector2(w * 0.45, h * 0.45), Vector2(w * 0.08, h * 0.35)), Color(0.6, 0.55, 0.5, 0.8), true)
				var k11 := clampf(t / 0.8, 0.0, 1.0)
				var pa := me; var pb := Vector2(w * 0.5, h * 0.22); var pc := foe
				var q0 := pa.lerp(pb, k11); var q1 := pb.lerp(pc, k11)
				var pt := q0.lerp(q1, k11)
				draw_circle(pt, R * (0.6 + 0.5 * k11), col)
				draw_arc(pt, R * (1.1 + 0.6 * k11), 0, TAU, 14, Color(col, 0.5), 2.0, true)
				hit = k11 >= 1.0 and t < 0.95
			"hex":
				var k12 := clampf(t / 0.5, 0.0, 1.0)
				if k12 < 1.0:
					draw_circle(me.lerp(foe, k12), R * 0.7, col)
				else:
					# the foe turned into a small critter, a ring of runes over it
					draw_circle(foe + Vector2(0, R * 0.5), R * 0.6, Color("f7c6ff"))
					draw_arc(foe, R * 2.0, t * 6.0, t * 6.0 + TAU * 0.8, 16, Color(col, 0.8), 2.0, true)
					foe = Vector2(-99, -99)
			"mirror":
				for sgn in [-1.0, 1.0]:
					var mp := me + Vector2(R * 1.5, sgn * h * 0.25)
					draw_circle(mp, R, Color(col, 0.45))
					var k13 := fmod(t * 1.5, 1.0)
					draw_circle(mp.lerp(foe, k13), R * 0.4, Color(col, 0.8))
				hit = fmod(t * 1.5, 1.0) > 0.85
			"fissure":
				var k14 := clampf(t / 0.35, 0.0, 1.0)
				var end := me.lerp(Vector2(w * 0.95, me.y), k14)
				draw_line(me, end, Color(col, 0.9), 3.0)
				if t > 0.5:
					for i in 5:
						var px := me.lerp(Vector2(w * 0.95, me.y), (i + 0.5) / 5.0)
						draw_line(px, px + Vector2(0, -h * 0.25 * sin(clampf((t - 0.5) * 4.0, 0.0, 1.0) * PI)), col, 4.0)
				foe = Vector2(w * 0.7, me.y)
				hit = t > 0.3
			"dome":
				draw_arc(me + Vector2(w * 0.2, 0), w * 0.3, PI, TAU, 24, Color(col, 0.8), 3.0, true)
				var k7 := fmod(t, 1.0)
				draw_circle(Vector2(w * 0.95, h * 0.5).lerp(Vector2(w * 0.73, h * 0.5), clampf(k7 / 0.5, 0.0, 1.0)), R * 0.5, red)
				me += Vector2(w * 0.2, 0)
				foe = Vector2(-99, -99)
		if foe.x > -50:
			draw_circle(foe, R * (1.25 if hit else 1.0), red.lightened(0.5) if hit else red)
			if hit: draw_arc(foe, R * 2.0, 0, TAU, 16, Color(1, 1, 1, 0.7), 2.0, true)
		draw_circle(me, R, white)
