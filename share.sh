#!/usr/bin/env bash
set -euo pipefail

# -------- Colors (portable) --------
COLOR_CMD=$'\033[1;32m' # Green for the command prompt
COLOR_OUT=$'\033[0;36m' # Cyan for the output
NC=$'\033[0m'           # No Color

# -------- Config (override via flags) --------
NAME="${NAME:-Dikpaal}"
COMPANY="${COMPANY:-Sendbird}"
ROLE="${ROLE:-AI Engineering Intern}"
START="${START:-Fall 2025}"
LOGO="${LOGO:-}"            # path to image or pre-rendered ANSI file
SPEED="${SPEED:-30}"        # chars per second for typing
PAUSE="${PAUSE:-0.5}"       # pause between beats
TYPE_RESULTS="${TYPE_RESULTS:-no}"  # yes/no — type results too?

# -------- Flags --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --company) COMPANY="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --start) START="$2"; shift 2 ;;
    --logo) LOGO="$2"; shift 2 ;;
    --speed) SPEED="$2"; shift 2 ;;
    --type-results) TYPE_RESULTS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# -------- Portable helpers --------
hide_cursor() { tput civis || true; }
show_cursor() { tput cnorm || true; }
reset_screen() { tput sgr0 || true; }
trap 'reset_screen; show_cursor' EXIT

center() {
  local text="$1"
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local pad=$(( (cols - ${#text}) / 2 ))
  printf "%*s%s\n" $((pad>0?pad:0)) "" "$text"
}

# macOS/Bash 3.2-safe "yes" check (no ${var,,})
is_yes() {
  case "$1" in
    y|Y|yes|Yes|YES|true|TRUE|1) return 0 ;;
    *) return 1 ;;
  esac
}

# Precompute a smooth per-char delay (one time only)
calc_interval() {
  if command -v awk >/dev/null 2>&1; then
    awk -v s="$SPEED" 'BEGIN{ if (s<=0) s=30; printf "%.6f", 1.0/s }'
  else
    printf "%.6f" "0.033" # ~30 cps
  fi
}
TYPING_INTERVAL="$(calc_interval)"

# Smooth typing: pv if available, light bash loop otherwise.
type_out() {
  local msg="$1"
  if command -v pv >/dev/null 2>&1; then
    printf "%s" "$msg" | pv -qL "$SPEED"
  else
    local i c len=${#msg}
    for (( i=0; i<len; i++ )); do
      c="${msg:i:1}"
      printf "%s" "$c"
      sleep "$TYPING_INTERVAL"
    done
  fi
}

typln() { type_out "$1"; printf "\n"; }

spinner() {
  local pid=$1
  local frames='|/-\'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r[%c] " "${frames:i++%${#frames}:1}"
    sleep 0.08
  done
  printf "\r    \r"
}

progress_bar() {
  local total=${1:-30}
  local i pct cols barw done left

  # Terminal width and a safe bar width so we don't wrap
  cols=$(tput cols 2>/dev/null || echo 80)
  # Reserve room for brackets, spaces, and " 100%"
  barw=$(( cols - 10 ))
  (( barw < 10 )) && barw=10

  for (( i=0; i<=total; i++ )); do
    pct=$(( 100 * i / total ))

    # Build bar strings without seq (faster, less noisy)
    done=$(printf "%0.s#" $(jot - 1 "$i" 2>/dev/null || seq 1 "$i"))
    left=$(printf "%0.s-" $(jot - 1 $((total - i)) 2>/dev/null || seq 1 $((total - i))))

    # Trim to bar width in case of tiny terminals
    done=${done:0:$barw}
    left=${left:0:$(( barw - ${#done} ))}

    # \r = carriage return, \033[K = clear to end-of-line (kills leftovers)
    printf "\r\033[K[%s%s] %3d%%" "$done" "$left" "$pct"

    # Smooth tick tied to SPEED, clamped
    local tick="0.03"
    if command -v awk >/dev/null 2>&1; then
      tick=$(awk -v s="${SPEED:-30}" 'BEGIN { d=0.9/s; if(d<0.01)d=0.01; if(d>0.06)d=0.06; printf "%.3f", d }')
    fi
    sleep "$tick"
  done

  printf "\n"
}

print_logo() {
  [[ -z "$LOGO" ]] && return 0
  echo
  if [[ "$LOGO" == *.ans || "$LOGO" == *.ansi || "$LOGO" == *.txt ]]; then
    cat "$LOGO"
  elif command -v chafa >/dev/null 2>&1; then
    chafa --symbols vhalf --size "$(tput cols)x20" "$LOGO"
  elif command -v jp2a >/dev/null 2>&1; then
    jp2a --width="$(tput cols)" "$LOGO"
  else
    echo "[hint] Install chafa or jp2a to render images in terminal."
  fi
  echo
}

# Types the command, then shows the result (typed or instant based on flag)
fake_cmd_and_result() {
  local cmd="$1"
  local result="$2"

  printf "${COLOR_CMD}$ ${NC}"
  type_out "$cmd"
  printf "\n"

  if is_yes "$TYPE_RESULTS"; then
    printf "${COLOR_OUT}"
    type_out "$result"
    printf "${NC}\n"
  else
    printf "${COLOR_OUT}%s${NC}\n" "$result"
  fi
}

# -------- Scene --------
clear
hide_cursor

typln "Initializing onboarding sequence…"
progress_bar 34
sleep "$PAUSE"

clear
if command -v figlet >/dev/null 2>&1; then
  if command -v lolcat >/dev/null 2>&1; then
    figlet -f Standard "Joining $COMPANY" | lolcat
  else
    figlet -f Standard "Joining $COMPANY"
  fi
else
  center "=============================="
  center "       Happy to announce...       "
  center "=============================="
fi
sleep "$PAUSE"

fake_cmd_and_result "whoami" "$NAME"
sleep "$PAUSE"

fake_cmd_and_result "echo \"$ROLE\"" "$ROLE"
sleep "$PAUSE"

fake_cmd_and_result "date -u" "$(date -u)"
sleep "$PAUSE"

fake_cmd_and_result "echo \"Start: $START\"" "Start: $START"
sleep "$PAUSE"

typln ""
typln "Cloning mindset…"
progress_bar 28
typln "✓ Curiosity pulled"
typln "✓ Shipping enabled"
typln "✓ Payments brain installed"
sleep "$PAUSE"

typln ""
typln "Final message:"
typln "\"Thrilled to join $COMPANY. Let’s build cool things.\""
sleep "$PAUSE"

print_logo
sleep "$PAUSE"


typln ""
typln "Done."
sleep 0.3