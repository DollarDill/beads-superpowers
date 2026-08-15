## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables the multi-agent tools that skills like `dispatching-parallel-agents` and
`subagent-driven-development` use. Which tools you get depends on the multi-agent version your
model preset selects (current presets run V2; older ones run V1). **Trust your actual tool list
over any table — including this one — when they disagree.**

- **Spawning:** give children a clean context with `spawn_agent {fork_turns: "none"}`; the default
  `"all"` copies your entire transcript into the child. On Codex 0.145+, role files under
  `~/.codex/agents/` attach to isolated forks via `agent_type`.
- **Model routing:** every `spawn_agent` sets `model` **AND** `reasoning_effort` explicitly, per
  the Model Selection rules of the skill you are executing. Setting `model` alone is a trap — the
  child's effort silently resets to that model's default, not yours. Never copy a model name from
  a skill, table, or old session without checking it against your current spawn allowlist.
- **Lifecycle:** V2 has no `close_agent`; finished children are evicted automatically when slots
  are needed, and leaving them unclosed costs nothing. Only V1 sessions have `close_agent` —
  there, close reviewers when their review returns, and close each implementer after its task's
  review passes.
- **Fix rounds — fork divergence:** upstream instructs you to *resume* the implementer with
  `followup_task`. This fork does NOT: every fix round dispatches a **fresh** implementer carrying
  the brief, the report file, and the findings (ADR-0064). The reason is not harness capability —
  on V2 resumption does work — it is that fresh eyes strengthen external-signal verification and
  avoid the author defending their own defect. Do not "restore parity" here.

## Waiting on children

`wait_agent` is an event subscription, not a poll: a long wait wakes the moment a child produces
mailbox activity, with the same latency as a short one. Short-timeout polling buys nothing and
costs a tool call — and a context rebill — per poll.

- While you still have local work, do not wait at all. A completed child's answer is pushed into
  your mailbox and arrives with your next turn.
- When genuinely idle with children outstanding, wait in bounded stretches: `wait_agent` with
  `timeout_ms` 300000–600000 (5–10 minutes). After each stretch — wake or timeout — post one
  status line, run `list_agents`, and chase any child that finished without reporting.
- A stretch that times out with no activity is your cue to reconcile, not to shorten the next
  stretch.

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.

## Beads

| Action | Codex equivalent |
|---|---|
| `bd` CLI (task tracking via beads) | Use native shell tools with `bd` commands |

- Structured questions: `request_user_input` is **plan-mode-gated** by default — outside Plan mode the call errors. Fall back to numbered plain-text options + STOP (config escape: `default_mode_request_user_input`).
