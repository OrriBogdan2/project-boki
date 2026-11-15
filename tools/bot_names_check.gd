extends RefCounted
## --bot-names-check: bots wear gamer tags, never a hunter's name or title. The pool has no hunter name
## or title, and a 10-trio match deals every hunter a different tag that the nameplate and feed show as is.

const MIN_POOL := 150
const MAX_LEN := 14   # a nameplate's width

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOTNAMES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The first hunter name or title found inside `text` (case-insensitive), "" when none.
func hunter_word_in(text: String) -> String:
	for id in Arch.ids():
		for word in [HeroTitle.base_name(id), HeroTitle.title(id)]:
			if text.to_lower().contains(String(word).to_lower()):
				return String(word)
	return ""

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var seen := {}
	var dup := 0
	var long_tag := ""
	var worded := ""
	for tag in Names.BOT:
		dup += 1 if seen.has(String(tag).to_lower()) else 0
		seen[String(tag).to_lower()] = true
		if String(tag).length() > MAX_LEN: long_tag = tag
		if hunter_word_in(tag) != "": worded = tag
	ok(Names.BOT.size() >= MIN_POOL, "%d tags in the pool" % Names.BOT.size())
	ok(dup == 0 and long_tag == "", "tags are unique and fit a nameplate (%s)" % long_tag)
	ok(worded == "", "no tag holds a hunter name or title (%s)" % worded)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	var tags := {}
	var texts: Array = []
	for h in m.hunters:
		tags[h.pname] = true
		texts.append(h.pname)
	ok(m.hunters.size() == 30 and tags.size() == 30, "10 trios: %d hunters, %d names" % [m.hunters.size(), tags.size()])
	var bot: Hunter = m.hunters.filter(func(x): return x.ctrl == "bot")[0]
	var other: Hunter = m.hunters.filter(func(x): return x.ctrl == "bot" and x != bot)[0]
	m.add_feed("%s knocked %s" % [bot.pname, other.pname])
	texts.append_array(m.feed.map(func(f): return String(f["text"])))
	var found := ""
	for t in texts:
		found = found if found != "" else hunter_word_in(String(t))
	ok(found == "", "no plate or feed text holds a hunter name or title (%s)" % found)
	print("BOTNAMES CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
