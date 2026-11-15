class_name RelayBeats
extends RefCounted
## What the Relay Cup's runners do with their bodies (scripts/home/base_relay.gd): the contact beat at a hand-off
## (the arriving Boki bumps the next, which braces), the burst start (the next one's run clip plays faster for
## a moment), and the finish (the winning team cheers, the losers sulk). Duo friends (BaseDuo) tap in the same
## happy hop and their burst swells and eases instead of stepping, so their pass reads smoother.
## A rigged Boki plays a clip through BokiRig's "kact" meta, the burst through its "kburst" meta; a clip the
## species does not have is a hop (stonehop), and a sulk without a clip is a head drop (the node pitches).
## Tuning: content/rules/base_relay.json "beats". Never touches the save.

const CLIP_DUO := "stonehop"       # both runners of a duo pass hop together
const CLIP_BUMP := "nudge"         # the arriving runner bumps the next one
const CLIP_BRACE := "brace"        # the next runner braces to take the baton
const CLIP_WIN := "win"            # BokiRig's react clip, where the species has it
const CLIP_SULK := "sulk"

var _live: Array = []              # hand-offs on show: {from, to, at, wait, duo, tapped}

static func rules() -> Dictionary:
	return BaseRelay.rules()["beats"]

## A hand-off at run time `at`: the next runner starts `wait` s later.
func hand_off(from: Node3D, to: Node3D, at: float, wait: float, duo: bool) -> void:
	_live.append({"from": from, "to": to, "at": at, "wait": wait, "duo": duo, "tapped": false})
	_play(from, CLIP_DUO if duo else CLIP_BUMP)
	_play(to, CLIP_DUO if duo else CLIP_BRACE)

## Ends each contact beat after its seconds and shapes the burst of each launch.
func step(now: float) -> void:
	var B := rules()
	var i := _live.size() - 1
	while i >= 0:
		var b: Dictionary = _live[i]
		if not b["tapped"] and now - float(b["at"]) >= float(B["contact_s"]):
			b["tapped"] = true
			(b["from"] as Node3D).remove_meta("kact")
			(b["to"] as Node3D).remove_meta("kact")
		var u := (now - float(b["at"]) - float(b["wait"])) / float(B["burst_s"])
		if u >= 1.0:
			(b["to"] as Node3D).remove_meta("kburst")
			_live.remove_at(i)
		elif u >= 0.0:
			var lift := float(B["burst_rate"]) - 1.0
			(b["to"] as Node3D).set_meta("kburst", 1.0 + lift * (sin(PI * u) if b["duo"] else 1.0))
		i -= 1

## A team's last runner is home: its three cheer if they won, sulk if not.
static func finish(nodes: Array, won: bool) -> void:
	for n in nodes:
		_play(n, CLIP_WIN if won else CLIP_SULK)
		if not won and not _has_clip(n, CLIP_SULK):
			n.rotation.x = float(rules()["sulk_drop"])

## Every runner back to its own life.
func clear(nodes: Array) -> void:
	_live = []
	for n in nodes:
		n.remove_meta("kact")
		n.remove_meta("kburst")
		n.rotation.x = 0.0

static func _play(n: Node3D, clip: String) -> void:
	n.set_meta("kact", clip if _has_clip(n, clip) else CLIP_DUO)

static func _has_clip(n: Node3D, clip: String) -> bool:
	for p in n.find_children("*", "AnimationPlayer", true, false):
		if (p as AnimationPlayer).has_animation(clip):
			return true
	return false
