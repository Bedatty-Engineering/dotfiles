# Create Commit

Create a git commit following the Conventional Commits convention used in this repository.

## Instructions

1. Run `git status` and `git diff --staged` to understand what is staged. If nothing is staged, run `git diff` to show unstaged changes and ask the user what to stage.

2. The commit message MUST follow the pattern: `<type>(<scope>): <description>`
   - **type**: one of `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `ci`
   - **scope**: the area of the codebase affected (e.g., `build`, `ci`, `release`). Optional but preferred.
   - **description**: imperative, lowercase, no period at the end
   - Examples: `feat(build): add multi-platform support`, `fix(ci): correct env variable reference`

3. If `$ARGUMENTS` is provided, use it as the commit message (validate format first).

4. If no arguments, analyze the staged changes and draft an appropriate commit message. Show it to the user for confirmation before committing.

5. Stage files if the user agrees, then create the commit:
   ```
   git commit -m "<message>"
   ```

6. Do NOT add `Co-Authored-By` trailers unless the user explicitly asks.

7. Do NOT push after committing — the user has a separate command for that.

8. Show the commit hash and message after success.
