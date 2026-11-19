class_name ClanChatPanel
extends RefCounted
## The clan channel in the Nesting Nook's side panel (ClanChat): the newest lines and a box to answer. Shows only
## in a clan.


static func side_rows(dv: VBoxContainer) -> void:
	var gid := Social.my_guild_id()
	if gid == "":
		return
	var box := UI.vbox(4)
	dv.add_child(box)
	box.add_child(UI.section("Clan chat"))
	var log := UI.vbox(2)
	box.add_child(log)
	var members: Array = []
	var refresh := func() -> void:
		ClanChat.read(
			gid,
			members,
			func(lines: Array):
				if not is_instance_valid(log):
					return
				for c in log.get_children():
					c.queue_free()
				for l in lines:
					var who: String = ("[%s] " % l["tag"] if l["tag"] != "" else "") + String(l["name"])
					log.add_child(UI.para("%s: %s" % [who, l["text"]], UI.T_SMALL, UI.INK))
				if lines.is_empty():
					log.add_child(UI.para("Quiet in here. Say hello to your clan.", UI.T_SMALL, UI.MUTED))
		)
	var row := UI.hbox(6)
	box.add_child(row)
	var input := LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "Message your clan..."
	input.max_length = Prematch.CHAT_MAX
	row.add_child(input)
	var send := func() -> void:
		var text := input.text
		ClanChat.send(
			text,
			func(sent: bool):
				if sent:
					input.clear()
					refresh.call()
		)
	input.text_submitted.connect(func(_t): send.call())
	row.add_child(UI.button("Send", send, 0.0))
	Social.guild_members(
		gid,
		func(list: Array):
			members.assign(list.map(func(m): return m["id"]))
			refresh.call()
	)
