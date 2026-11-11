class_name BokiCry
extends RefCounted
## A Boki's own cry: one short call per species in audio/cries/<name>.wav (tools/gen_boki_cries.py), the
## same voice across an evolution line. Played through Sfx so it sits in the mix like every other sound.

const DIR := "res://audio/cries/"
const PITCH_VAR := 0.03     # a touch of pitch spread so the same cry twice is not a copy

## The cry file of a species (a Data.KIN key), or "" when there is none for it. A file carries the species'
## name; one whose name differs from its files (Minkee, id ermink) is found by its id.
static func path(species_id: String) -> String:
	var sp: Dictionary = Data.KIN.get(species_id, {})
	for stem: String in [String(sp.get("name", "")).to_lower(), species_id]:
		var p := DIR + stem + ".wav"
		if ResourceLoader.exists(p):
			return p
	return ""


## Plays the species' cry (nothing when it has none).
static func play(species_id: String, pos = null, vol_db := 0.0) -> void:
	var p := path(species_id)
	if p != "":
		Sfx.play_stream(load(p), pos, vol_db, PITCH_VAR)
