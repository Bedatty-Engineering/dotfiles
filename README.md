# dotfiles

DevOps/Cloud engineering workstation configuration.

## Quick Install

Interactive:
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash
```

Auto-accept all prompts:
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash -s -- -y
```

## Uninstall

Interactive:
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash
```

Auto-accept all prompts:
```bash
curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash -s -- -y
```

## What's included

| File | Description |
|------|-------------|
| `.zshrc` | Oh-My-Zsh config, AWS profile manager, VPN, kubectl prompt, custom functions |
| `.gitconfig` | User config, SSH signing, GitHub SSH URL rewrite |
| `.tmux.conf` | Splits (F1/F2) and pane navigation (F3) |
| `.bashrc` | Base Ubuntu bash config |

## Manual steps after install

### SSH keys
```bash
# Copy your private key then:
chmod 600 ~/.ssh/company_github_key
ssh-add ~/.ssh/company_github_key
```

### AWS credentials
```bash
aws configure
# or use SSO: aws sso login --profile <profile>
```

### NPM (Lerian packages)
```bash
echo "//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN" >> ~/.npmrc
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/install.sh` | Full bootstrap (clone repo + packages + links) |
| `scripts/packages.sh` | Install tools only (oh-my-zsh, kubectl, nvm, aws, etc.) |
| `scripts/link.sh` | Create symlinks only (idempotent) |
| `scripts/uninstall.sh` | Remove symlinks, tools, and optionally the repo (interactive) |

## Adding new dotfiles

```bash
cp ~/.config/something dotfiles/config/something
# Then add to scripts/link.sh
git add dotfiles/config/something && git commit -m "add something config"
```
