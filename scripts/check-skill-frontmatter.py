#!/usr/bin/env python3
"""Validate YAML frontmatter in all skills/*/SKILL.md files.

Zero dependencies — parses simple key: value frontmatter without pyyaml.

Checks:
  - Frontmatter block exists (--- delimited)
  - Required fields present and non-empty: name, description
"""
import re
import sys
from pathlib import Path

REQUIRED = ("name", "description")
errors = []
skills = sorted(Path("skills").glob("*/SKILL.md"))

for f in skills:
    text = f.read_text()
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        errors.append(f"{f}: missing YAML frontmatter")
        continue

    # Parse simple key: value pairs from frontmatter
    fm = {}
    for line in m.group(1).strip().splitlines():
        kv = re.match(r"^(\w[\w-]*):\s*(.*)", line)
        if kv:
            fm[kv.group(1)] = kv.group(2).strip().strip("'\"")

    for key in REQUIRED:
        if key not in fm or not fm[key]:
            errors.append(f"{f}: missing required field '{key}'")

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)

print(f"All {len(skills)} skills have valid frontmatter")
