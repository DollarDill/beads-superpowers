"""Pure BM25F ranker over beads memories and knowledge-bead bodies.
No I/O, no bd calls, no third-party packages — see surface.sh for the bd interface."""
import re, math, collections, datetime
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
    """1.0 today, decaying linearly to 0.0 at 60 days. No parseable date == old
    (0.0), never new — an unparsed field must not silently promote an entry."""
    m = _CREATED.search(header)
    if not m:
        return 0.0
    try:
        age = (today - datetime.date(*map(int, m.groups()))).days
    except ValueError:
        return 0.0
    return max(0.0, (60 - age) / 60)

def _diversify(hits, toks):
    """Demote a hit sharing >50% of its top terms with a higher-ranked hit."""
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
    def __init__(self, docs):
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
            header = self.raw[key][:len(self.raw[key]) - len(self.bodies[key])]
            m = _SALIENCE.search(header)
            # else SALIENCE_UNSET, never a plausible-looking default: an entry with
            # no @salience header must stay visibly unpopulated. Defaulting to 3
            # here reintroduces exactly the fabrication finding eo9z2.2 closed, and
            # the suite's "salience is never fabricated" assertion enforces it.
            salience = int(m.group(1)) if m else SALIENCE_UNSET
            hazard = bool(_HAZARD.search(self.bodies[key]))
            score += 0.5 * (salience >= 4) + 0.5 * hazard + _recency(header, today or datetime.date.today())
            body_r = redact(self.bodies[key])          # redact BEFORE cutting
            idx = body_r.lower().find(qterms[0]) if qterms else -1
            start = max(0, idx - 60) if idx >= 0 else 0
            hits.append(Hit(key=key, score=score, sentence=body_r[start:start + 150].strip(),
                            salience=salience, hazard=hazard))
        hits.sort(key=lambda h: -h.score)
        return _diversify(hits, self.toks)[:top_n]
