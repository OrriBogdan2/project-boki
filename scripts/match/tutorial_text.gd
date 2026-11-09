class_name TutorialText
extends RefCounted
## The tutorial's longer words: the second line under a step's banner (content/rules/tutorial.json
## "detail") and the Boki's hints, filled in from the player's own keys and the hunter's ability data.
## %E the E key, %U the ultimate's level, %F interact, %T the Boki key, %R rank-up combo,
## %N the E ability's name, %X the E ability in
## plain words (key included).

## "Press E: Longneedle. Stand still ..." built from the hunter's card text (any Hunter).
static func ability_tip(h: Hunter) -> String:
	var cap := Settings.key_cap("signature")
	if h == null or h.ak == null:
		return "Press %s to use your ability." % cap
	var nm := String(h.ak.e_def().get("name", "your ability"))
	var body := String(h.ak.d.get("card", {}).get("e", ""))
	if body.begins_with(nm + ": "):
		body = body.substr(nm.length() + 2)
	if body == "":
		return "Press %s: %s." % [cap, nm]
	return "Press %s: %s. %s" % [cap, nm, body.substr(0, 1).to_upper() + body.substr(1)]

## The key combo that ranks up the E ability (Match: Alt plus the ability's key).
static func rank_combo() -> String:
	return "Alt + " + Settings.key_cap("signature")

## Fills the tokens above in a line (the ability name comes from the hunter's data).
static func fill(txt: String, h: Hunter) -> String:
	var nm := "your ability"
	if h != null and h.ak != null:
		nm = String(h.ak.e_def().get("name", nm))
	return txt.replace("%X", ability_tip(h)).replace("%R", rank_combo()).replace("%N", nm) \
			.replace("%E", Settings.key_cap("signature")).replace("%F", Settings.key_cap("interact")) \
			.replace("%T", Settings.key_cap("throw")).replace("%U", str(Hunter.ULT_AT[0]))

## Word-wraps a line to a pixel width, shrinking the type until it fits `max_lines`. Returns {lines, px}.
static func wrap(font: Font, txt: String, px: int, width: float, max_lines: int) -> Dictionary:
	var fit_px := px
	var lines: Array = []
	while true:
		lines = []
		var cur := ""
		for w in txt.split(" "):
			var trial: String = w if cur == "" else cur + " " + w
			if cur != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_px).x > width:
				lines.append(cur)
				cur = w
			else:
				cur = trial
		lines.append(cur)
		if lines.size() <= max_lines or fit_px <= 10:
			break
		fit_px -= 1
	return {"lines": lines, "px": fit_px}
