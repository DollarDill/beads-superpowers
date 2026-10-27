"""beads-superpowers plugin for Hermes Agent.

Upstream-parity base: obra/superpowers .hermes-plugin/__init__.py (v6.3.0) --
dual-layout skills resolution, native skill registration, and the pre_llm_call
injection path (upstream verified 2026-07-23 that on_session_start return values
are ignored and ctx.inject_message refuses from that hook).

Fork delta (minimal, policy-free): upstream's _build_bootstrap() is replaced by
an exec of the canonical composer, added in the next task. All selection and
degradation policy lives in hooks/session-start and is never reimplemented here.
Skill descriptions: upstream v7.0.1 parity (#2284).
Anti-fork guard: tests/hooks/test-hermes-injection.sh.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

BOOTSTRAP_MARKER = "EXTREMELY_IMPORTANT"

# The fallback emits the FIRST line of `bd memories`. That is safe only because
# bd prints a count header first ("Memories (220):", verified 2026-08-16) -- an
# assumption bd does not guarantee. wze77.8 proved memory KEYS can be
# secret-shaped, and this degraded path has no redactor, so we fail closed:
# anything that is not a count header is dropped.
_MEM_HEADER_RE = re.compile(r"^Memories \(\d+\)")


def _frontmatter_value(content: str, key: str) -> str:
    """Return a flat ``key: value`` scalar from a SKILL.md frontmatter block.

    Hermes reads a skill's description from ``register_skill``'s ``description``
    argument, which defaults to "" — registering only the path left every stock
    skill with a blank description in the skill catalogue, so the model had
    nothing to select on. Stock frontmatter is a flat block of single-line
    scalars, so a line scan covers it without a YAML dependency.
    """
    match = re.match(r"^---\n([\s\S]*?)\n---\n", content)
    if not match:
        return ""
    for line in match.group(1).splitlines():
        name, sep, value = line.partition(":")
        if sep and name.strip() == key:
            return value.strip().strip("\"'")
    return ""


def _here() -> str:
    return os.path.dirname(os.path.realpath(__file__))


def _skills_dir() -> str:
    """Locate the stock skills/ tree for either supported install layout.

    - git-clone install (`hermes plugins install DollarDill/beads-superpowers`):
      the plugin dir is the repo root, so `.hermes-plugin/` and `skills/` are
      siblings and this resolves `../skills`.
    - flattened install (plugin files copied to the plugin dir root): `skills/`
      sits next to this module.

    Raises loudly when neither matches -- a bootstrap that silently skips is how
    a broken install masquerades as a working one.
    """
    here = _here()
    candidates = (
        os.path.realpath(os.path.join(here, "..", "skills")),
        os.path.realpath(os.path.join(here, "skills")),
    )
    for cand in candidates:
        if os.path.isfile(os.path.join(cand, "using-superpowers", "SKILL.md")):
            return cand
    raise RuntimeError(
        "beads-superpowers plugin: cannot find the skills/ tree "
        f"(looked at {candidates}). Reinstall with "
        "`hermes plugins install DollarDill/beads-superpowers`."
    )


def _composer_path():
    """Resolve hooks/session-start across BOTH layouts _skills_dir() supports.

    Upstream has no hooks/ dependency -- its bootstrap is pure Python -- so its
    resolver never had to cover this. We are adding that dependency, and in the
    flattened layout hooks/ may simply not be there. Returns None rather than
    raising: unlike a missing skills/ tree, a missing composer is degradable.
    """
    here = _here()
    for cand in (
        os.path.realpath(os.path.join(here, "..", "hooks", "session-start")),
        os.path.realpath(os.path.join(here, "hooks", "session-start")),
    ):
        if os.path.isfile(cand):
            return cand
    return None


def _collapse(p):
    """A leading run of slashes collapsed to one, as the launcher does."""
    if p.startswith("//"):
        return "/" + p.lstrip("/")
    return p


def _strip1(p):
    """Shell ${p%/}: one trailing slash removed."""
    return p[:-1] if p.endswith("/") else p


def _phys_dir(p):
    """Shell `cd -P <p>/ && pwd -P`: the physical directory, or ""."""
    try:
        if not os.path.isdir(p):
            return ""
        return _collapse(os.path.realpath(p))
    except (OSError, ValueError):
        return ""


def _entry_outside(env):
    """hooks/session-start's in-project PATH-entry drop, for this process.

    The rule is hooks/run-hook.cmd's bsp_outside, applied to <entry>/bash: an
    entry is dropped when it has a . or .. component, literally starts with
    the cwd (logical, physical or canonical), or lies physically inside the
    cwd tree or the project root (CLAUDE_PROJECT_DIR, else
    CURSOR_PROJECT_DIR, else the highest .git ancestor of the cwd); every
    entry is dropped when a root variable is relative or does not resolve.
    The logical cwd is $PWD when it names the cwd, as a shell started here
    would take it. Pinned with the shell copies by
    tests/hooks/test-path-containment.sh. Exec hygiene, not policy.
    """
    try:
        cwd = _collapse(os.getcwd())
    except OSError:
        cwd = ""
    ok = True
    root = ""
    for var in ("CLAUDE_PROJECT_DIR", "CURSOR_PROJECT_DIR"):
        val = env.get(var, "")
        if val.startswith("/"):
            root = root or val
        elif val:
            ok = False
    pwd = env.get("PWD", "")
    try:
        if not (pwd.startswith("/") and os.path.samefile(pwd, ".")):
            pwd = cwd
    except OSError:
        pwd = cwd
    phys_pfx = _strip1(cwd)
    pwd_pfx = _strip1(_collapse(pwd)) if pwd else phys_pfx
    if pwd:
        can = _collapse(os.path.normpath(pwd)) if os.path.isdir(pwd) else ""
        if not can:
            ok = False
    else:
        can = cwd
    can_pfx = _strip1(can)
    if root:
        root = _phys_dir(root)
        if not root:
            ok = False
    elif ok:
        root = d = cwd
        while d:
            if os.path.exists(_strip1(d) + "/.git"):
                root = d
            if d == "/":
                break
            d = d[:d.rfind("/")] or "/"
    cwd_pfx, root_pfx = _strip1(cwd), _strip1(root)

    def outside(entry):
        cand = _strip1(entry) + "/bash"
        if "/./" in cand or "/../" in cand:
            return False
        lit = _collapse(cand)
        if any(lit.startswith(pfx + "/") for pfx in (pwd_pfx, phys_pfx, can_pfx)):
            return False
        d = _phys_dir(_strip1(entry) + "/")
        if not (ok and cwd and root and d):
            return False
        return not (d + "/").startswith((cwd_pfx + "/", root_pfx + "/"))

    return outside


def _child_env():
    """The env for every child: PATH cut to absolute entries outside the project.

    hooks/session-start's rule: ~ and ~/x become $HOME when HOME is absolute,
    anything else relative is dropped, then every entry inside the project
    (see _entry_outside), fallback /usr/bin:/bin. An empty or relative entry,
    or PATH="", makes a lookup search the cwd, an untrusted project, and an
    absolute entry can sit inside it (<proj>/node_modules/.bin); the
    launcher's bash and `bd` are both looked up on it. Exec hygiene, not
    composition policy.
    """
    env = dict(os.environ)
    home = env.get("HOME", "")
    outside = _entry_outside(env)
    keep = []
    for p in env.get("PATH", "").split(":"):
        if p == "~" or p.startswith("~/"):
            if not home.startswith("/"):
                continue
            p = home + p[1:]
        elif not p.startswith("/"):
            continue
        if outside(p):
            keep.append(p)
    env["PATH"] = ":".join(keep) or "/usr/bin:/bin"
    return env


def _no_children():
    """True on native Windows: start no child there.

    CreateProcess searches the cwd before PATH, and no env can change that, so
    a bash.exe or bd.exe in the project would run. Exec hygiene, not policy.
    """
    return sys.platform == "win32"


def _compose_bootstrap():
    """Exec the canonical composer. None on any failure, and on Windows.

    Through hooks/run-hook.cmd, run by /bin/sh: the launcher takes the first
    bash on PATH outside the project (an absolute entry can sit inside it,
    <proj>/node_modules/.bin), else $BASH under the same check, and execs
    session-start with it. The composer's own #!/usr/bin/env bash would take
    the first bash on PATH, wherever it is. No launcher next to the composer,
    or no usable bash (the launcher exits 0 with no output): None.
    """
    if _no_children():
        return None
    composer = _composer_path()
    if composer is None:
        return None
    launcher = os.path.join(os.path.dirname(composer), "run-hook.cmd")
    try:
        proc = subprocess.run(
            ["/bin/sh", launcher, "session-start", "--emit-plain"],
            capture_output=True, text=True, timeout=10, check=False,
            env=_child_env(),
        )
    except (OSError, subprocess.SubprocessError):
        return None
    text = (proc.stdout or "").strip()
    # A real payload always carries the injection marker; an empty rapid re-run
    # (the composer's event dedup) does not.
    if BOOTSTRAP_MARKER in text:
        return text
    return None


def _fallback_bootstrap():
    """Policy-free, DISCLOSING pointer. Never the full bd prime dump."""
    mem_line = ""
    if not _no_children():
        try:
            proc = subprocess.run(
                ["bd", "memories"],
                capture_output=True, text=True, timeout=5, check=False,
                env=_child_env(),
            )
            first = (proc.stdout or "").split("\n")[0].strip()
            if _MEM_HEADER_RE.match(first):
                mem_line = (f"{first} - search: bd memories <keyword>, "
                            "fetch: bd recall <key>")
        except (OSError, subprocess.SubprocessError):
            pass
    lines = [
        "<EXTREMELY_IMPORTANT>",
        "beads-superpowers: session composer unavailable in this environment.",
        "Load skills via the skill tool (start: using-superpowers).",
        mem_line,
        "</EXTREMELY_IMPORTANT>",
    ]
    return "\n".join(line for line in lines if line)


def register(ctx):
    skills_dir = _skills_dir()

    # register_skill requires a pathlib.Path -- a str raises AttributeError and
    # hermes silently disables the whole plugin (upstream verified 2026-07-23).
    registered = 0
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if os.path.isfile(skill_md):
            with open(skill_md, encoding="utf-8") as f:
                description = _frontmatter_value(f.read(), "description")
            ctx.register_skill(name, Path(skill_md), description=description)
            registered += 1

    # Fail loud rather than register nothing: a plugin that loads with zero
    # skills is indistinguishable from a working one until the agent needs a
    # skill, and no path fallback compensates for it.
    if registered == 0:
        raise RuntimeError(
            "beads-superpowers plugin: found the skills/ tree at "
            f"{skills_dir} but registered ZERO skills."
        )

    # Computed once here, then closed over: register() runs a single time per
    # session, so this IS the module-level cache the JS plugin needs explicitly
    # (its getBootstrapContent is called per message transform).
    bootstrap = _compose_bootstrap() or _fallback_bootstrap()

    # pre_llm_call returning {"context": ...} is the documented injection path
    # (on_session_start return values are ignored, and ctx.inject_message
    # refuses from that hook -- upstream verified empirically 2026-07-23). The
    # context is appended to the first turn's user message.
    def pre_llm_call(session_id=None, user_message=None,
                     conversation_history=None, is_first_turn=None,
                     model=None, platform=None, **kwargs):
        if is_first_turn:
            return {"context": bootstrap}
        return None

    ctx.register_hook("pre_llm_call", pre_llm_call)
