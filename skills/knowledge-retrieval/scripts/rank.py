"""Pure BM25F ranker over beads memories and knowledge-bead bodies.
No I/O, no bd calls, no third-party packages — see surface.sh for the bd interface."""
import re, math, collections
from dataclasses import dataclass

_HEADER = re.compile(r'^((?:@\w+=\S+\s+)+)', re.S)
_WORD = re.compile(r'[a-z0-9]+')
K1, B = 1.5, 0.75

def strip_header(value):
    """Return the body with the leading @key=value block removed.
    Anchored at the start ONLY: a header elsewhere is body text, and one real
    entry (pattern-gh-pages-...) carries its header at the end."""
    m = _HEADER.match(value)
    return (value[m.end():] if m else value).replace("\n", " ")

def tokenize(text):
    return _WORD.findall(text.lower())

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

    def search(self, query, top_n=5):
        qterms = tokenize(query)
        hits = []
        for key in self.raw:
            score = self._bm25(key, qterms)
            if score <= 0:
                continue
            hits.append(Hit(key=key, score=score, sentence="", salience=3, hazard=False))
        hits.sort(key=lambda h: -h.score)
        return hits[:top_n]
