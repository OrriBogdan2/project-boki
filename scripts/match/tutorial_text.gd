class_name TutorialText
extends RefCounted
## The tutorial's and the Boki's hint lines, filled in from the player's own keys and the hunter's
## ability data: %E the E key, %U the ultimate's level, %F interact, %T the Summon key, %D the Boki's summon
## seconds, %C its cooldown seconds, %R rank-up combo, %N the E ability's name.

## The key combo that ranks up the E ability (Match: Alt plus the ability's key).
static func rank_combo() -> String:
	return "Alt + " + Settings.key_cap("signature")

## Fills the tokens above in a line (the ability name comes from the hunter's data).
static func fill(txt: String, h: Hunter) -> String:
	var nm := "your ability"
	if h != null and h.ak != null:
		nm = String(h.ak.e_def().get("name", nm))
	var dur := 0
	var cd := 0
	if h != null and h.kin != null and h.kin.summon != null:
		dur = roundi(h.kin.summon.dur)
		cd = roundi(h.kin.summon.cd_base)
	return txt.replace("%D", str(dur)).replace("%C", str(cd)).replace("%R", rank_combo()).replace("%N", nm) \
			.replace("%E", Settings.key_cap("signature")).replace("%F", Settings.key_cap("interact")) \
			.replace("%T", Settings.key_cap("summon")).replace("%U", str(Hunter.ULT_AT[0]))
