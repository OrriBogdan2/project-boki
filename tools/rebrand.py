#!/usr/bin/env python3
"""Rebrand the player-facing text: "Kinfall" -> "Project Boki", and the creatures "kin" -> "Boki".

Run it from anywhere; it works on the repo it lives in (or --root DIR):

    python3 tools/rebrand.py --dry      # list every replacement as file:line, change nothing
    python3 tools/rebrand.py            # apply, then print a summary

It is idempotent: a second run changes nothing, and running it on a branch with new strings
rebrands those too. It is meant to be re-run on an integration branch right before shipping,
so the hundreds of strings don't have to be hand-edited (and conflict) on every branch.

What it touches (player-facing text only):
  * GDScript string literals that are shown to players (labels, toasts, tooltips, feed lines,
    tips, dialogue, data "name"/"desc" values...). Comments are never touched.
  * Text properties in .tscn files (text, tooltip_text, placeholder_text, title).
  * Display fields in content/**/*.json (see JSON_TEXT_KEYS); JSON keys and ids never.
  * project.godot: config/name and config/description. The save folder is pinned to the old
    one (use_custom_user_dir + custom_user_dir_name) so user:// and players' saves don't move.
  * export_presets.cfg: exported file names (ProjectBoki.exe / .zip) and product names.
  * README.md prose (not code); headings that name the game in docs/*.md, CONTENT.md,
    CONTRIBUTING.md; the visible text of the web shell (tools/shell.html); the heading the
    abilities doc generator writes; the boot splash logo (art/splash.png) is redrawn once.

What it never touches: identifiers, file paths, node names, class names, dictionary keys,
save keys, content ids, resource paths, JSON keys, test hooks / CLI flags, strings compared in
code ("kin" as a state key, a tab id like "Kin" that a `match` checks), print/assert/test
messages, and the dev-facing content-grammar validator (scripts/kin/).

How a GDScript literal is classified:
  1. Only literals containing one of the words (Kinfall, Kindex, kin, kins) are looked at.
  2. Identifier-like literals (no spaces and lowercase, or containing _ / . = :, or starting
     with "-") are keys: "kin", "kin_hp", "--work-board=Kin", "res://...".
  3. Literals inside print()/push_error()/assert()/ok()/... are debug or test text: skipped.
  4. Literals in a key position are keys: a dict key or match pattern ("Kin":), compared with
     == / != / in, a subscript ["..."], the first argument of get()/has()/erase()/..., a
     StringName (&"") or NodePath (^""), a node name (x.name = "..."), or a tab-id list given
     to UiWidgets.tabs()/UiShell.shell_tabs().
  5. A display literal whose exact text also appears in a key position anywhere in the game's
     scripts is FROZEN: it's an id that doubles as a label (tab names, panel titles that code
     compares). Frozen texts are left as they are in code, so every comparison still matches,
     and are rebranded on screen instead through a generated translation file
     (res://translations/rebrand.en.po): Godot auto-translates Control/Label3D text whose whole
     text matches.
  6. Everything else is display text and is rewritten.
Test scripts (tools/*.gd, tests/) get the same treatment (so expected strings follow the game)
but never freeze anything themselves.

Word rules (case-preserving): Kinfall -> Project Boki, KINFALL -> PROJECT BOKI;
Kindex -> Bokidex; kin / Kin / kins -> Boki, KIN -> BOKI ("kin's" -> "Boki's", "a kin" ->
"a Boki"). Words that merely contain the letters (kind, kinda, kindle, kindling, kinetic, skin,
akin, napkin, pumpkin, Kingpin, kinship, Glimmerkin...) are never matched.
"""
import argparse
import os
import re
import sys
from fnmatch import fnmatch

NEW_NAME = "Project Boki"
NEW_NAME_FILE = "ProjectBoki"   # exported file names (no space)
OLD_NAME = "Kinfall"            # also the save folder name that must not move
PO_PATH = "translations/rebrand.en.po"

# ---------------------------------------------------------------- word rules

# A word may not be glued to identifier/path characters on either side. `\n` / `\t` escapes
# right before the word count as a boundary (they are text, not letters).
_PRE = r"(?:(?<=\\n)|(?<=\\t)|(?<![A-Za-z0-9_/\\.\-@#$&{=%]))"
_POST = r"(?![A-Za-z0-9_/\\=}])(?!\.[A-Za-z0-9_])(?!-[a-z0-9_])"
WORD_RE = re.compile(_PRE + r"(Kinfall|KINFALL|kinfall|Kindex|KINDEX|kindex|Kins|KINS|kins|Kin|KIN|kin)" + _POST)
WORD_MAP = {
    "Kinfall": NEW_NAME, "KINFALL": NEW_NAME.upper(), "kinfall": NEW_NAME,
    "Kindex": "Bokidex", "KINDEX": "BOKIDEX", "kindex": "Bokidex",
    "Kins": "Boki", "KINS": "BOKI", "kins": "Boki",
    "Kin": "Boki", "KIN": "BOKI", "kin": "Boki",
}
GAME_ONLY_RE = re.compile(_PRE + r"(Kinfall|KINFALL)" + _POST)


