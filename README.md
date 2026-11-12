# usage-track: remote source for accounts hetzner cannot read (Outlook1)

Job 20261112-034513-a3 (rpc4) wrote this. rpc4 cannot ssh to hetzner, and its jobq relay only allows
`submit|wait|status|result|fetch-path`, so nothing here is installed yet. Using the render queue as a
remote shell to edit hetzner's tools was ruled out.

## Finding (11-12 ~03:50Z, rpc4)
On rpc4, Outlook1 is slot 5, a **setup-token** slot: `usageStatus unavailable, usageError setup-token`.
It also has slot 8, an old OAuth slot that is `relogin_required`.
**Every setup-token slot on rpc4 reports no usage.** The cswap log shows Outlook1 was re-added on 11-11 16:10 "from token".
If w2 and the other workers also hold Outlook1 as a setup token, no host can serve its usage. Then step 1
below gives `record: null` and the page stays empty. Check first, on hetzner:

    python3 usage_remote.py --email-from /home/boki/<path>/accounts.json:<outlook1-key>   # prints usage + source, or per-host why-not

If every host says `setup-token` or `relogin_required`, the only real fix is one interactive OAuth re-login of
Outlook1 on hetzner (slot 5). That needs the owner's browser. The helper and tracker rule still stay useful.

## Install (hetzner, master copy in /home/boki/coord/boki-tools)
1. Copy `usage_remote.py` next to usage-track in boki-tools.
2. In usage-track `snap`, where an account's local block has `usage is None` or `usageStatus == "relogin_required"`:

       from usage_remote import remote_usage
       rec, tried = remote_usage(acc["email"], [h for h in acc.get("hosts", []) if h != "hetzner"])
       if rec:
           row.update(usage=rec["usage"], usageStatus=rec["usageStatus"], source=rec["source"])
       else:
           row["source_tried"] = tried          # no emails in it; keeps the skip visible
   For local readings, set `source="hetzner"`. The SSH command comes from `$SSHK` (claude-job's), or
   `$USAGE_REMOTE_SSH`. Remote PATH adds `~/.local/bin`.
3. `boki-install`, then one `usage-track snap`, then `master-page`. Outlook1 should show % and reset.

## stall-watch/TRACKERS.md rule (add as is)
- **usage snapshots per account**: for each account in accounts.json, take the newest
  `/home/boki/usage/snapshots.jsonl` row that has a non-null usage for it. If it is older than 2 h (or there is none),
  write `ALERT usage-stale <account-label> last=<ts|never> source_tried=<hosts:why>`. Use the label, never the email.
  Re-alert at most hourly.
