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
from pathlib import Path

BOOTSTRAP_MARKER = "EXTREMELY_IMPORTANT"

# NOTE: `re`, `subprocess` and the fail-closed memory-line pattern are added
# alongside the composer exec, not here -- committing them early would leave
# unused symbols in the tree with no linter to catch them.


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

    def pre_llm_call(session_id=None, user_message=None,
                     conversation_history=None, is_first_turn=None,
                     model=None, platform=None, **kwargs):
        return None

    ctx.register_hook("pre_llm_call", pre_llm_call)