def has_word(s: str) -> bool:
    return WORD_RE.search(s) is not None


def rewrite_words(s: str) -> str:
    return WORD_RE.sub(lambda m: WORD_MAP[m.group(1)], s)


def rewrite_game_name(s: str) -> str:
    return GAME_ONLY_RE.sub(lambda m: WORD_MAP[m.group(1)], s)


# ---------------------------------------------------------------- configuration

# GDScript files whose strings are player-facing (or tests that mirror them).
GD_GAME_GLOBS = ["scripts/**/*.gd", "scenes/**/*.gd"]
GD_TEST_GLOBS = ["tools/*.gd", "tests/**/*.gd"]
TSCN_GLOBS = ["scenes/**/*.tscn", "scripts/**/*.tscn"]
GD_EXCLUDE = [
    "scripts/kin/*.gd",        # the content-grammar validator: error messages and docs for modders
]
# Lines (regex, searched in the source line) whose literals are never rewritten.
LINE_SKIPS = [
    ("scripts/home/kin_brain.gd", r'^\s*\["\w+",\s*\['),   # INTENTS: words matched against what the player types
    ("*", r"\bSYL\.get\("),                               # fallback voice syllables for an unknown species
]
# Calls whose literals are debug / test output, never shown to players.
DEBUG_CALLS = {"print", "prints", "printt", "printerr", "printraw", "print_rich", "print_debug",
               "print_verbose", "push_error", "push_warning", "assert", "ok", "_ac", "trace",
               "ok.call", "breakpoint"}
# Calls whose FIRST argument is a key / id / path.
KEY_ARG0_CALLS = {"get", "has", "erase", "get_meta", "has_meta", "set_meta", "remove_meta",
                  "begins_with", "ends_with", "contains", "containsn", "find", "findn", "rfind",
                  "count", "get_node", "get_node_or_null", "has_node", "find_child", "load",
                  "preload", "is_action_pressed", "is_action_just_pressed", "is_action_released",
                  "is_action_just_released", "is_action", "emit_signal", "connect", "has_signal",
                  "has_method",
                  "get_setting", "has_setting", "set_setting", "add_to_group", "is_in_group",
                  "remove_from_group", "set_shader_parameter", "get_shader_parameter",
                  "set_instance_shader_parameter", "play", "travel", "has_animation",
                  "get_animation", "_load", "ids", "key_cap", "has_building", "file_exists",
                  "dir_exists", "set_name", "get_value", "set_value", "has_section_key",
                  "_has_arg", "_arg", "_section_by_name"}
# Calls all of whose literals are keys.
KEY_ALL_CALLS = {"export_enum", "replace", "replacen", "split", "rsplit", "trim_prefix",
                 "trim_suffix", "match", "matchn"}
# Calls whose list argument is a list of tab ids (the tab names double as labels).
TAB_CALLS = {"tabs", "shell_tabs"}
# Calls that only paint text (drawn, toasted, fed): it's never read back or compared, so a
# literal here is rebranded even when the same text is an id elsewhere. Likewise the fallback
# of x.get("name", "...") is a display name.
PAINT_CALLS = {"_text", "_ctext", "draw_string", "draw_multiline_string", "draw_string_outline",
               "toast", "_toast", "add_feed", "note_log", "_note", "_notice", "_tip",
               "_show_when_free", "bark"}
KEYWORDS = {"if", "elif", "else", "while", "for", "return", "and", "or", "not", "in", "is",
            "match", "var", "const", "func", "await", "yield", "as", "pass", "break", "continue",
            "static", "class", "extends", "signal", "enum", "when", "super", "self"}

# JSON fields whose values are shown to players. Keys starting with "_" are docs.
JSON_GLOBS = ["content/**/*.json"]
JSON_EXCLUDE = ["content/rules/*"]   # tuning files: their "desc" is documentation
JSON_TEXT_KEYS = {"name", "desc", "flavor", "tip", "tips", "play", "blurb", "title", "text",
                  "hint", "label", "sub", "subtitle", "short", "lore", "display_name",
                  "description", "message", "toast", "egg"}

