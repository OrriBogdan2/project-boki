class_name CcLockout
extends RefCounted
## What a crowd-control status on a body forbids: one table for every Hunter, read from
## content/rules/cc_lockouts.json (the source rules and the table are in docs/COMBAT.md). The gates in
## Hunter (jump, dash, glide, crouch, fire, walking), ArchKit.busy() and the belt ask blocks().

const RULES_PATH := "res://content/rules/cc_lockouts.json"

static var _rules: Dictionary = {}

## Status -> the acts it forbids, read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if parsed is Dictionary else {}
	return _rules

## Is `act` forbidden by a status on `e` right now? `skip`: a status the caller's move ignores (a reeling
## Dredge is Grounded by his own hook but still barges, so his dash skips "gnd").
static func blocks(e: Ent, act: String, skip := "") -> bool:
	var r := rules()
	return (e.stun_t > 0.0 and act in r["stun"]) or (e.root_t > 0.0 and act in r["root"]) \
		or (skip != "gnd" and KitStatus.grounded(e) and act in r["gnd"]) \
		or (KitStatus.rattled(e) and act in r["daze"])
