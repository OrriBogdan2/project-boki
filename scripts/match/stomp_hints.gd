class_name StompHints
extends RefCounted
## The two first-time hints about the stomp (DECISIONS 2026-11-11 "stomping", docs/decisions/0061): the first
## rival you down, how to finish them (the stomp key) and what it costs; the first time a teammate is being
## stomped near you, that a stun on the stomper breaks it. One line each on the usual hint card (Match.tip_once,
## once per save, flags in Save.d["tutorial"]); off with tips off, in the tutorial and in arenas. Neither names
## a squad, so solos read them as they are (a solo never has a teammate to stomp).

const DOWN_FLAG := "stomp_down"
const SAVE_FLAG := "stomp_save"
const DOWN_TEXT := "Hold %s on a downed rival to stomp them. You're locked in until it ends"
const SAVE_TEXT := "%s is being stomped. Stun %s to break it"
const NEAR := 30.0     # m: a teammate this close to you counts as "near you"

## `h` was knocked down by the local player's side (Match.knock, the "knock" event on a client).
static func downed(m: Match, h: Hunter) -> void:
	if h.team == m.player.team or not CarryHints.wanted(m):
		return
	m.tip_once(DOWN_FLAG, DOWN_TEXT % Settings.key_cap("interact"))

## `stomper` started stomping `wisp` (Stomp.start, on every game).
static func started(m: Match, stomper: Hunter, wisp: Hunter) -> void:
	if wisp == m.player or wisp.team != m.player.team or not CarryHints.wanted(m) \
			or wisp.pos.distance_to(m.player.pos) > NEAR:
		return
	m.tip_once(SAVE_FLAG, SAVE_TEXT % [wisp.pname, stomper.pname])
