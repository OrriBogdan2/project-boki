class_name NookSfx
## The sound of pairing two Boki in the Nesting Nook (docs/AUDIO.md). Everything plays at the nest, from
## the garden UI sound set: a two-note chime (each note pitched by one parent's size), a nuzzle and a
## settle layered with each parent's own chirp, the egg settling, and on an unstable mix a short wobble.
## It is timed to the commit (the egg appears the moment you pair).

const BASE_VOL := -6.0          # dB, the garden cues' level (like garden_egg)
const PITCH_MIN := 0.75         # the chime's note range: the biggest Boki sings the lowest note
const PITCH_MAX := 1.35

## A Boki's note: the bigger, the lower.
static func note_pitch(rec: Dictionary) -> float:
	return clampf(pow(Unique.size_scale(rec), -0.7), PITCH_MIN, PITCH_MAX)

## The cues in order: [{t: seconds after the commit, snd, vol: dB, pitch, var: pitch spread}].
static func plan(a: Dictionary, b: Dictionary) -> Array:
	var steps := [
		{"t": 0.0, "snd": "nook_note", "vol": BASE_VOL, "pitch": note_pitch(a), "var": 0.0},
		{"t": 0.0, "snd": "garden_egg", "vol": BASE_VOL - 2.0, "pitch": 1.0, "var": 0.04},
		{"t": 0.2, "snd": "nook_note", "vol": BASE_VOL, "pitch": note_pitch(b), "var": 0.0},
		{"t": 0.7, "snd": "nook_nuzzle", "vol": BASE_VOL - 2.0, "pitch": 1.0, "var": 0.05},
		{"t": 0.75, "snd": "kin_happy", "vol": -12.0, "pitch": Unique.voice(a), "var": 0.05},
		{"t": 1.25, "snd": "nook_settle", "vol": BASE_VOL - 2.0, "pitch": 1.0, "var": 0.05},
		{"t": 1.3, "snd": "kin_happy", "vol": -12.0, "pitch": Unique.voice(b), "var": 0.05},
	]
	if UnstableMix.unstable(a, b):
		steps.append({"t": 1.8, "snd": "nook_wobble", "vol": BASE_VOL - 1.0, "pitch": 1.0, "var": 0.0})
	return steps

## Plays the pair's cues at the nest.
static func commit(tree: SceneTree, a: Dictionary, b: Dictionary, at: Vector3) -> void:
	for s in plan(a, b):
		var play := func(): Sfx.play(s["snd"], at, s["vol"], s["var"], s["pitch"])
		if float(s["t"]) <= 0.0:
			play.call()
		else:
			tree.create_timer(float(s["t"])).timeout.connect(play)
