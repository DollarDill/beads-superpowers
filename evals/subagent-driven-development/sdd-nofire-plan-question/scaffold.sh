#!/usr/bin/env bash
# Seeds a tiny habits app plus an approved export spec and its plan for the SDD fire/no-fire cases.
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

**Architecture:** A pure formatter in `src/csv.js` turns habit records into CSV text; a new route in
`src/server.js` serves it.

**Tech Stack:** Node 20, ES modules, `node:test`.

**Spec:** `.internal/specs/2026-01-01-habit-export-design.md`

## Global Constraints

- Columns, in order: `id,name,streak,last_done`.
- Dates are formatted as ISO-8601 (`YYYY-MM-DD`).
- The output never includes `password_hash` or any other field of the owner record.

---

### Task 1: CSV formatter

**Files:**
- Create: `src/csv.js`
- Test: `test/csv.test.js`

**Interfaces:**
- Produces: `toCsv(habits: Habit[]) -> string`

**Acceptance Criteria:**
- Header row `id,name,streak,last_done`, then one row per habit sorted by `name`.
- `lastCompleted` is written as `YYYY-MM-DD`; an empty list yields the header row only.

- [ ] **Step 1: Write failing tests** in `test/csv.test.js` for the header, the sort order, the date format and the empty list.
- [ ] **Step 2: Run `npm test`** — expect FAIL (`toCsv` not defined).
- [ ] **Step 3: Implement `toCsv`** in `src/csv.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 2: Export route

**Files:**
- Modify: `src/server.js`
- Test: `test/server.test.js`

**Interfaces:**
- Consumes: `toCsv(habits)` from Task 1, `listHabits()` from `src/habits.js`.

**Acceptance Criteria:**
- `GET /export.csv` responds 200 with `content-type: text/csv` and the body `toCsv(listHabits())`.
- The body never contains `password_hash`.

- [ ] **Step 1: Write a failing test** that requests `/export.csv` and checks the status, content type and body.
- [ ] **Step 2: Run `npm test`** — expect FAIL (404).
- [ ] **Step 3: Add the route** to `src/server.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 3: README

**Files:**
- Modify: `README.md`

**Acceptance Criteria:**
- The README documents `GET /export.csv` and its columns.

- [ ] **Step 1: Document the route** in `README.md`.
- [ ] **Step 2: Commit.**
EOF
