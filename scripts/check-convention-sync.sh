#!/usr/bin/env bash
#
# check-convention-sync.sh — keep the cross-cutting convention blocks in sync across every
# site that carries them. Free-form duplication rots (bd-6814 ADR-strip missed skills/; the
# TodoWrite gate drifted across 4 sites). Two tiers:
#   * Canonical BLOCKS — CB-3 (Capture gate) and CB-4 (memory convention) must be
#     BYTE-IDENTICAL at every site: enforced by extract-and-diff (assert_block_identical /
#     assert_line_identical), backstopped by an ASCII signature-presence grep.
#   * Per-site FRAGMENT (KB read-depth) and KERNELS — only a fixed sentence / per-skill line
#     is shared, so signature-presence (`grep -qF`) is the correct check (the fragment IS the
#     whole shared unit; kernels are per-site by design).
# Any missing/divergent copy is DRIFT. Guard-the-guards: tests/install-shape/selftest.sh
# (Mutations 13-16).
#
# Usage:
#   scripts/check-convention-sync.sh            # verify all sites (exit 1 on drift)
#   scripts/check-convention-sync.sh --self-test # prove the detector catches a mutated block
#
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

# ASCII-only signature slices (no em-dash) so the patterns are shell/grep-safe.
CB3_SIG="Worth keeping anything"
CB3_ANCHOR="present the Capture gate"
CB4_SIG="or secrets (tokens, keys, PII"

CB3_SITES=(
  skills/brainstorming/SKILL.md
  skills/writing-plans/SKILL.md
  skills/stress-test/SKILL.md
  skills/systematic-debugging/SKILL.md
)
CB4_SITES=(
  skills/executing-plans/SKILL.md
  skills/test-driven-development/SKILL.md
  .claude/skills/auditing-upstream-drift/SKILL.md
  skills/project-init/SKILL.md
  skills/subagent-driven-development/SKILL.md
  skills/using-git-worktrees/SKILL.md
  skills/requesting-code-review/SKILL.md
  skills/receiving-code-review/SKILL.md
  skills/research-driven-development/SKILL.md
  skills/finishing-a-development-branch/SKILL.md
  skills/dispatching-parallel-agents/SKILL.md
  skills/document-release/SKILL.md
  skills/write-documentation/SKILL.md
  skills/verification-before-completion/SKILL.md
)
# KB read-depth fragment (ADR-0058): one byte-identical ASCII sentence at every
# retrieval instruction site; stripping the read mandate strips the fragment.
KB_SIG="hits are pointers, not knowledge"
KB_SITES=(
  skills/brainstorming/SKILL.md
  skills/systematic-debugging/SKILL.md
  skills/research-driven-development/SKILL.md
  skills/research-driven-development/researcher-prompt.md
  skills/getting-up-to-speed/SKILL.md
  hooks/session-start
)
# --- Per-site kernel map (ADR-0049): each redesigned skill pins ONE ASCII invariant
# line phrased for its own operation. site|signature pairs; grep -qF per site.
KERNEL_MAP=(
  'skills/getting-up-to-speed/SKILL.md|is FORBIDDEN here'
  'hooks/session-start|bd <cmd> --help` on first use'
  'CLAUDE.md|on first use of a command or flag this session'
  'skills/session-handoff/SKILL.md|never weaken it'
  'skills/memory-curator/SKILL.md|Never persist secrets, credentials, tokens, keys, or PII'
  'skills/memory-curator/SKILL.md|Never forget first'
  'skills/document-release/SKILL.md|auto-resolved answer is not consent'
  'skills/stress-test/SKILL.md|bd update <id> --claim'
  'skills/research-driven-development/SKILL.md|bd update <id> --claim'
  'skills/project-init/SKILL.md|Iron Law: NEVER Run'
  '.claude/skills/auditing-upstream-drift/SKILL.md|NO PLUGIN RELEASE WITHOUT A FULL AUDIT FIRST'
  'skills/executing-plans/SKILL.md|the consent gate binds even when this skill is not loaded'
  'skills/subagent-driven-development/SKILL.md|the consent gate binds even when this skill is not loaded'
  'skills/using-git-worktrees/SKILL.md|the consent gate binds even when this skill is not loaded'
  'skills/finishing-a-development-branch/SKILL.md|Work is NOT complete until'
  'skills/finishing-a-development-branch/SKILL.md|This will permanently delete:'
  'skills/using-git-worktrees/SKILL.md|A skipped, dismissed, or auto-resolved answer is not consent'
  'skills/executing-plans/SKILL.md|bd import -'
  'skills/finishing-a-development-branch/SKILL.md|document-release must have run on this branch'
)

