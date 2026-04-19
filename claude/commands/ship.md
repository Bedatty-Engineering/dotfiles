# Ship

End-to-end workflow: create branch, stage & commit, push, and open a PR.

## Instructions

**IMPORTANT — Plan first, execute after approval.**

Before executing anything, analyze the current state (`git status`, `git branch`, `git diff`) and present a full plan to the user summarizing:
- Which branch will be created (or if the current one will be used)
- Which files will be staged
- The proposed commit message
- The target base branch for the PR

Only proceed with execution after the user explicitly approves the plan.

Execute the following steps sequentially. Stop and ask the user if any step fails or needs clarification.

### Step 1 — Branch

1. If already on a feature branch (not `main` or `develop`), ask the user if they want to use the current branch or create a new one.
2. If on `main`/`develop` or user wants a new branch:
   - Ask for **type** (`feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`) and **description** (kebab-case) — unless provided via `$ARGUMENTS`.
   - `git fetch origin`
   - `git checkout -b <type>/<description> origin/develop`

### Step 2 — Stage & Commit

1. Run `git status` and `git diff` to understand all changes.
2. Stage the relevant files (ask the user if unclear what to include).
3. Draft a commit message following Conventional Commits: `type(scope): description`
4. Do NOT add `Co-Authored-By` trailers. Ever.
5. Show the message to the user for approval, then commit.

### Step 3 — Push

1. Push the branch: `git push -u origin <branch>`
2. Confirm success.

### Step 4 — Pull Request

1. Run `git log origin/develop..HEAD --oneline` and `git diff origin/develop...HEAD --stat` for context.
2. **Read the repo's PR template** at `.github/pull_request_template.md` (if it exists). Use it as the body structure and fill in every section properly based on the changes.
3. Draft the PR:
   - **Title**: Conventional Commits format — `type(scope): description` (under 70 chars, lowercase, no period). Must match the commit type. Examples: `feat(gitops): add sandbox environment support`, `fix(ci): correct env variable reference`.
   - **Body**: Fill the repo's PR template. Specifically:
     - **Description**: summarize what the PR does and why
     - **Type of Change**: check the appropriate box(es) matching the commit type
     - **Breaking Changes**: describe if applicable, otherwise leave "None."
     - **Testing**: check boxes that apply, add the caller repo/workflow run link if available
     - **Related Issues**: fill if the user mentions an issue, otherwise leave blank
4. Show draft (title + full body) to the user for review.
5. Create: `gh pr create --title "<title>" --body "<body>" --base develop`
6. Return the PR URL.

## Arguments

If `$ARGUMENTS` is provided, parse as `<type>/<description>` for the branch name. Example: `/ship feat/add-caching-step`
