"""MkDocs build hooks for beads-superpowers.

Currently carries one compatibility shim:

mkdocs-static-i18n compatibility for mkdocs-panzoom-plugin
---------------------------------------------------------
mkdocs-static-i18n runs a separate build pass per locale (see its
``on_post_build`` → ``build()``), which re-invokes every plugin's
``on_config``. mkdocs-panzoom-plugin 0.5.2 (the latest release) does
``self.config.pop("mermaid")`` (and four sibling keys) with no default in
``on_config``. Because the panzoom plugin instance — and thus ``self.config``
— persists across passes, the second (zh) pass finds those keys already gone
and raises ``KeyError: 'mermaid'``, aborting the build.

We cannot fix this by monkeypatching ``PanZoomPlugin.on_config``: mkdocs
captures each plugin's bound event method when the plugin is registered, which
happens *before* hook modules are imported — so a late class patch is never
dispatched. Instead we register our own high-priority ``on_config`` handler
that runs *before* panzoom's on every pass: it snapshots the popped option
values on the first pass and restores them on later passes, so panzoom's pops
always succeed with the real values.

Remove this shim once panzoom guards its pops upstream (e.g. ``pop(key, None)``).
Tracked in the zh-docs epic bead + an upstream issue.
"""

import shutil
from pathlib import Path

from mkdocs.plugins import event_priority

_PANZOOM_POPPED_KEYS = ("mermaid", "images", "exclude", "include_selectors", "exclude_selectors")
_panzoom_saved_opts = {}


@event_priority(100)  # run before panzoom's on_config (default priority 0)
def on_config(config, **kwargs):
    """Keep mkdocs-panzoom-plugin's option keys present across i18n's per-locale passes."""
    panzoom = config["plugins"].get("panzoom")
    if panzoom is None:
        return config
    if not _panzoom_saved_opts:
        # First pass: capture the real values before panzoom pops them.
        for key in _PANZOOM_POPPED_KEYS:
            if key in panzoom.config:
                _panzoom_saved_opts[key] = panzoom.config[key]
    else:
        # Later passes (zh locale): restore so panzoom's pops don't KeyError.
        for key, value in _panzoom_saved_opts.items():
            panzoom.config[key] = value
    return config


def on_post_build(config, **kwargs):
    """Publish a duplicate of the generated sitemap named ``sitemap_index.xml``.

    Site-only SEO experiment (does NOT affect the distributed plugin): some
    search-console/robots probes look for a ``sitemap_index.xml`` name. We copy
    the MkDocs-generated ``sitemap.xml`` verbatim (plus its ``.gz``) so the
    duplicate can never drift from the real, auto-generated sitemap. Idempotent,
    so it is safe under mkdocs-static-i18n's per-locale re-builds.
    """
    site_dir = Path(config["site_dir"])
    for src_name, dst_name in (
        ("sitemap.xml", "sitemap_index.xml"),
        ("sitemap.xml.gz", "sitemap_index.xml.gz"),
    ):
        src = site_dir / src_name
        if src.exists():
            shutil.copy2(src, site_dir / dst_name)
