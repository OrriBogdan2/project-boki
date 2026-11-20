class_name ClanInfo
extends RefCounted
## What a clan shows of itself and its members: the short tag before a member's name (match nameplates,
## island visits) and the last thing each member did (extracted, raised, bred), read from the event log
## into their profile snapshot. Everything read back from the store is cleaned here. Rules:
## content/rules/clan_tag.json.

const DEEDS := ["extracted", "raised", "bred"]
const MIN_S := 60            # seconds in a minute, hour and day, for "3 h ago"
const HOUR_S := 3600
const DAY_S := 86400

static func rules() -> Dictionary:
	return Content.rules("clan_tag")

## A tag someone typed or stored: upper-case letters only, of the allowed length, not blocked; else "".
static func clean_tag(v) -> String:
	var t := Social.txt_of(v, "", 16).to_upper()
	var r := rules()
	if t.length() < int(r["min"]) or t.length() > int(r["max"]):
		return ""
	for ch in t:
		if ch < "A" or ch > "Z":
			return ""
	return "" if r["blocked"].has(t) else t

## The tag a clan without one gets: the first letters of its name's words (or its first letters), if allowed.
static func tag_from_name(clan_name: String) -> String:
	var letters := ""
	for w in clan_name.to_upper().split(" ", false):
		if w[0] >= "A" and w[0] <= "Z": letters += w[0]
	if letters.length() < int(rules()["min"]):
		letters = ""
		for ch in clan_name.to_upper():
			if ch >= "A" and ch <= "Z": letters += ch
	return clean_tag(letters.substr(0, int(rules()["max"])))

## My clan's tag, from the save ("" when in no clan).
static func my_tag() -> String:
	return clean_tag(Social.dict_of(Save.d.get("clan")).get("tag"))

## A name with its clan tag in front ("[WREN] Ivy"), or the name alone.
static func tagged(who: String, tag: String) -> String:
	return who if tag == "" else "[%s] %s" % [tag, who]

## The newest extraction, raise (a Boki taking a new form) or breed (an egg of two parents hatching) in an
## event log, as {did, t, sp}; {} if none.
static func last_deed(events: Array) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		var e := Social.dict_of(events[i])
		var ev := Social.txt_of(e.get("ev"))
		var did := ""
		if ev == "extracted": did = "extracted"
		elif ev == "evolved" and Social.txt_of(e.get("kind")) == "form": did = "raised"
		elif ev == "hatched" and e.get("bred", false) == true: did = "bred"
		if did != "":
			return {"did": did, "t": Social.int_of(e.get("t")), "sp": Social.txt_of(e.get("sp"), "", 24)}
	return {}

## A deed from someone else's snapshot: a known kind, a time not in the future, a known species or none.
static func clean_deed(v, now_s: int) -> Dictionary:
	var d := Social.dict_of(v)
	var did := Social.txt_of(d.get("did"))
	if not DEEDS.has(did):
		return {}
	var sp := Social.txt_of(d.get("sp"), "", 24)
	return {"did": did, "t": clampi(Social.int_of(d.get("t")), 0, now_s), "sp": sp if Data.KIN.has(sp) else ""}

## "bred a Cindle, 3 h ago" for the member roll; "" for no deed.
static func deed_text(deed: Dictionary, now_s: int) -> String:
	if deed.is_empty():
		return ""
	var kin := String(Data.KIN[deed["sp"]]["name"]) if deed["sp"] != "" else "Boki"
	var what: String = {"extracted": "made it out of a match", "raised": "raised a %s" % kin,
		"bred": "bred a %s" % kin}[deed["did"]]
	return "%s, %s" % [what, ago(now_s - int(deed["t"]))]

static func ago(secs: int) -> String:
	if secs < MIN_S: return "just now"
	if secs < HOUR_S: return "%d min ago" % (secs / MIN_S)
	if secs < DAY_S: return "%d h ago" % (secs / HOUR_S)
	return "%d d ago" % (secs / DAY_S)
