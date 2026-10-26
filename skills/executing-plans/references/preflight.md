# Pre-flight Scan

Read this when Setup reaches the pre-flight scan, before the first task: what to record in the epic's notes about cross-task interfaces and how to rule on conflicts.

Pre-flight scan: for every task that consumes what an earlier task produces, one row — the two tasks, what one produces against what the other consumes, what you found — appended with `bd update <epic-id> --append-notes "Pre-flight: <row>"`. Tasks that share nothing get no row; a plan whose tasks share nothing gets the single line `Pre-flight: no shared interfaces`. Rule on each conflict the spec settles; escalate the rest. Record each ruling beside its row. Each task's own text is checked when you read its brief, not here.
