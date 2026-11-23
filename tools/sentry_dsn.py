#!/usr/bin/env python3
"""Writes the Sentry DSN from the SENTRY_DSN environment variable into project.godot, for one export only.

The release and itch workflows run it just before they export; the DSN is never committed (docs/SENTRY.md).
With no SENTRY_DSN it changes nothing and the exported game keeps Sentry off. Never prints the DSN.
Usage: SENTRY_DSN=... python3 -I tools/sentry_dsn.py [path/to/project.godot]
"""
import os
import re
import sys

DSN_SHAPE = re.compile(r"https://[0-9a-f]+@[A-Za-z0-9.-]+/[0-9]+")   # https://<key>@<host>/<project id>


def with_dsn(text: str, dsn: str) -> str:
    """project.godot text with options/dsn set in its [sentry] section (the section is added if missing)."""
    line = 'options/dsn="%s"' % dsn
    if "\n[sentry]\n" not in text:
        return text.rstrip("\n") + "\n\n[sentry]\n\n" + line + "\n"
    head, tail = text.split("\n[sentry]\n", 1)
    body, sep, rest = tail.partition("\n[")
    body = re.sub(r"(?m)^options/dsn=.*\n?", "", body).rstrip("\n")
    return head + "\n[sentry]\n" + body + "\n" + line + "\n" + ("\n[" + rest if sep else "")


def main() -> int:
    dsn = os.environ.get("SENTRY_DSN", "").strip()
    if not dsn:
        print("sentry_dsn: no SENTRY_DSN; this export keeps Sentry off")
        return 0
    if not DSN_SHAPE.fullmatch(dsn):
        print("sentry_dsn: SENTRY_DSN does not look like a DSN; not writing it")
        return 1
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "project.godot")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    with open(path, "w", encoding="utf-8") as f:
        f.write(with_dsn(text, dsn))
    print("sentry_dsn: DSN written for this export (do not commit project.godot)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
