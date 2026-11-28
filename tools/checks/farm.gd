extends RefCounted
## New checks for the "farm" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--care-prompt-check": ["res://tools/care_prompt_check.gd", "care_prompt_check", null],  # the care line over a Boki
	"--bond-pace-check": ["res://tools/bond_pace_check.gd", "bond_pace_check", null],
	"--vet-check": ["res://tools/vet_check.gd", "vet_check", null],  # the vet booth: check-up and cure
	"--vet-booth-shots": ["res://tools/vet_booth_shots.gd", "vet_booth_shots", null],  # --shots-dir=<dir> (GPU)
	"--farm-cam-check": ["res://tools/farm_cam_check.gd", "farm_cam_check", null],  # the farm third-person view
	"--farm-cam-clip": ["res://tools/farm_cam_clip.gd", "farm_cam_clip", null],  # GPU film: the third-person view
	"--train-runs-check": ["res://tools/train_runs_check.gd", "train_runs_check", null],  # limited runs, bites
	"--farm-greet-clip": ["res://tools/farm_greet_clip.gd", "farm_greet_clip", null],  # GPU film: Boki notice you back
}
