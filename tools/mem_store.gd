extends RefCounted
## For checks: the shared store (tools/shell.html's local mode) in memory, so two players in one
## process can talk through Social (Social.fake_store = store.reply). Docs are "col/id" -> JSON text;
## queries support "==" only and ignore the order, which is all the callers here use.

var docs := {}
var _n := 0


func reply(method: String, args: Array) -> String:
	var path := String(args[0])
	match method:
		"dbGet":
			return docs.get(path, "null")
		"dbClaim":
			return docs.get(path, "0")
		"dbSet":
			docs[path] = String(args[1])
			return "ok"
		"dbDel":
			docs.erase(path)
			return "ok"
		"dbAdd":
			_n += 1
			docs["%s/m%d" % [path, _n]] = String(args[1])
			return "m%d" % _n
		"dbQuery":
			return JSON.stringify(_query(path, JSON.parse_string(args[1])))
	return ""


func _query(col: String, q: Dictionary) -> Array:
	var rows: Array = []
	for p in docs:
		var id := String(p).trim_prefix(col + "/")
		if not String(p).begins_with(col + "/") or id.contains("/"):
			continue
		var d: Dictionary = JSON.parse_string(docs[p])
		if (q["where"] as Array).all(func(w): return w[1] == "==" and d.get(w[0]) == w[2]):
			rows.append({"id": id, "data": d})
	return rows.slice(0, int(q["limit"]))
