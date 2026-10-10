---
type: regex
target:
  source: file
  path: .internal/plans/habit-export.md
pattern: '\b(TBD|TODO|implement later|fill in details)\b'
flags: i
match: not_contains
---
