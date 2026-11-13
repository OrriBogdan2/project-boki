class_name NetLeave
extends Node
## A player who drops off the relay mid-match, or never reached it, is out on every other game
## (docs/decisions/0061). Their body was a proxy only their own game could hurt, so without this
## it stood frozen for good: unkillable, holding the Heartspark, keeping its squad "alive".
## Same rule as the pre-match lobby (Prematch._gone): a roster peer missing from Net.peers is gone.

var m: Match

func _init(match_node: Match) -> void:
	m = match_node
	name = "NetLeave"

func _ready() -> void:
	Net.peers_changed.connect(_check)
	_check()

func _check() -> void:
	if not Net.online():
		return       # our own line went down (Net clears the peer list then): that's not them leaving
	for h in m.hunters.duplicate():
		if h.remote and not h.out and not h.extracted and h.nid.begins_with("P") and _gone(h):
			_left(h)

func _gone(h: Hunter) -> bool:
	return not Net.peers.has(Net.owner_of(h.nid))

func _left(h: Hunter) -> void:
	h.out = true
	h.downed = false
	Life.make_gone(m, h)
	for k in [h.kin, h.kin2]:
		if k:
			k.dead = true
	m.add_feed("%s left the match" % h.pname)
	m._check_team(h.team)
	m._check_last()
