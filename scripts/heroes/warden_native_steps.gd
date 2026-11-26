class_name WardenNativeSteps
extends RefCounted
## A Meshy-native Hunter's footsteps on the frames Meshy's walk, run and sneak clips plant a foot on Meshy's own foot
## bones (the contract path's twin is WardenSteps, which reads the hidden rig). Data "plants" in
## content/rules/warden_native.json: {state: {"L": [s], "R": [s]}}, the times into the clip a foot touches down, read
## off the clip's foot bones by --step-sync-check (which re-reads them and fails when a clip is swapped without
## them). A step sounds when the clip's playback passes a plant of the foot that did not step last; each step bumps
## the model's meta WardenSteps.STEPS, which HunterAnim hands on as `stepped` (Juice.footstep).

var root: Node3D
var player: AnimationPlayer
var plants := {}  # state -> [[s into the clip, foot]], by time
var cur := ""  # the state heard last frame ("": none)
var last := 0.0  # s into its clip then
var count := 0  # steps so far
var side := ""  # the foot that stepped last ("" none since he last stood)


## `data`: the Hunter's "plants".
func _init(model: Node3D, anim: AnimationPlayer, data: Dictionary) -> void:
	root = model
	player = anim
	for state in data:
		var times := []
		for foot in ["L", "R"]:
			for s in data[state].get(foot, []):
				times.append([float(s), foot])
		times.sort()
		plants[state] = times
	if not plants.is_empty() and not root.has_meta(WardenSteps.STEPS):
		root.set_meta(WardenSteps.STEPS, 0)


## After the clips advanced. `state`: the loop playing on the ground ("walk", "run", "crouch"), "" for any other.
func step(state: String) -> void:
	var times: Array = plants.get(state, [])
	if times.is_empty():
		cur = ""
		side = ""
		return
	var t := player.current_animation_position
	var from := last
	last = t
	if state != cur:  # (a new clip starts over: a plant it has passed is no step)
		cur = state
		return
	var length := player.current_animation_length
	var window := fposmod(t - from, length)
	var best := []
	for p in times:
		var ago := fposmod(t - float(p[0]), length)
		if ago < window and p[1] != side and (best.is_empty() or ago < float(best[0])):
			best = [ago, p[1]]
	if not best.is_empty():
		side = best[1]
		count += 1
		root.set_meta(WardenSteps.STEPS, int(root.get_meta(WardenSteps.STEPS)) + 1)
