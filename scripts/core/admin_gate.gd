class_name AdminGate
extends RefCounted
## Who may use the admin tools (` panel, Test Zone, Mod mode, the --god flag): a debug build (the editor and dev
## runs), the web artifact's owner (Social.is_owner), or a desktop with the owner's dev key. The key is a file at
## KEY_PATH holding a secret whose SHA-256 is KEY_SHA256; only the hash lives in the code. A release download
## without the key gets no admin at all.

const KEY_PATH := "user://dev.key"
const KEY_SHA256 := "e0e482ff5b3b1f219272ef10bc07f12ba08dab09340c6a53966a8b4669520f54"

static var _key_read := false
static var _key := ""


static func unlocked() -> bool:
	return allows(OS.is_debug_build(), Social.is_owner, _dev_key())


## The rule on its own, so the check can play a release build with and without the key.
static func allows(debug_build: bool, web_owner: bool, key: String, want_sha := KEY_SHA256) -> bool:
	return debug_build or web_owner or key_matches(key, want_sha)


static func key_matches(key: String, want_sha := KEY_SHA256) -> bool:
	return key.strip_edges() != "" and key.strip_edges().sha256_text() == want_sha


## Read once: the owner drops the file in and starts the game.
static func _dev_key() -> String:
	if not _key_read:
		_key_read = true
		if FileAccess.file_exists(KEY_PATH):
			_key = FileAccess.get_file_as_string(KEY_PATH)
	return _key
