# verify_commit_messages

**Code checker.** Verifies commit messages against Moodle rules (issue code, line length) and AMOS script syntax.

## Scripts

- `amoslib.php`
- `check_amos.php`
- `commits2checkstyle.php`
- `verify_commit_messages.sh`

## Environment variables

Configuration is passed via environment variables (as documented in the script header). Required ones are validated at startup.

- `gitcmd` — Path to the git CLI executable
- `gitdir` — Directory containing git repo
- `initialcommit` — hash of the initial commit
- `finalcommit` — hash of the final commit
- `issuecode` — code of the issue to verify
- `maxcommitswarn` — Max number of commits accepted per run. Warning if exceeded. Defaults to 10.
- `maxcommitserror` — Max number of commits accepted per run. Error if exceeded. Defaults to 100.
- `debug` — to return results in human-readable format for debugging
- `verifyissuecodeinmerge` — to apply the issue code matching checks to merge commits.
- `phpcmd` — Path to the PHP CLI executable

## Tests

[`tests/verify_commit_messages.bats`](../tests/verify_commit_messages.bats)

---

See [CLAUDE.md](../CLAUDE.md) for repo-wide conventions and [docs/testing.md](../docs/testing.md) for the testing workflow.