MD_FULL = ["README.md"]                                              # prose rebranded
MD_HEADINGS = ["docs/**/*.md", "CONTENT.md", "CONTRIBUTING.md"]       # only headings naming the game
HTML_FILES = ["tools/shell.html"]
PY_HEADING_FILES = ["tools/gen_abilities_doc.py"]


# ---------------------------------------------------------------- helpers

def glob_files(root, patterns):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root)
        if rel_dir == ".":
            rel_dir = ""
        parts = rel_dir.split(os.sep) if rel_dir else []
        if any(p.startswith(".") for p in parts) or (parts and parts[0] in ("build", "export")):
            dirnames[:] = []
            continue
        for fn in filenames:
            rel = os.path.join(rel_dir, fn).replace(os.sep, "/") if rel_dir else fn
            for pat in patterns:
                if _match(rel, pat):
                    out.append(rel)
                    break
    return sorted(set(out))


def _match(rel, pat):
    if "**/" in pat:
        a, b = pat.split("**/", 1)
        if not rel.startswith(a):
            return False
        rest = rel[len(a):]
        segs = rest.split("/")
        return any(fnmatch("/".join(segs[i:]), b) for i in range(len(segs)))
    return fnmatch(rel, pat) and rel.count("/") == pat.count("/")


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def identifier_like(s: str) -> bool:
    if re.search(r"\s", s):
        return False
    if s.startswith("-"):
        return True
    if re.search(r"[_/.=:]", s):
        return True
    return not re.search(r"[A-Z]", s)


# ---------------------------------------------------------------- GDScript

class Tok:
    __slots__ = ("kind", "val", "start", "end", "prefix", "body_start", "body_end", "ctx")

    def __init__(self, kind, val, start, end):
        self.kind, self.val, self.start, self.end = kind, val, start, end
        self.prefix = ""
        self.body_start = self.body_end = 0
        self.ctx = None


TWO_OPS = {"==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%=", ":=", "->", "**",
           "<<", ">>", "|=", "&=", "^="}


def gd_tokens(src):
    toks = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "#":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in " \t\r\n\\":
            i += 1
            continue
        prefix = ""
        if c in "r&^$" and i + 1 < n and src[i + 1] in "\"'" and not (i > 0 and (src[i - 1].isalnum() or src[i - 1] == "_")):
            prefix = c
            i += 1
            c = src[i]
        if c in "\"'":
            start = i - len(prefix)
            q3 = src[i:i + 3]
            if q3 in ('"""', "'''"):
                q, bs = q3, i + 3
            else:
                q, bs = c, i + 1
            j = bs
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src.startswith(q, j):
                    break
                if len(q) == 1 and src[j] == "\n":
                    break
                j += 1
            t = Tok("str", src[bs:j], start, j + len(q))
            t.prefix, t.body_start, t.body_end = prefix, bs, j
            toks.append(t)
            i = j + len(q)
            continue
        if c.isalpha() or c == "_" or (prefix and False):
            j = i
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            toks.append(Tok("id", src[i:j], i, j))
            i = j
            continue
        if c.isdigit():
            j = i
            while j < n and (src[j].isalnum() or src[j] in "._"):
                j += 1
            toks.append(Tok("num", src[i:j], i, j))
            i = j
            continue
        if src[i:i + 2] in TWO_OPS:
            toks.append(Tok("op", src[i:i + 2], i, i + 2))
            i += 2
            continue
        toks.append(Tok("op", c, i, i + 1))
        i += 1
    return toks


def _callee(toks, k):
    """Dotted name of the call whose '(' is toks[k], or None if it's a grouping paren."""
    j = k - 1
    if j < 0 or toks[j].kind != "id" or toks[j].val in KEYWORDS:
        return None
    parts = [toks[j].val]
    j -= 1
    while j >= 1 and toks[j].val == "." and toks[j - 1].kind == "id":
        parts.append(toks[j - 1].val)
        j -= 2
    return ".".join(reversed(parts))


def _is_for_in(toks, i):
    """toks[i] is `in`: is it the `in` of a for loop (for x in ... / for x: T in ...)?"""
    return (i >= 2 and toks[i - 2].val == "for") or (i >= 4 and toks[i - 4].val == "for" and toks[i - 2].val == ":")


