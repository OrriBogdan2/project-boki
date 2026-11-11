class_name UiFocus
extends RefCounted
## Who has the keys. Home, the interior, the town and the match all ask here before a key moves the
## hunter, so a press is either eaten or passed the same way everywhere. One holder wins, in this order:
## OVERLAY (pause/settings menu), CHAT (the talk bar), PANEL (a window, by id), TRAIN (a drill),
## BUILD (placing things). NONE means every world key reaches the hunter.
## The match's HUD windows take the PANEL slot too (MAP, PACK, SWAP, LOOT) and exclude each other.

enum Kind { NONE, PANEL, OVERLAY, CHAT, TRAIN, BUILD }

## Panel ids that are not a window title.
const MAP := "map"
const PACK := "pack"
const SWAP := "swap"
const LOOT := "loot"
const REVEAL := "reveal"      # the hatch/mask turn-round: the hunter stands still
const TALK := "Hob"           # talking to Hob: you stand still and no prompt shows

static var panel := ""        # id of the open window, "" when none
static var chat := false      # the talk bar is up
static var train := false     # a drill is running
static var build := false     # placing or decorating

static func reset() -> void:
	panel = ""
	chat = false
	train = false
	build = false

static func kind() -> Kind:
	if Overlay.is_open():
		return Kind.OVERLAY
	if chat:
		return Kind.CHAT
	if panel != "":
		return Kind.PANEL
	if train:
		return Kind.TRAIN
	return Kind.BUILD if build else Kind.NONE

## True when no menu, window, talk bar, drill or build mode holds the keys.
static func keys_free() -> bool:
	return kind() == Kind.NONE
