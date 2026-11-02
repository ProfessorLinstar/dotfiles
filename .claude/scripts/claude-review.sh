#!/bin/bash
# TODO(andywang): add comment

args=("$@")
session_id=""
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    -r|--resume) session_id="${args[i+1]}" ;;
    --resume=*) session_id="${args[i]#--resume=}" ;;
  esac
done

transcript=""
if [ -n "$session_id" ]; then
  transcript="$(compgen -G "$HOME/.claude/projects/*/$session_id.jsonl" | head -1)"
fi

if [ -n "$transcript" ]; then
  turns="${CLAUDE_REVIEW_TURNS:-20}"
  title="$(jq -r 'select(.type == "custom-title" or .type == "ai-title") | .customTitle // .aiTitle' "$transcript" | tail -1)"
  printf '\e[1;35m── %s (%s) ──\e[0m\n\n' "${title:-Claude session}" "$session_id"
  jq -j '
    select(.isSidechain != true and .isMeta != true)
    | if .type == "user" and (.message.content | type) == "string" then
        select(.message.content | test("^<(command|local-command|system-reminder)") | not)
        | "\u001b[1;36m> \(.message.content)\u001b[0m\n\n\u0000"
      elif .type == "assistant" then
        .message.content[]? | select(.type == "text") | "\(.text)\n\n\u0000"
      else empty end
  ' "$transcript" | awk -v RS='\0' -v ORS='' -v n="$turns" \
    '{ buf[NR % n] = $0 } END { for (i = NR - n + 1; i <= NR; i++) if (i > 0) print buf[i % n] }'
else
  printf '\e[33mNo transcript found for session %s\e[0m\n\n' "${session_id:-<none>}"
fi

exec claude "${args[@]}"
