class_name ClanLoanPanel
extends RefCounted
## The breeding-loan rows of the Nesting Nook (docs/specs/CLANS.md section 7). Both show only in a clan.

## On a Boki's card: one button per clanmate to lend it to for a garden day. reopen() redraws the Nook.
static func lend_rows(dv: VBoxContainer, rec: Dictionary, reopen: Callable) -> void:
	if Social.my_guild_id() == "":
		return
	dv.add_child(UI.section("Lend to a clanmate for a day"))
	var why := ClanLoan.why_not(rec)
	if why != "":
		dv.add_child(UI.para(why, UI.T_SMALL, UI.MUTED))
		return
	var row := HFlowContainer.new()
	dv.add_child(row)
	Social.guild_members(Social.my_guild_id(), func(members: Array):
		if not is_instance_valid(row):
			return
		for m in members:
			var id := String(m["id"])
			var who := String(m["d"]["name"])
			if id == Social.me:
				continue
			row.add_child(UI.button(who, func():
				if ClanLoan.offer(rec, id, who, Time.get_unix_time_from_system()):
					Save.save_game()
					reopen.call(), 0.0))
		if row.get_child_count() == 0:
			row.add_child(UI.label("No clanmates yet.", UI.T_SMALL, UI.MUTED)))

## In the side panel: my Boki out on loan, the clanmate's Boki staying here, or the offers I can take in.
static func side_rows(dv: VBoxContainer, reopen: Callable) -> void:
	if Social.my_guild_id() == "":
		return
	var box := UI.vbox(6)
	dv.add_child(box)
	box.add_child(UI.section("Clan loans"))
	var mine := ClanLoan.away()
	if not mine.is_empty():
		box.add_child(UI.para("%s is in %s's Nook, home in %s." % [mine["rec"]["name"], mine["name"],
			_hours_left(float(mine["t"]))], UI.T_SMALL, UI.INK))
	ClanLoan.for_me(func(got: Dictionary):
		if not is_instance_valid(box):
			return
		var guest: Dictionary = got["guest"]
		if not guest.is_empty():
			box.add_child(_guest_row(guest, box.get_tree()))
			return
		for o in got["offers"]:
			var offer: Dictionary = o
			box.add_child(UI.button("Take in %s from %s" % [offer["kin"]["name"], offer["from_name"]], func():
				ClanLoan.accept(offer, func(_stored: bool): reopen.call()), 0.0, "egg"))
		if mine.is_empty() and got["offers"].is_empty():
			var hint := "Open one of your Boki to lend it to a clanmate for a garden day."
			box.add_child(UI.para(hint, UI.T_SMALL, UI.MUTED)))

## The clanmate's Boki staying in this Nook: its picture and how long it stays.
static func _guest_row(o: Dictionary, tree: SceneTree) -> Control:
	var row := UI.hbox(10)
	row.add_child(KinPortrait.view(o["kin"], tree, 56.0))
	var kin: Dictionary = o["kin"]
	var says := UI.para("%s, %s's Lv %d %s, is staying with you for %s." % [kin["name"], o["from_name"],
		int(kin["level"]), Evo.form_name(kin), _hours_left(float(o["t"]))], UI.T_SMALL, UI.INK)
	says.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(says)
	return row

## "5 h" until a loan that started at t0 (s) is over.
static func _hours_left(t0: float) -> String:
	var left := t0 + Sleepover.DAY_SECS - Time.get_unix_time_from_system()
	return "%d h" % maxi(1, ceili(left / 3600.0))
