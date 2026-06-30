import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync } from "fs"
import { join, dirname } from "path"
import { execSync } from "child_process"

export const BeadsSuperpowers: Plugin = async () => {
  // Resolve skill content from installed locations (NOT cwd — plugin runs in user's project dir)
  const home = process.env.HOME || ""
  const skillCandidates = [
    join(home, ".config/opencode/skills/using-superpowers/SKILL.md"),
    join(home, ".claude/skills/using-superpowers/SKILL.md"),
    join(home, ".agents/skills/using-superpowers/SKILL.md"),
  ]

  let skillPath = ""
  let skillContent = ""
  for (const p of skillCandidates) {
    try {
      skillContent = readFileSync(p, "utf-8")
      skillPath = p
      break
    } catch {
      // try next
    }
  }

  // Read reminder-content.txt co-located with SKILL.md; strip full-line # comments
  // (equivalent to bash: sed '/^[[:space:]]*#/d')
  let reminder = ""
  if (skillPath) {
    try {
      const raw = readFileSync(join(dirname(skillPath), "reminder-content.txt"), "utf-8")
      reminder = raw.split("\n").filter(line => !/^\s*#/.test(line)).join("\n")
    } catch {
      // reminder-content.txt not found — per-turn reminder skipped
    }
  }

  const notFoundHint =
    "beads-superpowers: using-superpowers skill not found — run: npm exec --yes -- skills@latest add DollarDill/beads-superpowers -a opencode -g --copy -y"

  // once-per-session guard — closure-scoped (OpenCode instantiates the plugin once per process)
  const seen = new Set<string>()

  const bdPrime = (): string => {
    try {
      return execSync("bd prime 2>/dev/null", { encoding: "utf-8", timeout: 10000 })
    } catch {
      return ""
    }
  }

  return {
    // Hook 1: first chat.message of a session → bootstrap (using-superpowers + bd prime), once only.
    // Subsequent messages → per-turn reminder from reminder-content.txt.
    // Injection is via output.parts mutation (returning objects is a no-op in @opencode-ai/plugin).
    "chat.message": async (input: { sessionID: string }, output: { message: unknown; parts: any[] }) => {
      if (!seen.has(input.sessionID)) {
        seen.add(input.sessionID)
        const bootstrap = skillContent
          ? `<EXTREMELY_IMPORTANT>\nYou have beads-superpowers.\n\n${skillContent}\n</EXTREMELY_IMPORTANT>`
          : notFoundHint
        const prime = bdPrime()
        const text = prime ? `${bootstrap}\n\n<beads-context>\n${prime}\n</beads-context>` : bootstrap
        output.parts.unshift({ type: "text", text })
      } else if (reminder) {
        output.parts.unshift({ type: "text", text: reminder })
      }
    },

    // Hook 2: compaction resilience — re-inject beads context after context window compaction.
    "experimental.session.compacting": async (
      _input: { sessionID: string },
      output: { context: string[]; prompt?: string }
    ) => {
      const prime = bdPrime()
      output.context.push(
        prime
          ? `beads-superpowers is installed. Run skills via the skill tool.\n\n${prime}`
          : "beads-superpowers is installed. Run skills via the skill tool."
      )
    },
  }
}
