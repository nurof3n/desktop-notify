#!/usr/bin/env bash
# Usage: notify-handler.sh MESSAGE SOUND_FILE [VOLUME_0_TO_100]

message="$1"
sound="$2"
volume="${3:-100}"
project_dir="${CLAUDE_PROJECT_DIR:-}"

[[ $volume =~ ^[0-9]{1,3}$ ]] || volume=100
volume=$((10#$volume > 100 ? 100 : 10#$volume))

body="$message"
if [ -n "$project_dir" ]; then
  # Notification servers read the body as markup
  project_name=$(basename "$project_dir" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
  body+=$'\n\n'"$project_name"
fi

notify-send -a "Claude Code" -u normal "Claude Code" "$body" >/dev/null 2>&1 &

if [ -n "$sound" ] && [ -f "$sound" ]; then
  if command -v paplay >/dev/null 2>&1; then
    # paplay uses 65536 for 100%
    paplay --volume=$((volume * 65536 / 100)) "$sound" >/dev/null 2>&1 &
  elif command -v pw-play >/dev/null 2>&1; then
    pw-play --volume="$(awk -v v="$volume" 'BEGIN { print v / 100 }')" "$sound" >/dev/null 2>&1 &
  fi
fi

exit 0
