#!/usr/bin/env bash
# orient.sh — getting-up-to-speed Phase 1 data gatherer. RAW DATA ONLY: no verdicts,
# no freshness classification, no advisory language. Judgment (continuity, freshness,
# scale-path choice) stays with the agent in Phases 3-4 — this script only gathers.
# Invocation: bash scripts/orient.sh   (read-only; safe anywhere, exits 0 always)
set -uo pipefail

echo "== scale =="
TRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' '); echo "tracked=$TRACKED"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "git=1" || echo "git=0"

if ! command -v bd >/dev/null 2>&1 || ! bd ready -n 1 >/dev/null 2>&1; then
    echo "== ledger =="; echo "SKIP (bd absent or no beads workspace)"
    echo "== ready ==";  echo "SKIP"
    echo "== in-progress =="; echo "SKIP"
    echo "== blocked =="; echo "SKIP"
    echo "== memories =="; echo "SKIP"
else
    echo "== ledger =="
    bd count --by-status 2>/dev/null | head -10
    bd count --by-priority 2>/dev/null | head -10
    echo "== ready =="
    bd ready -n 10 2>/dev/null | head -14
    echo "== in-progress =="
    bd query "status=in_progress" -n 10 2>/dev/null | head -12
    echo "== blocked =="
    bd blocked 2>/dev/null | head -12
    echo "== memories =="
    if ! command -v python3 >/dev/null 2>&1; then
        # Visible degradation, never a silent partial digest: a truncated-body parse
        # detects only 19 of 71 hazard rules (27%) while reading as complete.
        printf 'digest requires python3 — showing count only\n'
        bd memories 2>/dev/null | head -1
        printf 'search: bd memories <keyword> · fetch: bd recall <key>\n'
    else
# shellcheck disable=SC2016  # the markdown-style backticks around {k} are literal Python print output, not bash command substitution; single quotes are intentional to keep the whole python3 -c script opaque to bash
bd memories --json 2>/dev/null | python3 -I -c '
import json,sys,re
d=json.load(sys.stdin); items={}
def absorb(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if isinstance(v,str): items[k]=v
            else: absorb(v)
    elif isinstance(o,list):
        for e in o: absorb(e)
absorb(d)
haz,hi=[],[]
_HAZ=re.compile(r"\b(never|always|do not|dont)\b",re.I)
# Read-side defence in depth: the write-side memory-curator kernel is the
# primary control, but this script now emits many excerpts, so redact
# high-confidence credential shapes before printing. _MASK is a plain
# variable (not a literal inline) because this whole block sits inside a
# bash single-quoted python3 -c "..." — any single-quote character here
# would break out of the outer bash quoting, and a same-quote literal
# nested inside an f-string expression needs Python 3.12+ (PEP 701).
_MASK="[REDACTED]"
# Branch 1 matches a full BEGIN..END block. Branch 2 is the fallback for
# when no END marker follows the header: it redacts from the header to
# the end of the string, not just the header label, so key bytes can
# never survive merely because no END line was captured.
_SECRET=re.compile(r"(-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----|-----BEGIN [A-Z ]*PRIVATE KEY-----.*|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})")
for k,v in sorted(items.items()):
    # Strip leading @key=value metadata tokens by known key name, not any
    # @\S+ token: an unclassified @-prefixed token is body content, not
    # metadata, and must reach hazard classification below (a body that
    # legitimately starts "@always-rotate-keys-quarterly ..." must not be
    # swallowed as if it were a header field).
    body=re.sub(r"^(@(?:type|created|salience|refs|tags)=\S+\s+)+","",v)
    body=re.sub(r"\s+"," ",body).strip()
    m=re.search(r"@salience=(\d)",v)
    # Classify against the pre-redaction body: the PEM fallback branch
    # above can consume to end-of-string when no END marker is present,
    # and hazard/salience classification must not depend on whatever
    # happens to survive that redaction.
    is_haz=bool(_HAZ.search(body))
    is_hi=bool(m and int(m.group(1))>=4)
    # Redact the FULL body before any truncation happens. Redacting an
    # already-truncated excerpt lets a credential with no preceding
    # whitespace inside the visible window get cut mid-secret, with the
    # truncated prefix too short to satisfy the length requirement the
    # pattern itself imposes — printing unredacted. Redact-then-truncate
    # makes a partial secret structurally impossible: it is already
    # [REDACTED] before any cutting happens.
    body_r=_SECRET.sub(_MASK, body)
    # Gist text only: strip backticks and collapse em-dashes so the
    # `key` — gist line can never contain a stray backtick or em-dash
    # that makes the separator ambiguous. The key itself is untouched.
    body_r=body_r.replace("`","").replace("—","-")
    # Gist always opens at the start of the body (readable, scannable), never
    # centered on a matched phrase — a mid-string window reads as noise
    # and defeats the point of a digest. Hazard classification is conveyed
    # by bucket ordering (haz+hi below) and the total=/digest=/hazard=
    # summary line, not by reshaping the excerpt.
    if len(body_r)<=80:
        excerpt=body_r
    else:
        excerpt=body_r[:80]
        if not body_r[80].isspace():
            # 80-char cut landed mid-word: trim back to the last whole word.
            cut=excerpt.rfind(" ")
            if cut>0:
                excerpt=excerpt[:cut]
        excerpt=excerpt.rstrip()+"…"
    if is_haz:
        haz.append((k, excerpt))
    elif is_hi:
        hi.append((k, excerpt))
for k,b in haz+hi:
    print(f"`{k}` — {b}")
print(f"total={len(items)} digest={len(haz)+len(hi)} hazard={len(haz)}")
' 2>/dev/null || printf 'digest unavailable — search: bd memories <keyword>\n'
    fi
fi

echo "== handoff =="
# shellcheck disable=SC2012  # mtime-sort intended (naming isn't lexically sortable); filenames are controlled, not adversarial
newest=$(ls -t .internal/handoff/*.md 2>/dev/null | head -1)
if [ -n "$newest" ]; then
    echo "path=$newest"
    echo "head_sha=$(git rev-parse HEAD 2>/dev/null || echo none)"
    echo "doc_sha=$(grep -m1 -oE '@ *[`*]*[0-9a-f]{7,40}' "$newest" 2>/dev/null | grep -oE '[0-9a-f]{7,40}' | head -1)"
    echo "doc_mtime=$(stat -c %Y "$newest" 2>/dev/null || stat -f %m "$newest" 2>/dev/null)"
    echo "last_commit_time=$(git log -1 --format=%ct 2>/dev/null || echo none)"
    # shellcheck disable=SC2012  # count only; filenames are controlled, not adversarial
    echo "inbox_count=$(ls .internal/handoff/*.md 2>/dev/null | wc -l | tr -d ' ')"
else
    echo "none"
fi

exit 0
