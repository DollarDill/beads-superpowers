"""BM25F ranker over beads memories and knowledge-bead bodies.

The module body is pure: no I/O, no bd calls, no third-party packages. The
__main__ block at the bottom is the CLI entry point — it reads the corpus from
stdin and prints the coverage line and the ranked hits. All bd I/O lives in
surface.sh; nothing here shells out."""
import re, math, collections, datetime, os
from dataclasses import dataclass

_HEADER = re.compile(r'^((?:@\w+=\S+(?:\s+|$))+)', re.S)
_WORD = re.compile(r'[a-z0-9]+')
_SECRET = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----"
    r"|-----BEGIN [A-Z ]*PRIVATE KEY-----.*"
    r"|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})", re.S)
_HAZARD = re.compile(r"\b(never|always|must not|do not|don't|forbidden)\b", re.I)
_SALIENCE = re.compile(r'@salience=(\d+)')   # (\d+), matching tests/skills/rank_invariants.py
_CREATED = re.compile(r'@created=(\d{4})-(\d{2})-(\d{2})')
K1, B = 1.5, 0.75
# An entry whose header carries no @salience keeps this sentinel rather than a
# plausible-looking number, so an unpopulated field can never be mistaken for
# real data.
SALIENCE_UNSET = -1

def strip_header(value):
    """Return the body with the leading @key=value block removed.
    Anchored at the start ONLY: a header elsewhere is body text, and one real
    entry (pattern-gh-pages-...) carries its header at the end."""
    m = _HEADER.match(value)
    return (value[m.end():] if m else value).replace("\n", " ")

def tokenize(text):
    return _WORD.findall(text.lower())

def redact(text):
    """Redact the FULL text before any truncation. Redacting an already-cut
    excerpt can leave a partial secret too short to match the pattern, and
    print it unredacted — see orient.sh:55-90."""
    return _SECRET.sub("[REDACTED]", text)

def _recency(header, today):
    """1.0 today, decaying linearly to 0.0 at 60 days, clamped at BOTH ends.
    A future @created clamps to 1.0: unclamped, (60 - age) / 60 at a negative
    age is unbounded (2099-01-01 scores 441.85), so one typo'd store-supplied
    date becomes a gate on scores of 15-48 instead of the tiebreak the spec
    allows. No parseable date == old (0.0), never new — an unparsed field must
    not silently promote an entry."""
    m = _CREATED.search(header)
    if not m:
        return 0.0
    try:
        age = (today - datetime.date(*map(int, m.groups()))).days
    except ValueError:
        return 0.0
    return min(1.0, max(0.0, (60 - age) / 60))

def _diversify(hits, toks):
    """Demote a hit sharing >50% of its top terms with a higher-ranked hit."""
    # Known: stopwords count as topical overlap and can demote a genuine hit — beads-superpowers-eo9z2.14
    kept, seen = [], []
    for h in hits:
        top = {t for t, _ in collections.Counter(toks[h.key]).most_common(8)}
        if any(len(top & prev) > len(top) / 2 for prev in seen):
            h.score *= 0.5
        seen.append(top)
        kept.append(h)
    kept.sort(key=lambda x: -x.score)
    return kept

@dataclass
class Hit:
    key: str
    score: float
    sentence: str
    salience: int
    hazard: bool

class Corpus:
    def __init__(self, docs, today=None):
        # Frozen ONCE here, not read per search() call: the module docstring
        # declares this body pure, and a per-call clock read lets a single Corpus
        # straddle midnight — two searches on the same corpus disagreeing, and the
        # suite going non-deterministic the moment a fixture carries @created
        # (beads-superpowers-eo9z2.4). Callers may still override per call.
        self.today = today or datetime.date.today()
        self.raw = docs
        self.bodies = {k: strip_header(v) for k, v in docs.items()}
        self.toks = {k: tokenize(v) for k, v in self.bodies.items()}
        self.N = max(len(self.toks), 1)
        self.avgdl = (sum(len(t) for t in self.toks.values()) / self.N) or 1.0
        self.df = collections.Counter()
        for t in self.toks.values():
            self.df.update(set(t))

    def _bm25(self, key, qterms):
        tf = collections.Counter(self.toks[key])
        dl = len(self.toks[key])
        score = 0.0
        for term in qterms:
            if not tf[term]:
                continue
            idf = math.log(1 + (self.N - self.df[term] + 0.5) / (self.df[term] + 0.5))
            score += idf * (tf[term] * (K1 + 1)) / (tf[term] + K1 * (1 - B + B * dl / self.avgdl))
        return score

    def search(self, query, top_n=5, today=None):
        qterms = tokenize(query)
        hits = []
        for key in self.raw:
            score = self._bm25(key, qterms)
            if score <= 0:
                continue
            # _HEADER.match, not length arithmetic against the body: the two
            # agree only because strip_header's .replace("\n", " ") preserves
            # length. A plausible future tidy there (adding .strip()) would shift
            # the boundary and let _SALIENCE / _CREATED read body text as header.
            hm = _HEADER.match(self.raw[key])
            header = hm.group(1) if hm else ""
            m = _SALIENCE.search(header)
            # else SALIENCE_UNSET, never a plausible-looking default: an entry with
            # no @salience header must stay visibly unpopulated. Defaulting to 3
            # here reintroduces exactly the fabrication finding eo9z2.2 closed, and
            # the suite's "salience is never fabricated" assertion enforces it.
            salience = int(m.group(1)) if m else SALIENCE_UNSET
            hazard = bool(_HAZARD.search(self.bodies[key]))
            score += 0.5 * (salience >= 4) + 0.5 * hazard + _recency(header, today or self.today)
            body_r = redact(self.bodies[key])          # redact BEFORE cutting
            # First query term that ACTUALLY occurs, not qterms[0]: _bm25 returns
            # a hit when ANY term matches, so a document matched by a later term
            # has no qterms[0] to find and would fall back to a fixed-length
            # prefix containing no match at all. Computed on body_r, the redacted
            # string, so the slice below can never cut a secret.
            idx = next((i for i in (body_r.lower().find(t) for t in qterms) if i >= 0), -1)
            start = max(0, idx - 60) if idx >= 0 else 0
            hits.append(Hit(key=key, score=score, sentence=body_r[start:start + 150].strip(),
                            salience=salience, hazard=hazard))
        hits.sort(key=lambda h: -h.score)
        return _diversify(hits, self.toks)[:top_n]


