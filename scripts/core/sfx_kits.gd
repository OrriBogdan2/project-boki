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
	# Breah (dolm) and Ostra: tools/gen_stone_sfx.py
	"br_throw", "br_boulder_hit", "br_wind", "br_punch", "br_launch", "br_burst", "br_rise", "br_roll", "br_shove",
	"br_leap", "br_slam", "br_crack", "br_raise", "br_sense",
	"os_orb", "os_orb_hot", "os_prime", "os_snap_wind", "os_snap", "os_snap_hit", "os_swap_lob", "os_swap", "os_seed",
	"os_full", "os_pop", "os_empower", "br_spine", "os_well", "os_well_hum",
]
