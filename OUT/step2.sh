cd /home/boki/cj/20261117-144652-a4/tree
for n in fsm-m1 hatch-mask-polish-1111 hud-g-armor-1111 hud-ref-copy-2 ui-bonus-column ui-hudref-verify ui-mode-cards ui-overhead-ref ui-overload-1115 ui-pro-1111 ui-settings-trim ui-simplify-1111 ui-solos-hud ui-zone-next verify-solos-pacing; do
  if git merge-base --is-ancestor origin/ext/$n HEAD; then echo "RESULT $n ALREADY-IN"; continue; fi
  if git merge --no-edit -m "Merge ext/$n into uihud lane 1117" origin/ext/$n >OUT/m_$n.log 2>&1; then echo "RESULT $n CLEAN $(git rev-parse --short HEAD)"; else
    echo "RESULT $n CONFLICT $(git diff --name-only --diff-filter=U | tr '\n' ' ')"; git merge --abort; fi
done
echo STEP2_DONE
