"""The shared store behind the game's Social (clans, island visits, gifts, market stalls, notice board,
Boki transfers) and the town's live presence. Documents are JSON under "col/id" paths in sqlite.

Players get a server-made id and a secret token from hello(); every other call names the caller by that token.
The store keeps nobody's word on who they are: a document keyed to a player (`<me>` or `<anything>_<me>`)
only that player may write or delete; any other document that names people (to, from, by, seller) only they or
the player holding its claim may overwrite or delete; and an added document's sender fields must name the caller. What a document says is still untrusted: the game cleans every read (Social.clean_*)."""

import hashlib
import json
import re
import secrets
import sqlite3
import threading
import time

COL_RE = re.compile(r"^[a-z_]{1,24}$")
ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,96}$")
PLAYER_RE = re.compile(r"^p[0-9a-f]{12}$")  # the ids hello() makes
SENDER_FIELDS = ("from", "by", "seller")  # an added document's author fields: must be the caller
NAMED_FIELDS = ("to",) + SENDER_FIELDS  # who a document is between
MAX_DOC = 64 * 1024  # bytes of JSON in one document (an island snapshot is the largest, ~10 KB)
MAX_LIMIT = 200  # rows one query returns
CLAIM_S = 8.0  # seconds a claim holds a document for its claimer (one buyer per listing)
HUB_TTL_S = 4.0  # seconds a town walker stays listed after their last presence
HUB_ROOM_CAP = 30  # walkers one room shows
CALLS_PER_MIN = 1200  # one player's requests per minute (presence at 5 Hz is 300)
HELLOS_PER_HOUR = 20  # new players one address may make per hour


