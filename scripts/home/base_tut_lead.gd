class_name BaseTutLead
extends RefCounted
## The base tutorial's lead (GARDEN.md section 8, DECISIONS Nov 3 "your Boki physically leads"): while a
## step of FarmTutorial's base list is up, your own Boki is in BaseLife's Lead state. It goes to the
## step's place (you, the toy, the portal), waits when you fall behind on the way and turns to look back
## at you, and says the step's line once over its head. content/rules/farm_tutorial.json base.lead holds the distances.

## Where the active Boki leads now: INF when no base step is up or k is not your active Boki.
static func target(h, k: Dictionary) -> Vector3:
	if not FarmTutorial.base() or k["rec"] != Save.active_kin() or not h.visit.is_empty():
		return Vector3.INF
	var wild := VisitorIntro.lead_at(h, k)      # the first wild visitor on a save: your partner runs to it
	if wild.x != INF:
		return wild
	var id := FarmTutorial.current()
	if id == "toy" and FarmTutorial.stage(id) == "watch":
		return FarmTutorial.toy_spot()
	if id in ["meet", "eat", "toy"]:
		return h.ppos       # it comes to you and stays at your side while you meet it, feed it and put a toy down
	return h.guide.target(id) if id != "" else Vector3.INF

## One 10 Hz tick of the Lead state: walk on to the target, or wait for you facing you. False when the
## lead is over (the machine goes back to Roam).
static func tick(h, k: Dictionary) -> bool:
	var at := target(h, k)
	if at.x == INF:
		return false
	if at == FarmTutorial.toy_spot() and h.toys.pick(k, true):
		return false      # the toy is down: it runs over to play (HomeToys has it now)
	var L: Dictionary = FarmTutorial.rules()["base"]["lead"]
	var pos: Vector3 = k["pos"]
	var behind := Vector2(h.ppos.x - pos.x, h.ppos.z - pos.z)
	var to := Vector2(at.x - pos.x, at.z - pos.z)
	var to_you: bool = at == h.ppos
	if (behind.length() > float(L["wait_m"]) and not to_you) or to.length() < float(L["stop_m"]):
		k["goal"] = pos
		(k["node"] as Node3D).rotation.y = atan2(-behind.x, -behind.y)      # looks back at you
	else:
		k["goal"] = at - Vector3(to.x, 0, to.y).normalized() * float(L["stop_m"]) * 0.8
	var id := FarmTutorial.current()
	if id != "" and String(k.get("lead_said", "")) != id:
		k["lead_said"] = id
		h._say(k, String(FarmTutorial.step_def(id).get("boki", "")))
	return true
