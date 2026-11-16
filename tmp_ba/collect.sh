R=/home/boki/meshy/before-after-1116/_raw
for J in $(ls /home/boki/jobq/done); do [ -d /home/boki/jobq/done/$J/out ] && for d in /home/boki/jobq/done/$J/out/*/; do [ -d "$d" ] && mkdir -p $R/$(basename $d) && cp -n $d/* $R/$(basename $d)/ 2>/dev/null; done; done
for d in $R/*/; do echo $(basename $d) $(ls $d | wc -l); done
