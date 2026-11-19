# worker-prune (11-19)
Ages out idle `/root/mcshard/<hash>` suite shards on pods (~20 GB each; suites use pods by default since 11-18).
`worker-prune.sh [--apply] [pod ...]` (dry run by default; pods from `~/.mc_pods`). Prunes a shard when its newest file is
older than 48 h (`PRUNE_AGE_H`), no process has `--path /root/mcshard/<hash>/` running, and it is not the newest shard with a
`gw/` seed (merge-candidate `import_remote` copies `/root/mcshard/*/gw`). Never kills processes.
Tested here (w2) on a fake tree via `MCSHARD_ROOT`: old shards pruned, a running-godot shard and the newest gw seed kept.
NOT tested against a real pod: w2 has no `~/.mc_pods`, `suite-pod` or pod key. Suggested use: run `--apply` from hetzner cron daily.
