import subprocess
def sh(c): print(subprocess.run(c,shell=True,capture_output=True,text=True).stdout[:3000])
print("FIND")
sh("grep -n -i CURRENT_OVERRIDES /home/boki/wt-mc-main2/docs/art/wardens/V95_SWAP.md | head -8")
sh("grep -rIl 'cg3d1115' /home/boki --include=* -s 2>/dev/null | grep -v -E 'jobq/done|claude-swap|\\.jsonl|/meshy/' | head -20")
sh("ls /home/boki/meshy/v95/Grimble/r5/cg3d1115/ /home/boki/meshy/cinder-grimble-3d-1115/ /home/boki/meshy/cinder-grimble-3d-1115/final | head -40")
sh("cat /home/boki/jobq/done/20261115-181913-26106/out/overrides.txt 2>/dev/null | head -20")
print("ENDFIND")
