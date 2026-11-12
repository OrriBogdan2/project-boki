class_name BaseBoard
extends RefCounted
## The Games board (briefs/design/GARDEN.md section 5), a prop by the Training post, base_mode only.
## Press interact at it for a plain list of the built Boki-vs-Boki minigames (the Dash, Stump Shove,
## Seek, Spark Volley): each one's best Boki (most wins) and last winner. Up and Down pick a game and
## interact starts it through the game's own use(), so no rules live here. Results are MinigameHub's
## (Save.d["game_board"]); this prop adds the rematch spot for BaseRival.

const BOARD_OFF := Vector3(-2.4, 0, 2.6)     # m from the Training post to the board
const REACH := 1.6                            # m from the board to open it
const CLOSE_AT := 3.2                         # m from the board at which the list closes itself
const POST_H := 1.1                           # m, the board's height

var h                          # the Home screen
var board: Node3D = null
var panel: Control = null
var pick := 0                  # the listed game under the marker

func _init(home) -> void:
	h = home

## The games built on this base: [id, title, game], in the order of the list.
func games() -> Array:
	var all := [["race", "The Dash", h.hrace], ["shove", "Stump Shove", h.hshove],
			["seek", "Seek", h.hseek], ["volley", "Spark Volley", h.hvolley]]
	return all.filter(func(g): return g[2] != null)

## The board beside the Training post (none without one); called when fixtures move.
func place() -> void:
	close()
	if is_instance_valid(board):
		board.queue_free()
	board = null
	if h.YARD_AT.x < -100.0:
		return
	board = Node3D.new()
	board.name = "GamesBoard"
	board.position = h.YARD_AT + BOARD_OFF
	h.add_child(board)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.1, POST_H, 0.1)
	post.mesh = pm
	post.material_override = BaseRace.mat(Color("7a5638"))
	post.position.y = POST_H * 0.5
	board.add_child(post)
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.9, 0.6, 0.05)
	face.mesh = fm
	face.material_override = BaseRace.mat(Color("d9b98a"))
	face.position.y = POST_H
	board.add_child(face)

func find(p2: Vector2) -> Dictionary:
	if not is_instance_valid(board) or p2.distance_to(Vector2(board.position.x, board.position.z)) > REACH:
		return {}
	return {"kind": "board"}

func has_game(id: String) -> bool:
	return games().any(func(g): return g[0] == id)

func label() -> String:
	var k := BaseRival.waiting(h)
	if not k.is_empty():
		return "Accept %s's rematch with %s" % [k["rec"]["name"], k["life_ask"]["foe"]["rec"]["name"]]
	return "Read the Games board"

func use() -> void:
	var k := BaseRival.waiting(h)
	if not k.is_empty():
		BaseRival.accept(h, k)
		return
	if is_instance_valid(panel):
		return
	pick = 0
	panel = BaseRace.result_card(h, [])
	_fill()

func close() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = null

func _fill() -> void:
	var v: VBoxContainer = panel.get_child(0)
	for c in v.get_children():
		c.queue_free()
	v.add_child(UI.label("Games", 18, UI.ACCENT_HI))
	var list := games()
	for i in list.size():
		var on := i == pick
		var line := "%s%s: %s" % ["> " if on else "  ", list[i][1], MinigameHub.summary(list[i][0])]
		v.add_child(UI.label(line, 14, UI.INK if on else UI.MUTED))
	var keys := ["up", "down", "interact", "menu"].map(func(a): return Settings.key_cap(a))
	v.add_child(UI.label("%s / %s pick   %s start   %s close" % keys, 12, UI.MUTED))

## A press while the list is open: true when it took the key.
func input(event: InputEvent) -> bool:
	if not is_instance_valid(panel):
		return false
	if event.is_action_pressed("menu"):
		close()
	elif event.is_action_pressed("up") or event.is_action_pressed("down"):
		pick = posmod(pick + (-1 if event.is_action_pressed("up") else 1), games().size())
		_fill()
	elif event.is_action_pressed("interact"):
		start(pick)
	else:
		return false
	return true

## Starts the game with this id (a rematch's).
func start_game(id: String) -> void:
	start(games().find_custom(func(g): return g[0] == id))

## Starts the game at index i of the list through its own prop code.
func start(i: int) -> void:
	close()
	if games().any(func(g): return g[2].running()):
		h._toast("A game is already on")
	else:
		games()[i][2].use()

func tick(_d: float) -> void:
	if not h.hrace.pair_force.is_empty() and not games().any(func(g): return g[2].running()):
		h.hrace.pair_force = []      # the rematch's pair is spent once its game is over
	if not is_instance_valid(panel):
		return
	var me := Vector2(h.ppos.x, h.ppos.z)
	if me.distance_to(Vector2(board.position.x, board.position.z)) > CLOSE_AT:
		close()
