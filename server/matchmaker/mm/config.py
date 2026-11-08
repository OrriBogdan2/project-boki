"""Matchmaker settings: an env file (/etc/boki/matchmaker.env) overridden by the process environment."""
import os
import shlex
from dataclasses import dataclass, field

ENV_FILE = "/etc/boki/matchmaker.env"


@dataclass
class Mode:
    slots: int        # players in a match, humans and bots together
    team_size: int    # players per team; slots are handed out team-major (team 0 gets slots 0..team_size-1)


@dataclass
class Config:
    region: str = "dev"
    public_host: str = "127.0.0.1"        # the address handed to clients
    http_host: str = "0.0.0.0"
    http_port: int = 8080
    server_cmd: list = field(default_factory=list)   # argv prefix; `--server --port ...` is appended
    server_version: str = ""              # Net.VERSION of the build; empty = probe with `--version`
    port_min: int = 7777
    port_max: int = 7799
    fill_timeout: dict = field(default_factory=lambda: {"duel": 20.0, "arena": 30.0, "trio": 20.0})  # s
    trio_slots: int = 18                  # players in an extraction match (6 trios: 2x Hollow Crown at 30 hunters); the server fills with bots
    token_ttl_s: float = 60.0             # a handed-out token nobody used is dropped after this
    ready_timeout_s: float = 30.0         # the server must print its ready line within this or is killed
    tokens_dir: str = "/run/boki"
    tick_s: float = 0.5

    def modes(self) -> dict:
        """Queue -> match shape."""
        return {"duel": Mode(2, 1), "arena": Mode(8, 4), "trio": Mode(self.trio_slots, 3)}


def read_env_file(path: str) -> dict:
    """KEY=VALUE lines; `#` comments and blank lines are skipped, quotes around a value are stripped."""
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            out[key.strip()] = value.strip().strip('"').strip("'")
    return out


def load(env_file: str = ENV_FILE, environ: dict = None) -> Config:
    """Build the config: file values first, then the environment on top."""
    values = read_env_file(env_file)
    values.update(os.environ if environ is None else environ)
    cfg = Config()
    cfg.region = values.get("REGION", cfg.region)
    cfg.public_host = values.get("PUBLIC_HOST", cfg.public_host)
    cfg.http_host = values.get("HTTP_HOST", cfg.http_host)
    cfg.http_port = int(values.get("HTTP_PORT", cfg.http_port))
    cfg.server_cmd = shlex.split(values.get("SERVER_CMD", ""))
    cfg.server_version = values.get("SERVER_VERSION", "")
    cfg.port_min = int(values.get("PORT_MIN", cfg.port_min))
    cfg.port_max = int(values.get("PORT_MAX", cfg.port_max))
    for mode in cfg.fill_timeout:
        cfg.fill_timeout[mode] = float(values.get(f"FILL_TIMEOUT_{mode.upper()}", cfg.fill_timeout[mode]))
    cfg.trio_slots = int(values.get("TRIO_SLOTS", cfg.trio_slots))
    cfg.token_ttl_s = float(values.get("TOKEN_TTL_S", cfg.token_ttl_s))
    cfg.ready_timeout_s = float(values.get("READY_TIMEOUT_S", cfg.ready_timeout_s))
    cfg.tokens_dir = values.get("TOKENS_DIR", cfg.tokens_dir)
    return cfg
