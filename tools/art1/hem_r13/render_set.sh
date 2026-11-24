#!/bin/bash
# render_set.sh TAG : 4 GPU jobs (match, close, video, grip) of the glb currently in the tree -> r13/<TAG>/{match,close,video,grip}
T=/home/boki/cj/20261124-104208-a1/tree; R=/home/boki/gens/hunter-round-1124/lace/r13; TAG=$1; cd $T
jobq submit --tree $T --needs gpu --only rp1 --out $TAG/match --label lace-r13-$TAG-match -- --live-audit --wardens=archer --shots-dir=$TAG/match --size=768 > $R/$TAG.match.log 2>&1 & sleep 4
jobq submit --tree $T --needs gpu --only rp1 --out $TAG/close --label lace-r13-$TAG-close -- --live-audit --wardens=archer --shots-dir=$TAG/close --size=768 --close > $R/$TAG.close.log 2>&1 & sleep 4
jobq submit --tree $T --needs gpu --only rp1 --out $TAG/video --label lace-r13-$TAG-video -- --live-audit --wardens=archer --shots-dir=$TAG/video --size=768 --video > $R/$TAG.video.log 2>&1 & sleep 4
jobq submit --tree $T --needs gpu --only rp1 --out $TAG/grip --label lace-r13-$TAG-grip -- --live-audit --wardens=archer --shots-dir=$TAG/grip --size=768 --grip > $R/$TAG.grip.log 2>&1 & sleep 4
wait; echo RENDER-SET-DONE $TAG >> $R/$TAG.done
