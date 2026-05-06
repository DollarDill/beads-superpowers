import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync } from "fs"
import { join } from "path"
import { execSync } from "child_process"

export const BeadsSuperpowers: Plugin = async () => {
  // Resolve skill content from installed locations (NOT cwd — plugin runs in user's project dir)
  const home = process.env.HOME || ""
  const skillPaths = [
    join(home, ".config/opencode/skills/using-superpowers/SKILL.md"),
    join(home, ".claude/skills/using-superpowers/SKILL.md"),
    join(home, ".agents/skills/using-superpowers/SKILL.md"),
  ]

  let usingSuperpowersContent = ""
  for (const p of skillPaths) {
    try {
      usingSuperpowersContent = readFileSync(p, "utf-8")
      break
    } catch {
      // Try next path
    }
  }

  // Build reminder text (same content as superpowers-reminder.sh)
  const reminderText = [
    "SUPERPOWERS REMINDER: Before responding, check if any beads-superpowers skill applies.",
    "Key triggers:",
    "- Bug/test failure → systematic-debugging",
    "- Writing code → test-driven-development",
    "- New feature/design → brainstorming",
    "- Challenge/stress-test → stress-test",
    "- Writing a plan → writing-plans",
    "- Executing a plan → subagent-driven-development or executing-plans",
    "- Research question → research-driven-development",
    "- Complex task (6+ files) → using-git-worktrees",
    "- About to claim done → verification-before-completion",
    "- Code review needed → requesting-code-review",
    "- Received review feedback → receiving-code-review",
    "- Writing prose → write-documentation",
    "- Branch complete → finishing-a-development-branch",
    "Also available: document-release, getting-up-to-speed, dispatching-parallel-agents, project-init, setup",
    "If even 1% chance a skill applies, you MUST invoke it.",
  ].join("\n")

  return {
    // Hook 1: SessionStart equivalent — inject using-superpowers + bd prime
    event: async (event: { type: string }) => {
      if (event.type !== "session.created") return

      let bdPrime = ""
      try {
        bdPrime = execSync("bd prime 2>/dev/null", {
          encoding: "utf-8",
          timeout: 10000,
        })
      } catch {
        // bd not installed or not in a beads workspace — skip
      }

      const context = [
        "<EXTREMELY_IMPORTANT>",
        "You have beads-superpowers.",
        "",
        "**Below is your 'using-superpowers' skill:**",
        "",
        usingSuperpowersContent,
        "</EXTREMELY_IMPORTANT>",
        bdPrime
          ? `\n<beads-context>\n${bdPrime}\n</beads-context>`
          : "",
      ].join("\n")

      return { additionalContext: context }
    },

    // Hook 2: UserPromptSubmit equivalent — skill trigger reminders
    "chat.message": async () => {
      return { additionalContext: reminderText }
    },

    // Hook 3: Compaction resilience — re-inject beads context after compaction
    "experimental.session.compacting": async () => {
      let bdPrime = ""
      try {
        bdPrime = execSync("bd prime 2>/dev/null", {
          encoding: "utf-8",
          timeout: 10000,
        })
      } catch {
        // bd not installed — skip
      }
      return {
        context: bdPrime
          ? `beads-superpowers is installed. Run skills via the skill tool.\n\n${bdPrime}`
          : "beads-superpowers is installed. Run skills via the skill tool.",
      }
    },
  }
}
