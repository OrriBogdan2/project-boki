class_name ArrivalQueue
extends RefCounted
## The farm's arrival modals (Welcome home, a Boki changing, while you were away, strays, notices), one at a
## time in the order they were added. A modal opens only when nothing else is open or playing, and the
## next one comes when it closes (home.gd's _close_panel calls pump), so they never stack.

const RETRY_S := 0.5      # seconds between looks while something else is playing (an evolution, a talk)

var h
var jobs: Array[Callable] = []
var waiting := false

func _init(home) -> void:
	h = home

## Queues a modal: open is called when it is its turn, with nothing else open.
func add(open: Callable) -> void:
	jobs.append(open)
	pump()

func pump() -> void:
	while not jobs.is_empty() and is_instance_valid(h) and h.is_inside_tree() and h.panel_open == "":
		if h.building_now:
			_retry_soon()
			return
		jobs.pop_front().call()

func _retry_soon() -> void:
	if waiting:
		return
	waiting = true
	h.get_tree().create_timer(RETRY_S).timeout.connect(func():
		waiting = false
		pump())
