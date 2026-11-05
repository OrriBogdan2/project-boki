# Hero reference footage (frames)

The SUPERVIVE reference footage behind briefs/hero-ref/*.md, as 5 fps JPG frames (720 px wide). Ext pushed it so every session can see it. The notes' paths `/home/claude/svvid/hero/<id>/frames/` map to `footage/<id>/frames/` here; frame N = the video second in each note's "Footage:" line.

| Folder | Source hunter | Our hero |
|---|---|---|
| bjorn | Oath | Breaker (bulwark) |
| breah | Tetra | Tarek (dolm) |
| dancer | Shiv | Sable (thief) |
| dredge | Kingpin | Grimble (dredge) |
| juggernaut | Brall | Kael (juggernaut) |
| linwick | Felix | Cinder (ashwick) |
| mooshmoosh | Elluna | Pip (tender) |
| ostra | Void | Motley (ostra) |
| pin | Myth | Lisette (archer) |
| tamsin | Celeste | Claire (rimewright) |
| venator, venator_ghost | Ghost | Vex (gunslinger) |
| vireo | Joule | Ryzz (mage) |

Fetch only what you need: `git fetch origin ext/hero-ref-footage && git checkout origin/ext/hero-ref-footage -- footage/<id>`. Or sparse-checkout it. Don't merge this branch into main.
