#!/usr/bin/env bash
# Anti-fork guard for .hermes-plugin/__init__.py.
#
# WHAT THIS PROVES AND WHAT IT DOES NOT:
# We have no Hermes runtime. The STATIC assertions below are the anti-fork
# properties -- they need no runtime, run in pure bash, and NEVER skip.
# The BEHAVIOURAL assertions run against a FAKE ctx, so they prove our code
# matches our BELIEF about Hermes' contract, not that the belief is correct.
# That belief is inherited, not invented: every behavioural assumption traces to
# a comment upstream wrote from empirical verification against a real Hermes on
# 2026-07-23 (register_skill requires a pathlib.Path; on_session_start return
# values are ignored; ctx.inject_message refuses from that hook).
#
# STYLE CONSTRAINT (verified, not preference): use explicit if/else, never
# `A && B || C`. Pre-commit's shellcheck hook runs `args: [-x]` with NO severity
# filter, so info-level SC2015 FAILS the commit. scripts/lint-shell.sh would NOT
# catch it -- it filters to --severity=warning. A green lint-shell.sh is
# therefore not evidence that a commit will land.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN="$ROOT/.hermes-plugin/__init__.py"
fail=0
ok()  { echo "   ok:   $1"; }
bad() { echo "   FAIL: $1"; fail=1; }

# ---------- STATIC (pure bash, never SKIPs) ----------
if [ ! -f "$PLUGIN" ]; then
  bad "plugin missing: $PLUGIN"
  echo "test-hermes-injection: FAIL"
  exit 1
fi

# The composer-exec assertions (single source of truth, shell/timeout) are added
# in Task 3, alongside the code they constrain.

# No selection policy forked into the plugin. Separate greps, not
# `grep -E 'a\|b'` -- with -E the backslash-pipe is a LITERAL pipe, not
# alternation.
for tok in 'salience' '@type=' 'BSP_MEM_CEILING'; do
  if grep -qF "$tok" "$PLUGIN"; then
    bad "selection-policy token present: $tok"
  else
    ok "no selection-policy token: $tok"
  fi
done

# No bd memories --json (the full dump path).
if grep -qF 'bd memories --json' "$PLUGIN"; then
  bad "plugin reads the full bd memories dump"
else
  ok "no bd memories --json"
fi

# ---------- BEHAVIOURAL (may SKIP without python3) ----------
if ! command -v python3 >/dev/null 2>&1; then
  echo "   SKIP: behavioural assertions (register_skill Path/count, fail-loud on"
  echo "         zero skills, resolver raise) -- python3 absent."
  echo "         Static anti-fork assertions above still ran."
  if [ "$fail" = 0 ]; then
    echo "test-hermes-injection: PASS (static only)"
  else
    echo "test-hermes-injection: FAIL"
  fi
  exit "$fail"
fi

python3 - "$ROOT" <<'PY' || fail=1
import os, sys, importlib.util, tempfile, shutil, pathlib

root = sys.argv[1]
ok_, bad_ = [], []


def check(cond, msg):
    (ok_ if cond else bad_).append(msg)


def load(plugin_dir):
    spec = importlib.util.spec_from_file_location(
        "hermes_plugin_under_test", os.path.join(plugin_dir, "__init__.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FakeCtx:
    """Signature pinned to upstream's call: register_skill(name, Path)."""

    def __init__(self):
        self.skills, self.hooks = [], {}

    def register_skill(self, name, path):
        self.skills.append((name, path))

    def register_hook(self, event, fn):
        self.hooks[event] = fn


def build_fixture(layout, with_hooks=True, n_skills=2):
    """layout: 'sibling' (git-clone) or 'flat' (flattened install)."""
    tmp = tempfile.mkdtemp()
    if layout == "sibling":
        plugin_dir = os.path.join(tmp, ".hermes-plugin")
        skills_root = tmp
    else:
        plugin_dir = os.path.join(tmp, "plugin")
        skills_root = plugin_dir
    os.makedirs(plugin_dir, exist_ok=True)
    shutil.copy(os.path.join(root, ".hermes-plugin", "__init__.py"),
                os.path.join(plugin_dir, "__init__.py"))
    names = ["using-superpowers"] + [f"skill{i}" for i in range(n_skills - 1)]
    for name in names[:n_skills]:
        d = os.path.join(skills_root, "skills", name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "SKILL.md"), "w") as f:
            f.write("# stub\n")
    if with_hooks:
        hd = os.path.join(skills_root, "hooks")
        os.makedirs(hd, exist_ok=True)
        p = os.path.join(hd, "session-start")
        with open(p, "w") as f:
            f.write('#!/bin/sh\n'
                    'echo "<EXTREMELY_IMPORTANT>STUB PAYLOAD</EXTREMELY_IMPORTANT>"\n')
        os.chmod(p, 0o755)
    return tmp, plugin_dir


# --- registration: Path type, count, hook wired ---
tmp, pdir = build_fixture("sibling")
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
check(len(ctx.skills) == 2, "register_skill called once per skill dir")
check(all(isinstance(p, pathlib.Path) for _, p in ctx.skills),
      "register_skill receives pathlib.Path, not str")
check("pre_llm_call" in ctx.hooks, "pre_llm_call hook registered")
shutil.rmtree(tmp)

# --- fail loud rather than register nothing ---
tmp, pdir = build_fixture("sibling", n_skills=1)
# Remove the SKILL.md so the tree resolves but nothing registers.
os.remove(os.path.join(tmp, "skills", "using-superpowers", "SKILL.md"))
mod = load(pdir)
try:
    mod.register(FakeCtx())
    check(False, "register() raises when zero skills registered")
except RuntimeError:
    check(True, "register() raises when zero skills registered")
except Exception as exc:  # resolver raised first -- also acceptable fail-loud
    check(isinstance(exc, RuntimeError),
          f"register() fails loudly when zero skills ({type(exc).__name__})")
shutil.rmtree(tmp)

# --- resolver raises when neither layout matches ---
tmp = tempfile.mkdtemp()
pdir = os.path.join(tmp, ".hermes-plugin")
os.makedirs(pdir)
shutil.copy(os.path.join(root, ".hermes-plugin", "__init__.py"),
            os.path.join(pdir, "__init__.py"))
mod = load(pdir)
try:
    mod._skills_dir()
    check(False, "_skills_dir() raises when neither layout matches")
except RuntimeError:
    check(True, "_skills_dir() raises when neither layout matches")
shutil.rmtree(tmp)

for m in ok_:
    print(f"   ok:   {m}")
for m in bad_:
    print(f"   FAIL: {m}")
sys.exit(1 if bad_ else 0)
PY

if [ "$fail" = 0 ]; then
  echo "test-hermes-injection: PASS"
else
  echo "test-hermes-injection: FAIL"
fi
exit "$fail"
