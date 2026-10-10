#!/usr/bin/env bash
# Seeds a tiny habits app plus an existing export plan for the writing-plans no-fire case.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src .internal/plans
cat > README.md <<'EOF'
# Habits tracker

A minimal app that tracks daily habits and their streaks.
EOF
cat > package.json <<'EOF'
{
  "name": "habits",
  "version": "0.1.0",
  "type": "module",
  "scripts": { "start": "node src/server.js" }
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
cat > .internal/plans/2026-01-01-habit-export.md <<'EOF'
# Habit Export Implementation Plan

**Goal:** Let users download their habits as a CSV file.

**Spec:** none — requirements: a CSV download of habits.

### Task 1: CSV formatter

**Files:**
- Create: `src/csv.js`

Add `toCsv(rows)`, which turns habit records into CSV text with a header row.

### Task 2: Download route

**Files:**
- Modify: `src/server.js`

Add a route to `src/server.js` that calls `toCsv(listHabits())` and returns the result with a
`text/csv` content type, so the browser downloads it.

### Task 3: README

**Files:**
- Modify: `README.md`

Document the new download route.
EOF
