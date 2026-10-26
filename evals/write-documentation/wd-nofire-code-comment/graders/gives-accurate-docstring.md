---
type: llm
arm: both
---

PASS if the reply gives a one-line docstring or JSDoc comment for `parseDate` that accurately describes what the scaffolded function does: it parses a strict `YYYY-MM-DD` string into a `Date` at UTC midnight, and returns `null` when the input does not match that format. FAIL if the reply is a refusal or is empty, gives no docstring line, gives more than one line, or describes behaviour the function does not have (for example claiming it throws on bad input or accepts other formats).
