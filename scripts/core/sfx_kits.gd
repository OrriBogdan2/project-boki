class_name SfxKits
extends RefCounted
## Sound names the hero kits play, loaded by Sfx next to its own NAMES (append-only: one block per kit
## branch, so kit sound sets never collide in sfx.gd). Each is audio/<name>.wav (or <name>_1..4.wav).

const NAMES := [
	# Breah (dolm) and Ostra: tools/gen_stone_sfx.py
	"br_throw", "br_boulder_hit", "br_wind", "br_punch", "br_launch", "br_burst", "br_rise", "br_roll", "br_shove",
	"br_leap", "br_slam", "br_crack", "br_raise", "br_sense",
	"os_orb", "os_orb_hot", "os_prime", "os_snap_wind", "os_snap", "os_snap_hit", "os_swap_lob", "os_swap", "os_seed",
	"os_full", "os_pop", "os_empower", "br_spine", "os_well", "os_well_hum",
]
