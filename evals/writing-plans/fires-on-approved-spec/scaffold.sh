#!/usr/bin/env bash
# Seeds a tiny habits app plus an approved export spec for the writing-plans eval cases.
# Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
mkdir -p src .internal/specs
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
cat > .internal/specs/2026-01-01-habit-export-design.md <<'EOF'
# Design: habit export

Status: Approved

## Background

Users have asked for a way to keep a personal record of their streaks outside the app.
This design adds a single download that gives them that record.

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
