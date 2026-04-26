# =========================================
#  ZSH Configuration — Ubuntu WSL + OMZ
# =========================================

# ----- 1. Environment Detection -----

export IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
  export IS_WSL=1
fi

# ----- 1b. SSH Agent (persistent) -----

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
  rm -f "$SSH_AUTH_SOCK"
  eval "$(ssh-agent -a "$SSH_AUTH_SOCK" -s)" > /dev/null
  [[ -f ~/.ssh/company_github_key ]] && ssh-add ~/.ssh/company_github_key
fi

# ----- 2. PATH -----

export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Merge all kubeconfig files in ~/.kube/
export KUBECONFIG="$HOME/.kube/config$(find "$HOME/.kube" -maxdepth 1 -name '*-config' -printf ':%p' 2>/dev/null)"

# ----- 3. Oh My Zsh -----

export ZSH="$HOME/.oh-my-zsh"
export FZF_BASE="$HOME/.fzf"
ZSH_THEME="robbyrussell"
DISABLE_AUTO_TITLE="true"
plugins=(git fzf bgnotify kubectl)
source "$ZSH/oh-my-zsh.sh"

# ----- 4. External Plugins -----

[ -f "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
  source "$ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ----- 5. Shell Options -----

# History
export HISTFILE=~/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000
setopt INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY

# Completion
autoload -Uz compinit && compinit -i
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=**' 'l:|=* r:|=*'
zstyle ':completion:*' menu select

# Navigation & behavior
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS NO_CASE_GLOB
unsetopt BEEP

# ----- 6. Aliases -----

alias tf="terraform"
alias git-cls="git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -r git branch -D"
alias kctx="kubectx"
alias kctx-clear="kubectl config unset current-context"
alias kns="kubens"
alias k="kubectl"
alias awsp-clear="unset AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION && echo 'AWS profile cleared.'"

# eza (better ls)
if command -v eza &>/dev/null; then
  alias ls="eza --icons"
  alias ll="eza --icons -lh"
  alias la="eza --icons -lha"
  alias lt="eza --icons --tree --level=2"
fi

# bat (better cat)
if command -v bat &>/dev/null; then
  alias cat="bat --paging=never"
fi

if [[ "$IS_WSL" -eq 1 ]]; then
  # In WSL: don't alias code/cursor to *.exe — use the bash wrappers in PATH
  # which properly translate Linux paths to Remote-WSL URIs (vscode-remote://wsl+<distro>/...).
  # Calling the .exe directly opens via UNC path and skips Remote-WSL mode.
  # Wrappers are installed via Command Palette: "Shell Command: Install 'X' command in PATH"
  alias explorer="explorer.exe"

  # Warn if the wrappers are missing (only on interactive shells)
  if [[ -o interactive ]]; then
    for _cmd in code cursor; do
      if ! command -v "$_cmd" &>/dev/null; then
        echo "⚠  '$_cmd' wrapper not found in PATH. In $_cmd Windows: Command Palette → 'Shell Command: Install \"$_cmd\" command in PATH'"
      fi
    done
    unset _cmd
  fi
else
  alias code="/usr/local/bin/code"
  alias cursor="/usr/local/bin/cursor"
fi

# ----- 7. Functions -----

# AWS profile indicator for prompt
function aws_profile_prompt() {
  if [[ -n $AWS_PROFILE ]]; then
    echo "%F{cyan}($AWS_PROFILE)%f"
  else
    echo "%F{245}(aws-profile)%f"
  fi
}

# Kubernetes context/namespace indicator for prompt
function kube_prompt_info() {
  local ctx ns
  ctx=$(kubectl config current-context 2>/dev/null)
  if [[ -n "$ctx" ]]; then
    ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
    ns="${ns:-default}"
    echo "%F{cyan}(${ctx}/${ns})%f"
  else
    echo "%F{245}(kctx/kns)%f"
  fi
}

# Git branch indicator for prompt
function git_prompt_info() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    echo "%B%F{red}($branch)%f%b"
  else
    echo "%B%F{245}(Git-branch)%f%b"
  fi
}

