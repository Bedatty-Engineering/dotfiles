# Create Pull Request

Create a GitHub Pull Request for the current branch.

## Instructions

1. Gather context by running in parallel:
   - `git status` — check for uncommitted changes
   - `git log origin/develop..HEAD --oneline` — list all commits in this branch
   - `git diff origin/develop...HEAD --stat` — summary of files changed

2. If there are uncommitted changes, warn the user and ask if they want to commit first (suggest using `/commit`).

3. If the branch has not been pushed, warn the user and ask if they want to push first (suggest using `/push`).

4. Determine the base branch (default: `develop`). Ask the user if unclear.

5. **Read the repo's PR template** at `.github/pull_request_template.md` (if it exists). Use it as the body structure and fill in every section properly based on the changes.

6. Draft the PR:
   - **Title**: Conventional Commits format — `type(scope): description` (under 70 chars, lowercase, no period). Must match the commit type. Examples: `feat(gitops): add sandbox environment support`, `fix(ci): correct env variable reference`.
   - **Body**: Fill the repo's PR template. Specifically:
     - **Description**: summarize what the PR does and why
     - **Type of Change**: check the appropriate box(es) matching the commit type
     - **Breaking Changes**: describe if applicable, otherwise leave "None."
     - **Testing**: check boxes that apply, add the caller repo/workflow run link if available
     - **Related Issues**: fill if the user mentions an issue, otherwise leave blank
   - If no PR template exists in the repo, use a sensible default with Summary and Test Plan sections.

7. Show the draft (title + full body) to the user for review. If `$ARGUMENTS` is provided, use it as the PR title.

8. Create the PR:
   ```
   gh pr create --title "<title>" --body "<body>" --base <base-branch>
   ```

9. Return the PR URL to the user.