FAIL=0
check_block() {
  local label="$1" sig="$2"; shift 2
  local f
  for f in "$@"; do
    if [ ! -f "$f" ]; then echo "MISSING FILE: $f"; FAIL=1; continue; fi
    if ! grep -qF -- "$sig" "$f"; then
      echo "DRIFT: [$label] missing/divergent in $f"
      FAIL=1
    fi
  done
}

# assert_line_identical <label> <sig> <site>...
# Single-line canonical blocks (CB-4): the WHOLE signature-containing line must be
# byte-identical across sites. grep -F locates the line; diff pins the full line.
# The first present-and-unique site is the reference (handles a missing site #1).
assert_line_identical() {
  local label="$1" sig="$2"; shift 2
  local tmp; tmp="$(mktemp -d)" || { echo "SETUP FAIL: mktemp ($label)"; FAIL=1; return; }
  local ref="" f n i=0
  for f in "$@"; do
    if [ ! -f "$f" ]; then echo "MISSING FILE: $f"; FAIL=1; i=$((i+1)); continue; fi
    grep -F -- "$sig" "$f" > "$tmp/line.$i"
    n=$(wc -l < "$tmp/line.$i")
    if [ "$n" -eq 0 ]; then echo "DRIFT: [$label] signature missing in $f"; FAIL=1; i=$((i+1)); continue; fi
    if [ "$n" -gt 1 ]; then echo "DRIFT: [$label] signature on $n lines in $f (expected 1)"; FAIL=1; i=$((i+1)); continue; fi
    if [ -z "$ref" ]; then ref="$tmp/line.$i"
    elif ! diff -q "$ref" "$tmp/line.$i" >/dev/null; then
      echo "DRIFT: [$label] line diverges in $f"; FAIL=1
    fi
    i=$((i+1))
  done
  rm -rf "$tmp"
}

# assert_block_identical <label> <start_anchor> <end_regex> <site>...
# Multi-line canonical blocks (CB-3): extract from the first line containing the fixed
# start_anchor through the first line matching end_regex (inclusive); the extracted BLOCK must
# be byte-identical across sites. ANY empty extract => FAIL (anti-vacuous: a uniformly-lost
# anchor must not diff clean as all-empty). First non-empty site is the reference.
assert_block_identical() {
  local label="$1" anchor="$2" endre="$3"; shift 3
  local tmp; tmp="$(mktemp -d)" || { echo "SETUP FAIL: mktemp ($label)"; FAIL=1; return; }
  local ref="" f i=0
  for f in "$@"; do
    if [ ! -f "$f" ]; then echo "MISSING FILE: $f"; FAIL=1; i=$((i+1)); continue; fi
    awk -v a="$anchor" -v e="$endre" 'index($0,a){f=1} f{print} f && $0 ~ e {exit}' "$f" > "$tmp/blk.$i"
    if [ ! -s "$tmp/blk.$i" ]; then
      echo "DRIFT: [$label] block anchor not found (empty extract) in $f"; FAIL=1; i=$((i+1)); continue
    fi
    if [ -z "$ref" ]; then ref="$tmp/blk.$i"
    elif ! diff -q "$ref" "$tmp/blk.$i" >/dev/null; then
      echo "DRIFT: [$label] block diverges in $f"; FAIL=1
    fi
    i=$((i+1))
  done
  rm -rf "$tmp"
}

