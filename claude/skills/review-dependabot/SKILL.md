---
name: review-dependabot
description: Reviews all open Dependabot PRs in a repository, evaluates breaking changes and risks, and after user approval approves, comments, and merges them.
argument-hint: "<owner/repo>"
allowed-tools:
  - Bash(gh *)
  - Bash(git *)
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# Review Dependabot PRs

You are a senior engineer specialized in dependency management. Your task is to review all open Dependabot PRs in a repository and help the user decide which ones to approve and merge.

## 1. Identify the repository

The repository is passed via `$ARGUMENTS` in the `owner/repo` format. If not provided, ask the user.

## 2. List Dependabot PRs

List all open PRs authored by Dependabot:

```
gh pr list --repo $ARGUMENTS --author "app/dependabot" --state open --json number,title,url,headRefName,baseRefName,labels,createdAt,body --limit 100
```

If there are no Dependabot PRs, inform the user and stop.

**IMPORTANT:** Only consider PRs where the base branch is `develop`. Filter out any PRs targeting other branches (e.g., `main`, `master`). The head branch must also originate from `develop` — Dependabot should be configured to target `develop`.

## 3. Analyze each PR

For **each** Dependabot PR, collect and analyze:

### 3.1 Data collection

```
gh pr view {number} --repo {owner/repo} --json number,title,body,url,headRefName,baseRefName,labels,commits,reviews,statusCheckRollup
```

```
gh pr diff {number} --repo {owner/repo}
```

### 3.2 Breaking changes analysis

For each dependency update, evaluate:

1. **Bump type**: patch (x.x.X), minor (x.X.0), or major (X.0.0)
2. **Breaking changes**: Read the PR body — Dependabot usually includes the changelog and release notes. Look for:
   - "Breaking Changes" or "BREAKING" sections
   - API changes
   - Removed deprecations
   - Changed minimum version requirements (Node, Python, etc.)
3. **Compatibility**: Check for changes that may affect the project
4. **CI Status**: Verify whether checks have passed

### 3.3 Risk classification

Classify each PR as:
- **Low risk**: Patch updates, security fixes, dev/test dependencies
- **Medium risk**: Minor updates with new features, changes in production dependencies
- **High risk**: Major updates, known breaking changes, core project dependencies

## 4. Present report

Generate the report in the following format:

---

## Dependabot Report — {owner/repo}

**Total open PRs:** {count}
**Analysis date:** {date}

### PRs by risk level

#### Low Risk

For each PR:
- **PR #{number}**: {title}
  - **URL:** {url}
  - **Bump type:** patch/minor/major
  - **CI Status:** passing/failing/pending
  - **Analysis:** Brief justification for why it's low risk
  - **Recommendation:** Approve and merge / Wait for CI / Investigate

#### Medium Risk

(same format)

#### High Risk

(same format, with additional details about breaking changes)

### Summary

- Low risk: X PRs — recommend direct merge
- Medium risk: X PRs — recommend quick review
- High risk: X PRs — recommend detailed analysis

---

## 5. Wait for user decision

After presenting the report, ask the user:

> Which PRs do you want me to approve and merge? You can answer:
> - "all" — approve and merge all
> - "all low risk" — only low risk ones
> - "all low and medium risk" — low and medium
> - "#123, #456, #789" — specific PRs by number
> - "none" — do nothing

**IMPORTANT:** Do NOT proceed without explicit user confirmation. Wait for the OK.

## 6. Execute actions

For each PR approved by the user:

### 6.1 Approve

```
gh pr review {number} --repo {owner/repo} --approve --body "Dependency update reviewed. No breaking changes identified. Auto-approved."
```

If the PR is high risk with identified breaking changes, include in the body:

```
gh pr review {number} --repo {owner/repo} --approve --body "Dependency update reviewed. Breaking changes noted: {details}. User approved merge after review."
```

### 6.2 Comment (if needed)

If there are relevant observations (breaking changes, future deprecations, etc.), comment on the PR:

```
gh pr comment {number} --repo {owner/repo} --body "{comment}"
```

### 6.3 Merge

```
gh pr merge {number} --repo {owner/repo} --squash --auto
```

If squash merge is not allowed, try:
```
gh pr merge {number} --repo {owner/repo} --merge --auto
```

If `--auto` fails (e.g., branch protection without auto-merge enabled), try without `--auto`:
```
gh pr merge {number} --repo {owner/repo} --squash
```

### 6.4 Report result

After processing each PR, report the outcome:
- PR #{number}: Approved and merged successfully
- PR #{number}: Approved, merge failed — {reason}
- PR #{number}: Error — {details}

## 7. Final summary

After processing all selected PRs, present:

- Total processed: X
- Successfully merged: Y
- Failures: Z (with details)

## Important rules

- NEVER merge without explicit user approval.
- If CI is failing on a PR, highlight it clearly and recommend NOT merging until resolved.
- Prioritize security: Dependabot security fixes should be flagged as priority.
- If there are many PRs (>10), group by type (security, patch, minor, major) to make the decision easier.
- When breaking changes are found, detail exactly what changed and the potential impact.
- Use `--squash` as the default merge strategy to keep history clean.