def _store(name, count, failed):
    """Coverage-line term for one store. A bd failure is NAMED, never rendered
    as a count of zero — 'beads(0)' and 'bd errored' must not look identical."""
    return "%s UNAVAILABLE(bd error)" % name if failed else "%s(%d)" % (name, count)


if __name__ == "__main__":
    import json, sys

    args = [a for a in sys.argv[1:] if a != "--stdin"]
    raw = sys.stdin.read().split("\0")
    mem = json.loads(raw[0] or "{}")
    beads = json.loads((raw[1] if len(raw) > 1 else "") or "[]")
    failed = {s for s in (raw[2] if len(raw) > 2 else "").split(",") if s}
    query = " ".join(args)

    # Stage 1 recall. Memories: whole corpus. Beads: label filter when the query
    # names a label, else all kb beads (ADR-0056's axis is recall, not ranking —
    # 12 of 19 buckets exceed 10 entries, so ranking still runs).
    # The vocabulary is DERIVED FROM THE DATA, never read from a file: a path
    # relative to __file__ resolves to ~/.claude/scripts/... once installed and
    # would silently disable label filtering for every real user. Deriving also
    # makes the skill portable to projects with their own label sets.
    # SUBSET match, not set intersection: tokenize() splits on hyphens, so
    # comparing whole label strings against query tokens can never fire for a
    # hyphenated label — 10 of the live store's 19 labels, including its four
    # largest buckets (skills-arch 61, beads-tooling 44, harness-parity 41,
    # adr-process 20). A label fires when its own tokens all appear in the query,
    # so `skills-arch` and `skills arch` both reach the same bucket, and
    # single-token labels behave exactly as before.
    vocab = {l for b in beads for l in b.get("labels", []) if l != "kb"}
    qtok = set(tokenize(query))
    named = {l for l in vocab if set(tokenize(l)) <= qtok}
    if named:
        beads = [b for b in beads if named & set(b.get("labels", []))]

    # `bd memories --json` wraps the {key: body} map in a "schema_version"
    # envelope key (verified against bd 1.1.2). It is not a memory: counting it
    # reports memories(3) for a 2-memory store, a miscount inside the one line
    # whose job is to make coverage checkable.
    docs = {k: v for k, v in mem.items() if isinstance(v, str) and k != "schema_version"}
    mem_count = len(docs)
    # .get throughout: an id-less bead must not raise before the coverage line
    # prints — a traceback where a coverage line belongs is the loudest possible
    # silent partial.
    # Title AND description, not description-else-title: the old fallback
    # indexed the title only when description was EMPTY, so on the live store
    # (all 232 kb beads have a description) no bead title was ever searchable
    # — e.g. querying "ADR-0049" never surfaced the bead titled "ADR-0049:
    # pocock-composition model" (beads-superpowers-eo9z2, FR4).
    docs.update({b.get("id"): ((b.get("title") or "") + " " + (b.get("description") or ""))
                 for b in beads if b.get("id")})

    print("searched: %s %s%s" % (
        _store("memories", mem_count, "memories" in failed),
        _store("beads", len(beads), "beads" in failed),
        " label=%s" % ",".join(sorted(named)) if named else ""))
    hits = Corpus(docs).search(query, top_n=int(os.environ.get("BSP_TOP_N", "5")))
    for h in hits:
        # SALIENCE_UNSET prints as "?", never as its -1 sentinel: "s-1" reads
        # like real data, which is the fabricated-plausible-value failure the
        # eo9z2.2 finding closed inside the ranker. Two-char field either way,
        # so the column stays scannable.
        sal = "?" if h.salience == SALIENCE_UNSET else str(h.salience)
        # %-42s PADS, it does not truncate. The key is the actionable payload —
        # the agent's next move is `bd recall <key>` — and 61% of the live store's
        # keys exceed 42 chars, so h.key[:42] would print an identifier that
        # resolves to nothing for the majority of results. A ragged column for
        # long keys is the correct trade.
        print("  %-42s s%-2s%s  %s" % (h.key, sal, " HAZ" if h.hazard else "    ", h.sentence))
    if not hits:
        print("  (no hits — re-angle the query once before reporting none)")
