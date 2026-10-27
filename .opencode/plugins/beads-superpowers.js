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
  // entry is dropped when it has a . or .. component, literally starts with
  // the cwd (logical, physical or canonical), or lies physically inside the
  // cwd tree or the project root (CLAUDE_PROJECT_DIR, else
  // CURSOR_PROJECT_DIR, else the highest .git ancestor of the cwd); every
  // entry is dropped when a root variable is relative or does not resolve.
  // The logical cwd is $PWD when it names the cwd, as a shell started here
  // would take it. Pinned with the shell copies by
  // tests/hooks/test-path-containment.sh.
  const entryOutside = () => {
    const collapse = (p) => (p.startsWith('//') ? '/' + p.replace(/^\/+/, '') : p);
    const strip1 = (p) => (p.endsWith('/') ? p.slice(0, -1) : p);
    // Shell `cd -P <p>/ && pwd -P`: the physical directory, or ''.
    const physDir = (p) => {
      try {
        return statSync(p).isDirectory() ? collapse(realpathSync(p)) : '';
      } catch {
        return '';
      }
    };
    let cwd = '';
    try { cwd = collapse(process.cwd()); } catch { cwd = ''; }
    let ok = true;
    let root = '';
    for (const v of ['CLAUDE_PROJECT_DIR', 'CURSOR_PROJECT_DIR']) {
      const val = process.env[v] ?? '';
      if (val.startsWith('/')) root = root || val;
      else if (val) ok = false;
    }
    let pwd = process.env.PWD ?? '';
    try {
      const a = statSync(pwd);
      const b = statSync('.');
      if (!pwd.startsWith('/') || a.dev !== b.dev || a.ino !== b.ino) pwd = cwd;
    } catch {
      pwd = cwd;
    }
    const physPfx = strip1(cwd);
    const pwdPfx = pwd ? strip1(collapse(pwd)) : physPfx;
    let can = cwd;
    if (pwd) {
      can = physDir(pwd) ? collapse(path.posix.normalize(pwd)) : '';
      if (!can) ok = false;
    }
    const canPfx = strip1(can);
    if (root) {
      root = physDir(root);
      if (!root) ok = false;
    } else if (ok) {
      root = cwd;
      let d = cwd;
      while (d) {
        if (existsSync(strip1(d) + '/.git')) root = d;
        if (d === '/') break;
        d = d.slice(0, d.lastIndexOf('/')) || '/';
      }
    }
    const cwdPfx = strip1(cwd);
    const rootPfx = strip1(root);
    return (entry) => {
      const cand = strip1(entry) + '/bash';
      if (cand.includes('/./') || cand.includes('/../')) return false;
      const lit = collapse(cand);
      if ([pwdPfx, physPfx, canPfx].some((pfx) => lit.startsWith(pfx + '/'))) return false;
      const d = physDir(strip1(entry) + '/');
      if (!(ok && cwd && root && d)) return false;
      return !((d + '/').startsWith(cwdPfx + '/') || (d + '/').startsWith(rootPfx + '/'));
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
