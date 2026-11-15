#!/bin/bash
# regate_stub.sh PR BRANCH SHA GATED OUT : stand-in for regate-run in train_batch_test.sh (merge origin/main into BRANCH, push, GREEN)
mkdir -p "$5"; d=$(mktemp -d); git clone -q -b "$2" "$(git -C "$BOKI_REPO" remote get-url origin)" "$d" && cd "$d" || exit 1
git -c user.email=t@t -c user.name=t merge -q --no-ff -m "Merge main (stub)" origin/main && git push -q origin "HEAD:$2"
echo "GREEN $(git rev-parse HEAD)" > "$5/result"; echo "GATE GREEN $(git rev-parse HEAD): delta ok" > "$5/comment.md"
