> **This PR MUST target the `dev` branch, not `main`.** `main` is the released branch; active work lands on `dev` first. PRs opened against `main` will be asked to retarget before review.

## Summary

<!-- One sentence: what does this PR change and why? -->

## Who produced this PR? (required)

<!-- We weigh contributions by what produced them. State which coding agent/harness wrote it (and model, if known), or "hand-written". -->

## Human review (required)

- [ ] A human has reviewed the COMPLETE diff before submission

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New skill or feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would change existing behaviour)
- [ ] Documentation only (README, CHANGELOG, docs/)
- [ ] Build / tooling

## Checklist

- [ ] I have read [`CONTRIBUTING.md`](../CONTRIBUTING.md)
- [ ] Lint passes locally (`npx markdownlint-cli2 "**/*.md"`)
- [ ] If I added or modified a skill, I did NOT add `TodoWrite` references — only `bd` commands
- [ ] If I added or modified a skill, I did NOT remove anti-rationalization tables, Iron Laws, or Red Flags
- [ ] If I changed plugin metadata, I bumped the version via `scripts/bump-version.sh` (never by hand)
- [ ] I updated `CHANGELOG.md` under `## [Unreleased]`
- [ ] I updated `README.md` (and `README.zh-CN.md`) if user-facing behaviour changed

## Validation (run before submitting)

```bash
just guards                                                 # all guard scripts
bash hooks/session-start 2>&1 | python3 -m json.tool        # Should be valid JSON
./scripts/bump-version.sh --check                           # Should pass
```

## Linked issue

Closes #
