#!/bin/bash
# merge_batch.sh LIST SKIPS : merge every "ext/<branch> <sha>" line of LIST into the current checkout, one --no-ff merge
# each ("Merge ext/<b> <sha9> (merge rush)"). Branches already in HEAD are passed over. Conflicts only in the check
# registry or hand-written docs are union-merged (one entry per line); conflicts in generated files (docs/wiki,
# lint/style baselines, .import, .uid) take ours and are regenerated after the batch. Any other conflict aborts that merge
# and appends "ext/<b> <sha> conflict: <files>" to SKIPS. rerere is off: the shared rr-cache (other sessions' resolutions,
# autoupdate on) would otherwise turn a real conflict into a silent "clean" merge.
# STRUCT docs (tables/prose where a row's meaning depends on its neighbours, docs/DOC_FRAGMENTS.md) are unioned only
# when every clash is two pure additions; a clash where either side changed an existing line stays a conflict, because
# union keeps the stale row next to its fix (11-21: main's HUD.md carried 4 copies of the hud_plate row that way).
set -u
LIST=$1 SKIPS=$2
UNION='^(tools/check_registry\.gd|docs/[^/]+\.md|docs/(heroes|art|decisions)/.*\.md)$'
STRUCT='^docs/(HUD|AUDIO|KIT_PARITY|MOVEMENT_FEEL)\.md$'
OURS='^(MERGE_REPORT\.md|docs/wiki/.*|tools/(style|lint)_baseline\.json|.*\.import|.*\.uid)$'
# add_only OURS BASE THEIRS: 0 when every conflict hunk of the 3-way merge has an empty (blank-only) base side
add_only() {
	git merge-file -p --diff3 "$1" "$2" "$3" | awk '/^<<<<<<< /{s=1;next} s&&/^\|\|\|\|\|\|\| /{s=2;next}
		s&&/^=======$/{s=3;next} s&&/^>>>>>>> /{s=0;next} s==2&&NF{bad=1} END{exit bad}'
}
while read -r b s; do
	[ -n "$b" ] || continue
	git merge-base --is-ancestor "$s" HEAD 2>/dev/null && continue
	git -c rerere.enabled=false merge -q --no-ff -m "Merge $b ${s:0:9} (merge rush)" "$s" >/dev/null 2>&1 && continue
	bad=()
	mapfile -t unmerged < <(git diff --name-only --diff-filter=U)  # read first: git diff can hold index.lock
	for f in "${unmerged[@]}"; do
		if [[ $f =~ $UNION ]]; then
			git show ":2:$f" > "$f.ours" 2>/dev/null; git show ":1:$f" > "$f.base" 2>/dev/null || : > "$f.base"
			git show ":3:$f" > "$f.theirs" 2>/dev/null
			if [[ $f =~ $STRUCT ]] && ! add_only "$f.ours" "$f.base" "$f.theirs"; then
				bad+=("$f")
			else
				git merge-file --union "$f.ours" "$f.base" "$f.theirs" && mv "$f.ours" "$f" && git add "$f"
			fi
			rm -f "$f.ours" "$f.base" "$f.theirs"
		elif [[ $f =~ $OURS ]]; then
			{ git checkout --ours -- "$f" 2>/dev/null || git checkout --theirs -- "$f"; } && git add "$f"
		else
			bad+=("$f")
		fi
	done
	if [ ${#bad[@]} -eq 0 ] && [ -z "$(git diff --name-only --diff-filter=U)" ]; then
		GIT_EDITOR=true git commit -q --no-edit < /dev/null && continue
	fi
	git merge --abort; git clean -fdq  # an aborted merge can leave added files untracked
	echo "$b $s conflict: ${bad[*]:0:6}" >> "$SKIPS"
done < "$LIST"
