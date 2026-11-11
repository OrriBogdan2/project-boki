class_name KinVoice
## A Boki's wordless voice: every species has its own set (audio/bk_<species>_<mood>, made by
## tools/gen_sfx_boki.py, listed in content/sfx/boki_voices.json). docs/AUDIO.md.

## What a mood plays for a species with no voice set of its own.
const GENERIC_CUE := {
	"happy": "kin_happy", "alert": "kin_alert", "unsure": "kin_unsure", "sleepy": "boki_sleep", "hurt": "kinhit",
}

## The sound for a mood ("happy", "alert", "unsure", "sleepy", "hurt"): the species' own voice when it
## has one, else the shared cue.
static func cue(species: String, mood: String) -> String:
	var own := "bk_%s_%s" % [species, mood]
	return own if Sfx.ensure(own) else String(GENERIC_CUE[mood])
