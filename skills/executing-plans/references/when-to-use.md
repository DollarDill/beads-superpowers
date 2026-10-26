# When to Use

Read this when deciding whether inline execution fits this plan, or whether subagent-driven development is the better path.

- You have a plan from beads-superpowers:writing-plans and your human partner chose inline execution at the handoff.
- Your harness has no subagent tool (see `../using-superpowers/references/`). Never fabricate a dispatch; run the plan here.
- Tasks are mostly independent — the same precondition as beads-superpowers:subagent-driven-development.

Prefer subagent-driven development when the plan has more than about eight tasks, when a task's brief plus its expected test output would not fit one uncompacted stretch, or when the plan touches auth, secrets, permissions, input validation or data deletion. Inline over a long plan still works — beads make it recoverable — but the last tasks get the least of you.
