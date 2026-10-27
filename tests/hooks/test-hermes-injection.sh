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

# Exactly ONE composer invocation -- single source of truth for composition.
# Match the quoted string literal, NOT the bare token: `session-start`
# legitimately appears in the module docstring and twice in _composer_path()'s
# candidate list, and `grep -c` counts LINES, not occurrences. Only the argv
# literal is unique to the actual invocation.
n=$(grep -c -F '"--emit-plain"' "$PLUGIN")
if [ "$n" = "1" ]; then
  ok "exactly one composer invocation"
else
  bad "expected 1 quoted --emit-plain literal, found $n"
fi

# subprocess is list-form with a timeout, never shell=True.
if grep -qF 'shell=True' "$PLUGIN"; then
  bad "shell=True present"
else
  ok "no shell=True"
fi
if grep -qF 'timeout=' "$PLUGIN"; then
  ok "subprocess timeout present"
else
  bad "no subprocess timeout"
fi

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
import glob, os, sys, importlib.util, tempfile, shutil, pathlib, subprocess

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
    """Signature pinned to upstream's call; mirrors Hermes's description default."""

    def __init__(self):
        self.skills, self.hooks = [], {}

    def register_skill(self, name, path, description=""):
        self.skills.append((name, path, description))

    def register_hook(self, event, fn):
        self.hooks[event] = fn


def build_fixture(layout, with_hooks=True, n_skills=2, env_bash=False):
    """layout: 'sibling' (git-clone) or 'flat' (flattened install).
    env_bash: the real hook's #!/usr/bin/env bash shebang (bash looked up on
    PATH) instead of #!/bin/sh."""
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
            f.write('---\nname: ' + name + '\ndescription: "Use when: a, b"\n---\n# stub\n')
    if with_hooks:
        hd = os.path.join(skills_root, "hooks")
        os.makedirs(hd, exist_ok=True)
        p = os.path.join(hd, "session-start")
        with open(p, "w") as f:
            f.write(('#!/usr/bin/env bash\n' if env_bash else '#!/bin/sh\n') +
                    'echo "<EXTREMELY_IMPORTANT>STUB PAYLOAD</EXTREMELY_IMPORTANT>"\n')
        os.chmod(p, 0o755)
        # The plugin starts the composer through the real launcher, which
        # picks a bash outside the project.
        shutil.copy(os.path.join(root, "hooks", "run-hook.cmd"),
                    os.path.join(hd, "run-hook.cmd"))
    return tmp, plugin_dir


# --- registration: Path type, count, hook wired ---
tmp, pdir = build_fixture("sibling")
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
check(len(ctx.skills) == 2, "register_skill called once per skill dir")
check(all(isinstance(p, pathlib.Path) for _, p, _ in ctx.skills),
      "register_skill receives pathlib.Path, not str")
check("pre_llm_call" in ctx.hooks, "pre_llm_call hook registered")
check(all(d == "Use when: a, b" for _, _, d in ctx.skills),
      "register_skill receives the frontmatter description")
shutil.rmtree(tmp)

# --- real tree: every shipped skill registers its non-empty description ---
tmp, pdir = build_fixture("sibling", with_hooks=False)
shutil.rmtree(os.path.join(tmp, "skills"))
os.symlink(os.path.join(root, "skills"), os.path.join(tmp, "skills"))
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
real_count = len(glob.glob(os.path.join(root, "skills", "*", "SKILL.md")))
check(len(ctx.skills) == real_count, "every real skill registers")


def expected_description(skill_md):
    """Independent of the plugin's parser: the shipped skills use a single-line
    `description:` scalar, so read that one line and strip matching quotes."""
    with open(skill_md) as f:
        head = f.read().split("\n---\n", 1)[0]
    for line in head.splitlines():
        if line.startswith("description:"):
            v = line[len("description:"):].strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            return v
    return None


mismatches = []
for _, path, desc in ctx.skills:
    want = expected_description(str(path))
    if not want or desc != want:
        mismatches.append((path.parent.name, desc, want))
check(not mismatches,
      "every real skill registers a non-empty description equal to its "
      "frontmatter value" + (f" (first mismatch: {mismatches[0]})" if mismatches else ""))
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

BOOT_MARK = "EXTREMELY_IMPORTANT"
STUB = "<EXTREMELY_IMPORTANT>STUB PAYLOAD</EXTREMELY_IMPORTANT>"

# --- composer exec + strict-equality injection (git-clone layout) ---
tmp, pdir = build_fixture("sibling", with_hooks=True)
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
fn = ctx.hooks["pre_llm_call"]
out = fn(is_first_turn=True)
check(isinstance(out, dict) and "context" in out,
      "pre_llm_call returns {'context': ...} on first turn")
