class_name KinAct
extends RefCounted
## What a Boki in the garden is doing with its body right now, as the "kact" meta a rigged Boki (BokiRig) plays a clip
## for: "eat" at the bowl, "pet" while it is being scratched, "" otherwise. Napping is "kstate" sleep and joy is "happy"
## (the hop), both set by Home already.

static func of(k: Dictionary) -> String:
	if k.has("eat") and String(k["eat"]["phase"]) == "eat":
		return "eat"
	if float(k.get("hold_t", 0.0)) > 0.0 and float(k.get("joy_t", 0.0)) > 0.0:
		return "pet"
	return ""
