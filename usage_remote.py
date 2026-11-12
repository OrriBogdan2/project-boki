#!/usr/bin/env python3
"""usage_remote: read ONE account's usage block from another host's `cswap list --json`.

For usage-track snap: when the local (hetzner) reading of an account is missing or relogin_required,
call remote_usage(email, hosts) and store the result with source=<host>. No cswap slot is copied;
nothing printed here contains an email or token (matching is done on the email, output is usage only).

CLI (for a manual check):  usage_remote.py --email-from accounts.json:<acct-key> --hosts w2,rpc4
   or                      usage_remote.py --email-env OUTLOOK1_EMAIL --hosts w2
Host "local" runs cswap on this machine. SSH command: $USAGE_REMOTE_SSH, else $SSHK, else a BatchMode default.
"""
import json, os, shlex, subprocess, sys

DEFAULT_SSH = "ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new"


def _ssh_prefix():
    return shlex.split(os.environ.get("USAGE_REMOTE_SSH") or os.environ.get("SSHK") or DEFAULT_SSH)


def _list_json(host, timeout=40):
    cmd = ["cswap", "list", "--json"]
    if host != "local":
        cmd = _ssh_prefix() + [host, "PATH=$HOME/.local/bin:$HOME/bin:$PATH cswap list --json"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except Exception as e:  # unreachable host, timeout
        return None, type(e).__name__
    if p.returncode != 0:
        return None, "rc=%d" % p.returncode
    try:
        d = json.loads(p.stdout)
    except ValueError:
        return None, "bad-json"
    accs = d.get("accounts", d) if isinstance(d, dict) else d
    if isinstance(accs, dict):
        accs = list(accs.values())
    return [a for a in accs if isinstance(a, dict)], None


def _is_account(block, email):
    e = email.strip().lower()
    if str(block.get("email", "")).strip().lower() == e:
        return True
    # OAuth slots name their org "<email>'s Organization"; setup-token slots may carry a placeholder email.
    return str(block.get("organizationName", "")).strip().lower().startswith(e + "'")


def remote_usage(email, hosts):
    """-> (record, tried). record = {"usage", "usageStatus", "source", "slot"} from the first host whose block
    for this account has usage; None if no host has one. tried = [(host, why-not)] (no emails in it)."""
    tried = []
    for host in hosts:
        accs, err = _list_json(host)
        if err:
            tried.append((host, err)); continue
        blocks = [a for a in accs if _is_account(a, email)]
        if not blocks:
            tried.append((host, "not-on-host")); continue
        good = [a for a in blocks if a.get("usage")]
        if not good:
            tried.append((host, ",".join("slot%s:%s/%s" % (a.get("number"), a.get("usageStatus"), a.get("usageError", ""))
                                          for a in blocks)))
            continue
        a = good[0]
        return {"usage": a["usage"], "usageStatus": a.get("usageStatus"), "source": host, "slot": a.get("number")}, tried
    return None, tried


def _email_from(spec):
    path, key = spec.rsplit(":", 1)
    acc = json.load(open(path))
    acc = acc.get("accounts", acc) if isinstance(acc, dict) else acc
    if isinstance(acc, dict):
        acc = acc[key]
    else:
        acc = next(a for a in acc if str(a.get("id") or a.get("name") or a.get("slot")) == key)
    return acc["email"], acc.get("hosts", [])


def main(argv):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--email-from")
    ap.add_argument("--email-env")
    ap.add_argument("--hosts", default="")
    a = ap.parse_args(argv)
    hosts = [h for h in a.hosts.split(",") if h]
    if a.email_from:
        email, acc_hosts = _email_from(a.email_from)
        hosts = hosts or acc_hosts
    else:
        email = os.environ[a.email_env]
    rec, tried = remote_usage(email, hosts)
    print(json.dumps({"record": rec, "tried": tried}))
    return 0 if rec else 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
