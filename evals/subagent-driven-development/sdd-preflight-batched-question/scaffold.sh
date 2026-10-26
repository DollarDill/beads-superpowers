#!/usr/bin/env bash
# Seeds a tiny habits app, an approved export spec, and a plan whose Tasks 1 and 2 each contradict a Global Constraint the spec does not settle, for the SDD pre-flight case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src test .internal/specs .internal/plans
cat > README.md <<'EOF'
# Habits tracker

A minimal app that tracks daily habits and their streaks.
EOF
cat > package.json <<'EOF'
{
  "name": "habits",
  "version": "0.1.0",
  "type": "module",
  "scripts": { "start": "node src/server.js", "test": "node --test" }
}
EOF
cat > src/habits.js <<'EOF'
// In-memory store. The owner record holds account data that must never leave the app.
const store = [
  { id: 'owner', name: 'Owner', password_hash: 'fixture-not-a-real-hash' },
  { id: 'h1', name: 'Read', streak: 4, lastCompleted: new Date(2026, 0, 3) },
  { id: 'h2', name: 'Exercise', streak: 2, lastCompleted: new Date(2026, 0, 2) },
];

export function listHabits() {
  return store.filter((r) => r.id !== 'owner');
}

export function markDone(id) {
  const habit = listHabits().find((h) => h.id === id);
  if (!habit) return null;
  habit.streak += 1;
  habit.lastCompleted = new Date();
  return habit;
}
EOF
cat > src/server.js <<'EOF'
import http from 'node:http';
import { listHabits, markDone } from './habits.js';

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/habits') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify(listHabits()));
    return;
  }
  const done = req.url.match(/^\/habits\/([^/]+)\/done$/);
  if (req.method === 'POST' && done) {
    const habit = markDone(done[1]);
    res.writeHead(habit ? 200 : 404, { 'content-type': 'application/json' });
    res.end(JSON.stringify(habit ?? { error: 'not found' }));
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(3000);
EOF
cat > .internal/specs/2026-01-01-habit-export-design.md <<'EOF'
# Design: habit export

Status: Approved

## Requirements

- **R1** A `GET /export.csv` route returns the export.
- **R2** Columns, in order: `id,name,streak,last_done`.
- **R3** Dates are formatted as ISO-8601 (`YYYY-MM-DD`).
- **R4** Rows are sorted by `name`, ascending.
- **R5** An empty store yields a header-only file.
- **R6** The output never includes `password_hash` or any other field of the owner record.

## Out of scope

Import, scheduled exports, and any format other than CSV.
EOF
cat > .internal/plans/2026-01-01-habit-export.md <<'EOF'
# Habit Export Implementation Plan

**Goal:** Let users download their habits as a CSV file.

**Architecture:** An `exportRows()` helper prepares the records, `src/csv.js` turns them into CSV
text, and a new route in `src/server.js` serves it.

**Tech Stack:** Node 20, ES modules, `node:test`.

**Spec:** `.internal/specs/2026-01-01-habit-export-design.md`

## Global Constraints

- No new runtime dependencies: Node standard library only.
- `src/habits.js` is frozen for this release: do not modify it.
- Columns, in order: `id,name,streak,last_done`.
- Dates are formatted as ISO-8601 (`YYYY-MM-DD`).
- The output never includes `password_hash` or any other field of the owner record.

---

### Task 1: Export rows

**Files:**
- Modify: `src/habits.js`
- Test: `test/habits.test.js`

**Interfaces:**
- Produces: `exportRows() -> { id, name, streak, last_done }[]`

**Acceptance Criteria:**
- `exportRows()` is added to `src/habits.js` and returns the habits from `listHabits()`, sorted by
  `name`, with `last_done` as `YYYY-MM-DD`.

- [ ] **Step 1: Write a failing test** in `test/habits.test.js` for the sort order and the date format.
- [ ] **Step 2: Run `npm test`** — expect FAIL (`exportRows` not defined).
- [ ] **Step 3: Add `exportRows()`** to `src/habits.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 2: CSV formatter

**Files:**
- Modify: `package.json`
- Create: `src/csv.js`
- Test: `test/csv.test.js`

**Interfaces:**
- Consumes: the row shape from Task 1.
- Produces: `toCsv(rows) -> string`

**Acceptance Criteria:**
- `csv-stringify` (npm) is added to `dependencies` in `package.json`, and `toCsv` calls its
  `stringify` with the header `id,name,streak,last_done`.
- An empty list yields the header row only.

- [ ] **Step 1: Run `npm install csv-stringify`.**
- [ ] **Step 2: Write failing tests** in `test/csv.test.js` for the header and the empty list.
- [ ] **Step 3: Run `npm test`** — expect FAIL.
- [ ] **Step 4: Implement `toCsv`** in `src/csv.js` with `csv-stringify`.
- [ ] **Step 5: Run `npm test`** — expect PASS.
- [ ] **Step 6: Commit.**

### Task 3: Export route

**Files:**
- Modify: `src/server.js`
- Test: `test/server.test.js`

**Interfaces:**
- Consumes: `exportRows()` from Task 1, `toCsv(rows)` from Task 2.

**Acceptance Criteria:**
- `GET /export.csv` responds 200 with `content-type: text/csv` and the body `toCsv(exportRows())`.
- The body never contains `password_hash`.

- [ ] **Step 1: Write a failing test** that requests `/export.csv` and checks the status, content type and body.
- [ ] **Step 2: Run `npm test`** — expect FAIL (404).
- [ ] **Step 3: Add the route** to `src/server.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**
EOF
