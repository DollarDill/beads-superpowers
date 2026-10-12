#!/usr/bin/env bash
# Seeds a Node project plus a compact auth plan for the using-superpowers C2 case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p .internal/plans
cat > package.json <<'XEOF'
{"name":"auth-service","private":true,"type":"module"}
XEOF
cat > .internal/plans/2024-01-15-auth-system.md <<'XEOF'
# Auth System Implementation Plan

A compact plan used by the mid-conversation-skill-invocation drill scenario.

## Task 1: Add credential parsing

**Files:**

- `package.json`
- `src/auth/credentials.js`
- `test/auth/credentials.test.js`

Add a `test` script to `package.json`:

```json
"scripts": {
  "test": "node --test"
}
```

Create `src/auth/credentials.js` exporting `parseCredentials(input)`. It
should accept an object with `email` and `password` fields, trim and lowercase
the email, and return `{ email, password }` when both fields are non-empty
strings. It should return `null` for missing fields, empty strings, or
non-string values.

Create `test/auth/credentials.test.js` with node:test coverage for:

- normalizing an uppercase email
- rejecting an empty password
- rejecting a missing email
- rejecting non-string input fields

Run `npm test` and keep it passing.

## Task 2: Add request validation helper

**Files:**

- `src/auth/requireCredentials.js`
- `test/auth/requireCredentials.test.js`

Create `src/auth/requireCredentials.js` exporting
`requireCredentials(body)`. It should call `parseCredentials(body)` and
return `{ ok: true, credentials }` for valid input. For invalid input, return
`{ ok: false, status: 400, error: "email and password are required" }`.

Create `test/auth/requireCredentials.test.js` covering the success and invalid
input paths.

Run `npm test` after the change.
XEOF
