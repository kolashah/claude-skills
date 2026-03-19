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
3. Read the project's CLAUDE.md if it exists and follow all coding conventions strictly.
4. Implement the plan step by step. Write clean, production-quality code.
5. After making changes, run any relevant code generation commands if needed (e.g., `flutter pub run build_runner build --delete-conflicting-outputs` for Dart/Flutter projects with Freezed/JsonSerializable changes).
6. If you modified any localization files (`.arb` files), run `flutter gen-l10n` to regenerate localizations. If the project has a sort script (e.g., `dart run tool/sort_arb.dart`), run that too. This must happen before formatting.
7. Run the formatter and analyzer:
   - Check if a `Makefile` exists with a `format` target: run `make format` if so.
   - Otherwise: run `dart format .` for Dart/Flutter projects.
   - Then run the analyzer/linter if available (e.g., `flutter analyze` for Flutter projects).
7. Check if any existing test files cover the code you changed. Search for test files that import or reference the modified files (e.g., `grep -r 'modified_file' test/`). If tests exist, update them to reflect your changes so they pass. Run `flutter test` (or the relevant test command) to verify.
8. Commit your changes with a clear commit message describing what was done.
9. Push the branch to remote: `git push -u origin {branch}`
10. Create a PR targeting the base branch using `gh pr create --base <base-branch>` with a clear title and body summarizing the changes. The body should follow this format:
    ```
    ## Summary
    - bullet points of what changed

    ## Plan
    <paste a condensed version of the plan here — key approach decisions, files changed and why, any notable trade-offs. Do NOT reference a todo number (e.g., "todo #16") as GitHub auto-links numbers to PRs in the same repo.>

    ## Test Plan
    - testing steps
    ```
11. After creating the PR, update `{homedir}/.claude/todos.json`: set the todo's `status` to `pr open`, save the PR URL in `pr`, and **write the resolved base branch back to `baseBranch`** (so the JSON reflects what was actually used, even if auto-detected). Update the `updated` timestamp.
12. Write a summary of what you did to `{homedir}/.claude/todo-plans/result-{id}.md` in this format:

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
3. **Amend the existing commit** instead of creating a new one: `git add -A && git commit --amend --no-edit`
4. **Force push** to update the PR: `git push --force-with-lease`
5. Update the result file if the changes are significant enough to note.

This keeps the commit history clean for release branches. Only use amend + force push for small follow-ups. If the follow-up is a substantial change, create a new commit instead.
