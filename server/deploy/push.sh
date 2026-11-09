#!/usr/bin/env bash
# Uploads the matchmaker and a game server build to a box and (re)installs there.
#
#   push.sh <host> <region> [<build-dir>] [--dry-run]
#
# <host>       the server's public IP or name; also written as PUBLIC_HOST (what clients connect to)
# <region>     eu | us
# <build-dir>  the exported "Linux Server" build (binary + .pck), made outside the repo, e.g. ../build/server.
#              Leave it out to push only the matchmaker.
# --dry-run    print the commands instead of running them.
#
# Uses ssh -i ~/.ssh/boki_s2_deploy as root. Steps: rsync server/matchmaker, the build and install.sh to
# /opt/boki/upload, run install.sh --region --public-host there (it restarts boki-matchmaker), then curl /health.
set -euo pipefail

HOST="${1:-}"
REGION="${2:-}"
BUILD=""
DRY=0
for arg in "${@:3}"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    *) BUILD="$arg" ;;
  esac
done
if [ -z "$HOST" ] || [ -z "$REGION" ] || [ "$HOST" = "--dry-run" ]; then
  echo "usage: push.sh <host> <eu|us> [<build-dir>] [--dry-run]" >&2
  exit 2
fi
case "$REGION" in eu|us) ;; *) echo "region must be eu or us" >&2; exit 2 ;; esac
if [ -n "$BUILD" ] && [ ! -d "$BUILD" ]; then
  echo "build dir not found: $BUILD" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="$HOME/.ssh/boki_s2_deploy"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "root@$HOST")
RSYNC=(rsync -az --delete -e "ssh -i $KEY -o StrictHostKeyChecking=accept-new")
UPLOAD="root@$HOST:/opt/boki/upload"

run() {
  if [ "$DRY" = 1 ]; then echo "+ $*"; else "$@"; fi
}

echo "== upload to $HOST ($REGION)"
run "${SSH[@]}" mkdir -p /opt/boki/upload
run "${RSYNC[@]}" --exclude __pycache__ "$HERE/../matchmaker/" "$UPLOAD/matchmaker/"
run "${RSYNC[@]}" "$HERE/install.sh" "$UPLOAD/install.sh"
if [ -n "$BUILD" ]; then
  run "${RSYNC[@]}" "$BUILD/" "$UPLOAD/server/"
fi

echo "== install"
run "${SSH[@]}" bash /opt/boki/upload/install.sh --region "$REGION" --public-host "$HOST" ${PORTS:+--ports "$PORTS"}      # PORTS=7777-7781 push.sh ... sizes the match slots

echo "== health"
run curl -fsS --max-time 10 "http://$HOST:8080/health"
echo
