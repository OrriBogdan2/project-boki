"""POST /feedback: the in-game "Rate this build" card. Validates one small JSON object and appends it as a JSONL line."""
import json
import os
import threading
import time

MAX_FEEDBACK = 2048   # bytes of request body
MAX_STEPS = 40        # steps per tutorial track in the funnel
ENDS = ("", "done", "skip")
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
    scores = body.get("scores")
    if not isinstance(scores, dict) or set(scores) != set(SCORE_KEYS):
        return "scores"
    for v in scores.values():
        if isinstance(v, bool) or not isinstance(v, int) or not 1 <= v <= 10:
            return "scores"
    note = body.get("note", "")
    if not isinstance(note, str) or len(note) > 300:
        return "note"
    m = body.get("minutes_played")
    if isinstance(m, bool) or not isinstance(m, (int, float)) or not 0 <= m <= 100000:
        return "minutes_played"
    return _funnel_problem(body.get("funnel", {}))


def _funnel_problem(fun) -> str:
    """{track: {step id: [entered s, finished s or -1, idle s, hints, end]}}: small numbers, no free text."""
    if not isinstance(fun, dict) or len(fun) > 4:
        return "funnel"
    for steps in fun.values():
        if not isinstance(steps, dict) or len(steps) > MAX_STEPS:
            return "funnel"
        for sid, r in steps.items():
            if not isinstance(sid, str) or not 0 < len(sid) <= 24 or not isinstance(r, list) or len(r) != 5:
                return "funnel"
            # (the game re-reads its queue from JSON, so whole numbers can arrive as 4.0)
            if any(isinstance(n, bool) or not isinstance(n, (int, float)) or n != int(n) or not -1 <= n <= 10_000_000
                   for n in r[:4]):
                return "funnel"
            if r[4] not in ENDS:
                return "funnel"
    return ""


def store(path: str, body: dict) -> None:
    """Append the validated payload plus a server timestamp as one JSON line."""
    rec = {"received": int(time.time()), "version": body["version"], "player": body["player"],
           "scores": body["scores"], "note": body.get("note", ""), "minutes_played": body["minutes_played"]}
    if body.get("funnel"):
        rec["funnel"] = {t: {sid: [int(n) for n in r[:4]] + [r[4]] for sid, r in steps.items()}
                         for t, steps in body["funnel"].items()}
    with _lock:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, separators=(",", ":")) + "\n")
