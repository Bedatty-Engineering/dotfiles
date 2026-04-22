# dotfiles

DevOps/Cloud engineering workstation. One-command setup from a fresh Ubuntu/WSL install to a fully configured environment with shell, cloud tools, Kubernetes stack, and editor configs.

---

## Quick Install

**Interactive** (recommended first time — you pick which categories/tools to install):
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash
```

**Auto-accept everything** (install all categories and all tools):
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash -s -- -y
```

## Uninstall

**Interactive:**
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash
```

**Auto-accept (remove everything):**
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash -s -- -y
```

---

## Repository layout

```
dotfiles/
├── home/                          # linked into $HOME
│   ├── .zshrc                     # Oh-My-Zsh, AWS switcher, VPN, k8s prompt
│   ├── .bashrc
│   ├── .gitconfig                 # SSH signing, delta, URL rewrite
│   ├── .gitignore_global          # global git ignores
│   ├── .editorconfig              # consistent indent/encoding
│   └── .tmux.conf                 # splits, plugins (resurrect, continuum)
│
├── config/                        # linked into $HOME/.xxx or $HOME/.config/
│   ├── aws/
│   │   ├── config                 # SSO profiles (placeholders)
│   │   └── credentials.example    # template
│   ├── ssh/
│   │   ├── config                 # global SSH options
│   │   └── config.example         # template with host examples
│   └── kube/
│       ├── config.example         # per-cluster kubeconfig template
│       └── default-config.example # local minikube/kind template
│
├── claude/                        # Claude Code config
│   ├── settings.json
│   ├── statusline-command.sh
│   ├── commands/                  # custom slash commands (/ship, /cluster-ops)
│   └── skills/                    # custom skills (review-coderabbit, review-dependabot)
│
└── scripts/
    ├── install.sh                 # Bootstrap (curl-able)
    ├── packages.sh                # Tool installer (granular by category)
    ├── link.sh                    # Create symlinks (with .bak backup)
    └── uninstall.sh               # Remove everything
```

---

## What gets installed

Install is organized in **6 categories**. Each can be skipped entirely, installed as a whole, or have tools picked individually.

| Category | Tools |
|---|---|
| **Shell** | Oh-My-Zsh, zsh-autosuggestions, zsh-syntax-highlighting, fzf, tmux TPM, JetBrainsMono Nerd Font |
| **Kubernetes** | kubectl, minikube, kubectx/kubens, helm, k9s, stern, kustomize, argocd |
| **Cloud** | aws-cli v2, AWS SSM plugin, terraform, openvpn |
| **Dev** | docker, python3 + pipx, bun, gh, claude-code |
| **Terminal** | zoxide, bat, eza, delta, atuin, direnv |
| **Editors** | VS Code, Cursor |

Always installed as base: `git curl wget zsh tmux unzip build-essential jq`.

---

## Interactive flow

```
==> What would you like to do?
  Install packages? [Y/n] y
    Choose which categories to install:
  • Shell tools? [Y/n] y
    Pick tools individually? [Y/n] n
  • Kubernetes? [Y/n] y
    Pick tools individually? [Y/n] y
      - kubectl? [Y/n] y
      - minikube? [Y/n] n
      - helm? [Y/n] y
      ...
  • Cloud? [Y/n] y
  ...
```

At the end you get a color-coded table:
- `+ installed` (green)
- `= present` (already existed)
- `○ skipped` (you said no)
- `✗ failed`

---

## Shell experience

The `.zshrc` provides:

- **Oh-My-Zsh** with `robbyrussell` theme, `git fzf bgnotify kubectl` plugins
- **External plugins:** zsh-autosuggestions, zsh-syntax-highlighting
- **Custom multi-line prompt** with user@host, path, AWS profile, k8s context/namespace, git branch, timestamp
- **AWS profile switcher** — `awsp` (fzf-based), `awsp use <profile>`, `awsp login`, `awsp status`
- **OpenVPN functions** — `vpn-start` / `vpn-stop` / `vpn-status`
- **Kubernetes** — `k` (kubectl), `kctx` (kubectx), `kns` (kubens), automatic `KUBECONFIG` merge of all `~/.kube/*-config` files
- **Terminal productivity** — `eza --icons` aliases for ls/ll/la/lt, `bat` as cat, `zoxide` (`z <partial-dir>`), `atuin` (Ctrl+R fuzzy history search), `direnv` for per-project env vars
- **Git** — `git-cls` to clean deleted remote branches; delta configured as diff pager

