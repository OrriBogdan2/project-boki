#!/bin/bash
# archive.sh <list: branch sha tagname class reason...> <log>. Tag archive/<tagname> at the tip, confirm on origin, then delete (lease on sha).
list=$1; log=$2; B=40
mapfile -t L < "$list"
for ((i=0;i<${#L[@]};i+=B)); do
  chunk=("${L[@]:i:B}"); tags=()
  for l in "${chunk[@]}"; do set -- $l; tags+=("$2:refs/tags/archive/$3"); done
  git push -q origin "${tags[@]}" 2>>/tmp/mt/archive.err
  git ls-remote origin 'refs/tags/archive/*' > /tmp/mt/w/tags.now
  leases=(); refs=()
  for l in "${chunk[@]}"; do set -- $l; b=$1; s=$2; t=$3; shift 3
    if grep -qP "^$s\trefs/tags/archive/\Q$t\E\$" /tmp/mt/w/tags.now; then leases+=("--force-with-lease=refs/heads/$b:$s"); refs+=(":refs/heads/$b")
      echo "ARCHIVED $b $s class=$* | restore: git push origin 'archive/$t^{commit}:refs/heads/$b'" >> $log
    else echo "SKIP-NO-TAG $b $s class=$*" >> $log; fi
  done
  [ ${#refs[@]} -gt 0 ] && git push -q origin "${leases[@]}" "${refs[@]}" 2>>/tmp/mt/archive.err
done
