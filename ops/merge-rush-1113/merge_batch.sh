#!/bin/bash
# merge_batch.sh LIST SKIPS : merge every "ext/<branch> <sha>" line of LIST into the current checkout, one --no-ff merge
# each ("Merge ext/<b> <sha9> (merge rush)"). Branches already in HEAD are passed over. Conflicts only in the check
# registry or hand-written docs are union-merged (one entry per line); conflicts in generated files (docs/wiki,
# lint/style baselines, .import) take ours and are regenerated after the batch. Any other conflict aborts that merge
# and appends "ext/<b> <sha> conflict: <files>" to SKIPS.
set -u
LIST=$1 SKIPS=$2
UNION='^(tools/check_registry\.gd|docs/[^/]+\.md|docs/(heroes|art|decisions)/.*\.md)$'
OURS='^(MERGE_REPORT\.md|docs/wiki/.*|tools/(style|lint)_baseline\.json|.*\.import)$'
while read -r b s; do
	[ -n "$b" ] || continue
	git merge-base --is-ancestor "$s" HEAD 2>/dev/null && continue
	git merge -q --no-ff -m "Merge $b ${s:0:9} (merge rush)" "$s" >/dev/null 2>&1 && continue
	bad=()
	while read -r f; do
		if [[ $f =~ $UNION ]]; then
			git show ":2:$f" > "$f.ours" 2>/dev/null; git show ":1:$f" > "$f.base" 2>/dev/null || : > "$f.base"
			git show ":3:$f" > "$f.theirs" 2>/dev/null
			git merge-file --union "$f.ours" "$f.base" "$f.theirs" && mv "$f.ours" "$f" && git add "$f"
			rm -f "$f.ours" "$f.base" "$f.theirs"
		elif [[ $f =~ $OURS ]]; then
			{ git checkout --ours -- "$f" 2>/dev/null || git checkout --theirs -- "$f"; } && git add "$f"
		else
			bad+=("$f")
		fi
	done < <(git diff --name-only --diff-filter=U)
	if [ ${#bad[@]} -eq 0 ] && [ -z "$(git diff --name-only --diff-filter=U)" ]; then
		git commit -q --no-edit && continue
	fi
	git merge --abort; git clean -fdq  # an aborted merge can leave added files untracked
	echo "$b $s conflict: ${bad[*]:0:6}" >> "$SKIPS"
done < "$LIST"
