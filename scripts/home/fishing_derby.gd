class_name FishingDerby
extends RefCounted
## Fishing derby, a Glint Fishing mode (rules: content/rules/glint_fishing.json "derby"). Five casts against the
## catch a friend's visit snapshot kept: each finished session stores its points per cast in your save
## (fish_last), the snapshot carries them (Social.profile_doc), and a derby plays your five casts against the
## friend's list as if it were a ghost. The higher total wins gems, once per friend per garden day (fish_paid).
## The snapshot is untrusted: clean() bounds every entry, and only friends who landed something are raced.


static func rules() -> Dictionary:
	return GlintFishing.rules()["derby"]


## Points one cast scored: nothing unless it landed a glint, more for a rare one.
static func cast_pts(c: Dictionary) -> int:
	if c["how"] != "caught":
		return 0
	return int(rules()["rare" if c["rare"] else "common"])


static func total(pts: Array) -> int:
	var n := 0
	for p in pts:
		n += int(p)
	return n


## The catch kept in a snapshot (untrusted): at most one entry per cast, each within what a cast can score.
static func clean(v) -> Array:
	var out: Array = []
	for p in Social.arr_of(v).slice(0, int(GlintFishing.rules()["casts"])):
		out.append(clampi(Social.int_of(p), 0, int(rules()["rare"])))
	return out


## Your last session's points per cast, what friends see.
static func stored() -> Array:
	return clean(Save.d.get("fish_last"))


static func record(run: GlintFishing.Run) -> void:
	Save.d["fish_last"] = run.casts.map(cast_pts)


## Friends worth racing from Social.list_islands rows: the ones whose stored catch scored.
static func rivals(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		var pts: Array = r["d"]["fish"]
		if total(pts) > 0:
			out.append({"id": r["id"], "name": r["d"]["name"], "pts": pts})
	return out.slice(0, int(rules()["friends"]))


static func paid_today(id: String, day: int) -> bool:
	return int(Save.d.get("fish_paid", {}).get(id, -1)) == day


## Scores a finished derby and pays the gems for a win not yet paid today: {mine, theirs, won, gems}.
static func settle(foe: Dictionary, run: GlintFishing.Run, day: int) -> Dictionary:
	var mine := total(run.casts.map(cast_pts))
	var theirs := total(foe["pts"])
	var won := mine > theirs
	var gems := 0
	if won and not paid_today(foe["id"], day):
		gems = int(rules()["gems"])
		Save.d["gems"] = int(Save.d["gems"]) + gems
		var paid := {}
		for id in Save.d.get("fish_paid", {}):
			if int(Save.d["fish_paid"][id]) == day:
				paid[id] = day
		paid[foe["id"]] = day
		Save.d["fish_paid"] = paid
	return {"mine": mine, "theirs": theirs, "won": won, "gems": gems}


## The line the result card shows for a derby.
static func card_line(foe: Dictionary, res: Dictionary) -> Array:
	var verdict := "You win"
	if not res["won"]:
		verdict = "A tie" if res["mine"] == res["theirs"] else "They win"
	var gems := ", +%d gems" % res["gems"] if res["gems"] > 0 else ""
	return [
		"%s's catch: %s, %d to %d%s" % [foe["name"], verdict, res["mine"], res["theirs"], gems],
		UI.GOLD if res["won"] else UI.INK
	]


## The choice at the rock: fish alone, or race one of the friends' catches. `start` gets {} or the friend.
static func choose(h, day: int, start: Callable) -> void:
	var v: VBoxContainer = h._new_panel("Glint Fishing", 460)
	v.add_child(UI.label("Five casts. Fish for the glints, or race a friend's catch.", 14, UI.MUTED))
	v.add_child(
		UI.button(
			"Fish alone",
			func():
				h._close_panel()
				start.call({}),
			420
		)
	)
	var list := UI.vbox(6)
	v.add_child(list)
	list.add_child(UI.label("Looking for friends' catches...", 14, UI.MUTED))
	Social.list_islands(
		func(rows: Array):
			if not is_instance_valid(list):
				return
			for c in list.get_children():
				c.queue_free()
			var foes := rivals(rows)
			if foes.is_empty():
				list.add_child(UI.label("No friend has a catch to race yet.", 14, UI.MUTED))
			for f in foes:
				var tail := "prize taken today" if paid_today(f["id"], day) else "%d gems" % int(rules()["gems"])
				var text := "Derby vs %s: beat %d (%s)" % [f["name"], total(f["pts"]), tail]
				list.add_child(
					UI.button(
						text,
						func():
							h._close_panel()
							start.call(f),
						420
					)
				)
	)
