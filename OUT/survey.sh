cd /home/boki/cj/20261117-144233-a4/tree
for b in spike-on-glidespike split-models-rebased stretch-reds stuck-integ-09e533a4 stuck-integ-38a28c4e stuck-integ-42241ff1 stuck-integ-5b12f708 stuck-integ-7fc43430 stuck-integ-86b7d6eb stuck-integ-aeb8eb0f stuck-integ-c2a69297 stuck-integ-cd1e658f stuck-integ-d2f36c16 stuck-integ-f60f9dd7 stuck-integ-f6bd2b7c summon-clips-port summon-kill-credit-port tenzo-ridge-bursts training-merge-1111 training-time-trial ttk-five-cast-share ttk-kael ui-ability-text-one; do
 r=origin/ext/$b
 mb=$(git merge-base origin/main $r)
 files=$(git diff --name-only $mb $r | wc -l)
 st=$(git diff --shortstat $mb $r)
 at=$(git rev-parse -q --verify refs/tags/archive/$b^{commit}); tip=$(git rev-parse $r)
 [ "$at" = "$tip" ] && A=ARCHIVED_AT_TIP || { [ -n "$at" ] && A=archtag_differs || A=-; }
 out=$(git merge-tree --write-tree --name-only origin/main $r 2>&1); rc=$?
 nconf=$(echo "$out" | grep -c '^CONFLICT')
 echo "$b mb=${mb:0:8} $A rc=$rc conflicts=$nconf |$st"
done
