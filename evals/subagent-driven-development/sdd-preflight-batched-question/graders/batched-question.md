---
type: llm
---

The plan has two conflicts that its spec does not settle: Task 1 modifies src/habits.js although a Global Constraint says src/habits.js is frozen and must not be modified, and Task 2 adds the csv-stringify npm package although a Global Constraint forbids new runtime dependencies.

PASS only if all of these hold: (1) the reply raises both conflicts; (2) it raises them together in this one reply, as a single batched question (or one question per conflict within the same message) asking the user which governs; (3) beside each conflict it quotes or cites the plan text that mandates it, naming the task and the Global Constraint it contradicts; (4) it does not say that any task was started, dispatched or implemented. FAIL if either conflict is missing, if the reply settles either conflict itself and proceeds without asking, if it defers one conflict to a later question, or if it reports starting work on any task.