check_kernels() {
  local entry f sig
  for entry in "${KERNEL_MAP[@]}"; do
    f="${entry%%|*}"; sig="${entry#*|}"
    if [ ! -f "$f" ]; then echo "MISSING FILE: $f"; FAIL=1; continue; fi
    if ! grep -qF -- "$sig" "$f"; then
      echo "KERNEL DRIFT: $f lost its pinned invariant: $sig"; FAIL=1
    fi
  done
}

self_test() {
  # Prove the grep-based detector distinguishes a correct copy from a mutated one.
  local tmp; tmp="$(mktemp -d)"
  local fixture="canonical convention block fixture: byte-identical at every site"
  printf '%s\n' "$fixture" > "$tmp/correct.txt"
  printf '%s\n' "canonical convention block fixture: byte-identicaI at every site" > "$tmp/mutated.txt"
  local ok=1
  grep -qF -- "$fixture" "$tmp/correct.txt" || { echo "self-test FAIL: signature did not match its own correct copy"; ok=0; }
  if grep -qF -- "$fixture" "$tmp/mutated.txt"; then
    echo "self-test FAIL: detector did NOT catch the mutated block"; ok=0
  fi

  # Kernel-map self-test (ADR-0049): copy a real KERNEL_MAP site into a temp dir,
  # strip its pinned kernel line, and confirm the check flags the mutation.
  local ksrc="skills/getting-up-to-speed/SKILL.md" ksig="is FORBIDDEN here"
  if [ ! -f "$ksrc" ]; then
    echo "self-test FAIL: kernel fixture source missing: $ksrc"; ok=0
  else
    cp -f "$ksrc" "$tmp/kernel-correct.md"
    grep -v -- "$ksig" "$ksrc" > "$tmp/kernel-mutated.md"
    grep -qF -- "$ksig" "$tmp/kernel-correct.md" || { echo "self-test FAIL: kernel signature missing from unmutated copy"; ok=0; }
    if grep -qF -- "$ksig" "$tmp/kernel-mutated.md"; then
      echo "self-test FAIL: kernel detector did NOT catch the stripped kernel line"; ok=0
    fi
  fi

  # KB-block self-test (ADR-0058): copy a real KB site, strip the fragment,
  # and confirm the detector flags the mutation.
  local kbsrc="skills/brainstorming/SKILL.md" kbsig="hits are pointers, not knowledge"
  if [ ! -f "$kbsrc" ]; then
    echo "self-test FAIL: KB fixture source missing: $kbsrc"; ok=0
  else
    cp -f "$kbsrc" "$tmp/kb-correct.md"
    grep -v -- "$kbsig" "$kbsrc" > "$tmp/kb-mutated.md"
    grep -qF -- "$kbsig" "$tmp/kb-correct.md" || { echo "self-test FAIL: KB signature missing from unmutated copy"; ok=0; }
    if grep -qF -- "$kbsig" "$tmp/kb-mutated.md"; then
      echo "self-test FAIL: KB detector did NOT catch the stripped fragment"; ok=0
    fi
  fi

  rm -rf "$tmp"
  if [ "$ok" -eq 1 ]; then echo "self-test OK: detector matches correct, rejects mutated"; return 0; else return 1; fi
}

if [ "${1:-}" = "--self-test" ]; then
  self_test; exit $?
fi

check_block "CB-3 Capture gate"    "$CB3_SIG" "${CB3_SITES[@]}"
check_block "CB-4 memory convention" "$CB4_SIG" "${CB4_SITES[@]}"
assert_line_identical "CB-4 memory convention (byte-identity)" "$CB4_SIG" "${CB4_SITES[@]}"
assert_block_identical "CB-3 Capture gate (byte-identity)" "$CB3_ANCHOR" '^```$' "${CB3_SITES[@]}"
check_block "KB read-depth fragment" "$KB_SIG" "${KB_SITES[@]}"
check_kernels

if [ "$FAIL" -eq 0 ]; then
  echo "convention-sync: OK (all canonical blocks byte-identical at their sites)"
else
  echo "convention-sync: FAIL (drift above)"
fi
exit "$FAIL"
