class_name KinVoice
## The sound a Boki makes for a mood: its species' own voice when it has one, else the shared cue.

## What a mood plays for a species with no voice set of its own.
const GENERIC_CUE := {
	"happy": "kin_happy", "alert": "kin_alert", "unsure": "kin_unsure", "sleepy": "boki_sleep", "hurt": "kinhit",
}

## The sound for a mood ("happy", "alert", "unsure", "sleepy", "hurt"): the species' own voice
## (audio/bk_<species>_<mood>, tools/gen_sfx_boki.py) when it has one, else the shared cue.
static func cue(species: String, mood: String) -> String:
	var own := "bk_%s_%s" % [species, mood]
	return own if Sfx.ensure(own) else String(GENERIC_CUE[mood])