def gd_annotate(toks):
    """Attach a context snapshot to every string token: the enclosing brackets."""
    stack = []
    for k, t in enumerate(toks):
        if t.kind == "str":
            if stack and stack[-1]["kind"] == "call" and stack[-1]["arg"] == 0 and toks[k - 1].val == "(":
                stack[-1]["arg0"] = t.val
            t.ctx = [dict(f) for f in stack]
            continue
        v = t.val
        if v == "(":
            cal = _callee(toks, k)
            stack.append({"b": "(", "kind": "call" if cal else "group", "callee": cal or "", "arg": 0})
        elif v == "[":
            p = toks[k - 1] if k else None
            sub = p is not None and ((p.kind == "id" and p.val not in KEYWORDS) or p.val in (")", "]") or p.kind == "str")
            after_in = bool(p and p.val == "in" and not _is_for_in(toks, k - 1))
            stack.append({"b": "[", "kind": "sub" if sub else "list", "after_in": after_in, "arg": 0})
        elif v == "{":
            stack.append({"b": "{", "kind": "dict", "arg": 0})
        elif v in ")]}":
            if stack:
                stack.pop()
        elif v == "," and stack:
            stack[-1]["arg"] += 1


def _last(callee):
    return callee.rsplit(".", 1)[-1]


def gd_classify(toks, k):
    """'debug', 'key' or 'display' for the string token toks[k]."""
    t = toks[k]
    ctx = t.ctx or []
    if _gd_is_key(toks, k, ctx):
        return "key"     # even inside ok()/assert(): a comparison is a comparison
    for f in ctx:
        if f["kind"] == "call" and (f["callee"] in DEBUG_CALLS or _last(f["callee"]) in DEBUG_CALLS):
            return "debug"
    return "display"


def _gd_is_key(toks, k, ctx):
    t = toks[k]
    if t.prefix in ("&", "^", "$"):
        return True
    prv = toks[k - 1] if k else None
    nxt = toks[k + 1] if k + 1 < len(toks) else None
    nxt2 = toks[k + 2] if k + 2 < len(toks) else None
    if nxt is not None and nxt.val == ":":
        return True
    if (prv is not None and prv.val in ("==", "!=")) or (nxt is not None and nxt.val in ("==", "!=")):
        return True
    if (nxt is not None and nxt.val == "in") or (nxt is not None and nxt.val == "not" and nxt2 is not None and nxt2.val == "in"):
        return True
    if prv is not None and prv.val == "in" and not _is_for_in(toks, k - 1):
        return True
    if prv is not None and prv.val == "=" and k >= 2 and toks[k - 2].val == "name" and k >= 3 and toks[k - 3].val == ".":
        return True   # node.name = "..."
    if ctx:
        top = ctx[-1]
        if top["kind"] == "sub":
            return True
        if top["kind"] == "list" and top.get("after_in"):
            return True
        if top["kind"] == "call":
            last = _last(top["callee"])
            if last in KEY_ALL_CALLS or (last in KEY_ARG0_CALLS and top["arg"] == 0):
                return True
        if top["kind"] == "list" and len(ctx) >= 2 and ctx[-2]["kind"] == "call" and _last(ctx[-2]["callee"]) in TAB_CALLS:
            return True
    return False


def gd_line_skipped(rel, line):
    for pat, rx in LINE_SKIPS:
        if fnmatch(rel, pat) and re.search(rx, line):
            return True
    return False


def gd_paint(t):
    """Is the literal painted text: inside a PAINT_CALLS call, or the default of get("name", ...)?"""
    calls = [f for f in (t.ctx or []) if f["kind"] == "call"]
    if not calls:
        return False
    top = calls[-1]
    if _last(top["callee"]) in PAINT_CALLS:
        return True
    return t.ctx[-1] is top and _last(top["callee"]) == "get" and top.get("arg0") == "name" and top["arg"] == 1


def gd_scan(rel, src):
    """Yield (token, classification, line, painted) for literals containing one of the words."""
    toks = gd_tokens(src)
    gd_annotate(toks)
    lines = src.split("\n")
    for k, t in enumerate(toks):
        if t.kind != "str" or not has_word(t.val):
            continue
        ln = line_of(src, t.start)
        ltxt = lines[ln - 1]
        paint = gd_paint(t)
        if gd_line_skipped(rel, ltxt):
            cls = "skip"
        elif identifier_like(t.val) and not (paint and re.fullmatch(r"[a-z]+", t.val) and t.prefix == ""):
            cls = "id"
        else:
            cls = gd_classify(toks, k)
        yield t, cls, ln, paint


# ---------------------------------------------------------------- JSON

