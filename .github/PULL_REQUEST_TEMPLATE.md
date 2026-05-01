## Summary

<!-- One sentence: what does this PR change and why? -->

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New skill or feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would change existing behaviour)
- [ ] Documentation only (README, CHANGELOG, METHODOLOGY, etc.)
- [ ] Build / CI / tooling

## Checklist

- [ ] I have read [`CONTRIBUTING.md`](../CONTRIBUTING.md)
- [ ] CI passes locally (`npx markdownlint-cli2 "**/*.md"`)
- [ ] If I added or modified a skill, I did NOT add `TodoWrite` references — only `bd` commands
- [ ] If I added or modified a skill, I did NOT remove anti-rationalization tables, Iron Laws, or Red Flags
- [ ] If I changed plugin metadata, I bumped the version in all 3 manifests via `scripts/bump-version.sh`
- [ ] I updated `CHANGELOG.md` under `## [Unreleased]`
- [ ] I updated `README.md` if user-facing behaviour changed

## Validation (run before submitting)

```bash
ls -d skills/*/ | wc -l                                                    # Should be 20
grep -r "TodoWrite" skills/ | grep -v "Do NOT use" | grep -v "replaces"    # Should be empty
grep -r "bd create\|bd close\|bd ready" skills/ | wc -l                    # Should be 30+
bash hooks/session-start 2>&1 | python3 -m json.tool                       # Should be valid JSON
./scripts/bump-version.sh --check                                          # Should pass
```

## Linked issue

Closes #
