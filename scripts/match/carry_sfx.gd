class_name CarrySfx
extends RefCounted
## The carry cues ("carry 2 in, 1 extra out", docs/decisions/0090; sounds from tools/gen_sfx_carry.py, docs/AUDIO.md):
## the lead swap's two-note handover, the warm lock-in of a carry-out claim, and a stolen Boki: a sting for its
## owner, a sly take at the thief that nearby squads hear (content/sfx/carry.json "reach"). One-shots through Sfx
## (pooled, MIN_GAP), at most two voices per event.

const SWAP_GAP_S := 0.13       # s from the outgoing Boki's chirp to the incoming one's
const SWAP_DB := -6.0          # dB: the handover sits under the fight (a key pressed often)
const STING_DB := -2.0         # dB: the owner's sting plays flat, wherever the thief is

## The swap key: the outgoing Boki's chirp, then the incoming one's a fifth up, each at its own size's pitch.
static func swap(m, h: Hunter, now_k: Kin, was: Kin) -> void:
	var pos := h.pos
	if was:
		Sfx.play("carry_swap_out", pos, SWAP_DB, 0.03, _pitch(was.rec))
	var p_in := _pitch(now_k.rec)
	m.get_tree().create_timer(SWAP_GAP_S).timeout.connect(func(): Sfx.play("carry_swap_in", pos, SWAP_DB, 0.03, p_in))

## A Boki locked into the carry-out slot (a wild claim, or a capsule from a friendly box).
static func claim(m, h: Hunter) -> void:
	m.sfx("carry_claim", h.pos)

## A rival took one of `victim`'s Boki: its owner hears the sting, everyone else the take at the thief.
static func stolen(m, thief: Hunter, victim: Hunter) -> void:
	if victim == m.player:
		Sfx.play("carry_stolen", null, STING_DB, 0.0)
	else:
		m.sfx("carry_take", thief.pos)

## A capsule out of a deathbox into the looter's slots: from a rival's box it is a steal, else a claim.
static func from_box(m, h: Hunter, b: Dictionary) -> void:
	var o = b.get("owner")
	if o is Hunter and (o as Hunter).team != h.team:
		stolen(m, h, o)
	else:
		claim(m, h)

static func _pitch(rec: Dictionary) -> float:
	return HomeChimes.PITCH[GardenSfx.SIZE[Unique.size_tag(rec)]]
