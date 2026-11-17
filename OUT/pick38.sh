cd /home/boki/cj/20261117-144233-a4/tree
for c in ef5cfe9425 d95721ee68 87f1f9019d ba7de7b971 334a66e2a0 5efb734186 b24ee8dccd b310a1a621 23b3e91ac3 da994ed0ca 80747c29fb 2bb9c7791a ab80f7f467 4ad2bd04a5 5109eea5d0 71c53a6dc6 cbb26d25de; do
  if git cherry-pick -x $c >/dev/null 2>&1; then echo "OK $c"; else
    f=$(git diff --name-only --diff-filter=U | head -6 | tr '\n' ' '); echo "CONFLICT $c: $f"; git cherry-pick --abort >/dev/null 2>&1; git reset -q --hard; fi
done
echo DONE