def json_value_strings(src):
    """(start, end, owner_key) of every string VALUE (not key) in a JSON text."""
    out = []
    stack = []    # frames: {"t": "obj"/"arr", "key": str|None, "expect_key": bool, "owner": str|None}
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            s = src[i + 1:j]
            top = stack[-1] if stack else None
            if top and top["t"] == "obj" and top["expect_key"]:
                top["key"] = s
                top["expect_key"] = False
            else:
                owner = top["key"] if top and top["t"] == "obj" else (top["owner"] if top else None)
                out.append((i + 1, j, owner))
            i = j + 1
            continue
        if c == "{":
            owner = None
            if stack:
                owner = stack[-1]["key"] if stack[-1]["t"] == "obj" else stack[-1]["owner"]
            stack.append({"t": "obj", "key": None, "expect_key": True, "owner": owner})
        elif c == "[":
            owner = None
            if stack:
                owner = stack[-1]["key"] if stack[-1]["t"] == "obj" else stack[-1]["owner"]
            stack.append({"t": "arr", "key": None, "expect_key": False, "owner": owner})
        elif c in "}]":
            if stack:
                stack.pop()
        elif c == "," and stack and stack[-1]["t"] == "obj":
            stack[-1]["expect_key"] = True
        i += 1
    return out


# ---------------------------------------------------------------- the run

