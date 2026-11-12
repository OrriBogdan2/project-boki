"""One-line structured logs on stdout (journald keeps them when run under systemd)."""
import time


def log(event: str, **fields) -> None:
    """Print `time event=<event> key=value ...`; values with spaces are quoted."""
    parts = [time.strftime("%Y-%m-%dT%H:%M:%S"), f"event={event}"]
    for key, value in fields.items():
        text = str(value)
        if " " in text or text == "":
            text = '"' + text.replace('"', "'") + '"'
        parts.append(f"{key}={text}")
    print(" ".join(parts), flush=True)
