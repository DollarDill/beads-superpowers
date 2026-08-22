"""beads-superpowers plugin for Hermes Agent.

Upstream-parity base: obra/superpowers .hermes-plugin/__init__.py (v6.3.0) --
dual-layout skills resolution, native skill registration, and the pre_llm_call
injection path (upstream verified 2026-07-23 that on_session_start return values
are ignored and ctx.inject_message refuses from that hook).

Fork delta (minimal, policy-free): upstream's _build_bootstrap() is replaced by
an exec of the canonical composer, added in the next task. All selection and
degradation policy lives in hooks/session-start and is never reimplemented here.
Anti-fork guard: tests/hooks/test-hermes-injection.sh.
"""

import os
import re
import subprocess
from pathlib import Path

BOOTSTRAP_MARKER = "EXTREMELY_IMPORTANT"

# The fallback emits the FIRST line of `bd memories`. That is safe only because
# bd prints a count header first ("Memories (220):", verified 2026-08-16) -- an
# assumption bd does not guarantee. wze77.8 proved memory KEYS can be
# secret-shaped, and this degraded path has no redactor, so we fail closed:
# anything that is not a count header is dropped.
_MEM_HEADER_RE = re.compile(r"^Memories \(\d+\)")


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


def _compose_bootstrap():
    """Exec the canonical composer. None on any failure."""
    composer = _composer_path()
    if composer is None:
        return None
    try:
        proc = subprocess.run(
            [composer, "--emit-plain"],
            capture_output=True, text=True, timeout=10, check=False,
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
    try:
        proc = subprocess.run(
            ["bd", "memories"],
            capture_output=True, text=True, timeout=5, check=False,
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
            ctx.register_skill(name, Path(skill_md))
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
