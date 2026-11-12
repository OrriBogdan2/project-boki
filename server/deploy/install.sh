#!/usr/bin/env bash
# Installs or updates a Project Boki game server box (matchmaker + game server) on a fresh Ubuntu 24.04.
# Run as root. Idempotent: run it again to update.
#
#   install.sh [--region eu|us] [--public-host <ip>] [--src <dir>] [--dry-run]
#
# --src (default: the directory this script is in) holds what push.sh uploaded:
#   <src>/matchmaker/   the matchmaker (server/matchmaker in the repo)
#   <src>/server/       the exported "Linux Server" build (binary + .pck); optional on the first run
# --dry-run prints every command and file it would write instead of running them (works without root).
#
# What it sets up: the `boki` user, /opt/boki/{server,matchmaker}, /etc/boki/matchmaker.env (REGION,
# PUBLIC_HOST, SERVER_CMD, ports), systemd `boki-matchmaker.service` (Restart=always, logs to journald),
# ufw mirroring the Hetzner firewall: TCP 22, TCP 8080, UDP 7777-7799.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION=""
PUBLIC_HOST=""
DRY=0
ENV_FILE=/etc/boki/matchmaker.env
UNIT=/etc/systemd/system/boki-matchmaker.service

while [ $# -gt 0 ]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --public-host) PUBLIC_HOST="$2"; shift 2 ;;
    --src) SRC="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRY" = 1 ]; then echo "+ $*"; else "$@"; fi
}

# write <path> [mode]: the file content comes on stdin
write() {
  if [ "$DRY" = 1 ]; then
    echo "+ write $1${2:+ (mode $2)}"
    sed 's/^/    /'
  else
    cat > "$1"
    [ -z "${2:-}" ] || chmod "$2" "$1"
  fi
}

# set_env KEY VALUE: replace or append one line of the env file
set_env() {
  if [ "$DRY" = 1 ]; then echo "+ set $ENV_FILE: $1=$2"; return; fi
  if grep -q "^$1=" "$ENV_FILE"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
  else
    echo "$1=$2" >> "$ENV_FILE"
  fi
}

if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then
  echo "run as root (or with --dry-run)" >&2
  exit 1
fi

echo "== packages"
run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
run env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 rsync ufw curl libfontconfig1

echo "== user and directories"
if ! id boki >/dev/null 2>&1; then
  run useradd --system --create-home --home-dir /opt/boki --shell /usr/sbin/nologin boki
fi
run mkdir -p /opt/boki/server /opt/boki/matchmaker /etc/boki

echo "== files"
if [ -d "$SRC/matchmaker" ]; then
  run rsync -a --delete --exclude __pycache__ "$SRC/matchmaker/" /opt/boki/matchmaker/
else
  echo "   no $SRC/matchmaker: keeping the installed matchmaker"
fi
if [ -d "$SRC/server" ]; then
  run rsync -a --delete "$SRC/server/" /opt/boki/server/
  run bash -c 'chmod +x /opt/boki/server/*.x86_64 2>/dev/null || true'
else
  echo "   no $SRC/server: keeping the installed game server build"
fi
run chown -R boki:boki /opt/boki

echo "== $ENV_FILE"
if [ "$DRY" = 1 ] || [ ! -f "$ENV_FILE" ]; then
  write "$ENV_FILE" 640 <<'ENV'
# Project Boki matchmaker settings (read by boki-matchmaker.service; see server/README.md in the repo).
REGION=eu
PUBLIC_HOST=
SERVER_CMD=/opt/boki/server/ProjectBoki.x86_64 --headless --
PORT_MIN=7777
PORT_MAX=7799
HTTP_PORT=8080
FILL_TIMEOUT_DUEL=20
FILL_TIMEOUT_ARENA=30
FILL_TIMEOUT_TRIO=20
TOKENS_DIR=/run/boki
ENV
fi
run chown root:boki "$ENV_FILE"
run chmod 640 "$ENV_FILE"
[ -z "$REGION" ] || set_env REGION "$REGION"
[ -z "$PUBLIC_HOST" ] || set_env PUBLIC_HOST "$PUBLIC_HOST"
binaries=(/opt/boki/server/*.x86_64)
if [ "${#binaries[@]}" = 1 ] && [ -f "${binaries[0]}" ]; then
  set_env SERVER_CMD "${binaries[0]} --headless --"
else
  echo "   no single /opt/boki/server/*.x86_64 yet: SERVER_CMD left as is (push a build, then re-run)"
fi

echo "== systemd"
write "$UNIT" <<'SVC'
[Unit]
Description=Project Boki matchmaker (queues and game server processes)
After=network-online.target
Wants=network-online.target

[Service]
User=boki
Group=boki
WorkingDirectory=/opt/boki
EnvironmentFile=/etc/boki/matchmaker.env
RuntimeDirectory=boki
RuntimeDirectoryMode=0700
StateDirectory=boki
ExecStart=/usr/bin/python3 /opt/boki/matchmaker/matchmaker.py --env-file /etc/boki/matchmaker.env
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=20
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVC

echo "== firewall (mirrors the Hetzner firewall)"
run ufw allow 22/tcp
run ufw allow 8080/tcp
run ufw allow 7777:7799/udp
run ufw --force enable

echo "== start"
run systemctl daemon-reload
run systemctl enable boki-matchmaker.service
run systemctl restart boki-matchmaker.service
if [ "$DRY" = 0 ]; then
  sleep 2
  systemctl --no-pager --lines=5 status boki-matchmaker.service || true
fi
echo
echo "Done. Health: curl http://${PUBLIC_HOST:-<this host>}:8080/health   Logs: journalctl -u boki-matchmaker -f"