class SocialStore:
    def __init__(self, db_path: str, owners: tuple = (), clock=time.time):
        self._db = sqlite3.connect(db_path, check_same_thread=False)
        self._db.executescript(
            "CREATE TABLE IF NOT EXISTS players (token TEXT PRIMARY KEY, id TEXT UNIQUE, created REAL);"
            "CREATE TABLE IF NOT EXISTS docs (col TEXT, id TEXT, data TEXT, t REAL, PRIMARY KEY (col, id));"
        )
        self._lock = threading.Lock()
        self._owners = set(owners)
        self._clock = clock
        self._claims = {}  # path -> (player, until)
        self._hub = {}  # room -> {player: (presence, seen)}
        self._calls = {}  # player -> (minute, count)
        self._hellos = {}  # client address -> (hour, count)

    # ------------------------------------------------------------------ players
    def hello(self, token: str, client: str) -> dict:
        """The caller's id, making a new player when the token is empty. {me, owner, token?} or {error}."""
        with self._lock:
            if token:
                me = self._player(token)
                return {"me": me, "owner": me in self._owners} if me else {"error": "not_member"}
            if not self._count(self._hellos, client, 3600, HELLOS_PER_HOUR):
                return {"error": "rate_limited"}
            token, me = secrets.token_urlsafe(24), "p" + secrets.token_hex(6)
            self._db.execute("INSERT INTO players VALUES (?, ?, ?)", (_hash(token), me, self._clock()))
            self._db.commit()
            return {"me": me, "owner": False, "token": token}

    def player(self, token: str) -> str:
        """The id behind a token ("" when unknown or over its call budget)."""
        with self._lock:
            me = self._player(token) if token else ""
            return me if me and self._count(self._calls, me, 60, CALLS_PER_MIN) else ""

    def _player(self, token: str) -> str:
        row = self._db.execute("SELECT id FROM players WHERE token = ?", (_hash(token),)).fetchone()
        return row[0] if row else ""

    def _count(self, table: dict, key: str, span_s: int, cap: int) -> bool:
        """One more event for key in the current span; False once it is over cap."""
        window = int(self._clock() // span_s)
        was, n = table.get(key, (window, 0))
        n = n + 1 if was == window else 1
        table[key] = (window, n)
        return n <= cap

    # ------------------------------------------------------------------ documents
    def op(self, me: str, body: dict) -> dict:
        """One store call: {"op": get|set|del|add|query|claim, "path", "data"?, "q"?}. Answers {"r": ...}."""
        kind, path = body.get("op"), body.get("path")
        if not isinstance(path, str):
            return {"error": "bad_request"}
        parts = path.split("/")
        if kind in ("add", "query"):
            ok_path = len(parts) == 1 and COL_RE.match(parts[0])
        else:
            ok_path = len(parts) == 2 and COL_RE.match(parts[0]) and ID_RE.match(parts[1])
        if not ok_path:
            return {"error": "bad_request"}
        with self._lock:
            if kind == "get":
                return {"r": self._get(parts)}
            if kind == "claim":
                return {"r": self._claim(me, path, parts)}
            if kind == "query":
                return self._query(parts[0], body.get("q"))
            if kind in ("set", "del") and not self._may_write(me, path, parts):
                return {"error": "not_yours"}
            if kind == "del":
                self._db.execute("DELETE FROM docs WHERE col = ? AND id = ?", parts)
                self._db.commit()
                self._claims.pop(path, None)
                return {"r": "ok"}
            return self._write(me, kind, parts, body.get("data"))

    def _may_write(self, me: str, path: str, parts: list) -> bool:
        owner = parts[1].rsplit("_", 1)[-1]
        if PLAYER_RE.match(owner):
            return owner == me
        doc = self._get(parts)
        named = [doc[f] for f in NAMED_FIELDS if isinstance(doc, dict) and f in doc]
        holder, until = self._claims.get(path, ("", 0.0))
        return not named or me in named or (holder == me and until > self._clock())

    def _get(self, parts: list):
        row = self._db.execute("SELECT data FROM docs WHERE col = ? AND id = ?", parts).fetchone()
        return json.loads(row[0]) if row else None

    def _claim(self, me: str, path: str, parts: list):
        holder, until = self._claims.get(path, ("", 0.0))
        now = self._clock()
        if holder and holder != me and until > now:
            return None
        doc = self._get(parts)
        if doc is not None:
            self._claims[path] = (me, now + CLAIM_S)
        return doc

    def _write(self, me: str, kind: str, parts: list, data) -> dict:
        text = json.dumps(data, separators=(",", ":")) if isinstance(data, dict) else ""
        if kind not in ("set", "add") or not text or len(text) > MAX_DOC:
            return {"error": "bad_request"}
        if kind == "add":
            if any(f in data and data[f] != me for f in SENDER_FIELDS):
                return {"error": "not_yours"}
            parts = [parts[0], secrets.token_hex(8)]
        self._db.execute("INSERT OR REPLACE INTO docs VALUES (?, ?, ?, ?)", (*parts, text, self._clock()))
        self._db.commit()
        return {"r": parts[1] if kind == "add" else "ok"}

    def _query(self, col: str, q) -> dict:
        """where: [[field, "==", value], ...] (the only operator the game asks for); order, dir, limit."""
        q = q if isinstance(q, dict) else {}
        where = q.get("where") or []
        if not isinstance(where, list) or not all(isinstance(w, list) and len(w) == 3 and w[1] == "==" for w in where):
            return {"error": "bad_request"}
        rows = []
        for doc_id, text in self._db.execute("SELECT id, data FROM docs WHERE col = ?", (col,)):
            data = json.loads(text)
            if all(data.get(w[0]) == w[2] for w in where):
                rows.append({"id": doc_id, "data": data})
        order = q.get("order")
        if isinstance(order, str) and order:
            rows.sort(key=lambda r: _sort_key(r["data"].get(order)), reverse=q.get("dir") == "desc")
        limit = q.get("limit")
        limit = min(limit, MAX_LIMIT) if isinstance(limit, int) and limit > 0 else 50
        return {"r": rows[:limit]}

    # ------------------------------------------------------------------ the town
    def hub(self, me: str, room, presence) -> dict:
        """Lists me in room with presence (a small dict) and answers the others seen in the last HUB_TTL_S."""
        if not isinstance(room, str) or not ID_RE.match(room):
            return {"error": "bad_request"}
        with self._lock:
            now = self._clock()
            walkers = self._hub.setdefault(room, {})
            if isinstance(presence, dict) and len(json.dumps(presence)) <= 512:
                walkers[me] = (presence, now)
            elif presence is None:
                walkers.pop(me, None)
            for who in [w for w, (_p, seen) in walkers.items() if now - seen > HUB_TTL_S]:
                del walkers[who]
            if not walkers:
                del self._hub[room]
            peers = [{"id": w, "p": p} for w, (p, _seen) in walkers.items() if w != me]
            return {"r": peers[:HUB_ROOM_CAP]}


def _sort_key(v):
    return (0, v) if isinstance(v, (int, float)) and not isinstance(v, bool) else (1, str(v))


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
