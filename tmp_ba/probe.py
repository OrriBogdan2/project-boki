import os, socket, sys
print("HOST", socket.gethostname(), os.getcwd())
for p in ["/home/boki/meshy/v95/Gil/v95.glb", "/mnt/HC_Volume_107406663/offload/meshy/v95/Gil", "/home/boki/site-repo/assets/img/hunters/gill-1600.webp"]:
    print("EXISTS", p, os.path.exists(p))
