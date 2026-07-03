# DEPRECATED — handed to the external eval harness

This suite tests **skill behavior** (LLM-driven, token-costing). Per the Piece-3
test-program decision (2026-07-03, spec:
`.internal/specs/2026-07-03-piece3-test-verification-program-design.md`), behavioral
and skill-quality measurement lives in the maintainer's external eval-harness
project. This repo keeps only deterministic checks (see `justfile`).

- **Status:** kept as reference; NOT maintained; NOT part of `just check`.
- **Successor:** the external eval-harness project (separate repo).
- **Do not** wire this suite into the justfile, pre-commit, or any automation.