check(out["context"] == STUB,
      "injected text equals composer payload EXACTLY (no re-wrap)")
check(fn(is_first_turn=False) is None, "pre_llm_call returns None after turn 1")
shutil.rmtree(tmp)

# --- composer absent -> disclosing fallback, policy-free ---
tmp, pdir = build_fixture("sibling", with_hooks=False)
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
check("session composer unavailable" in text,
      "fallback DISCLOSES the degradation")
check(BOOT_MARK in text, "fallback carries the injection marker")
for tok in ("salience", "@type=", "BSP_MEM_CEILING"):
    check(tok not in text, f"fallback carries no selection policy: {tok}")
shutil.rmtree(tmp)

# --- FLATTENED layout: the branch a git-clone-only fixture would hide ---
# Upstream supports it; our hooks/ dependency is one upstream never had, so
# either the composer resolves there or we degrade DISCLOSINGLY. Never silent.
tmp, pdir = build_fixture("flat", with_hooks=False)
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
check("session composer unavailable" in text,
      "flattened layout without hooks/ degrades DISCLOSINGLY, not silently")
shutil.rmtree(tmp)

tmp, pdir = build_fixture("flat", with_hooks=True)
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
check(text == STUB, "flattened layout WITH hooks/ resolves the composer")
shutil.rmtree(tmp)

# The composer is started through hooks/run-hook.cmd; without it next to the
# composer, degrade DISCLOSINGLY, never exec the composer some other way.
tmp, pdir = build_fixture("flat", with_hooks=True)
os.remove(os.path.join(pdir, "hooks", "run-hook.cmd"))
mod = load(pdir)
ctx = FakeCtx()
mod.register(ctx)
text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
check("session composer unavailable" in text,
      "composer without the launcher next to it degrades DISCLOSINGLY")
shutil.rmtree(tmp)

# --- fail-closed memory line: only a count header may pass through ---
check(mod._MEM_HEADER_RE.match("Memories (220):") is not None,
      "memory-line pattern accepts a count header")
check(mod._MEM_HEADER_RE.match(
    "akia1234567890abcdef-appeared-in-the-deploy-log") is None,
      "memory-line pattern REJECTS a bare key (wze77.8 secret-shaped-key class)")

# --- a bash or bd planted in the host cwd never runs (security) ---
# An empty or relative PATH entry (or PATH="") makes a command lookup search
# the cwd, which for a session is an untrusted project. The composer's
# #!/usr/bin/env bash and the `bd memories` fallback both look a command up,
# so the plugin must hand its children a PATH of absolute entries only.
evil = os.path.realpath(tempfile.mkdtemp())
markers = os.path.realpath(tempfile.mkdtemp())
for b in ("bash", "bd"):
    bp = os.path.join(evil, b)
    with open(bp, "w") as f:
        f.write(f'#!/bin/sh\n: > "{markers}/ran-{b}"\n')
    os.chmod(bp, 0o755)


def planted_ran():
    ran = sorted(os.listdir(markers))
    for m in ran:
        os.remove(os.path.join(markers, m))
    return [m[len("ran-"):] for m in ran]


def bash_on_clean_path(p):
    # The cleaned PATH: its absolute entries, else /usr/bin:/bin. macOS has
    # no /usr/bin/bash, a merged-/usr Linux does.
    ents = [e for e in p.split(":") if e.startswith("/")] or ["/usr/bin", "/bin"]
    return any(os.access(os.path.join(e, "bash"), os.X_OK) for e in ents)


# The plugin runs the launcher with /bin/sh. With no usable bash on PATH the
# launcher falls back to $BASH: /bin/sh sets it when it is bash (macOS), so
# the composer still runs under it; dash leaves it unset, so the plugin falls
# back to the pointer.
SH_SETS_BASH = subprocess.run(["/bin/sh", "-c", 'printf %s "${BASH-}"'],
                              capture_output=True, text=True).stdout != ""


def composer_runs(p):
    return bash_on_clean_path(p) or SH_SETS_BASH


