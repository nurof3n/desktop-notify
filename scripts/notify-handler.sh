#!/usr/bin/env bash
# Usage: notify-handler.sh MESSAGE SOUND_FILE [VOLUME_0_TO_100] < hook-input.json

notify_args=(-a "Claude Code" -u normal)

# Prints the PIDs of this process and of its parents, nearest first
parent_pids() {
  local pid=$$
  while [ "${pid:-0}" -gt 1 ]; do
    echo "$pid"
    pid=$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null)
  done
}

# Prints the desktop type if the plugin can focus windows on it
detect_desktop() {
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null && command -v jq >/dev/null; then
    echo hyprland
  elif [ -n "${SWAYSOCK:-}" ] && command -v swaymsg >/dev/null && command -v jq >/dev/null; then
    echo sway
  elif [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null && command -v jq >/dev/null; then
    echo niri
  elif [ -z "${WAYLAND_DISPLAY:-}" ] && [ -n "${DISPLAY:-}" ] && command -v wmctrl >/dev/null; then
    echo x11
  fi
}

# Prints "PID WINDOW_ID" for each window; on Hyprland, the most recently focused window comes first
list_windows() {
  case "$1" in
    hyprland) hyprctl clients -j | jq -r 'sort_by(.focusHistoryID < 0, .focusHistoryID) | .[] | "\(.pid) \(.address)"' ;;
    sway) swaymsg -t get_tree | jq -r '.. | objects | select(.type == "con" or .type == "floating_con") | select(.pid != null) | "\(.pid) \(.id)"' ;;
    niri) niri msg --json windows | jq -r '.[] | select(.pid != null) | "\(.pid) \(.id)"' ;;
    x11) wmctrl -lp | awk '{ print $3, $1 }' ;;
  esac
}

# Prints "PID WINDOW_ID" for the window of the nearest parent process
find_window() {
  local windows pid line
  windows=$(list_windows "$1" 2>/dev/null) || return
  for pid in $(parent_pids); do
    line=$(awk -v p="$pid" '$1 == p { print; exit }' <<<"$windows")
    if [ -n "$line" ]; then
      echo "$line"
      return
    fi
  done
}

# Focuses the window only if it still belongs to the same process
focus_window() {
  local desktop="$1" pid="$2" id="$3"
  list_windows "$desktop" 2>/dev/null | grep -qxF "$pid $id" || return
  case "$desktop" in
    hyprland)
      [ "$(hyprctl dispatch "hl.dsp.focus({ window = \"address:$id\" })")" = ok ] ||
        hyprctl dispatch focuswindow "address:$id"
      ;;
    sway) swaymsg "[con_id=$id] focus" ;;
    niri) niri msg action focus-window --id "$id" ;;
    x11) wmctrl -ia "$id" ;;
  esac
}

# Click waiter mode: shows the notification, waits at most 1 hour for a click, then focuses the window
if [ "${1:-}" = --await-click ]; then
  pidfile="$2"
  action=$(timeout 1h notify-send "${notify_args[@]}" -A default=Focus "Claude Code" "$3")
  [ "$action" = default ] && focus_window "$4" "$5" "$6"
  [ -n "$pidfile" ] && [ "$(cat "$pidfile" 2>/dev/null)" = "$$" ] && rm -f "$pidfile"
  exit 0
fi

message="$1"
sound="$2"
volume="${3:-100}"
project_dir="${CLAUDE_PROJECT_DIR:-}"

[[ $volume =~ ^[0-9]{1,3}$ ]] || volume=100
volume=$((10#$volume > 100 ? 100 : 10#$volume))

[ -t 0 ] || input=$(cat)
session_id=$(sed -n 's/.*"session_id" *: *"\([A-Za-z0-9-]*\)".*/\1/p' <<<"${input:-}" | head -n 1)

body="$message"
if [ -n "$project_dir" ]; then
  # Notification servers read the body as markup
  project_name=$(basename "$project_dir" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
  body+=$'\n\n'"$project_name"
fi

window=""
desktop=$(detect_desktop)
if [ -n "$desktop" ] && notify-send --help 2>&1 | grep -q -- '--action'; then
  window=$(find_window "$desktop")
fi

pidfile=""
if [ -n "$session_id" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  # Only the newest notification of a session waits for a click
  pidfile="$XDG_RUNTIME_DIR/desktop-notify-$session_id.pid"
  old=$(cat "$pidfile" 2>/dev/null)
  if [[ $old =~ ^[0-9]+$ ]] && [ -r "/proc/$old/cmdline" ]; then
    mapfile -d '' -t old_argv <"/proc/$old/cmdline"
    if [ "${old_argv[1]:-}" = "$0" ] && [ "${old_argv[2]:-}" = --await-click ]; then
      pkill -s "$old"
    fi
  fi
  rm -f "$pidfile"
fi

if [ -n "$window" ]; then
  read -r window_pid window_id <<<"$window"
  # The waiter is not a process group leader, so setsid does not fork and $! is the PID of the new session
  setsid "$BASH" "$0" --await-click "$pidfile" "$body" "$desktop" "$window_pid" "$window_id" \
    </dev/null >/dev/null 2>&1 &
  [ -n "$pidfile" ] && echo $! >"$pidfile"
else
  notify-send "${notify_args[@]}" "Claude Code" "$body" >/dev/null 2>&1 &
fi

if [ -n "$sound" ] && [ -f "$sound" ]; then
  if command -v paplay >/dev/null 2>&1; then
    # paplay uses 65536 for 100%
    paplay --volume=$((volume * 65536 / 100)) "$sound" >/dev/null 2>&1 &
  elif command -v pw-play >/dev/null 2>&1; then
    pw-play --volume="$(awk -v v="$volume" 'BEGIN { print v / 100 }')" "$sound" >/dev/null 2>&1 &
  fi
fi

exit 0