class Run:
    def __init__(self, root, dry):
        self.root, self.dry = root, dry
        self.changes = []      # (rel, line, old, new, category)
        self.keys = {}         # text -> [(rel, line)] where the game uses it as a key / id
        self.frozen = {}       # text -> [(rel, line)] display uses kept because the text is a key
        self.files_changed = set()
        self.notes = []

    def read(self, rel):
        with open(os.path.join(self.root, rel), encoding="utf-8", newline="") as f:
            return f.read()

    def write(self, rel, text):
        if self.dry:
            return
        p = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(text)

    def commit(self, rel, old, new):
        if old != new:
            self.files_changed.add(rel)
            self.write(rel, new)

    def change(self, rel, line, old, new, cat):
        self.changes.append((rel, line, old, new, cat))

    # -- GDScript
    def gd_files(self):
        game = [f for f in glob_files(self.root, GD_GAME_GLOBS) if not any(fnmatch(f, x) for x in GD_EXCLUDE)]
        tests = [f for f in glob_files(self.root, GD_TEST_GLOBS) if not any(fnmatch(f, x) for x in GD_EXCLUDE)]
        return game, tests

    def collect_keys(self, game):
        for rel in game:
            src = self.read(rel)
            for t, cls, ln, paint in gd_scan(rel, src):
                if cls == "key":
                    self.keys.setdefault(t.val, []).append((rel, ln))
        return self.keys

    def do_gd(self):
        game, tests = self.gd_files()
        keys = self.collect_keys(game)
        rewritten = set()     # display texts the game's scripts got rebranded
        for rel in game + tests:
            is_test = rel in tests
            src = self.read(rel)
            edits = []
            for t, cls, ln, paint in gd_scan(rel, src):
                if is_test and cls == "key" and t.val in rewritten and t.val not in keys:
                    pass      # a test comparing against a label the game rebranded: follow it
                elif cls != "display":
                    continue
                elif t.val in keys and not paint:
                    self.frozen.setdefault(t.val, []).append((rel, ln))
                    continue
                elif not is_test:
                    rewritten.add(t.val)
                new = rewrite_words(t.val)
                if new != t.val:
                    edits.append((t.body_start, t.body_end, new))
                    self.change(rel, ln, t.val, new, "gd-test" if is_test else "gd")
            self.commit(rel, src, _apply(src, edits))

    # -- scenes
    def do_tscn(self, keys_cache=None):
        rx = re.compile(r'^(\s*(?:text|tooltip_text|placeholder_text|title) = ")((?:[^"\\]|\\.)*)(")', re.M)
        for rel in glob_files(self.root, TSCN_GLOBS):
            src = self.read(rel)
            edits = []
            for m in rx.finditer(src):
                body = m.group(2)
                if not has_word(body) or identifier_like(body) or body in self.keys:
                    continue
                new = rewrite_words(body)
                edits.append((m.start(2), m.end(2), new))
                self.change(rel, line_of(src, m.start()), body, new, "tscn")
            self.commit(rel, src, _apply(src, edits))

    # -- content JSON
    def do_json(self):
        for rel in glob_files(self.root, JSON_GLOBS):
            if any(fnmatch(rel, x) for x in JSON_EXCLUDE):
                continue
            src = self.read(rel)
            edits = []
            for s, e, owner in json_value_strings(src):
                body = src[s:e]
                if owner is None or owner.startswith("_") or owner not in JSON_TEXT_KEYS:
                    continue
                if not has_word(body) or identifier_like(body):
                    continue
                new = rewrite_words(body)
                edits.append((s, e, new))
                self.change(rel, line_of(src, s), body, new, "json")
            self.commit(rel, src, _apply(src, edits))

    # -- project.godot
    def do_project(self):
        rel = "project.godot"
        src = self.read(rel)
        out = src
        m = re.search(r'^config/name="([^"]*)"', out, re.M)
        if not m:
            self.notes.append("project.godot: no config/name found")
            return
        cur = m.group(1)
        has_custom = re.search(r"^config/use_custom_user_dir=true", out, re.M) is not None
        # Pin the save folder before the name changes, so user:// stays where players' saves are.
        if not has_custom and cur != NEW_NAME:
            old = cur
            lines = [
                'config/use_custom_user_dir=true',
                'config/custom_user_dir_name="godot/app_userdata/%s"' % old,
                'config/custom_user_dir_name.windows="Godot/app_userdata/%s"' % old,
                'config/custom_user_dir_name.macos="Godot/app_userdata/%s"' % old,
            ]
            anchor = re.search(r'^config/description="[^"\n]*"\n', out, re.M) or re.search(r'^config/name="[^"]*"\n', out, re.M)
            out = out[:anchor.end()] + "\n".join(lines) + "\n" + out[anchor.end():]
            self.change(rel, line_of(out, anchor.end()), "(default user:// folder)", "custom_user_dir_name -> app_userdata/%s (saves stay put)" % old, "project")
        elif cur != NEW_NAME and has_custom:
            self.notes.append("project.godot already uses a custom user dir; left as is")
        if cur != NEW_NAME:
            out = out.replace('config/name="%s"' % cur, 'config/name="%s"' % NEW_NAME, 1)
            self.change(rel, line_of(out, m.start()), cur, NEW_NAME, "project")
        m2 = re.search(r'^(config/description=")([^"]*)(")', out, re.M)
        if m2 and has_word(m2.group(2)):
            new = rewrite_words(m2.group(2))
            self.change(rel, line_of(out, m2.start()), m2.group(2), new, "project")
            out = out[:m2.start(2)] + new + out[m2.end(2):]
        out = self._project_translations(out, rel)
        self.commit(rel, src, out)

    def _project_translations(self, out, rel):
        want = "res://" + PO_PATH
        if not self.keys:
            return out
        m = re.search(r"^locale/translations=PackedStringArray\(([^)]*)\)", out, re.M)
        if m:
            if want in m.group(1):
                return out
            items = m.group(1).strip()
            new_items = (items + ", " if items else "") + '"%s"' % want
            out = out[:m.start(1)] + new_items + out[m.end(1):]
        else:
            sec = re.search(r"^\[internationalization\]\n", out, re.M)
            line = 'locale/translations=PackedStringArray("%s")\n' % want
            if sec:
                out = out[:sec.end()] + "\n" + line + out[sec.end():] if out[sec.end():sec.end() + 1] != "\n" else out[:sec.end() + 1] + line + out[sec.end() + 1:]
            else:
                # keep Godot's alphabetical section order: before the first section after it
                block = "[internationalization]\n\n" + line + "\n"
                pos = len(out)
                for sm in re.finditer(r"^\[([a-z_]+)\]", out, re.M):
                    if sm.group(1) > "internationalization":
                        pos = sm.start()
                        break
                if pos == len(out) and not out.endswith("\n\n"):
                    block = "\n" + block
                out = out[:pos] + block + out[pos:]
        self.change(rel, line_of(out, out.find(want)), "(no translations)", want, "project")
        return out

    def do_po(self):
        if not self.keys:
            return
        rel = PO_PATH
        body = ['# Generated by tools/rebrand.py: do not edit by hand, re-run the tool instead.',
                '# Texts that double as ids in code (tab names, panel titles) keep their old text in',
                '# the scripts so comparisons still match; Godot auto-translates them on screen.',
                'msgid ""', 'msgstr ""', '"Content-Type: text/plain; charset=UTF-8\\n"', '"Language: en\\n"', '']
        for text in sorted(self.keys):
            body += ['msgid "%s"' % text, 'msgstr "%s"' % rewrite_words(text), '']
            if text.upper() != text:   # UiText.section() and friends upper-case their text
                body += ['msgid "%s"' % text.upper(), 'msgstr "%s"' % rewrite_words(text).upper(), '']
        new = "\n".join(body)
        p = os.path.join(self.root, rel)
        old = self.read(rel) if os.path.exists(p) else ""
        if old != new:
            for text in sorted(self.keys):
                self.change(rel, 0, text, rewrite_words(text), "po")
        self.commit(rel, old, new)

    # -- export presets
    def do_export(self):
        rel = "export_presets.cfg"
        if not os.path.exists(os.path.join(self.root, rel)):
            return
        src = self.read(rel)
        out_lines = []
        for ln, line in enumerate(src.split("\n"), 1):
            new = line
            m = re.match(r'^export_path="(.*)"$', line)
            if m:
                d, _, base = m.group(1).rpartition("/")
                nb = re.sub(OLD_NAME, NEW_NAME_FILE, base, flags=re.I) if re.match(OLD_NAME, base, re.I) else base
                new = 'export_path="%s"' % ((d + "/" if d else "") + nb)
            m = re.match(r'^(application/(?:product_name|file_description|company_name|name|bundle_name|display_name))="(.*)"$', line)
            if m:
                new = '%s="%s"' % (m.group(1), rewrite_game_name(m.group(2)))
            if new != line:
                self.change(rel, ln, line, new, "export")
            out_lines.append(new)
        self.commit(rel, src, "\n".join(out_lines))

    # -- markdown
    def do_markdown(self):
        for rel in MD_FULL:
            if os.path.exists(os.path.join(self.root, rel)):
                self._md(rel, full=True)
        for rel in glob_files(self.root, MD_HEADINGS):
            self._md(rel, full=False)

    def _md(self, rel, full):
        src = self.read(rel)
        out, fence = [], False
        for ln, line in enumerate(src.split("\n"), 1):
            if line.lstrip().startswith("```"):
                fence = not fence
                out.append(line)
                continue
            new = line
            if not fence:
                if full:
                    new = _md_prose(line)
                elif line.startswith("#"):
                    new = _md_prose(line, game_only=True)
            if new != line:
                self.change(rel, ln, line, new, "md")
            out.append(new)
        self.commit(rel, src, "\n".join(out))

    # -- web shell
    def do_html(self):
        for rel in HTML_FILES:
            if not os.path.exists(os.path.join(self.root, rel)):
                continue
            src = self.read(rel)
            parts = re.split(r"(<script\b.*?</script>)", src, flags=re.S | re.I)
            outp = []
            for p in parts:
                if p.lower().startswith("<script"):
                    outp.append(p)
                    continue
                # visible text only: leave attribute values and tags alone
                outp.append(re.sub(r">([^<]*)<", lambda m: ">" + rewrite_game_name(m.group(1)) + "<", p))
            new = "".join(outp)
            if new != src:
                a, b = src.split("\n"), new.split("\n")
                for i, (x, y) in enumerate(zip(a, b), 1):
                    if x != y:
                        self.change(rel, i, x.strip()[:160], y.strip()[:160], "html")
            self.commit(rel, src, new)

    # -- boot splash
    def do_splash(self):
        import hashlib
        p = os.path.join(self.root, SPLASH)
        if not os.path.exists(p):
            return
        with open(p, "rb") as fh:
            if hashlib.sha256(fh.read()).hexdigest() != SPLASH_ORIGINAL_SHA256:
                return       # already redrawn (or replaced by hand)
        self.change(SPLASH, 0, "KINFALL logo", NEW_NAME.upper() + " logo (redrawn)", "art")
        if self.dry:
            return
        try:
            draw_splash(p, os.path.join(self.root, SPLASH_FONT), p, NEW_NAME.upper())
            self.files_changed.add(SPLASH)
        except ImportError:
            self.notes.append("Pillow isn't installed: %s still says KINFALL (pip install pillow, re-run)" % SPLASH)

    # -- doc generators
    def do_py(self):
        rx = re.compile(r"""(["'])(#+ [^"'\n]*)\1""")
        for rel in PY_HEADING_FILES:
            if not os.path.exists(os.path.join(self.root, rel)):
                continue
            src = self.read(rel)
            edits = []
            for m in rx.finditer(src):
                new = rewrite_game_name(m.group(2))
                if new != m.group(2):
                    edits.append((m.start(2), m.end(2), new))
                    self.change(rel, line_of(src, m.start()), m.group(2), new, "py")
            self.commit(rel, src, _apply(src, edits))


