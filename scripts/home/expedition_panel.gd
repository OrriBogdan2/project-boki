class_name ExpeditionPanel
extends RefCounted
## The expedition panel at the portal, kept to what a player decides: who goes (Hunter, Boki), where (the
## drop), the one line of today's conditions, and Start. The Boki's care notes, the loadout, the match
## settings and the mode links sit behind "Details" (ExpFold); other Relics and locked drops sit behind
## their own buttons.


## Opens the panel on `h` (the farm).
static func open(h: Home) -> void:
	h.raid_squad = 0
	if h.panel_open != "Expedition":
		ExpFold.reset()  # (a rebuild around a pick keeps the folds as they were)
	var v := h._new_panel("Expedition", 940, true)
	var cols := UI.hbox(UI.GAP_BIG + 8)
	v.add_child(cols)
	var details := UI.vbox(10)
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	HunterPickRow.add(h, left, true)
	var ak := Save.active_kin()
	if not ak.is_empty():
		left.add_child(UI.spacer(2))
		left.add_child(UI.section("Boki you bring"))
		CarryPick.add_cards(left, h._open_expedition)
	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.section("Where"))
	_tiles(h, right)
	right.add_child(UI.spacer(2))
	right.add_child(UI.section("Mode"))
	right.add_child(ModeCards.make(Data.saved_mode(), func(m): ModeCards.pick(m, h._open_expedition)))
	right.add_child(UI.spacer(2))
	_details(h, ak, details)
	_conditions(h, right, details)
	_links(h, details)
	ExpFold.add(v, [details], "Details", "Fewer details")
	v.add_child(details)
	var start_b := UI.footer_primary(v, "Start expedition", h._confirm_start, 250, "portal")
	start_b.grab_focus.call_deferred()


## One tile per drop; the picked one shows its risk tag, locked ones fold away.
static func _tiles(h: Home, into: Control) -> void:
	var extracts := int(Save.d.get("extracts", 0))
	if h.exp_tier >= Data.TIERS.size() or extracts < int(Data.TIERS[h.exp_tier]["unlock"]):
		h.exp_tier = 0
	var locked_tiles: Array = []
	for i in Data.TIERS.size():
		var td: Dictionary = Data.TIERS[i]
		var locked := extracts < int(td["unlock"])
		var pick := func() -> void:
			h.exp_tier = i
			h._open_expedition()
		var risky := KinLoss.at_risk(i)
		var on_pick := Callable() if locked else pick
		var col := UI.BAD if risky else UI.ACCENT
		var tc := UI.tile_card(h.exp_tier == i and not locked, on_pick, 12, col)
		var th := UI.hbox(12)
		tc.add_child(th)
		var tv := UI.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(tv)
		var nrow := UI.hbox(8)
		nrow.add_child(UI.label(String(td["name"]), UI.T_HEAD, UI.MUTED if locked else UI.INK, UI.big))
		nrow.add_child(UI.tag("Depth %d" % int(td["depth"]), UI.FAINT))
		if risky:
			nrow.add_child(UI.tag("Boki can be lost", UI.BAD))
		tv.add_child(nrow)
		tc.tooltip_text = String(td["desc"])
		if locked:
			var need := int(td["unlock"]) - extracts
			tv.add_child(
				UI.label("Make it out %d more time%s to open" % [need, "" if need == 1 else "s"], UI.T_SMALL, UI.FAINT)
			)
			th.add_child(UI.IconDot.new("lock", UI.FAINT, 18.0))
			tc.modulate.a = 0.7
			tc.focus_mode = Control.FOCUS_NONE
			tc.mouse_default_cursor_shape = Control.CURSOR_ARROW
			locked_tiles.append(tc)
		into.add_child(tc)
	if not locked_tiles.is_empty():
		ExpFold.add(into, locked_tiles, "Locked drops")


