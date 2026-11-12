class_name TermHints
extends RefCounted
## One-line first-time hints for HUD words that show before anything explains them (UI_FIRST15 §4): the
## moment the thing first changes, the lane says what it is, once per save (the same `Save.d["tutorial"]`
## flags as Match._tip). The words that could simply be plainer were swapped in the HUD instead.

## Called each HUD tick for the local hunter.
static func watch(H, p: Hunter) -> void:
	if p == null or not Settings.get_v("tips"):
		return
	var seen: Dictionary = Save.d["tutorial"]
	var fever := p.ak != null and String(p.ak.res_def().get("id", "")) == "fever" and p.ak.res_frac() > 0.0
	if fever and not seen.get("term_fever", false):
		_say(H, seen, "term_fever", "Fever is lit: your hits heal you until it burns out")
	if p.armor_tier > 0 and not seen.get("term_armor", false):
		_say(H, seen, "term_armor", "Armor tier up: hitting foes fills it, and each tier adds plates")
	if p.kin != null and p.kin.state == "active" and not seen.get("term_boki", false):
		var orders := "hold %s for orders" % Settings.key_cap("throw")
		_say(H, seen, "term_boki", "Your Boki fights and uses its move by itself (AUTO)  ·  " + orders)

static func _say(H, seen: Dictionary, key: String, text: String) -> void:
	seen[key] = true
	H.tip(text)
