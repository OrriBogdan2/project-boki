extends RefCounted
## New checks for the "net" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	# 2 games, relay: kit zones on the other game (--shots-dir=: GPU, the guest's frames)
	"--zone-net-check": ["res://tools/zone_net_check.gd", "zone_net_check", null],
	"--remote-anim-1-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "1"],
	"--remote-anim-2-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "2"],
	"--remote-anim-3-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "3"],
	"--remote-anim-rest-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", "rest"],
	"--remote-anim-guest": ["res://tools/remote_anim_check.gd", "remote_anim_check", ""],  # its guest game
	"--squad-chat-check": ["res://tools/squad_chat_check.gd", "squad_chat_check", null],  # in-match squad chat
	"--social-net-check": ["res://tools/social_net_check.gd", "social_net_check", null],  # 2 games, real store
	"--social-net-peer": ["res://tools/social_net_check.gd", "social_net_check", "peer"],  # its second game
	"--stomp-net-check": ["res://tools/stomp_net_check.gd", "stomp_net_check", null],  # a stomp reaches the peer
}
