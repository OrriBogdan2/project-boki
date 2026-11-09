class_name MatchmakerClient
extends Node
## The matchmaker over plain HTTP (server/matchmaker, SERVERS_CONTRACT.md): which region answers
## fastest, queue for a mode, poll the ticket, leave. Every call returns a Dictionary with "code"
## (the HTTP status, 0 when the server couldn't be reached) and "json" (the parsed body, or null).

const TIMEOUT_S := 6.0          # s per request; a region slower than this isn't worth queueing at
const CODE_UNREACHABLE := 0

## One request. `body` (a Dictionary) goes out as JSON.
func request(url: String, method := HTTPClient.METHOD_GET, body = null) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_S
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json", "User-Agent: ProjectBoki/%s" % Net.VERSION])
	var t0 := Time.get_ticks_msec()
	var err := req.request(url, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		req.queue_free()
		return {"code": CODE_UNREACHABLE, "json": null, "ms": 0}
	var res = await req.request_completed
	req.queue_free()
	var out := {"code": int(res[1]), "json": null, "ms": Time.get_ticks_msec() - t0}
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		out["code"] = CODE_UNREACHABLE
		return out
	var txt := (res[3] as PackedByteArray).get_string_from_utf8()
	out["json"] = JSON.parse_string(txt) if txt != "" else null
	return out

## GET /health on every region at once; the one that answered fastest (ms in "ms"), or empty.
## `want` picks a region by id instead (the Settings override), if it answers at all.
func best_region(regions: Array, want := "auto") -> Dictionary:
	var pings: Array = []
	for r in regions:
		Callable(self, "_health").call(r, pings)      # side by side: through a Callable it returns at its first await
	while pings.size() < regions.size():
		await get_tree().process_frame
	var best := {}
	for h in pings:
		if h.is_empty():
			continue
		if String(h.get("id", "")) == want:
			return h
		if best.is_empty() or int(h["ms"]) < int(best["ms"]):
			best = h
	return best

## One region's /health, appended to `pings` when it answers (or doesn't).
func _health(r: Dictionary, pings: Array) -> void:
	var res := await request(String(r.get("url", "")).path_join("health"))
	if res["code"] != 200 or typeof(res["json"]) != TYPE_DICTIONARY:
		pings.append({})
		return
	pings.append({"id": String(r.get("id", "")), "url": String(r.get("url", "")), "ms": int(res["ms"]),
		"version": String(res["json"].get("version", ""))})

## POST /queue -> {"ticket": id} | {"error": "version", "server_version": v} | unreachable.
func queue(base: String, mode: String, player_name: String) -> Dictionary:
	var body := {"mode": mode, "name": player_name, "version": Net.VERSION}
	return await request(base.path_join("queue"), HTTPClient.METHOD_POST, body)

## GET /queue/<ticket> -> waiting (position, eta_s) | ready (host, port, token) | gone.
func poll(base: String, ticket: String) -> Dictionary:
	return await request(base.path_join("queue").path_join(ticket))

## DELETE /queue/<ticket>: out of the queue.
func leave(base: String, ticket: String) -> void:
	await request(base.path_join("queue").path_join(ticket), HTTPClient.METHOD_DELETE)
