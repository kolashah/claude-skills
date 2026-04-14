**You are an execution agent. Implement the following plan in the repository.**

**Task:** {todo description}
**Notes:** {todo notes joined by newline}
**Repo:** {repoPath}
**Branch:** {branch}
**Base branch:** {baseBranch}

**Plan:**
{contents of plan file}

**Instructions:**

1. You are running in a git worktree — an isolated copy of the repo. Your changes won't affect the main working directory.
2. Determine the base branch to branch from and PR against:
   - If `{baseBranch}` is provided (not empty/null), use it.
   - Otherwise, auto-detect: run `git branch -r --sort=-creatordate | grep 'origin/release/' | head -1` to find the latest release branch. If one exists, use it. If none, use `main`.
   - Run `git fetch origin <base>` and `git checkout <base>` before creating your feature branch.
3. Create and checkout the branch: `git checkout -b {branch}`
4. Read the project's CLAUDE.md if it exists and follow all coding conventions strictly.
5. Implement the plan step by step. Write clean, production-quality code.
6. After making changes, run any relevant code generation commands if the project uses them (e.g., `flutter pub run build_runner build --delete-conflicting-outputs` for Dart/Flutter, `npm run generate` for TypeScript, etc.). Check the project's CLAUDE.md or Makefile for the correct commands.
7. If you modified any localization/i18n files, run the project's localization generation command (e.g., `flutter gen-l10n` for Flutter, etc.). Check CLAUDE.md for project-specific instructions.
8. Run the project's formatter and linter/analyzer:
   - Check if a `Makefile` exists with a `format` or `lint` target and use those.
   - Otherwise, use the standard tools for the project's language (e.g., `dart format .` + `flutter analyze` for Flutter, `prettier` + `eslint` for JS/TS, `black` + `ruff` for Python, etc.).
   - Fix any warnings or errors before committing.
9. Check if any existing test files cover the code you changed. Search for test files that import or reference the modified files. If tests exist, update them to reflect your changes so they pass. Run the project's test command to verify.
10. Commit your changes with a clear commit message describing what was done.
11. Push the branch to remote: `git push -u origin {branch}`
12. Create a PR targeting the base branch using `gh pr create --base <base-branch>` with a clear title and body summarizing the changes. The body should follow this format:
    ```
    ## Summary
    - bullet points of what changed

    ## Plan
    <paste a condensed version of the plan here — key approach decisions, files changed and why, any notable trade-offs. Do NOT reference a todo number (e.g., "todo #16") as GitHub auto-links numbers to PRs in the same repo.>

    ## Test Plan
    - testing steps
    ```
13. After creating the PR, update `{homedir}/.claude/todos.json`: set the todo's `status` to `pr open`, save the PR URL in `pr`, and **write the resolved base branch back to `baseBranch`** (so the JSON reflects what was actually used, even if auto-detected). Update the `updated` timestamp.
14. **Clean up the worktree.** Run `git -C {repoPath} worktree remove <your worktree path> --force`. The worktree serves no purpose after the PR is pushed and blocks the user from checking out the branch in the main repo.
15. Write a summary of what you did to `{homedir}/.claude/todo-plans/result-{id}.md` in this format:

```markdown
# Result: {description}
**Branch:** {branch}
**Worktree:** {worktree path from environment}
**Status:** complete|partial (if you couldn't finish everything)
**PR:** {PR URL from gh pr create}

## Changes Made
- file1.dart — what was changed
- file2.dart — what was changed

## Commits
- {commit hash} {commit message}

## Notes
- anything the user should review or be aware of
- any remaining work if partial
```

## Follow-up Changes

If the user asks for small follow-up changes on a todo that already has a PR (e.g., via `/todo chat` or direct instructions):

1. Make the requested changes.
2. Run the same formatting, linting, l10n, and test steps as above.
3. Check `{squashCommits}`:
   - If **true**: amend the existing commit (`git add -A && git commit --amend --no-edit`) and force push (`git push --force-with-lease`). This keeps a single clean commit for release branches.
   - If **false** (default): create a new commit with a descriptive message and push normally (`git push`).
4. Update the result file if the changes are significant enough to note.
