class_name NetEnet
extends Node
## Desktop transport for online play: one ENet connection to the Project Boki relay server
## (scripts/server/relay.gd). Carries the same lobby and match messages the browser room does.
##
## Wire format: one JSON object per packet. Channel 0 is reliable (lobby, presence, hits, events);
## channel 1 is unreliable-ordered (position snapshots, where only the newest one matters).

signal got(d: Dictionary)
signal closed(why: String)

const CH_RELIABLE := 0
const CH_FAST := 1

var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var connected := false

func open(host: String, port: int) -> int:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port, 2)
	if err != OK:
		return err
	api = SceneMultiplayer.new()
	api.server_relay = false
	api.multiplayer_peer = peer
	get_tree().set_multiplayer(api, get_path())
	api.connected_to_server.connect(func(): connected = true)
	api.connection_failed.connect(func(): closed.emit("Couldn't reach the server."))
	api.server_disconnected.connect(_on_lost)
	api.peer_packet.connect(_on_packet)
	return OK

func send(d: Dictionary, fast := false) -> void:
	if not connected or api == null:
		return
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	api.send_bytes(JSON.stringify(d).to_utf8_buffer(), 1, mode, CH_FAST if fast else CH_RELIABLE)

func close() -> void:
	if peer:
		peer.close()
	connected = false

func _on_lost() -> void:
	connected = false
	closed.emit("Lost the connection to the server.")

func _on_packet(_from: int, bytes: PackedByteArray) -> void:
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY:
		got.emit(parsed)
