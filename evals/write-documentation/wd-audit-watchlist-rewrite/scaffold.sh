#!/usr/bin/env bash
# Seeds a ~330-word README section draft for the wd-audit-watchlist-rewrite case.
# The draft leans on repeated fallback diction from the write-documentation audit
# watchlist (robust, seamless(ly), leverage family, crucial x3 each; plays a pivotal
# role x3; in today's fast-paced world, delve into x2 each) around concrete,
# checkable facts. Runs in the eval's empty workspace; writes relative paths only.
set -euo pipefail
cat > DRAFT.md <<'EOF'
# README draft: Why queuekit

In today's fast-paced world, background jobs play a pivotal role in almost every Node.js application. queuekit is a robust job queue that leverages SQLite, so you get durable jobs without running Redis or a separate server. All jobs live in one SQLite file, `queue.db` by default, and payloads are stored as JSON. It needs Node 20 or later and has one runtime dependency, `better-sqlite3`.

## Retries

Retries play a pivotal role in any robust queue. By default queuekit retries a failed job up to 5 times, with exponential backoff that starts at 2 seconds and is capped at 5 minutes. You can leverage the `maxAttempts` option to change that limit per queue. It's crucial to understand that delivery is at-least-once, so your handlers must be idempotent. A job that fails its final attempt moves to the `dead_jobs` table, and `queue.retryDead(id)` seamlessly puts it back in line. Every job keeps its most recent error message in the `last_error` column.

## Concurrency and scheduling

Concurrency plays a pivotal role too. Each worker runs 4 jobs at a time by default, and the `concurrency` option seamlessly raises or lowers that number. Several workers can share one database file on the same machine, but queuekit does not support a database file on a network file system. To delay a job, pass `runAt` to `queue.add(name, payload, { runAt })`; scheduled jobs fire with one-second resolution. Let's delve into the numbers: in our benchmark (`bench/throughput.js`), a single worker processed about 1,200 jobs per second on an M2 MacBook Air.

## Shutting down

A clean shutdown is crucial for a robust deployment. `queue.close()` waits up to 30 seconds for running jobs to finish before it exits, so a deploy can seamlessly replace workers without dropping work. Leveraging `queue.close()` in your SIGTERM handler is crucial.

## Next steps

In today's fast-paced world, you shouldn't have to delve into queue internals to ship. Install it with `npm install queuekit` and see `docs/api.md` for every option. queuekit is MIT licensed.
EOF
