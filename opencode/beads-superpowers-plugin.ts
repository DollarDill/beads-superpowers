import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, readFileSync } from "fs"
import { join } from "path"
import { execSync } from "child_process"

export const BeadsSuperpowers: Plugin = async () => {
  // Resolve skill content from installed locations (NOT cwd — plugin runs in user's project dir)
  const home = process.env.HOME || ""
  const skillCandidates = [
    join(home, ".config/opencode/skills/using-superpowers/SKILL.md"),
    join(home, ".claude/skills/using-superpowers/SKILL.md"),
    join(home, ".agents/skills/using-superpowers/SKILL.md"),
  ]

  let skillContent = ""
  for (const p of skillCandidates) {
    try {
      skillContent = readFileSync(p, "utf-8")
      break
    } catch {
      // try next
    }
  }

  const notFoundHint =
    "beads-superpowers: using-superpowers skill not found — run: npm exec --yes -- skills@latest add DollarDill/beads-superpowers -a opencode -g --copy -y"

  // Resolve the plugin root (dir containing hooks/session-start) using the same
  // home-relative candidate search as skillCandidates above.
  const pluginRootCandidates = [join(home, ".config/opencode"), join(home, ".claude"), join(home, ".agents")]
  let pluginRoot = pluginRootCandidates[0]
  for (const root of pluginRootCandidates) {
    if (existsSync(join(root, "hooks/session-start"))) {
      pluginRoot = root
      break
    }
  }

  // once-per-session guard — closure-scoped (OpenCode instantiates the plugin once per process)
  const seen = new Set<string>()

  // One source of truth: all selection/degradation policy lives in hooks/session-start.
  // This execs the canonical composer with --emit-plain (raw text, no JSON envelope).
  // primary=true means text is the COMPLETE session context (bootstrap + <beads-context>
  // envelope) and must be injected as-is. On ANY throw (hook missing, non-bash environment,
  // timeout) it falls back (primary=false) to a minimal, policy-free pointer — NEVER the
  // 168KB bd prime dump. See tests/hooks/test-opencode-injection.mjs for the anti-fork
  // guard that keeps this function free of memory-selection policy.
  const composerContext = (root: string): { text: string; primary: boolean } => {
    try {
      const text = execSync(`"${join(root, "hooks/session-start")}" --emit-plain 2>/dev/null`, {
        encoding: "utf-8",
        timeout: 10000,
      }).trim()
      return { text, primary: true }
    } catch {
      let memLine = ""
      try {
        memLine = execSync("bd memories 2>/dev/null", { encoding: "utf-8", timeout: 5000 }).split("\n")[0] ?? ""
      } catch {
        // bd absent
      }
      const text = [
        "beads-superpowers: session hook unavailable in this environment.",
        "Load skills via the Skill tool (start: using-superpowers).",
        memLine ? `${memLine} — search: bd memories <keyword>, fetch: bd recall <key>` : "",
      ]
        .filter(Boolean)
        .join("\n")
      return { text, primary: false }
    }
  }

  return {
    // Hook 1: first chat.message of a session → bootstrap (using-superpowers + composer context), once only.
    // No per-turn injection (ADR-0039).
    // Injection is via output.parts mutation (returning objects is a no-op in @opencode-ai/plugin).
    "chat.message": async (input: { sessionID: string }, output: { message: unknown; parts: any[] }) => {
      if (!seen.has(input.sessionID)) {
        seen.add(input.sessionID)
        const ctx = composerContext(pluginRoot)
        // Primary output already IS the complete session context — inject as-is; adding the
        // plugin-side bootstrap would double it and re-wrapping would nest the tags. Only
        // the fallback needs the bootstrap + <beads-context> envelope built here.
        const bootstrap = skillContent
          ? `<EXTREMELY_IMPORTANT>\nYou have beads-superpowers.\n\n${skillContent}\n</EXTREMELY_IMPORTANT>`
          : notFoundHint
        const text = ctx.primary
          ? ctx.text || bootstrap
          : `${bootstrap}\n\n<beads-context>\n${ctx.text}\n</beads-context>`
        output.parts.unshift({ type: "text", text })
      }
    },

    // Hook 2: compaction resilience — re-inject beads context after context window compaction.
    "experimental.session.compacting": async (
      _input: { sessionID: string },
      output: { context: string[]; prompt?: string }
    ) => {
      const ctx = composerContext(pluginRoot)
      const pointer = "beads-superpowers is installed. Run skills via the skill tool."
      // Same rule as bootstrap: primary composer output is complete — push as-is.
      output.context.push(ctx.primary && ctx.text ? ctx.text : ctx.text ? `${pointer}\n\n${ctx.text}` : pointer)
    },
  }
}
