# 0060: Every Boki has a sex from the moment it hatches

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save format

## Problem
Owner (11-11): the hatch reveal should show the Boki's sex and say he or she, never "it". The first egg's reveal had no record yet (`Save.new_kin` ran only after naming), so it showed no sex and its lines said "it". Old saves got their sex in the v2 -> v3 step from a 50/50 roll, so a kind that is all one sex (Hivara, Mossgrade, Buckleron: `content/rules/boki_quirks.json` female_share) could hold the wrong one.

## Options
1. Leave old records alone and fix the sex on read (`Unique.sex`). Cons: the saved record and what the game shows disagree.
2. A save step that writes the sex once, by the kind's share, and puts a single-sex kind right.

## Decision
Option 2. Save v13 -> v14 runs the same step as v2 -> v3 (`_migrate_sexes`, `Unique.ensure_sex`), which now draws by the kind's share (`BokiQuirks.sex_for`) and overrides a wrong sex on a single-sex kind. The first egg builds its record as the Boki pops out (`Hatch._hatched_rec`), so the reveal, the name card and the save all use one sex. Text says he / she through `Unique.pronouns(rec)` templates ("{He}'s looking at you").

## Consequences
save.gd (VERSION 14), unique.gd, hatch.gd, kin_reveal.gd, and the Boki text that names one Boki (burrow, bond, About page, Boki actions in boki_lines.json). No Net change: kin records already sync whole. Checks: --hatch-check (the "it" scan, the sex mark), --unique-check (the v14 step).
