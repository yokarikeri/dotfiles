#!/bin/sh
input=$(cat)

# Parse all fields in a single jq call
eval "$(echo "$input" | jq -r '
  @sh "model=\(.model.display_name // "Unknown Model")",
  @sh "cwd=\(.cwd // empty)",
  @sh "used=\(.context_window.used_percentage // empty)",
  @sh "total_in=\(.context_window.total_input_tokens // 0)",
  @sh "total_out=\(.context_window.total_output_tokens // 0)",
  @sh "cost=\(.cost.total_cost_usd // empty)",
  @sh "lines_added=\(.cost.total_lines_added // 0)",
  @sh "lines_removed=\(.cost.total_lines_removed // 0)",
  @sh "rate_5h=\(.rate_limits.five_hour.used_percentage // empty)",
  @sh "rate_7d=\(.rate_limits.seven_day.used_percentage // empty)"
')"

# --- Line 1: Workspace info ---
# Shorten home directory to ~
short_cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

# Git branch (suppress errors if not in a repo)
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Build line 1
line1="\033[34m${short_cwd}\033[0m"
if [ -n "$branch" ]; then
  line1="${line1} | \033[36m⎇ ${branch}\033[0m"
  if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
    line1="${line1} (\033[32m+${lines_added}\033[0m, \033[31m-${lines_removed}\033[0m)"
  fi
elif [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
  line1="${line1} | (\033[32m+${lines_added}\033[0m, \033[31m-${lines_removed}\033[0m)"
fi

printf "%b\n" "$line1"

# --- Line 2: Model & context & cost ---

# Human-readable token count (e.g. 1.2K, 3.5M)
format_tokens() {
  tokens=$1
  if [ "$tokens" -ge 1000000 ]; then
    whole=$((tokens / 1000000))
    frac=$(( (tokens % 1000000) / 100000 ))
    printf "%d.%dM" "$whole" "$frac"
  elif [ "$tokens" -ge 1000 ]; then
    whole=$((tokens / 1000))
    frac=$(( (tokens % 1000) / 100 ))
    printf "%d.%dK" "$whole" "$frac"
  else
    printf "%d" "$tokens"
  fi
}

# Map a single level (0-8) to a braille character
braille_char() {
  case $1 in
    0) printf " " ;;
    1) printf "⡀" ;;
    2) printf "⣀" ;;
    3) printf "⣄" ;;
    4) printf "⣤" ;;
    5) printf "⣦" ;;
    6) printf "⣶" ;;
    7) printf "⣷" ;;
    *) printf "⣿" ;;
  esac
}

# Braille progress bar: maps 0-100% to 3 braille characters (24 levels total)
braille_bar() {
  pct=$1
  if [ -z "$pct" ]; then
    printf "   "
    return
  fi
  pct_int=$(printf "%.0f" "$pct")
  units=$((pct_int * 24 / 100))
  # Ensure >0% shows at least 1 unit
  if [ "$pct_int" -gt 0 ] && [ "$units" -eq 0 ]; then
    units=1
  fi
  c1=$units; [ "$c1" -gt 8 ] && c1=8
  c2=$((units - 8)); [ "$c2" -lt 0 ] && c2=0; [ "$c2" -gt 8 ] && c2=8
  c3=$((units - 16)); [ "$c3" -lt 0 ] && c3=0; [ "$c3" -gt 8 ] && c3=8
  braille_char "$c1"
  braille_char "$c2"
  braille_char "$c3"
}

# Bar color: red >= 80%, green otherwise
bar_color() {
  pct=$1
  if [ -z "$pct" ]; then
    printf "\033[32m"
    return
  fi
  pct_int=$(printf "%.0f" "$pct")
  if [ "$pct_int" -ge 80 ]; then
    printf "\033[31m"
  else
    printf "\033[32m"
  fi
}

total_tokens=$((total_in + total_out))
tokens_str=$(format_tokens "$total_tokens")

# Build line 2
line2="\033[36m${model}\033[0m"

# Context window usage
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  ctx_bar=$(braille_bar "$used")
  ctx_bc=$(bar_color "$used")
  line2="${line2} | Ctx ${ctx_bc}${ctx_bar}\033[0m \033[33m${used_int}%\033[0m"
else
  line2="${line2} | Ctx     --%"
fi

