---
type: llm
---

The reply must contain a revised version of the README section in DRAFT.md (the Skill and Read tool calls are graded separately). Grade only the revised section itself: ignore any commentary, change list or notes outside it, including any that quote the draft's wording. DRAFT.md contains exactly:

```
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
```

The draft repeats seven items from the write-documentation skill's audit watchlist across its paragraphs. Their counts in the draft above (case-insensitive, any inflection):

- A. `robust`: 3
- B. `seamless` / `seamlessly`: 3
- C. `leverage` / `leverages` / `leveraging`: 3
- D. `crucial`: 3
- E. `play a pivotal role` / `plays a pivotal role`: 3
- F. `in today's fast-paced world`: 2
- G. `delve into`: 2

PASS only if all of these hold.

(1) The repeated fallback is gone. Count each of A to G in the revised section the same way. Every count must be 0 or 1: one remaining use of an item is acceptable, and two or more uses of any single item FAILS. Then count each of these stock substitutes in the revised section (case-insensitive, any inflection): `powerful`, `effortless` / `effortlessly`, `essential`, `critical`, `vital`, `key` as an adjective meaning important, `utilize`, `harness`, `streamline`, `plays a key role`, `dive deep into`, `It's worth noting that`, `It's important to note that`, `Notably`, `Importantly`. If any single one of them appears 3 or more times, FAIL: the fallback was swapped for another, not cut.

(2) Every fact is preserved. Wording, order and headings may change, and facts may be merged, but none may be dropped, and changing any number, unit, default, name or identifier FAILS. The facts are: (a) queuekit is a job queue for Node.js built on SQLite, so it needs no Redis or separate server; (b) all jobs live in one SQLite file, `queue.db` by default, with payloads stored as JSON; (c) it needs Node 20 or later and has one runtime dependency, `better-sqlite3`; (d) by default a failed job is retried up to 5 times, with exponential backoff starting at 2 seconds and capped at 5 minutes; (e) the `maxAttempts` option changes that limit per queue; (f) delivery is at-least-once, so handlers must be idempotent; (g) a job that fails its final attempt moves to the `dead_jobs` table, and `queue.retryDead(id)` puts it back in line; (h) every job keeps its most recent error message in the `last_error` column; (i) each worker runs 4 jobs at a time by default, and the `concurrency` option changes that; (j) several workers can share one database file on the same machine, but a database file on a network file system is not supported; (k) a job is delayed by passing `runAt` to `queue.add(name, payload, { runAt })`, and scheduled jobs fire with one-second resolution; (l) in the `bench/throughput.js` benchmark a single worker processed about 1,200 jobs per second on an M2 MacBook Air; (m) `queue.close()` waits up to 30 seconds for running jobs to finish before it exits, so a deploy can replace workers without dropping work, and readers should call it from their SIGTERM handler; (n) install with `npm install queuekit`, `docs/api.md` covers every option, and queuekit is MIT licensed. The opening claim that background jobs matter in almost every Node.js application, and the closing line about not having to learn queue internals to ship, are framing rather than facts and may be cut.

(3) Nothing is invented. FAIL if the revised section adds any feature, option, method, default, number, version, platform, benchmark result, comparison with another tool, or claim that is not in the draft above. Restating a draft fact in other words is not invention.

FAIL if the reply has no revised section, revises only part of the section, or only lists suggestions instead of giving the revised text. In your explanation, give the counts of A to G you found in the revised section.