# AWS profile switcher
function awsp() {
  local cmd="${1:-select}"
  local profile="$2"
  local region
  local login_target

  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI not found in PATH."
    return 1
  fi

  case "$cmd" in
    select)
      if command -v fzf >/dev/null 2>&1; then
        profile=$(aws configure list-profiles 2>/dev/null | fzf \
          --prompt="  " \
          --header="AWS Profile Switcher" \
          --header-first \
          --layout=reverse \
          --height=~40% \
          --min-height=10 \
          --border=rounded \
          --border-label=" awsp " \
          --padding=1 \
          --margin=1 \
          --pointer=">" \
          --color="header:cyan:bold,border:cyan,label:cyan:bold,pointer:cyan:bold,prompt:cyan" \
          --preview='echo "Profile: {}" && echo "---" && aws configure get region --profile {} 2>/dev/null && echo "" && aws configure get sso_start_url --profile {} 2>/dev/null | sed "s|^|SSO: |" || echo "(no SSO)"' \
          --preview-label=" profile details " \
          --preview-window=right,40%,border-left)
      else
        echo "fzf not found. Use: awsp use <profile>"
        return 1
      fi
      [[ -z "$profile" ]] && { echo "No profile selected."; return 1; }
      ;;
    use)
      if [[ -z "$profile" ]]; then
        echo "Usage: awsp use <profile>"
        return 1
      fi
      ;;
    list)
      aws configure list-profiles
      return $?
      ;;
    clear)
      unset AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION
      echo "AWS profile cleared (using default chain)."
      return 0
      ;;
    status)
      if [[ -n "$AWS_PROFILE" ]]; then
        echo "Current profile: $AWS_PROFILE"
      else
        echo "Current profile: default"
      fi
      if aws sts get-caller-identity --query 'Arn' --output text >/dev/null 2>&1; then
        local arn
        arn=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
        echo "STS: authenticated as $arn"
        return 0
      fi
      echo "STS: not authenticated (token missing/expired or profile invalid)."
      return 1
      ;;
    login)
      login_target="${profile:-$AWS_PROFILE}"
      if [[ -z "$login_target" ]]; then
        echo "Usage: awsp login <profile>  (or set AWS_PROFILE first)"
        return 1
      fi
      aws sso login --profile "$login_target"
      return $?
      ;;
    logout)
      echo "Logging out of all AWS SSO sessions..."
      aws sso logout 2>/dev/null
      unset AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION
      echo "SSO sessions cleared and profile unset."
      return 0
      ;;
    help|-h|--help)
      cat <<'EOF'
Usage:
  awsp                 # interactive profile selection (fzf)
  awsp use <profile>   # switch to specific profile
  awsp list            # list configured profiles
  awsp status          # show active profile and STS auth status
  awsp login [profile] # run SSO login for profile
  awsp logout          # logout from all SSO sessions
  awsp clear           # unset AWS_PROFILE/AWS_REGION/AWS_DEFAULT_REGION
EOF
      return 0
      ;;
    *)
      echo "Unknown command: $cmd"
      echo "Try: awsp help"
      return 1
      ;;
  esac

  if ! aws configure list-profiles 2>/dev/null | grep -Fxq "$profile"; then
    echo "Profile not found: $profile"
    return 1
  fi

  export AWS_PROFILE="$profile"
  region=$(aws configure get region --profile "$profile" 2>/dev/null)
  if [[ -n "$region" ]]; then
    export AWS_REGION="$region"
    export AWS_DEFAULT_REGION="$region"
  fi

  echo "Switched to AWS profile: $AWS_PROFILE"
  [[ -n "$AWS_REGION" ]] && echo "Region: $AWS_REGION"

  if ! aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Arn' --output text >/dev/null 2>&1; then
    local has_sso
    has_sso=$(aws configure get sso_start_url --profile "$AWS_PROFILE" 2>/dev/null || \
              aws configure get sso_session --profile "$AWS_PROFILE" 2>/dev/null)
    if [[ -n "$has_sso" ]]; then
      echo "SSO session missing/expired. Logging in..."
      aws sso login --profile "$AWS_PROFILE"
      return $?
    else
      echo "Credentials not ready for '$AWS_PROFILE'."
      return 1
    fi
  fi

  awsp status
}