# 5-hour rate limit
if [ -n "$rate_5h" ]; then
  rate_5h_int=$(printf "%.0f" "$rate_5h")
  r5h_bar=$(braille_bar "$rate_5h")
  r5h_bc=$(bar_color "$rate_5h")
  line2="${line2} | 5h ${r5h_bc}${r5h_bar}\033[0m \033[33m${rate_5h_int}%\033[0m"
else
  line2="${line2} | 5h     --%"
fi

# 7-day rate limit
if [ -n "$rate_7d" ]; then
  rate_7d_int=$(printf "%.0f" "$rate_7d")
  r7d_bar=$(braille_bar "$rate_7d")
  r7d_bc=$(bar_color "$rate_7d")
  line2="${line2} | 7d ${r7d_bc}${r7d_bar}\033[0m \033[33m${rate_7d_int}%\033[0m"
else
  line2="${line2} | 7d     --%"
fi

# Cost and tokens
if [ -n "$cost" ]; then
  cost_str=$(printf '$%.2f' "$cost")
  line2="${line2} | Cost \033[33m${cost_str}\033[0m (\033[35m${tokens_str} tokens\033[0m)"
else
  line2="${line2} | \033[35m${tokens_str} tokens\033[0m"
fi

# --- Status check (Claude Code / API) ---
STATUS_CACHE_DIR="${HOME}/.claude/cache"
STATUS_CACHE_FILE="${STATUS_CACHE_DIR}/status.json"
STATUS_CACHE_TTL=60

[ -d "$STATUS_CACHE_DIR" ] || mkdir -p "$STATUS_CACHE_DIR" 2>/dev/null

cache_mtime=$(stat -c %Y "$STATUS_CACHE_FILE" 2>/dev/null \
              || stat -f %m "$STATUS_CACHE_FILE" 2>/dev/null \
              || echo 0)
now=$(date +%s)
cache_age=$((now - cache_mtime))

if [ "$cache_age" -ge "$STATUS_CACHE_TTL" ]; then
  # Fire-and-forget background refresh; never blocks render
  (
    curl -fsS --max-time 3 \
      "https://status.claude.com/api/v2/summary.json" \
      -o "${STATUS_CACHE_FILE}.tmp" 2>/dev/null \
    && mv "${STATUS_CACHE_FILE}.tmp" "$STATUS_CACHE_FILE"
  ) >/dev/null 2>&1 &
fi

status_line=""
if [ -s "$STATUS_CACHE_FILE" ]; then
  status_line=$(jq -r '
    def relevant: ["Claude Code", "Claude API (api.anthropic.com)"];
    ( [ .incidents[]?
        | select( any(.components[]?.name; . as $n | relevant | index($n)) )
        | "I\t\(.impact)\t\(.status)\t\(.name)" ] ) as $inc
    | ( [ .components[]?
          | select(.name as $n | relevant | index($n))
          | select(.status != "operational")
          | "C\t\(.status)\t\(.name)" ] ) as $deg
    | if ($inc | length) > 0 then $inc[0]
      elif ($deg | length) > 0 then $deg[0]
      else empty end
  ' "$STATUS_CACHE_FILE" 2>/dev/null)
fi

line3=""
if [ -n "$status_line" ]; then
  kind=$(printf '%s' "$status_line" | cut -f1)
  if [ "$kind" = "I" ]; then
    impact=$(printf '%s' "$status_line" | cut -f2)
    istatus=$(printf '%s' "$status_line" | cut -f3)
    iname=$(printf '%s' "$status_line" | cut -f4 | cut -c1-60)
    case "$impact" in
      critical) color="\033[31m" ;;
      maintenance) color="\033[36m" ;;
      *) color="\033[33m" ;;
    esac
    line3="${color}⚠ ${istatus}: ${iname}\033[0m"
  else
    cstatus=$(printf '%s' "$status_line" | cut -f2)
    cname=$(printf '%s' "$status_line" | cut -f3)
    case "$cstatus" in
      major_outage) color="\033[31m" ;;
      under_maintenance) color="\033[36m" ;;
      *) color="\033[33m" ;;
    esac
    line3="${color}⚠ Claude Status: ${cname}: ${cstatus}\033[0m"
  fi
fi

# --- Output ---
if [ -n "$line3" ]; then
  printf "%b\n" "$line2"
  printf "%b" "$line3"
else
  printf "%b" "$line2"
fi
