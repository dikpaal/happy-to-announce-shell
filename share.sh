#!/usr/bin/env bash
set -euo pipefail

# Set both tab and window titles (OSC 1 + OSC 2)
set_title() {
  local t="$1"
  printf "\033]1;%s\007" "$t"   # tab
  printf "\033]2;%s\007" "$t"   # window
}

# =================== THEME (calm, modern) ===================
# 256-color friendly soft blues/purples; falls back to basic colors when needed
supports_256() { tput colors >/dev/null 2>&1 && [ "$(tput colors)" -ge 256 ]; }
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'

if supports_256; then
  C_PRIMARY() { printf '\033[38;5;%sm' "${1}"; }              # gradient step
  C_SUB=$'\033[38;5;247m'                                     # soft gray
  C_ACCENT=$'\033[38;5;81m'                                   # cyan-ish
  C_OK=$'\033[38;5;120m'                                      # mint
  C_CMD=$'\033[38;5;45m'                                      # calm blue
  GRADIENT=(69 68 67 104 141 140 139 138 99 69)
else
  C_PRIMARY() { printf '\033[36m'; }                           # cyan
  C_SUB=$'\033[37m'
  C_ACCENT=$'\033[36m'
  C_OK=$'\033[32m'
  C_CMD=$'\033[34m'
  GRADIENT=(36 36 36 36 36 36 36 36 36 36)
fi

# =================== CONFIG (flags or env) ===================
NAME="${NAME:-Dikpaal Patel}"
MSG="${MSG:-Excited to join the AI team at}"
COMPANY="${COMPANY:-Sendbird}"
ROLE="${ROLE:-AI Engineering Intern}"
START="${START:-Fall 2025}"
# FIX: LOGO must be set via the --logo flag for it to appear.
# Example: --logo "/path/to/your/logo.png" or --logo "/path/to/art.ans"
LOGO="${LOGO:-}"
SPEED="${SPEED:-50}"                 # <<<<<<< MODIFIED: Slower typing speed (chars per second)
PAUSE="${PAUSE:-0.5}"                # short beats
TYPE_RESULTS="${TYPE_RESULTS:-no}"   # yes/no — type results too?
QUIET_BORDER="${QUIET_BORDER:-no}"   # yes to hide borders
BAR_STEPS="${BAR_STEPS:-34}"         # main bar resolution
USE_CURSOR="${USE_CURSOR:-yes}"   # yes/no — draw a faux cursor when typing
CURSOR_SYM="${CURSOR_SYM:-▌}"     # try ▉ █ ▍ | _


# call early, and again right before long animations
set_title "Joining $COMPANY — $NAME"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --company) COMPANY="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --start) START="$2"; shift 2 ;;
    --logo) LOGO="$2"; shift 2 ;;
    --speed) SPEED="$2"; shift 2 ;;
    --type-results) TYPE_RESULTS="$2"; shift 2 ;;
    --quiet-border) QUIET_BORDER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# =================== TTY HELPERS ===================
hide_cursor() { tput civis || true; }
show_cursor() { tput cnorm || true; }
reset_screen() { tput sgr0 || true; }
trap 'reset_screen; show_cursor; printf "\n"' EXIT

