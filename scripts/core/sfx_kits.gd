class_name SfxKits
extends RefCounted
## Sound names the hero kits play, loaded by Sfx next to its own NAMES (append-only: one block per kit
## branch, so kit sound sets never collide in sfx.gd). Each is audio/<name>.wav (or <name>_1..4.wav).

const NAMES := [
	# Moosh Moosh (tender) and Tamsin (rimewright): tools/gen_care_sfx.py
	"tend_ember", "tend_ember_emp", "tend_seed_aim", "tend_seed", "tend_stick", "tend_root", "tend_hearth", "tend_toss",
	"tend_land", "tend_flare", "tend_hop", "tend_relay", "tend_pickup", "tend_kindled",
	"rime_shard", "rime_beam", "rime_spear_aim", "rime_lance", "rime_zone", "rime_burst", "rime_splinter", "rime_run",
	"rime_stop", "rime_wall_tell", "rime_wall", "rime_freeze", "rime_flip", "rime_ward",
	"tend_call", "tend_call_hum", "tend_arrive", "rime_lock", "rime_creak", "rime_crash", "rime_crack",
]
