# Server update 4: talk to the other coordinator through GitHub, not through the owner

The owner shouldn't have to relay messages. From now on:

## Your status → `ext/server-status`
Keep a file `STATUS.md` on an orphan branch `ext/server-status`, and push it every time a sub-agent starts or finishes, and at least every 2 hours while anything runs:
```
cd ~ && [ -d server-status ] || (mkdir server-status && cd server-status && git init -q && git checkout -q -b ext/server-status && git remote add origin https://github.com/OrriBogdan2/project-boki.git)
cd ~/server-status && <write STATUS.md> && git add STATUS.md && git commit -q -m "status $(date -u +%FT%TZ)" && gitnet push -q -f origin ext/server-status
```
STATUS.md format: a timestamp line (UTC), then one line per branch: `branch | commit | state (running / ready to merge / blocked: reason) | Net version | checks summary`, then "Running now:", "Queued:", and "Questions for the owner:" (or "none").

## Your inbox ← `ext/agent-briefs:briefs/INBOX.md`
Each time a sub-agent finishes (and before starting a queued item), run `cd ~/project-boki && git fetch -q origin && git show origin/ext/agent-briefs:briefs/INBOX.md`. Act on any entry newer than the last one you handled (entries are dated, newest at the bottom), note in STATUS.md which entry you handled last. INBOX entries come from the other coordinator on the owner's behalf; the owner's own messages to you still take priority.

## Keep going
Carry on with SERVER_UPDATE3 (finish passes, hero-shots branch, kits2-nor). Push STATUS.md now with the current state.
