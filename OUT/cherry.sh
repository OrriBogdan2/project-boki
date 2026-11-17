cd /home/boki/cj/20261117-144233-a4/tree
for b in spike-on-glidespike split-models-rebased stretch-reds stuck-integ-09e533a4 stuck-integ-38a28c4e stuck-integ-42241ff1 stuck-integ-5b12f708 stuck-integ-7fc43430 stuck-integ-86b7d6eb stuck-integ-aeb8eb0f stuck-integ-c2a69297 stuck-integ-cd1e658f stuck-integ-d2f36c16 stuck-integ-f60f9dd7 stuck-integ-f6bd2b7c summon-clips-port summon-kill-credit-port tenzo-ridge-bursts training-merge-1111 training-time-trial ttk-five-cast-share ttk-kael ui-ability-text-one; do
 r=origin/ext/$b
 at=$(git rev-parse -q --verify refs/tags/archive/$b^{commit}); tip=$(git rev-parse $r)
 [ "$at" = "$tip" ] && A=ARCHIVED_AT_TIP || A=-
 c=$(git cherry origin/main $r | grep -c '^+'); m=$(git cherry origin/main $r | grep -c '^-')
 echo "$b $A novel=$c inmain=$m"
done
