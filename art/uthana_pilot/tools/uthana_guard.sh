#!/bin/bash
# usage: guard.sh <estimated_cost_usd> <label> ; exit 1 if the call may not run
START=${UTH_START:-24.5958}; CAP=${UTH_CAP:-10}
B=$(./uthana_q.sh '{"query":"{ org { payg_total_usd } }"}' | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['org']['payg_total_usd'])")
echo "$(date -u +%T) bal=$B est=$1 $2" >> spend.log
python3 -c "
b=float('$B');s=$START-b;e=float('$1')
import sys
if b>$START+0.0001: print('BALANCE ROSE (recharge?) stop',b);sys.exit(1)
if s+e>$CAP: print('CAP: spent',round(s,4),'+est',e);sys.exit(1)
print('ok spent',round(s,4),'bal',b)"
