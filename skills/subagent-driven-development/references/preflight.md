# Pre-Flight Plan Review

Read this when you are about to dispatch Task 1 of a plan.

Before dispatching Task 1, read the plan once — and **if it names a `Spec:`, read that too**: the
spec is the authority the plan argues from, so in-plan conflicts resolve against it. A plan with no
reachable spec gets a ledger note saying so, because rulings made without one are provisional. Then
scan for conflicts:

- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a defect (a test that asserts nothing, verbatim duplication of a logic block)

Conflicts the spec unambiguously settles: rule on them, record each as `Ruling: … — settled by … — …` in the ledger, and proceed.
Everything else — anything the spec does not settle, and anything on the must-stop list — goes to
your human partner as **one batched structured question**, each finding beside the plan text that
mandates it, asking which governs. Ask before execution begins, not one interrupt per discovery
mid-plan. The review loop remains the net for conflicts that only emerge from implementation.
