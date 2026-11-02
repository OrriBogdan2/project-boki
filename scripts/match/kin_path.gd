class_name KinPath
extends RefCounted
## A* on the tile grid for a Boki that follows or chases (docs/decisions/0002; the checklist's "pathfinding
## and steering"). The same walkable rule as the bots' grid walk (a ground tile, no more than STEP of
## height to the next), but A* with an 8-way move and no corner cutting, searched only in a window round
## the trip and capped, so a long detour costs a bounded amount. KinFollow asks for a path on a timer
## (rules follow.path_every_s), never every step.

const STEP := 1.7          # m: the most height one move may climb or drop (as in Bot._grid_path)
const MAX_NODES := 900     # nodes expanded per search: the cost cap
const DIAG := 1.41421356

## Is the straight walk a to b (tile-space metres, x/z) free of blocks and the abyss?
static func clear_line(W: World, a: Vector2, b: Vector2, width := 0.3) -> bool:
	var d := b - a
	var n := int(d.length() / 0.4) + 1
	var side := Vector2(-d.y, d.x).normalized() * width
	for i in range(1, n + 1):
		var p := a + d * (float(i) / n)
		if W.is_block(p.x, p.y) or W.is_block(p.x + side.x, p.y + side.y) or W.is_block(p.x - side.x, p.y - side.y) or W.is_void(p.x, p.y):
			return false
	return true

static func _walkable(W: World, x: int, z: int) -> bool:
	return W.inb(x, z) and W.kind[W.idx(x, z)] == World.T_GROUND

## The tile centres from a to b (excluding a's own tile), or [] when there is no way on foot inside
## the window. `pad` widens the search window round the two points.
static func find(W: World, a: Vector3, b: Vector3, pad := 12) -> Array:
	var s := Vector2i(int(floor(a.x)), int(floor(a.z)))
	var g := Vector2i(int(floor(b.x)), int(floor(b.z)))
	if s == g:
		return []
	if not _walkable(W, g.x, g.y):
		return []
	var lo := Vector2i(mini(s.x, g.x) - pad, mini(s.y, g.y) - pad)
	var hi := Vector2i(maxi(s.x, g.x) + pad, maxi(s.y, g.y) + pad)
	var cost := {s: 0.0}
	var prev := {s: s}
	var open: Array = [[_h(s, g), s]]          # a binary min-heap on the first element
	var closed := {}
	var n := 0
	var found := false
	while not open.is_empty() and n < MAX_NODES:
		var cur: Vector2i = _pop(open)
		if closed.has(cur):
			continue
		closed[cur] = true
		n += 1
		if cur == g:
			found = true
			break
		var cg := W.ground_at(cur.x + 0.5, cur.y + 0.5)
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nx := Vector2i(cur.x + dx, cur.y + dz)
				if closed.has(nx) or nx.x < lo.x or nx.y < lo.y or nx.x > hi.x or nx.y > hi.y or not _walkable(W, nx.x, nx.y):
					continue
				if dx != 0 and dz != 0 and (not _walkable(W, cur.x + dx, cur.y) or not _walkable(W, cur.x, cur.y + dz)):
					continue         # no cutting a corner
				if absf(W.ground_at(nx.x + 0.5, nx.y + 0.5) - cg) > STEP:
					continue
				var c := float(cost[cur]) + (DIAG if dx != 0 and dz != 0 else 1.0)
				if not cost.has(nx) or c < float(cost[nx]):
					cost[nx] = c
					prev[nx] = cur
					_push(open, [c + _h(nx, g), nx])
	if not found:
		return []
	var out: Array = []
	var t := g
	while t != s:
		out.push_front(Vector2(t.x + 0.5, t.y + 0.5))
		t = prev[t]
	return out

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if float(heap[up][0]) <= float(heap[i][0]):
			break
		var t = heap[up]; heap[up] = heap[i]; heap[i] = t
		i = up

static func _pop(heap: Array) -> Vector2i:
	var top: Vector2i = heap[0][1]
	var last = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and float(heap[l][0]) < float(heap[m][0]): m = l
			if r < n and float(heap[r][0]) < float(heap[m][0]): m = r
			if m == i:
				break
			var t = heap[m]; heap[m] = heap[i]; heap[i] = t
			i = m
	return top

static func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return float(dx + dz) + (DIAG - 2.0) * float(mini(dx, dz))     # octile distance
