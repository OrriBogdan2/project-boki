#!/bin/bash
# usage: ttm3.sh <character_id> <length_s> <prompt> : TTM 3.0 job, polled to the end; prints the motion id. Key never echoed.
body=$(python3 -c 'import json,sys;print(json.dumps({"query":"mutation($p:String!,$c:String!,$l:Float){ create_text_to_motion_job(prompt:$p, character_id:$c, length:$l, model:\"text-to-motion-3.0\"){ job { id status } } }","variables":{"p":sys.argv[3],"c":sys.argv[1],"l":float(sys.argv[2])}}))' "$@")
r=$(./uthana_q.sh "$body"); job=$(echo "$r" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["create_text_to_motion_job"]["job"]["id"])' 2>/dev/null) || { echo "$r" | head -c 400 >&2; exit 1; }
for _ in $(seq 60); do sleep 5
  r=$(./uthana_q.sh "{\"query\":\"{ job(job_id: \\\"$job\\\") { status result } }\"}")
  st=$(echo "$r" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["job"]["status"])')
  [ "$st" = FINISHED ] && { echo "$r" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["job"]["result"]["result"]["id"])'; exit 0; }
  [ "$st" = FAILED ] && { echo "FAILED $r" >&2; exit 1; }
done; echo "timeout $job" >&2; exit 1