saved_path, saved_cwd = os.environ.get("PATH"), os.getcwd()
try:
    for p in ("", ".:/usr/bin", ":/usr/bin:/bin"):
        for with_hooks in (True, False):
            tmp, pdir = build_fixture("sibling", with_hooks=with_hooks,
                                      env_bash=True)
            os.chdir(evil)
            os.environ["PATH"] = p
            try:
                mod = load(pdir)
                ctx = FakeCtx()
                mod.register(ctx)
                text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
            finally:
                if saved_path is None:
                    os.environ.pop("PATH", None)
                else:
                    os.environ["PATH"] = saved_path
                os.chdir(saved_cwd)
                shutil.rmtree(tmp)
            what = f"{'composer' if with_hooks else 'bd fallback'}, PATH='{p}'"
            ran = planted_ran()
            check(ran == [], f"no planted binary ran ({what}); ran: {ran}")
            if with_hooks and composer_runs(p):
                check(text == STUB, f"composer payload injected ({what})")
            else:
                check(BOOT_MARK in text and "session composer unavailable" in text,
                      f"fallback pointer injected ({what})")
    # A literal ~ or ~/x entry becomes $HOME (bash expands it at lookup), as
    # hooks/session-start keeps it: a ~/bin/bash wrapper is the bash used.
    home = os.path.realpath(tempfile.mkdtemp())
    os.makedirs(os.path.join(home, "bin"))
    wp = os.path.join(home, "bin", "bash")
    with open(wp, "w") as f:
        f.write(f'#!/bin/sh\n: > "{markers}/ran-tildebash"\nexec /bin/bash "$@"\n')
    os.chmod(wp, 0o755)
    saved_home = os.environ.get("HOME")
    tmp, pdir = build_fixture("sibling", with_hooks=True, env_bash=True)
    os.chdir(evil)
    os.environ["PATH"], os.environ["HOME"] = "~/bin", home
    try:
        mod = load(pdir)
        ctx = FakeCtx()
        mod.register(ctx)
        text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
    finally:
        for k, v in (("PATH", saved_path), ("HOME", saved_home)):
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        os.chdir(saved_cwd)
        shutil.rmtree(tmp)
        shutil.rmtree(home)
    ran = planted_ran()
    check(ran == ["tildebash"], f"PATH='~/bin' resolves bash in $HOME/bin; ran: {ran}")
    check(text == STUB, "composer payload injected (PATH='~/bin')")

    # --- an absolute PATH entry inside the project (security review #8) ---
    # The cleaned PATH keeps absolute entries, and one can sit inside the
    # project (<proj>/node_modules/.bin from npm exec, direnv PATH_add). The
    # composer must start with the launcher's containment walk: the planted
    # bash never runs, and a bash further down the cleaned PATH runs the
    # composer. With none there (a planted-only PATH cleans to /usr/bin:/bin),
    # the launcher's $BASH fallback decides (see SH_SETS_BASH).
    proj = os.path.realpath(tempfile.mkdtemp())
    os.makedirs(os.path.join(proj, ".git"))
    nmbin = os.path.join(proj, "node_modules", ".bin")
    os.makedirs(nmbin)
    nb = os.path.join(nmbin, "bash")
    with open(nb, "w") as f:
        f.write(f'#!/bin/sh\n: > "{markers}/ran-nmbash"\n')
    os.chmod(nb, 0o755)
    try:
        for p, layout in ((f"{nmbin}:/usr/bin:/bin", "sibling"),
                          (f"{nmbin}:/usr/bin:/bin", "flat"),
                          (nmbin, "sibling")):
            tmp, pdir = build_fixture(layout, with_hooks=True, env_bash=True)
            os.chdir(proj)
            os.environ["PATH"] = p
            try:
                mod = load(pdir)
                ctx = FakeCtx()
                mod.register(ctx)
                text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
                handed = mod._child_env()["PATH"]  # the PATH the child really gets
            finally:
                if saved_path is None:
                    os.environ.pop("PATH", None)
                else:
                    os.environ["PATH"] = saved_path
                os.chdir(saved_cwd)
                shutil.rmtree(tmp)
            what = f"in-project PATH entry, {layout}, PATH='{p.replace(proj, '<proj>')}'"
            ran = planted_ran()
            check(ran == [], f"no planted binary ran ({what}); ran: {ran}")
            # The planted bash is refused, so only the bashes after it count.
            # Judged on the PATH the plugin hands the child, not the raw one: the
            # in-project entry is dropped, leaving /usr/bin:/bin.
            if composer_runs(handed):
                check(text == STUB, f"composer payload injected ({what})")
            else:
                check(BOOT_MARK in text and "session composer unavailable" in text,
                      f"fallback pointer injected ({what})")
    finally:
        shutil.rmtree(proj)

    # --- bd dropped because a git $HOME is the root: the note reaches Hermes ---
    # HOME holds a .git, no root variable is set, the cwd is below HOME and
    # bd is only in $HOME/.local/bin, which the cleaning drops. The real
    # composer (hooks/session-start, through the launcher) decides; the plugin
    # only runs it. Its injected text must carry the composer's note, the
    # PATH the plugin actually hands the composer child (captured from the
    # subprocess.run call, not recomputed) must still drop the entry, and the
    # planted bd must never run. With bd simply absent, no note.
    NOTE = ("set CLAUDE_PROJECT_DIR (or CURSOR_PROJECT_DIR) to your project "
            "directory, or install bd outside your home directory")
    saved_env = {k: os.environ.get(k) for k in
                 ("PATH", "HOME", "XDG_RUNTIME_DIR", "CLAUDE_PROJECT_DIR",
                  "CURSOR_PROJECT_DIR")}
    for plant in (True, False):
        ghome = os.path.realpath(tempfile.mkdtemp())
        os.makedirs(os.path.join(ghome, ".git"))
        os.makedirs(os.path.join(ghome, "sub"))
        lbin = os.path.join(ghome, ".local", "bin")
        os.makedirs(lbin)
        if plant:
            with open(os.path.join(lbin, "bd"), "w") as f:
                f.write(f'#!/bin/sh\n: > "{markers}/ran-homebd"\necho "Memories (1):"\n')
            os.chmod(os.path.join(lbin, "bd"), 0o755)
        # The real composer, launcher and skills, behind a copy of the plugin
        # (a copy, so loading it writes no bytecode into the repo).
        tmp, pdir = build_fixture("sibling", with_hooks=False)
        shutil.rmtree(os.path.join(tmp, "skills"))
        os.symlink(os.path.join(root, "skills"), os.path.join(tmp, "skills"))
        os.symlink(os.path.join(root, "hooks"), os.path.join(tmp, "hooks"))
        os.chdir(os.path.join(ghome, "sub"))
        os.environ["PATH"] = f"{lbin}:/usr/bin:/bin"
        os.environ["HOME"] = ghome
        os.environ["XDG_RUNTIME_DIR"] = os.path.realpath(tempfile.mkdtemp())
        os.environ.pop("CLAUDE_PROJECT_DIR", None)
        os.environ.pop("CURSOR_PROJECT_DIR", None)
        handed_envs = []
        try:
            mod = load(pdir)
            real_run = mod.subprocess.run

            def capture(*a, **kw):
                args = a[0] if a else kw.get("args")
                if "session-start" in args:
                    handed_envs.append(kw.get("env"))
                return real_run(*a, **kw)

            mod.subprocess.run = capture
            try:
                ctx = FakeCtx()
                mod.register(ctx)
                text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
            finally:
                mod.subprocess.run = real_run
        finally:
            shutil.rmtree(os.environ["XDG_RUNTIME_DIR"])
            for k, v in saved_env.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v
            os.chdir(saved_cwd)
            shutil.rmtree(tmp)
            shutil.rmtree(ghome)
        what = "bd under a git HOME" if plant else "bd absent, git HOME"
        ran = planted_ran()
        check(ran == [], f"no planted binary ran ({what}); ran: {ran}")
        check(len(handed_envs) == 1 and handed_envs[0] is not None,
              f"composer child started once with an explicit env ({what}): {len(handed_envs)}")
        handed = (handed_envs[0] or {}).get("PATH", "") if handed_envs else ""
        check(handed != "" and lbin not in handed.split(":"),
              f"PATH handed to the composer child still drops the HOME entry ({what}): {handed}")
        check("session composer unavailable" not in text and BOOT_MARK in text,
              f"real composer payload injected ({what})")
        if plant:
            check(NOTE in text, f"injected text carries the composer's HOME note ({what})")
        else:
            check(NOTE not in text, f"no HOME note when bd is simply absent ({what})")

    # --- Windows spawns nothing (P1) ---
    # CreateProcess searches the cwd before PATH, which env cannot change, so
    # on win32 register() must start no child and inject the static pointer,
    # without a memory line. sys.platform is forced; subprocess.run records.
    for with_hooks in (True, False):
        tmp, pdir = build_fixture("sibling", with_hooks=with_hooks)
        mod = load(pdir)
        calls = []

        def recorder(*a, **kw):
            calls.append(a[0] if a else kw.get("args"))
            raise OSError("spawn attempted")

        saved_run, saved_platform = mod.subprocess.run, sys.platform
        mod.subprocess.run, sys.platform = recorder, "win32"
        try:
            ctx = FakeCtx()
            mod.register(ctx)
            text = ctx.hooks["pre_llm_call"](is_first_turn=True)["context"]
        finally:
            mod.subprocess.run, sys.platform = saved_run, saved_platform
            shutil.rmtree(tmp)
        what = "composer present" if with_hooks else "composer absent"
        check(calls == [], f"win32 spawns no child ({what}); spawned: {calls}")
        check(BOOT_MARK in text and "session composer unavailable" in text,
              f"win32 injects the static pointer ({what})")
        check("Memories" not in text, f"win32 pointer has no memory line ({what})")
finally:
    shutil.rmtree(evil)
    shutil.rmtree(markers)

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
