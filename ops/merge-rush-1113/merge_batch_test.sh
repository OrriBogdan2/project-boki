#!/bin/bash
# merge_batch_test.sh : merge_batch.sh's doc policy in a scratch repo. A STRUCT doc (docs/HUD.md) is unioned when both
# sides only added lines, and stays a conflict when both changed the same row (union would keep the stale row);
# docs/DEBT.md is unioned either way.
MB=$(cd "$(dirname "$0")" && pwd)/merge_batch.sh
T=$(mktemp -d /tmp/mb_test.XXXX); cd "$T" || exit 2; git init -q -b main r; cd r || exit 2
git config user.email t@t; git config user.name t; mkdir docs
printf '# HUD\n\n| file | role |\n|---|---|\n| `a.gd` | old a |\n| `b.gd` | b |\n' > docs/HUD.md
printf '# Debt\n\n- one\n- two\n' > docs/DEBT.md; git add -A; git commit -qm base
git checkout -qb add1 main; sed -i '/`b.gd`/a | `c.gd` | c |' docs/HUD.md; git commit -qam c; git checkout -q main
git checkout -qb add2 main; sed -i '/`b.gd`/a | `d.gd` | d |' docs/HUD.md; git commit -qam d; git checkout -q main
git checkout -qb ed1 main; sed -i 's/old a/new a (one)/' docs/HUD.md; sed -i 's/- two/- two (fixed one)/' docs/DEBT.md; git commit -qam e1; git checkout -q main
git checkout -qb ed2 main; sed -i 's/old a/new a (two)/' docs/HUD.md; sed -i 's/- two/- two (fixed two)/' docs/DEBT.md; git commit -qam e2; git checkout -q main
fail=0; ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
git checkout -q --detach add1; echo "add2 $(git rev-parse add2)" > L1; : > S1; bash "$MB" L1 S1
ok "HUD add/add is unioned" "[ ! -s S1 ] && grep -q 'c.gd' docs/HUD.md && grep -q 'd.gd' docs/HUD.md"
git checkout -q --detach ed1; echo "ed2 $(git rev-parse ed2)" > L2; : > S2; bash "$MB" L2 S2
ok "HUD edit/edit stays a conflict" "grep -q 'conflict: docs/HUD.md' S2 && ! grep -q DEBT S2"
ok "aborted merge leaves ed1's HUD row" "[ \$(grep -c 'new a' docs/HUD.md) = 1 ]"
git checkout -qb debt2 main; sed -i 's/- two/- two (fixed two)/' docs/DEBT.md; git commit -qam d2
git checkout -q --detach ed1; echo "debt2 $(git rev-parse debt2)" > L3; : > S3; bash "$MB" L3 S3
ok "DEBT edit/edit is unioned" "[ ! -s S3 ] && grep -q 'fixed one' docs/DEBT.md && grep -q 'fixed two' docs/DEBT.md"
rm -rf "$T"; exit $fail
