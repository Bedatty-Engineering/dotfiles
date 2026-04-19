# Create Branch

Create a new git branch following the repository naming conventions.

## Instructions

1. Ask the user (if not provided via `$ARGUMENTS`) for:
   - **Type**: one of `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`
   - **Description**: short kebab-case description of the change

2. The branch name MUST follow the pattern: `<type>/<description>`
   - Examples: `feat/add-caching-step`, `fix/missing-env-var`, `chore/update-dependencies`

3. Before creating:
   - Run `git fetch origin` to ensure remote refs are up to date
   - Confirm the base branch with the user (default: `develop`)
   - Check that a branch with the same name does not already exist locally or remotely

4. Create and checkout the branch:
   ```
   git checkout -b <type>/<description> origin/<base-branch>
   ```

5. Confirm success to the user and show the branch name.

## Arguments

If `$ARGUMENTS` is provided, parse it as `<type>/<description>` or `<type> <description>`.