# ----- 7b. OpenVPN -----

VPN_CONFIG_DIR="$HOME/Downloads"

function vpn-start() {
  local config

  # Check if already connected
  if pgrep -x openvpn &>/dev/null; then
    echo "VPN already running. Use vpn-stop first."
    return 1
  fi

  # Select .ovpn file with fzf
  config=$(find "$VPN_CONFIG_DIR" -maxdepth 1 -name '*.ovpn' -printf '%f\n' 2>/dev/null | sort | fzf \
    --prompt="  " \
    --header="OpenVPN — Select config" \
    --header-first \
    --layout=reverse \
    --height=~40% \
    --min-height=8 \
    --border=rounded \
    --border-label=" vpn " \
    --padding=1 \
    --margin=1 \
    --pointer=">" \
    --color="header:cyan:bold,border:cyan,label:cyan:bold,pointer:cyan:bold,prompt:cyan")

  [[ -z "$config" ]] && { echo "No config selected."; return 1; }

  local fullpath="$VPN_CONFIG_DIR/$config"

  # Prompt for credentials
  echo -n "Username: "; read -r vpn_user
  echo -n "Password: "; read -rs vpn_pass; echo

  # Create temp auth file
  local auth_file
  auth_file=$(mktemp /tmp/ovpn-auth.XXXXXX)
  chmod 600 "$auth_file"
  printf '%s\n%s\n' "$vpn_user" "$vpn_pass" > "$auth_file"

  # Start OpenVPN in background
  sudo openvpn --config "$fullpath" --auth-user-pass "$auth_file" --daemon --log /tmp/openvpn.log

  sleep 2
  rm -f "$auth_file" 2>/dev/null

  if pgrep -x openvpn &>/dev/null; then
    echo "VPN connected: $config"
  else
    echo "VPN failed to start. Check: tail /tmp/openvpn.log"
    return 1
  fi
}

function vpn-stop() {
  if ! pgrep -x openvpn &>/dev/null; then
    echo "No VPN running."
    return 1
  fi
  sudo pkill openvpn
  sleep 1
  echo "VPN disconnected."
}

function vpn-status() {
  if pgrep -x openvpn &>/dev/null; then
    echo "VPN: connected"
    echo "Log: tail -f /tmp/openvpn.log"
  else
    echo "VPN: disconnected"
  fi
}

# ----- 8. Prompt -----

# Terminal tab title: use `title "name"` to set manually, or auto-uses directory name
TERMINAL_TITLE=""
title() { TERMINAL_TITLE="$1"; }

function update_prompt() {
  # Update terminal tab title
  if [[ -n "$TERMINAL_TITLE" ]]; then
    echo -ne "\033]0;${TERMINAL_TITLE}\007"
  else
    echo -ne "\033]0;${PWD##*/}\007"
  fi
  PROMPT=$'┌─[%B%F{245}%n%f%F{cyan}@%f%F{245}%m%f%b] - [%B%F{cyan}%~%f%b] - [%B%F{245}%D{%a %b %d, %H:%M}%f%b] - [%B$(aws_profile_prompt)%b] - [%B$(kube_prompt_info)%b] - [$(git_prompt_info)%b]\n└─[%B%F{cyan}$%f%b] <> '
}
precmd() { update_prompt }

# ----- 9. Tool Managers -----

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ----- 10. direnv -----

command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ----- 11. zoxide -----

command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ----- 12. atuin -----

command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# ----- 13. Integrations -----

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
export PATH="$HOME/.local/bin:$PATH"

# ArgoCD CLI
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=$HOME/.opencode/bin:$PATH
