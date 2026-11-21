# worker-prune (11-19)
Ages out idle `/root/mcshard/<hash>` suite shards on pods (~20 GB each; suites use pods by default since 11-18).
`worker-prune.sh [--apply] [pod ...]` (dry run by default; pods from `~/.mc_pods`). Prunes a shard when:
- its newest **ctime** (any file or dir) is older than 48 h (`PRUNE_AGE_H`). ctime, not mtime: `rsync -a`/`cp -a` keep old
  mtimes, so a shard synced a minute ago looks days old by mtime. Claims live on the server (`$OUT/<side>/<n>.claim`), not
  on the pod, so shard ctime is the pod-side "last claim" signal (every claimed check writes logs/imports there);
- no process names the shard path anywhere in its command line (godot `--path`, rsync/cp seed copies, suite-pod);
- it is not the newest shard with a `gw/` seed (merge-candidate `import_remote` copies `/root/mcshard/*/gw`).
Never kills processes. Tested on w2 on a fake tree (`MCSHARD_ROOT`, `PRUNE_AGE_S`): 2 old shards pruned; kept the newest gw
seed, a shard named by a running process, and a fresh shard whose files had 2020 mtimes.
NOT run against a real pod yet (w2 has no `~/.mc_pods` or pod key). Use: dry run on hetzner, then `--apply` daily from cron.
