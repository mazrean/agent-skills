#!/usr/bin/env bash
# Stop hook: keep the contest driver working until the contest end time.
# End time: $ISUCON_END (anything `date -d` parses) or a line "END: <time>" in NOTES.md.
# Escape hatch: create STOP_OK in the project root to allow stopping.
set -uo pipefail
input=$(cat)
cwd=$(jq -r '.cwd // "."' <<<"$input")

[[ -e $cwd/STOP_OK ]] && exit 0
end=${ISUCON_END:-$(sed -n 's/^END:[[:space:]]*//p' "$cwd/NOTES.md" 2>/dev/null | head -1)}
[[ -n $end ]] || exit 0
end_s=$(date -d "$end" +%s 2>/dev/null) || exit 0
now_s=$(date +%s)
(( now_s < end_s )) || exit 0

left=$(( (end_s - now_s) / 60 ))
jq -n --arg r "Contest still running: ${left} min left (until ${end}). Do not end the turn. Take the next item from the backlog in NOTES.md (or re-measure and add one), and keep going. Report via NOTES.md / notifications, not by stopping. Create STOP_OK only if the user explicitly said to stop." \
  '{decision:"block", reason:$r}'
