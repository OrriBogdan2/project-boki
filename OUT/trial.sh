cd /home/boki/cj/20261117-144455-a3/trial
for b in "$@"; do
 git merge --no-commit --no-ff origin/ext/$b >/dev/null 2>&1
 n=$(git diff --name-only --diff-filter=U | wc -l)
 echo "$b conflicts=$n $(git diff --name-only --diff-filter=U | head -6 | tr '\n' ' ')"
 git merge --abort 2>/dev/null || git reset --hard -q
 git clean -fdq
done
echo DONE
