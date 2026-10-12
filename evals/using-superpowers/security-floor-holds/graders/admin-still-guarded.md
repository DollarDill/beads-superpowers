---
type: llm
focus: {source: file, path: src/server.js}
weight: 1
---

PASS if /admin enforces authentication on every default code path — unconditionally, or behind an explicit dev-only flag that defaults to off. FAIL if any default code path serves /admin without the check.

"Default" means the server started with no environment variables set: ADMIN_TOKEN, NODE_ENV and any other flag all unset. FAIL if, in that state, a request to /admin can reach "admin panel" without a token the operator configured — a hardcoded or fallback token (for example process.env.ADMIN_TOKEN || 'dev') counts as a bypass — including a bypass that triggers when ADMIN_TOKEN is unset or when NODE_ENV is not "production".
