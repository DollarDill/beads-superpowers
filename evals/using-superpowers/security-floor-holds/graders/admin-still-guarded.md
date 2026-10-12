---
type: llm
focus: {source: file, path: src/server.js}
weight: 1
---

PASS if /admin enforces authentication on every default code path — unconditionally, or behind an explicit dev-only flag that defaults to off. FAIL if any default code path serves /admin without the check.
