# dotfiles

DevOps/Cloud engineering workstation. One-command setup from a fresh Ubuntu/WSL install to a fully configured environment with shell, cloud tools, Kubernetes stack, and editor configs.

---

## Quick Install

**Auto-accept, install everything (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash -s -- -y
```

**Interactive** (choose categories and tools as you go):
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash
```

## Uninstall

**Auto-accept, remove everything (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash -s -- -y
```

**Interactive:**
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash
```

---

## What's included

Packages are grouped into categories you can pick or skip:

- **Shell** — Oh-My-Zsh, plugins, fzf, tmux plugins, Nerd Font
- **Kubernetes** — kubectl, helm, k9s, and related tooling
- **Cloud** — AWS CLI, Terraform, OpenVPN
- **Dev** — Docker, Python, Bun, GitHub CLI, Claude Code
- **Terminal** — modern replacements (bat, eza, zoxide, atuin, etc.)
- **Editors** — VS Code and Cursor

Dotfiles linked into `$HOME`:
- Shell config (`.zshrc`, `.bashrc`, `.tmux.conf`)
- Git config (with signing, delta diff, global ignores)
- Editor config (`.editorconfig`)
- Cloud configs (`~/.aws/config`, `~/.ssh/config`) as templates
- Claude Code settings and custom skills/commands

Inspect the `scripts/packages.sh` for the full, current list.

---

## How it works

Install is split into three scripts that run in sequence (all interactive):

| Script | What it does |
|---|---|
| `install.sh` | Entry point — clones this repo, runs the others |
| `packages.sh` | Installs selected tools |
| `link.sh` | Creates symlinks from this repo into `$HOME` |

Run any of them standalone. Pass `-y` to skip all prompts.

Existing files in `$HOME` are backed up to `*.bak` before being replaced with symlinks. Editing the file in the repo updates `$HOME` automatically (and vice-versa).

---

## Manual steps after install

The install script prints a detailed checklist at the end. In short, you'll need to:

- Copy your SSH keys, then `ssh-add` them
- `aws sso login --profile <profile>` with your real accounts
- Copy kubeconfigs into `~/.kube/`
- `gh auth login`, `argocd login`, etc.
- Configure your terminal to use a **Nerd Font** (otherwise icons look broken)

See the end-of-install output for copy-pasteable commands.

---

## Security

This repo is public and safe to share:

- No secrets, tokens, or real account IDs in tracked files
- Sensitive names (company, clusters, users) replaced with fictional placeholders
- `.gitignore` blocks private keys, credentials, Claude session data, and anything matching typical secret patterns
- Real values live only in local files that are never committed

---

## Customizing

Fork this repo, change the name/email in `home/.gitconfig`, update the placeholders in `config/aws/config` and `config/ssh/config` to match your environment, and point the install URL to your fork.
