class_name HomeVerbs
extends RefCounted
## Times the player's garden moves at home (HunterVerbs): feed, pat, toss, cheer, and Glint Fishing's rod
## (HunterRod). The paths that already do the feeding, petting, ball tossing and drill cheering call play();
## the owner passes step() to HunterAnim every frame. act_t is what a Hero's own clip (warden_anim "act")
## seeks to. Fishing holds a pose (hold: "wait" or "reel", "" to put the rod away) under the one-shot
## moves (cast, bite, land), which play over it and hand back.

var act := ""
var t := 0.0
var stance := ""

func play(verb: String) -> void:
	act = verb
	t = 0.0

## The pose held between one-shots; "" ends it and cuts any one-shot short.
func hold(pose: String) -> void:
	stance = pose
	if pose == "" or pose == "reel":
		act = ""

## Advances the clock; what the owner hands to HunterAnim this frame.
func step(dt: float) -> Dictionary:
	if act != "":
		t += dt
		if t >= float(HunterVerbs.LENGTH.get(act, HunterRod.LENGTH.get(act, 0.0))):
			act = ""
	if act != "":
		return {"holster": true, "act": act, "act_t": t}
	if stance != "":
		return {"holster": true, "act": stance}
	return {}