# The boot splash (art/splash.png, also the logo screen_fade.gd shows) has the old name baked in.
# It is redrawn once, only while it is still the exact original Kinfall image: a second run,
# or a branch where an artist already replaced it, leaves the file alone.
SPLASH = "art/splash.png"
SPLASH_FONT = "fonts/LilitaOne-Regular.ttf"
SPLASH_ORIGINAL_SHA256 = "e5d7e5529151946cb7e85765af1cc969d9679f0f486c1c1fb9f0fea8f98b62cc"


def draw_splash(src_path, font_path, out_path, text):
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    orig = Image.open(src_path).convert("RGBA")
    W, H = orig.size
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.paste(orig.crop((0, 310, W, H)), (0, 310))     # keep the tagline, drop the old word
    size = 200
    while True:
        f = ImageFont.truetype(font_path, size)
        l, t, r, b = f.getbbox(text)
        if r - l <= W - 180 or size < 40:
            break
        size -= 2
    k = size / 108.0       # the in-game title logo is drawn at 108px: scale its outline and extrusion
    l, t, r, b = f.getbbox(text)
    x, y = (W - (r - l)) // 2 - l, 150 - (b - t) // 2 - t - int(6 * k)
    blank = lambda: Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = blank()
    ImageDraw.Draw(glow).text((x, y), text, font=f, fill=(255, 150, 70, 110), stroke_width=int(26 * k), stroke_fill=(255, 150, 70, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(24 * k))
    body = blank()
    d = ImageDraw.Draw(body)
    for i in range(9, 0, -1):          # extrusion: stacked copies going down, dark plum to brick
        u = 1.0 - i / 9.0
        c = tuple(int(p + (q - p) * u) for p, q in zip((0x3a, 0x1f, 0x3e), (0x7a, 0x3a, 0x3a))) + (255,)
        d.text((x, y + i * 2.4 * k), text, font=f, fill=c, stroke_width=int(14 * k), stroke_fill=c)
    ink = (0x2a, 0x15, 0x30, 255)
    d.text((x, y), text, font=f, fill=ink, stroke_width=int(14 * k), stroke_fill=ink)
    face, top = blank(), blank()
    ImageDraw.Draw(face).text((x, y), text, font=f, fill=(0xf7, 0xa0, 0x3c, 255))
    ImageDraw.Draw(top).text((x, y), text, font=f, fill=(0xfb, 0xbf, 0x62, 255))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rectangle((0, 0, W, y + t + (b - t) * 0.47), fill=255)
    face.paste(top, (0, 0), Image.composite(top.getchannel("A"), Image.new("L", (W, H), 0), mask))
    for lay in (glow, body, face):
        img = Image.alpha_composite(img, lay)
    img.save(out_path)


def _apply(src, edits):
    for s, e, new in sorted(edits, reverse=True):
        src = src[:s] + new + src[e:]
    return src


def _md_prose(line, game_only=False):
    """Rewrite a markdown line outside `code spans` and link targets."""
    rw = rewrite_game_name if game_only else rewrite_words
    pieces = re.split(r"(`[^`]*`|\]\([^)]*\))", line)
    return "".join(p if (p.startswith("`") or p.startswith("](")) else rw(p) for p in pieces)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dry", action="store_true", help="list every replacement (file:line), change nothing")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))), help="repo root")
    a = ap.parse_args()
    r = Run(a.root, a.dry)
    r.do_gd()
    r.do_tscn()
    r.do_json()
    r.do_po()
    r.do_project()
    r.do_export()
    r.do_markdown()
    r.do_html()
    r.do_py()
    r.do_splash()

    if a.dry:
        for rel, ln, old, new, cat in r.changes:
            print('%s:%s: [%s] "%s"\n    -> "%s"' % (rel, ln, cat, old, new))
        if r.keys:
            print("\nKept in code (ids that double as labels; rebranded on screen by %s):" % PO_PATH)
            for text, where in sorted(r.keys.items()):
                print('  "%s" -> "%s"' % (text, rewrite_words(text)))
                print("      key at:   " + ", ".join("%s:%d" % w for w in where))
                if text in r.frozen:
                    print("      label at: " + ", ".join("%s:%d" % w for w in r.frozen[text]))
    by_cat = {}
    for c in r.changes:
        by_cat[c[4]] = by_cat.get(c[4], 0) + 1
    files = sorted({c[0] for c in r.changes})
    print("\nrebrand%s: %d replacements in %d files (%s)" % (
        " (dry run, nothing written)" if a.dry else "", len(r.changes), len(files),
        ", ".join("%s %d" % kv for kv in sorted(by_cat.items())) or "nothing to do"))
    if not a.dry:
        for f in sorted(r.files_changed):
            print("  wrote " + f)
    if r.keys:
        print("  %d id-like texts kept in code and translated on screen" % len(r.keys))
    for n in r.notes:
        print("  note: " + n)


if __name__ == "__main__":
    main()
