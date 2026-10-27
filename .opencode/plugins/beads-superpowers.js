/**
 * beads-superpowers plugin for OpenCode.ai
 *
 * Upstream-parity base: obra/superpowers .opencode/plugins/superpowers.js (v6.1.1)
 * — bootstrap injected via message transform into the first user message
 * (upstream #750/#894), module-level caching (#1202), skills auto-registered via
 * the config hook. Install is the git-backed package spec in opencode.json
 * (see ../INSTALL.md); everything resolves repo-relative — no fallback roots.
 *
 * Fork delta (minimal, policy-free): bootstrap content comes from the canonical
 * composer `hooks/session-start --emit-plain` (using-superpowers bootstrap +
 * composed <beads-context>); on failure it falls back to a minimal pointer —
 * NEVER the full bd prime dump. Plus a compaction re-injection hook. All
 * selection/degradation policy lives in hooks/session-start; the anti-fork
 * guard is tests/hooks/test-opencode-injection.mjs.
 */

import path from 'path';
import { execSync } from 'child_process';
import { existsSync, realpathSync, statSync } from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Module-level cache for bootstrap content (upstream #1202 pattern).
// undefined = not yet loaded; a string = cached payload (composed or pointer).
let _bootstrapCache = undefined;

export const BeadsSuperpowersPlugin = async ({ client, directory }) => {
  const packageRoot = path.resolve(__dirname, '../..');
  const skillsDir = path.join(packageRoot, 'skills');

  // hooks/session-start's in-project PATH-entry drop, for this process. The
  // rule is hooks/run-hook.cmd's bsp_outside, applied to <entry>/bash: an
  // entry is dropped when it has a . or .. component, passes through the cwd
  // as written, or lies physically inside the cwd tree or the project root
  // (CLAUDE_PROJECT_DIR, else CURSOR_PROJECT_DIR, else the highest .git
  // ancestor of the cwd below $HOME), all compared by file identity; every entry is
  // dropped when a root variable is relative or does not resolve. Pinned
  // with the shell copies by tests/hooks/test-path-containment.sh.
  const entryOutside = () => {
    const strip1 = (p) => (p.endsWith('/') ? p.slice(0, -1) : p);
    // Shell `cd -P <p>/ && pwd -P`: the physical directory, or ''. The
    // native realpath(3) lets the kernel resolve a symlink before a later
    // "..", as the shell copies do; realpathSync's JS version cancels
    // lnk/.. as text first and lands elsewhere.
    const physDir = (p) => {
      try {
        return statSync(p).isDirectory() ? realpathSync.native(p) : '';
      } catch {
        return '';
      }
    };
    // p or an ancestor of it, up to /, is the same directory as d: compared
    // by identity (device and inode), never by spelling, since a case- or
    // normalisation-insensitive filesystem (the macOS APFS default) gives one
    // directory many spellings. The launcher's bsp_within.
    const same = (a, b) => {
      try {
        const x = statSync(a, { bigint: true });
        const y = statSync(b, { bigint: true });
        return x.dev === y.dev && x.ino === y.ino;
      } catch {
        return false;
      }
    };
    const within = (p, d) => {
      for (;;) {
        if (same(p, d)) return true;
        if (!/\/.*[^/]/.test(p)) return false;
        p = p.slice(0, p.lastIndexOf('/')) || '/';
      }
    };
    let cwd = '';
    try { cwd = process.cwd(); } catch { cwd = ''; }
    let ok = true;
    let root = '';
    for (const v of ['CLAUDE_PROJECT_DIR', 'CURSOR_PROJECT_DIR']) {
      const val = process.env[v] ?? '';
      if (val.startsWith('/')) root = root || val;
      else if (val) ok = false;
    }
    if (root) {
      root = physDir(root);
      if (!root) ok = false;
    } else if (ok) {
      // Stop below $HOME (by identity): $HOME is never the root, so a
      // dotfiles repo's .git there cannot pull every ~/... entry into the
      // project; with no .git found below it, the root is the cwd. A HOME
      // that is unset or not absolute is not used.
      const home = process.env.HOME ?? '';
      root = cwd;
      let d = cwd;
      while (d) {
        if (home.startsWith('/') && same(d, home)) break;
        if (existsSync(strip1(d) + '/.git')) root = d;
        if (d === '/') break;
        d = d.slice(0, d.lastIndexOf('/')) || '/';
      }
    }
    return (entry) => {
      const cand = strip1(entry) + '/bash';
      if (cand.includes('/./') || cand.includes('/../')) return false;
      const dir = cand.slice(0, cand.lastIndexOf('/'));
      if (within(dir, '.')) return false;
      const d = physDir(dir + '/');
      if (!(ok && cwd && root && d)) return false;
      return !(within(d, '.') || within(d, root));
    };
  };

  // The env for every child: PATH cut to absolute entries outside the
  // project, with hooks/session-start's rule (~ and ~/x become $HOME when
  // HOME is absolute, anything else relative is dropped, then every entry
  // inside the project, see entryOutside; fallback /usr/bin:/bin). An empty
  // or relative entry, or PATH="", makes a lookup search the cwd, an
  // untrusted project, and an absolute entry can sit inside it
  // (<proj>/node_modules/.bin); the launcher's bash and `bd` are both
  // looked up on it.
  const childEnv = () => {
    const home = process.env.HOME ?? '';
    const outside = entryOutside();
    const keep = [];
    for (let p of (process.env.PATH ?? '').split(':')) {
      if (p === '~' || p.startsWith('~/')) {
        if (!home.startsWith('/')) continue;
        p = home + p.slice(1);
      } else if (!p.startsWith('/')) {
        continue;
      }
      if (outside(p)) keep.push(p);
    }
    return { ...process.env, PATH: keep.join(':') || '/usr/bin:/bin' };
  };

  // On Windows the plugin starts no child: CreateProcess and cmd.exe
  // (execSync's shell) search the cwd before PATH, and no env can change that,
  // so a bash.exe or bd.exe in the project would run.
  const noChildren = () => process.platform === 'win32';

  // Exec the canonical composer through hooks/run-hook.cmd, run by /bin/sh:
  // the launcher takes the first bash on PATH outside the project (an
  // absolute entry can sit inside it, <proj>/node_modules/.bin), else $BASH
  // under the same check, and execs session-start with it. The composer's
  // own #!/usr/bin/env bash would take the first bash on PATH, wherever it
  // is. No usable bash: the launcher exits 0 with no output.
  // Returns null on failure, on Windows, OR on the composer's event-dedup
  // yielding an empty rapid re-run — a real payload always carries the
  // <EXTREMELY_IMPORTANT> injection marker.
  const composeBootstrap = () => {
    if (noChildren()) return null;
    try {
      const text = execSync(
        `/bin/sh "${path.join(packageRoot, 'hooks/run-hook.cmd')}" session-start --emit-plain 2>/dev/null`,
        { encoding: 'utf8', timeout: 10000, env: childEnv() }
      ).trim();
      return text.includes('EXTREMELY_IMPORTANT') ? text : null;
    } catch {
      return null;
    }
  };

  const getBootstrapContent = () => {
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    const composed = composeBootstrap();
    if (composed) {
      _bootstrapCache = composed;
      return _bootstrapCache;
    }

    // Policy-free pointer fallback (composer missing/failed). Wrapped in the
    // marker so the transform guard below stays idempotent.
    let memLine = '';
    if (!noChildren()) {
      try {
        memLine = execSync('bd memories 2>/dev/null', { encoding: 'utf8', timeout: 5000, env: childEnv() }).split('\n')[0] ?? '';
      } catch {
        // bd absent
      }
    }
    _bootstrapCache = [
      '<EXTREMELY_IMPORTANT>',
      'beads-superpowers: session composer unavailable in this environment.',
      'Load skills via the skill tool (start: using-superpowers).',
      memLine ? `${memLine} — search: bd memories <keyword>, fetch: bd recall <key>` : '',
      '</EXTREMELY_IMPORTANT>',
    ].filter(Boolean).join('\n');
    return _bootstrapCache;
  };

  return {
    // Upstream: inject the skills path into live config so OpenCode discovers
    // the bundled skills without symlinks or config edits.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },

    // Upstream: inject bootstrap into the first user message of each session.
    // Fires on every agent step; the cache + marker guard keep it idempotent.
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;
      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    },

    // Fork delta: compaction resilience — re-compose fresh beads context after
    // context-window compaction (beads state has moved on; a stale cache is
    // also promoted here if the composer was briefly unavailable at startup).
    'experimental.session.compacting': async (_input, output) => {
      const fresh = composeBootstrap();
      if (fresh) _bootstrapCache = fresh;
      output.context.push(fresh || 'beads-superpowers is installed. Run skills via the skill tool.');
    },
  };
};
