#!/bin/bash
# $1 branch name, $2 sha: list commits of branch not on main
f=/tmp/ma/rl/$(echo "$1" | tr / _)
git rev-list "$2" ^origin/main > "$f"
