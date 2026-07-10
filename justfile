# beads-superpowers check-suite — tool, not gate. Run when touching harness plumbing
# (hooks/, install.sh, manifests, .opencode/). Skill QUALITY testing lives in the
# external eval-harness project, not here.

default: check

# Fast deterministic set (fresh-clone deps: bash + python3 + just)
check: guards hooks manifests contracts shape

guards:
    bash scripts/run-guards.sh

hooks:
    bash scripts/run-hook-tests.sh

manifests:
    bash tests/manifests/test-manifest-validation.sh

contracts:
    bash scripts/run-contracts.sh

# Install-shape suite: 9 harnesses (Tier A ×3 full artifacts, Tier B ×6 hint+manifest)
shape HARNESS="all":
    bash tests/install-shape/run.sh {{HARNESS}}

# Guard-the-guards: mutations that must FAIL (added in Task 7)
selftest:
    bash tests/install-shape/selftest.sh

# Shellcheck gate over tracked .sh with baseline + visible-SKIP
lint:
    bash scripts/lint-shell.sh

# Opt-in (extra deps)
server:
    cd tests/brainstorm-server && npm install --no-audit --no-fund && npm test && bash windows-lifecycle.test.sh

docker:
    bash tests/installer/run-tests.sh

docs:
    mkdocs build --strict
