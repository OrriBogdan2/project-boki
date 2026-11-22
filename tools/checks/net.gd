extends RefCounted
## New checks for the "net" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--remote-anim-1-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "1"],
	"--remote-anim-2-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "2"],
	"--remote-anim-3-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "3"],
	"--remote-anim-rest-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "rest"],
	"--remote-anim-guest": ["res://tools/remote_anim_check.gd", "remote_anim_check", ""],  # its guest game
}