cols() { tput cols 2>/dev/null || echo 80; }
center() {
  local text="$1"; local w; w=$(cols)
  local raw="${text//\e\[[0-9;]*[a-zA-Z]/}"                    # strip ANSI for width calc
  local pad=$(( (w - ${#raw}) / 2 )); ((pad<0)) && pad=0
  printf "%*s%s\n" "$pad" "" "$text"
}

is_yes() { case "$1" in y|Y|yes|Yes|YES|true|TRUE|1) return 0;; *) return 1;; esac; }

calc_interval() {
  if command -v awk >/dev/null 2>&1; then
    awk -v s="$SPEED" 'BEGIN{ if (s<=0) s=30; printf "%.6f", 1.0/s }'
  else
    printf "%.6f" "0.033"
  fi
}
TYPING_INTERVAL="$(calc_interval)"

type_out() {
  local msg="$1"

  if is_yes "$USE_CURSOR"; then
    local rest="$msg" chunk c j endch

    while [[ -n "$rest" ]]; do
      # If starts with ESC [
      if [[ "${rest:0:1}" == $'\x1b' && "${rest:1:1}" == "[" ]]; then
        # Consume until final byte in @..~
        j=2
        while (( j < ${#rest} )); do
          endch="${rest:j:1}"
          # Final bytes are ASCII 0x40..0x7E => [@-~]
          if [[ "$endch" =~ [@-~] ]]; then
            (( j++ ))
            chunk="${rest:0:j}"
            printf "%s" "$chunk"
            rest="${rest:j}"
            break
          fi
          (( j++ ))
        done
        # If we didn't find a final byte, just print what we have and bail
        if (( j >= ${#rest} )); then
          printf "%s" "$rest"
          rest=""
        fi
        continue
      fi

      # Normal visible char with faux cursor
      c="${rest:0:1}"
      rest="${rest:1}"
      printf "%s%s" "$c" "$CURSOR_SYM"
      sleep "$TYPING_INTERVAL"
      printf "\b"
    done
    return
  fi

  # No cursor mode: keep pv fast path
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

flush_cursor() { is_yes "$USE_CURSOR" && printf " \b"; }

# FIX: The original typln function was incorrect.
# It ignored its arguments and only printed a newline.
# This corrected version calls type_out() to print the message.
typln() {
  type_out "$@"
  flush_cursor
  printf "\n"
}

# =================== ANIMATIONS ===================
fade_in_line() {
  local s="$1"
  # animate on the same line, then end with a single newline
  printf "\r\033[K%s%s" "$C_DIM" "$s"; sleep 0.08
  printf "\r\033[K%s%s" "$C_RESET" "$s"; sleep 0.08
  printf "\r\033[K%s%s%s\n" "$C_BOLD" "$s" "$C_RESET"
}

pulse_line() {
  local s="$1"
  # gentle pulse across three shades, but only one final line printed
  printf "\r\033[K%s%s%s" "$(C_PRIMARY 141)" "$s" "$C_RESET"; sleep 0.06
  printf "\r\033[K%s%s%s" "$(C_PRIMARY 99)"  "$s" "$C_RESET"; sleep 0.06
  printf "\r\033[K%s%s%s\n" "$(C_PRIMARY 69)"  "$s" "$C_RESET"
}

spinner() {
  local pid=$1; local frames='⠋⠙⠸⠴⠦⠇'; local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s[%s]%s " "$(C_PRIMARY ${GRADIENT[i%${#GRADIENT[@]}]})" "${frames:i++%${#frames}:1}" "$C_RESET"
    sleep 0.08
  done
  printf "\r\033[K"
}

gradient_bar() {
  # A no-wrap progress bar with gradient and accurate % at 100.
  local steps=${1:-30}
  local i pct w filled remain seg col
  w=$(cols); ((w=w-10)); ((w<10)) && w=10

  for (( i=0; i<=steps; i++ )); do
    pct=$(( 100 * i / steps ))
    filled=$(( w * i / steps ))
    remain=$(( w - filled ))
    seg=""
    if (( filled > 0 )); then
      # build gradient left->right across GRADIENT palette
      local j; seg=""
      for (( j=0; j<filled; j++ )); do
        col_idx=$(( (j * ${#GRADIENT[@]}) / (w==0?1:w) ))
        col_idx=$(( col_idx >= ${#GRADIENT[@]} ? ${#GRADIENT[@]}-1 : col_idx ))
        seg+=$(printf "%s━" "$(C_PRIMARY ${GRADIENT[col_idx]})")
      done
    fi
    printf "\r\033[K[%s%s%s]%s %3d%%" "$seg" "$C_SUB" "$(printf '%*s' "$remain" | tr ' ' '·')" "$C_RESET" "$pct"

    # tie tick to SPEED; clamp for smoothness
    local tick="0.03"
    if command -v awk >/dev/null 2>&1; then
      tick=$(awk -v s="${SPEED:-30}" 'BEGIN{ d=0.9/s; if(d<0.010)d=0.010; if(d>0.060)d=0.060; printf "%.3f", d }')
    fi
    sleep "$tick"
  done
  printf "\n"
}

soft_rule() {
  is_yes "$QUIET_BORDER" && return 0
  local w; w=$(cols)
  local line=""
  local i col
  for (( i=0; i<w; i++ )); do
    col=${GRADIENT[i%${#GRADIENT[@]}]}
    line+=$(printf "%s─" "$(C_PRIMARY $col)")
  done
  printf "%s\n%s%s\n" "$line" "$C_RESET" ""
}

print_logo() {
  [[ -z "$LOGO" ]] && return 0
  echo
  if [[ "$LOGO" == *.ans || "$LOGO" == *.ansi || "$LOGO" == *.txt ]]; then
    cat "$LOGO"
  elif command -v chafa >/dev/null 2>&1; then
    chafa --symbols vhalf --size "$(cols)x20" "$LOGO"
  elif command -v jp2a >/dev/null 2>&1; then
    jp2a --width="$(cols)" "$LOGO"
  else
    printf "%s[hint]%s Install %schafa%s or %sjp2a%s to render images in terminal.\n" "$C_SUB" "$C_RESET" "$C_ACCENT" "$C_RESET" "$C_ACCENT" "$C_RESET"
  fi
  echo
}

fake_cmd_and_result() {
  local cmd="$1" result="$2"
  printf "%s$ %s%s" "$C_CMD" "$C_RESET" ""
  type_out "$cmd"
  flush_cursor; printf "\n"
  if is_yes "$TYPE_RESULTS"; then
    printf "%s" "$C_SUB"; type_out "$result"; printf "%s\n" "$C_RESET"
  else
    printf "%s%s%s\n" "$C_SUB" "$result" "$C_RESET"
  fi
}

progress_with_caption() {
  local caption="$1"
  local steps="${2:-30}"

  # 1) Caption
  printf "%s%s%s\n" "$C_SUB" "$caption" "$C_RESET"

  # 2) Progress bar on next line
  gradient_bar "$steps"

  # 3) Animate the BAR LINE itself:
  # move to bar line, replace with a collapsing pill → checkmark → fade
  tput cuu 1 2>/dev/null || true

  # Build frames: collapsing bar
  local w; w=$(cols); ((w=w-10)); ((w<10)) && w=10
  local i dec frame
  for (( i=w; i>=0; i-= (w/8>0?w/8:1) )); do
    printf "\r\033[K["
    # left side fades to nothing
    printf "%s" "$(C_PRIMARY 99)"
    printf "%*s" "$i" | tr ' ' '━'
    printf "%s]" "$C_RESET"
    sleep 0.03
  done

  # Final pill with check + shimmer
  local frames=(
    "$(printf "%s[%s✓%s] %sAll set%s" "$(C_PRIMARY 141)" "$C_BOLD" "$C_RESET" "$C_SUB" "$C_RESET")"
    "$(printf "%s[%s✓%s] %sAll set%s" "$(C_PRIMARY 99)"  "$C_BOLD" "$C_RESET" "$C_SUB" "$C_RESET")"
    "$(printf "%s[%s✓%s] %sAll set%s" "$C_OK"            "$C_BOLD" "$C_RESET" "$C_SUB" "$C_RESET")"
  )
  for frame in "${frames[@]}"; do
    printf "\r\033[K%s" "$frame"
    sleep 0.06
  done

  # 4) Optional: fade the pill away to keep it clean
  sleep 0.20
  printf "\r\033[K%s[%s✓%s] All set%s" "$C_DIM" "$C_BOLD" "$C_RESET" "$C_RESET"
  sleep 0.15
  printf "\r\033[K"   # clear the line

  # 5) Move cursor down to resume flow under the old bar
  tput cud 1 2>/dev/null || true
}

# =================== SCENE ===================

# call early, and again right before long animations
set_title "Joining $COMPANY — $NAME"
clear
hide_cursor

# Terminal title (nice touch)
printf "\033]0;Joining %s — %s\007" "$COMPANY" "$NAME"

fade_in_line "${C_SUB}Initializing onboarding sequence…$C_RESET"
gradient_bar "$BAR_STEPS"
sleep "$PAUSE"

clear
# banner "Joining $COMPANY"
sleep "$PAUSE"
soft_rule

fake_cmd_and_result "whoami" "$NAME"; sleep "$PAUSE"
fake_cmd_and_result "echo position" "$ROLE"; sleep "$PAUSE"
fake_cmd_and_result "echo start_date" "$START"; sleep "$PAUSE"

soft_rule
# fade_in_line "${C_SUB}User message:${C_RESET}"
# This will now correctly type out the message
fake_cmd_and_result "echo user_message" "$MSG"; sleep "$PAUSE"
# typln "${C_BOLD}Excited to join... ${C_RESET}"
# sleep "$PAUSE"

# This will print the logo if the --logo flag is used
print_logo
sleep "$PAUSE"

soft_rule
progress_with_caption "Special thanks to..." 28

# Run a background faux task and show spinner
(
  sleep 1.0
  :
) &
spinner $!

pulse_line "✓ Jennifer Cole"
pulse_line "✓ Kibeom Lee"
pulse_line "✓ Sher Najafi"
sleep "$PAUSE"

soft_rule
fade_in_line "${C_OK}Done.${C_RESET}"
sleep 0.3