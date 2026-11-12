class_name InvSfx
## The inventory cues (docs/AUDIO.md): grab (a drag starts), drop (a thing set into a slot), equip (gear
## put on), swap (a thing traded with the box) and take (a box thing comes to you). Short UI sounds
## (content/sfx/ui.json), played non-positionally and well under the fight, so looting in combat
## never covers a hit or a cast. The action's own button stays silent (SILENT), so a press makes one sound.

const CUE_DB := -8.0     # dB on top of the ui level (-22 RMS): about 13 dB under a hit or a shot
const SILENT := ""       # a button's "snd" meta for an action that plays its own cue

static func grab() -> void:
	Sfx.play("inv_grab", null, CUE_DB)

static func drop() -> void:
	Sfx.play("inv_drop", null, CUE_DB)

static func equip() -> void:
	Sfx.play("inv_equip", null, CUE_DB)

static func swap() -> void:
	Sfx.play("inv_swap", null, CUE_DB)

static func take() -> void:
	Sfx.play("inv_take", null, CUE_DB)
