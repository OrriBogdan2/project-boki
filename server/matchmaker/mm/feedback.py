"""POST /feedback: the in-game "Rate this build" card and F8 quick notes. Validates one small JSON object and appends it as a JSONL line."""
import json
import os
import threading
import time

MAX_FEEDBACK = 8192   # bytes of request body (a quick note carries a small screenshot)
MAX_SHOT = 6000       # characters of base64 JPEG in a quick note
MAX_CTX = 12          # fields in a quick note's context
SCORE_KEYS = ("combat", "boki", "onboarding", "look")
_lock = threading.Lock()


def validate(body) -> str:
    """"" when `body` is a well-formed feedback payload, else a short reason."""
    if not isinstance(body, dict):
        return "not_object"
    if not isinstance(body.get("version"), str) or not 0 < len(body["version"]) <= 64:
        return "version"
    if not isinstance(body.get("player"), str) or not 0 < len(body["player"]) <= 64:
        return "player"
    note = body.get("note", "")
    if not isinstance(note, str) or len(note) > 300:
        return "note"
    if body.get("kind") == "note":
        return _validate_quick_note(body)
    scores = body.get("scores")
    if not isinstance(scores, dict) or set(scores) != set(SCORE_KEYS):
        return "scores"
    for v in scores.values():
        if isinstance(v, bool) or not isinstance(v, int) or not 1 <= v <= 10:
            return "scores"
    m = body.get("minutes_played")
    if isinstance(m, bool) or not isinstance(m, (int, float)) or not 0 <= m <= 100000:
        return "minutes_played"
    return ""


def _validate_quick_note(body: dict) -> str:
    """A quick note has text, a small context object and an optional screenshot, but no scores."""
    if not body["note"].strip():
        return "note"
    ctx = body.get("ctx")
    if not isinstance(ctx, dict) or len(ctx) > MAX_CTX:
        return "ctx"
    shot = body.get("shot", "")
    if not isinstance(shot, str) or len(shot) > MAX_SHOT:
        return "shot"
    return ""


def store(path: str, body: dict) -> None:
    """Append the validated payload plus a server timestamp as one JSON line."""
    rec = {"received": int(time.time()), "version": body["version"], "player": body["player"],
           "note": body.get("note", "")}
    if body.get("kind") == "note":
        rec.update(kind="note", ctx=body["ctx"], shot=body.get("shot", ""))
    else:
        rec.update(scores=body["scores"], minutes_played=body["minutes_played"])
    with _lock:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, separators=(",", ":")) + "\n")
