#!/usr/bin/env bash

input=$(cat)

# --- Line 1: GitHub repo + branch (or shortened dir + branch) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Shorten the path: replace $HOME with ~, then shorten intermediate dirs
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

short_cwd=$(echo "$short_cwd" | awk -F'/' '{
  if (NF <= 3) {
    print $0
  } else {
    out = $1
    for (i = 2; i < NF; i++) {
      out = out "/" substr($i, 1, 1)
    }
    out = out "/" $NF
    print out
  }
}')

# Try to get git info: repo toplevel, remote, and branch
git_branch=""
github_repo=""
git_toplevel=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)

if [ -n "$git_toplevel" ]; then
  # Get branch
  git_out=$(git -C "$git_toplevel" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$git_out" ]; then
    git_branch="$git_out"
  fi

  # Get GitHub repo (org/repo) from remote
  remote_url=$(git -C "$git_toplevel" --no-optional-locks remote get-url origin 2>/dev/null)
  if [ -n "$remote_url" ]; then
    # Extract org/repo from SSH or HTTPS URL, strip .git suffix
    github_repo=$(echo "$remote_url" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s/\.git$//')
  fi
fi

if [ -n "$github_repo" ]; then
  line1="\033[1;35m${github_repo}\033[0m"
  if [ -n "$git_branch" ]; then
    line1="${line1} \033[0;36m(${git_branch})\033[0m"
  fi
  # Append shortened cwd in dim
  line1="${line1}  \033[0;90m${short_cwd}\033[0m"
  printf "%b\n" "$line1"
else
  # No git repo — fallback to just shortened dir
  printf "\033[1;33m%s\033[0m\n" "$short_cwd"
fi

# --- Line 2: Model name + Claude Code version ---
model=$(echo "$input" | jq -r '.model.display_name // ""')
version=$(echo "$input" | jq -r '.version // ""')

printf "\033[1;34m%s\033[0m  \033[0;37mv%s\033[0m\n" "$model" "$version"

# --- Line 3: Context window usage progress bar ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  # Round to integer
  used_int=$(printf "%.0f" "$used_pct")
  bar_width=20
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))

  bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do  bar="${bar}░"; done

  # Color: green < 50%, yellow < 80%, red >= 80%
  if [ "$used_int" -ge 80 ]; then
    color="\033[1;31m"
  elif [ "$used_int" -ge 50 ]; then
    color="\033[1;33m"
  else
    color="\033[1;32m"
  fi

  printf "${color}[%s]\033[0m \033[0;37m%d%% used\033[0m\n" "$bar" "$used_int"
else
  printf "\033[0;37m[%s] no data\033[0m\n" "$(printf '░%.0s' $(seq 1 20))"
fi

# --- Line 4: Active MCP servers ---
mcp_servers=$(echo "$input" | jq -r '.mcp_servers // [] | map(select(.status == "connected") | .name) | join(", ")')

if [ -n "$mcp_servers" ] && [ "$mcp_servers" != "null" ]; then
  printf "\033[1;33mMCP\033[0m \033[0;32m%s\033[0m\n" "$mcp_servers"
fi
