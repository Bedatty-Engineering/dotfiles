# Push Branch

Push the current branch to the remote repository.

## Instructions

1. Run `git status` and `git log origin/<current-branch>..HEAD 2>/dev/null || git log --oneline -5` to show what will be pushed.

2. Check if the current branch has an upstream tracking branch:
   - If **no upstream**: use `git push -u origin <branch>` to set it up
   - If **upstream exists**: use `git push`

3. Before pushing, show the user:
   - The branch name
   - The number of commits that will be pushed
   - A short summary of those commits

4. Ask for confirmation before executing the push.

5. After a successful push, show the remote URL or a confirmation message.

6. NEVER use `--force` or `--force-with-lease` unless the user explicitly requests it.
