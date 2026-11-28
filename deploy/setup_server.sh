#!/usr/bin/env bash
# Sets up the Project Boki relay server on a fresh Ubuntu 24.04 machine (e.g. Hetzner CPX21).
# Run as root:  curl -sSL https://raw.githubusercontent.com/OrriBogdan2/project-boki/main/deploy/setup_server.sh | bash
# Then put the Discord settings in /etc/boki/relay.env (see relay.env.example) and run:
#   systemctl restart boki-relay
set -euo pipefail
REPO="${BOKI_REPO:-OrriBogdan2/project-boki}"

apt-get update -qq
apt-get install -y -qq curl unzip jq ufw libfontconfig1 >/dev/null

id boki >/dev/null 2>&1 || useradd --system --create-home --home-dir /opt/boki --shell /usr/sbin/nologin boki
mkdir -p /etc/boki /opt/boki/game
[ -f /etc/boki/relay.env ] || cat > /etc/boki/relay.env <<'ENV'
# Project Boki relay settings. Leave the Discord lines empty to let anyone with the game join.
BOKI_PORT=7777
BOKI_MAX_PLAYERS=120
BOKI_DISCORD_BOT_TOKEN=
BOKI_GUILD_ID=
# comma-separated role ids allowed to play (Kinfall Playtester, Trial Dev, OG, ...)
BOKI_ALLOWED_ROLES=
ENV
chmod 600 /etc/boki/relay.env

# the updater: fetches the latest release's Linux build when it changes
cat > /opt/boki/update.sh <<UPD
#!/usr/bin/env bash
set -euo pipefail
cd /opt/boki
REL=\$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=\$(echo "\$REL" | jq -r .tag_name)
URL=\$(echo "\$REL" | jq -r '.assets[] | select(.name=="ProjectBoki-linux.zip") | .browser_download_url')
[ -z "\$URL" ] || [ "\$URL" = "null" ] && { echo "no linux build in latest release"; exit 0; }
[ -f version ] && [ "\$(cat version)" = "\$TAG" ] && exit 0
echo "updating relay to \$TAG"
curl -sSL -o game.zip "\$URL"
rm -rf game.new && mkdir game.new && unzip -q game.zip -d game.new && rm game.zip
chmod +x game.new/*.x86_64
rm -rf game.old && [ -d game ] && mv game game.old
mv game.new game
echo "\$TAG" > version
chown -R boki:boki /opt/boki
systemctl restart boki-relay || true
UPD
chmod +x /opt/boki/update.sh

cat > /etc/systemd/system/boki-relay.service <<'SVC'
[Unit]
Description=Project Boki relay server
After=network-online.target
Wants=network-online.target

[Service]
User=boki
WorkingDirectory=/opt/boki
EnvironmentFile=/etc/boki/relay.env
ExecStart=/bin/bash -c 'exec /opt/boki/game/ProjectBoki.x86_64 --headless -- --relay'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVC

# check for a new release every 5 minutes
cat > /etc/systemd/system/boki-update.service <<'SVC'
[Unit]
Description=Update the Project Boki relay to the latest release
[Service]
Type=oneshot
ExecStart=/opt/boki/update.sh
SVC
cat > /etc/systemd/system/boki-update.timer <<'SVC'
[Unit]
Description=Check for new Project Boki releases
[Timer]
OnBootSec=30
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
SVC

ufw allow OpenSSH >/dev/null
ufw allow 7777/udp >/dev/null
ufw --force enable >/dev/null

systemctl daemon-reload
/opt/boki/update.sh
systemctl enable --now boki-relay boki-update.timer
echo
echo "Project Boki relay is running on UDP port 7777."
echo "Logs: journalctl -u boki-relay -f"
