class_name HomeVerbs
extends RefCounted
## Times the player's garden moves at home (HunterVerbs): feed, pat, toss, cheer. The paths that
## already do the feeding, petting, ball tossing and drill cheering call play(); the owner passes
## step() to HunterAnim every frame.

var act := ""
var t := 0.0

func play(verb: String) -> void:
	act = verb
	t = 0.0

## Advances the clock; what the owner hands to HunterAnim this frame.
func step(dt: float) -> Dictionary:
	if act == "":
		return {}
	t += dt
	if t >= float(HunterVerbs.LENGTH[act]):
		act = ""
		return {}
	return {"holster": true, "act": act}