## The one line this drop's raid condition makes (rolled with the match's seed: RaidLook); its blurb is
## in Details.
static func _conditions(h: Home, into: Control, details: Control) -> void:
	if h.exp_seed == 0:
		h.exp_seed = randi() | 1
	var rc := RaidLook.pick(Settings.demo_opts({}), h.exp_seed)
	var blurb := String(RaidLook.BLURBS.get(rc, ""))
	into.add_child(UI.section("Conditions"))
	into.add_child(UI.chip("clock", String(RaidLook.NAMES.get(rc, rc)), RaidLook.COLORS.get(rc, UI.INK), blurb))
	details.add_child(UI.section("Match"))
	var drop_line := "Everyone drops together; about 10 minutes. Bots fill the empty places."
	details.add_child(UI.label(drop_line, UI.T_SMALL, UI.MUTED))
	details.add_child(UI.para("%s: %s" % [RaidLook.NAMES.get(rc, rc), blurb], 12, UI.MUTED))
	details.add_child(UI.para("The drop: " + String(Data.TIERS[h.exp_tier]["desc"]), 12, UI.MUTED))


## Behind "Details": Boki care, the loss rule and the loadout.
static func _details(h: Home, ak: Dictionary, into: Control) -> void:
	if not ak.is_empty():
		into.add_child(UI.para(Care.care_line(ak), UI.T_SMALL, UI.MUTED))
		if float(ak["trust"]) < 30.0:
			into.add_child(
				UI.para("%s doesn't trust you much yet and may refuse risky throws." % ak["name"], UI.T_SMALL, UI.BAD)
			)
		into.add_child(
			UI.para(
				(
					"Go down for good and the Boki you bring are left behind (the Black Market holds "
					+ "the unclaimed ones)."
				),
				12,
				UI.FAINT
			)
		)
	if Save.d.get("treat", "") != "":
		into.add_child(UI.chip("heart", "Treat: " + h._treat_name(Save.d["treat"]), Color("ffb0d0")))
	h.hecon.loadout_rows(into, h._open_expedition)


## The ways to play something else: practice, online, Heart Raid.
static func _links(h: Home, into: Control) -> void:
	var links := UI.hbox(10)
	into.add_child(links)
	links.add_child(
		UI.ghost(
			"Training Grounds",
			func():
				Save.save_game()
				Game.start_match(Match.arena_opts(Arch.of_save())),
			0,
			"knock"
		)
	)
	if Net.available():
		links.add_child(
			UI.ghost(
				"Play online", func(): Game.goto("lobby", {"cls": Data.class_of_save(), "tier": h.exp_tier}), 0, "bond"
			)
		)
	links.add_child(UI.ghost("Heart Raid (prototype)", func(): HeartRaidPick.open(h), 0, "heart"))


## "Your Boki can be lost": one line to read, the rules of the loss behind Details, then go or back.
static func confirm_risk(h: Home, tier: Dictionary) -> void:
	var v := h._new_panel("Your Boki can be lost", 640)
	var names: Array = []
	for rec in Save.d.get("roster", []):
		if rec.get("uid", "") in [Save.d.get("active", ""), Save.d.get("active2", "")]:
			names.append(String(rec.get("name", "your Boki")))
	var who := " and ".join(names) if not names.is_empty() else "the Boki you bring"
	var line := "In %s, if you go down, %s stays behind and a rival can take it." % [tier["name"], who]
	v.add_child(UI.para(line, UI.T_BODY, UI.INK))
	var rules := UI.vbox(8)
	var guard := "%s drops dazed beside your deathbox and guards it. Get revived and run into it to pick it up."
	var pull := "If a rival takes it you feel its pull: an arrow points at them and their spot pings on your map. "
	pull += "Knock them out and it drops. If they get out with it, or nobody picks it up, "
	pull += "it ends up at the Black Market."
	rules.add_child(UI.para(guard % who, 14, UI.MUTED))
	rules.add_child(UI.para(pull, 14, UI.MUTED))
	ExpFold.forget("Details")
	ExpFold.add(v, [rules], "Details", "Fewer details")
	v.add_child(rules)
	var row := UI.hbox(10)
	row.add_child(UI.primary("I understand, go", h._start_match, 220))
	row.add_child(UI.button("Back", h._open_expedition, 140))
	v.add_child(row)
