# Project Boki launcher

A small Godot 4.6 project (separate from the game) that playtesters run instead of the game:

1. **Log in with Discord** (opens the browser; scope `identify` only).
2. **Updates** the game from the latest GitHub Release (`ProjectBoki-<platform>.zip`).
3. **Play** starts the game connected to the relay server with the player's Discord token.

Settings are in `launcher_config.json`. CI fills in `discord_client_id` and `server` from the
repository variables `DISCORD_CLIENT_ID` and `BOKI_SERVER` (Settings → Secrets and variables → Actions → Variables).

The Discord app needs this redirect URL: `http://127.0.0.1:53134/cb`.
