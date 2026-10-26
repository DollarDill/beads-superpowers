#!/usr/bin/env bash
# Seeds a tiny habits app, an approved reports spec, and a plan with six independent tasks, for the SDD parallel-batch case.
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
cat > .internal/specs/2026-01-01-habit-reports-design.md <<'EOF'
# Design: habit report helpers

Status: Approved

## Requirements

- **R1** `src/dates.js` exports `isoDate(date)`, which returns the date as `YYYY-MM-DD`.
- **R2** `src/streaks.js` exports `longestStreak(habits)`, which returns the habit with the highest
  `streak`, or `null` for an empty list.
- **R3** `src/counts.js` exports `doneToday(habits, today)`, which counts the habits whose
  `lastCompleted` falls on the same calendar day as `today`.
- **R4** `src/names.js` exports `habitNames(habits)`, which returns the habit names sorted
  alphabetically.
- **R5** `src/totals.js` exports `totalStreak(habits)`, which returns the sum of every habit's
  `streak`, or `0` for an empty list.
- **R6** `src/stale.js` exports `staleHabits(habits, cutoff)`, which returns the habits whose
  `lastCompleted` is before `cutoff`.

## Out of scope

Routes, persistence, and any user interface for these helpers.
EOF
cat > .internal/plans/2026-01-01-habit-reports.md <<'EOF'
# Habit Report Helpers Implementation Plan

**Goal:** Add six small, independent report helpers.

**Architecture:** Six pure functions, each in its own module with its own test file. No task
consumes another task's output.

**Tech Stack:** Node 20, ES modules, `node:test`.

**Spec:** `.internal/specs/2026-01-01-habit-reports-design.md`

## Global Constraints

- No new runtime dependencies: Node standard library only.
- Each helper is a pure function and does not import `src/habits.js`.

---

### Task 1: ISO date helper

**Files:**
- Create: `src/dates.js`
- Test: `test/dates.test.js`

**Interfaces:**
- Produces: `isoDate(date: Date) -> string`

**Acceptance Criteria:**
- `isoDate(new Date(2026, 0, 3))` returns `2026-01-03`.

- [ ] **Step 1: Write the failing test** in `test/dates.test.js`.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `isoDate`** in `src/dates.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 2: Longest streak

**Files:**
- Create: `src/streaks.js`
- Test: `test/streaks.test.js`

**Interfaces:**
- Produces: `longestStreak(habits: Habit[]) -> Habit | null`

**Acceptance Criteria:**
- Returns the habit with the highest `streak`; returns `null` for an empty list.

- [ ] **Step 1: Write failing tests** in `test/streaks.test.js` for a populated and an empty list.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `longestStreak`** in `src/streaks.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 3: Done-today count

**Files:**
- Create: `src/counts.js`
- Test: `test/counts.test.js`

**Interfaces:**
- Produces: `doneToday(habits: Habit[], today: Date) -> number`

**Acceptance Criteria:**
- Counts the habits whose `lastCompleted` is on the same calendar day as `today`.

- [ ] **Step 1: Write failing tests** in `test/counts.test.js` for same-day, previous-day and empty inputs.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `doneToday`** in `src/counts.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 4: Habit names

**Files:**
- Create: `src/names.js`
- Test: `test/names.test.js`

**Interfaces:**
- Produces: `habitNames(habits: Habit[]) -> string[]`

**Acceptance Criteria:**
- Returns the habit names sorted alphabetically; returns `[]` for an empty list.

- [ ] **Step 1: Write failing tests** in `test/names.test.js` for an unsorted and an empty list.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `habitNames`** in `src/names.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 5: Total streak

**Files:**
- Create: `src/totals.js`
- Test: `test/totals.test.js`

**Interfaces:**
- Produces: `totalStreak(habits: Habit[]) -> number`

**Acceptance Criteria:**
- Returns the sum of every habit's `streak`; returns `0` for an empty list.

- [ ] **Step 1: Write failing tests** in `test/totals.test.js` for a populated and an empty list.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `totalStreak`** in `src/totals.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**

### Task 6: Stale habits

**Files:**
- Create: `src/stale.js`
- Test: `test/stale.test.js`

**Interfaces:**
- Produces: `staleHabits(habits: Habit[], cutoff: Date) -> Habit[]`

**Acceptance Criteria:**
- Returns the habits whose `lastCompleted` is before `cutoff`.

- [ ] **Step 1: Write failing tests** in `test/stale.test.js` for habits before, on and after the cutoff.
- [ ] **Step 2: Run `npm test`** — expect FAIL.
- [ ] **Step 3: Implement `staleHabits`** in `src/stale.js`.
- [ ] **Step 4: Run `npm test`** — expect PASS.
- [ ] **Step 5: Commit.**
EOF
