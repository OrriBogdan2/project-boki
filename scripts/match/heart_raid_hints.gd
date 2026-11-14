class_name HeartRaidHints
extends RefCounted
## Heart Raid's first-time hints (DECISIONS 11-08: one line, once, nothing blocks). Five moments, each shown
## once per save in the message lane through the match's own first-time hint (Match._tip, seen in
## Save.d["tutorial"]): the difficulty pick (HeartRaidPick), the raid-only Boki reward a few seconds in, the
## first wave's marks, the boss rising and the Heart's final seat opening. Texts: content/rules/heart_raid.json "hints".

const SEEN := "raid_%s"     # the key in Save.d["tutorial"]

static func text(id: String) -> String:
	return String(HeartRaid.rules()["hints"][id]).replace("{boss}", String(HeartRaid.rules()["boss"]["name"]))

static func _seen(id: String) -> bool:
	return bool(Save.d["tutorial"].get(SEEN % id, false))

## On the difficulty pick: what Hard and Nightmare change, in the pick screen's message lane.
static func pick(ui: Control) -> void:
	if _seen("diff") or not Settings.get_v("tips") or Record.clean():
		return
	Save.d["tutorial"][SEEN % "diff"] = true
	MsgLane.of(ui).push(text("diff"), HubHints.TIP_COL, MsgLane.NORMAL, HubHints.TIP_LIFE)

## Per director look (HeartRaid.tick), for you and for a client alike: the first unseen hint whose moment is now.
static func tick(rd: HeartRaid) -> void:
	var m := rd.m
	if m.hud == null or m.player == null or m.player.out or m.opts.get("autoplay", false):
		return
	if not Settings.get_v("tips") or Record.clean():
		return
	var now := {"boki": m.sess_time() >= float(rd.rules()["hints"]["boki_s"]),
		"wave": rd.gates.marked_wave == rd.wave and rd.gates.left() > 0.0 and rd.phase == HeartRaid.P.WAVES,
		"boss": rd.phase == HeartRaid.P.BOSS, "seat": rd.phase == HeartRaid.P.HOLD}
	for id in now:
		if now[id] and not _seen(id):
			m._tip(SEEN % id, text(id))
			return