---

## Git configuration

- SSH-based commit/tag signing via `~/.ssh/company_github_key`
- `url."git@github.com:".insteadOf = https://github.com/` rewrite (HTTPS → SSH automatically)
- `delta` as default pager with side-by-side diff
- Global excludesfile: `~/.gitignore_global`

---

## Manual steps (post-install)

The install script prints these at the end. Summary:

```bash
# 1. Activate zsh in current session
exec zsh

# 2. SSH keys
cp /path/to/company_github_key ~/.ssh/
chmod 600 ~/.ssh/company_github_key
ssh-add ~/.ssh/company_github_key
ssh -T git@github.com     # verify

# 3. AWS (edit real account IDs then SSO login)
$EDITOR ~/dotfiles/config/aws/config
aws sso login --profile <profile>
awsp                       # switch profiles interactively

# 4. Kubernetes (copy each cluster kubeconfig)
cp /path/to/alpha-k8s-config ~/.kube/
kctx                       # switch cluster
k9s                        # UI for pods/logs

# 5. ArgoCD
argocd login <argocd.example.com> --sso

# 6. GitHub CLI
gh auth login

# 7. NPM (private registry)
echo '//npm.pkg.github.com/:_authToken=YOUR_TOKEN' >> ~/.npmrc

# 8. Docker (logout/login needed for group membership)
docker run hello-world

# 9. tmux plugins
tmux
# Press Ctrl+B then Shift+I to install plugins

# 10. atuin history sync (optional)
atuin register -u <username> -e <email>
atuin import auto

# 11. Terminal font (IMPORTANT)
# Configure your terminal to use "JetBrainsMono Nerd Font"
# Otherwise eza icons and prompt symbols show as boxes
```

---

## Security (public repo)

- No real secrets, API keys, or tokens in tracked files
- Real names (company, clusters, users, emails) replaced with fictional placeholders (`acme`, `alpha/beta/gamma/delta`, etc.)
- `.gitignore` blocks: `*.pem`, `*.key`, `*credentials*`, `*token*`, `.ssh/`, `.gnupg/`, `claude/settings.local.json`, and Claude private data (history, sessions, projects)
- AWS account IDs → `<ACCOUNT_ID_*>` placeholders
- Cluster IPs → `<CLUSTER_IP>` placeholders

Real values are kept only in local files (`~/.aws/credentials`, `~/.ssh/`, `~/.kube/*-config`) that are never committed.

---

## Scripts reference

| Script | Purpose |
|---|---|
| `scripts/install.sh` | Bootstrap: deps check → clone repo → run packages/link/ring (interactive) |
| `scripts/packages.sh` | Tool installer with per-category gating (`INSTALL_K8S=1`, etc.) |
| `scripts/link.sh` | Create symlinks from repo to `$HOME` (backs up existing files to `.bak`) |
| `scripts/uninstall.sh` | Remove everything with same granular control + summary table |

**Flags:**
- `-y` / `--yes` — auto-accept all prompts
- `-h` / `--help` — print usage

**Env vars for `packages.sh`:**
- `INSTALL_SHELL=0/1`, `INSTALL_K8S=0/1`, `INSTALL_CLOUD=0/1`, `INSTALL_DEV=0/1`, `INSTALL_TERMINAL=0/1`, `INSTALL_EDITORS=0/1`
- `SKIP_<TOOLNAME>=1` — skip individual tool (e.g. `SKIP_MINIKUBE=1`)

**Example — install only K8s without minikube:**
```bash
INSTALL_SHELL=0 INSTALL_CLOUD=0 INSTALL_DEV=0 INSTALL_TERMINAL=0 INSTALL_EDITORS=0 \
  SKIP_MINIKUBE=1 \
  bash scripts/packages.sh
```

---

## Adding new dotfiles

```bash
# 1. Copy the file into the repo
cp ~/.config/newtool/config dotfiles/config/newtool/config

# 2. Add symlink line in scripts/link.sh

# 3. Commit
git add . && git commit -m "add newtool config"
```
