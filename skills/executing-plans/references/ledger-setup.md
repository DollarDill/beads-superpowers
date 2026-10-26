# Fresh Ledger Setup

Read this when no epic for this plan exists yet and you are creating the ledger: the epic, the one-call task import, and the `blocks` ordering.

**Fresh:** create the epic, then import the tasks:

   ```bash
   # 1. Create the epic (→ note its id). Plan: and Spec: are the resume anchors.
   bd create "Epic: <plan-name>" -t epic -p 2 -d "<goal>
Plan: <plan file path>
Spec: <spec file path or 'none reachable'>

## Success Criteria
- <measurable outcome from the plan's Goal>"

   # 2. Author the tasks as JSONL — one issue per line, id OMITTED (auto-assigned;
   #    a supplied colliding id would overwrite that bead and reset its omitted fields).
   #    Parent each to the epic; embed the bd lint-required '## Acceptance Criteria' in
   #    'description'. Read `bd import --help` on first use; `bd export | jq -c 'select(.id=="<id>")'` round-trips
   #    a real bead as a schema template.
   cat <<'EOF' | bd import -
{"title":"Task 1: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
{"title":"Task 2: <title>","issue_type":"task","priority":2,"description":"<summary>\n\n## Acceptance Criteria\n- <outcome>","dependencies":[{"depends_on_id":"<epic-id>","type":"parent-child"}]}
EOF
   ```

   Confirm the import output shows no `Skipped dependency`.

   > **Wire task ordering (`blocks`) after the import.** `parent-child` rides the import, but inter-task `blocks` deps do not. Capture the ids **scoped to the parent**, then wire ordering atomically:
   > ```bash
   > bd ready --parent <epic-id> --json   # → the child task ids
   > printf 'dep add <task-2-id> <task-1-id> blocks\n' | bd batch
   > ```
   > Note: `bd batch create` does not support `--description`/`--parent`/`--acceptance` — that is why task *creation* uses `bd import`, not `bd batch`.
