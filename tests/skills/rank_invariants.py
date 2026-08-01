import sys, os, re, pathlib
# RANK_DIR lets the guard-the-guards mutation (Task 5) point this at a mutated
# COPY. Without the override, sys.path.insert(0, ...) would always win over
# PYTHONPATH and the mutation would be silently inert.
_dir = os.environ.get("RANK_DIR") or str(
    pathlib.Path(__file__).resolve().parents[2] / "skills/knowledge-retrieval/scripts")
sys.path.insert(0, _dir)
from rank import Corpus, strip_header, SALIENCE_UNSET

# NOTE: "bd" appears in EVERY document that has a body on purpose — that is what
# makes it ubiquitous (df=14 of the 14 bodied documents, low IDF) against the
# rare "worktree" (df=2, high IDF). Verified: query "bd worktree" scores
# hit-worktree/hit-gotcha at 1.72 and ubiquitous at 0.20. Remove "bd" from any
# document and the IDF gap collapses, TF-saturation lets the 10x-repeated term
# win, and the rare-term invariant fails against correct BM25. Do not "tidy"
# this fixture.
FIXTURE = {
    "hit-worktree":  "@type=semantic:lesson @salience=3 bd worktree create resolves paths from the shell cwd",
    "hit-gotcha":    "@type=semantic:lesson @salience=4 bd worktree gotchas fire the moment you create one",
    "miss-unrelated":"@type=semantic:lesson @salience=5 bd installer writes a staging directory",
    "header-only":   "@type=semantic:pattern @salience=5 bd release runbook lives on dev",
    "ubiquitous":    "@type=semantic:lesson @salience=3 bd bd bd bd bd bd bd bd bd bd",
}

# The five documents above pin IDF and the header strip. They say nothing about
# length normalisation (B) or term-frequency saturation (K1): those knobs can be
# mutated to any value without turning the suite red. The documents below exist
# to bracket B and K1 from BOTH sides — a single-sided assertion always leaves
# the opposite mutation alive (an assertion that the shorter document wins kills
# B=0 but passes even harder at B=1).
#
# Group rules, all load-bearing:
#   - Each probe term (ledger, sextant, quarry/piston/girder, mortise) appears in
#     exactly TWO documents, so its IDF is identical on both sides of every
#     comparison and only length or term frequency can move the result.
#   - "pad" is filler that no query ever mentions; it exists solely to set
#     document length. Lengths marked "equal" below MUST stay equal.
#   - These documents also carry "bd", keeping it ubiquitous as the note above
#     requires. The body-less entry is the sole exception: it has no body at all,
#     which is the whole point of it.
_H = "@type=semantic:lesson @salience=4 "

def _body(*tokens, length=None):
    """Body tokens, padded with never-queried filler to an exact token count."""
    toks = list(tokens)
    if length is not None:
        assert length >= len(toks), "pad target below token count"
        toks += ["pad"] * (length - len(toks))
    return " ".join(toks)

FIXTURE.update({
    # Header block and nothing else. The separator after the final @key=value
    # pair is end-of-string, not whitespace — the one shape where the header
    # strip can silently leak its tokens into the index.
    "bodyless":  "@type=semantic:pattern @salience=4",

    # B > 0: same term, same tf, different length.
    "len-short": _H + _body("bd", "ledger"),                            # dl 2
    "len-long":  _H + _body("bd", "ledger", length=12),                 # dl 12

    # B < 1: dup-twice is dup-once concatenated with itself — twice the
    # evidence at twice the length.
    "dup-once":  _H + _body("bd", "sextant", "tally"),                  # dl 3
    "dup-twice": _H + _body("bd", "sextant", "tally",
                            "bd", "sextant", "tally"),                  # dl 6

    # K1 upper bracket: equal length, quarry at tf 1 vs tf 4. decoy-pg gives
    # piston and girder the same df as quarry so all three IDFs cancel.
    "cov-three": _H + _body("bd", "quarry", "piston", "girder",
                            length=6),                                  # dl 6
    "rep-four":  _H + _body("bd", "quarry", "quarry", "quarry",
                            "quarry", length=6),                        # dl 6
    "decoy-pg":  _H + _body("bd", "piston", "girder", length=6),        # dl 6

    # K1 lower bracket: equal length, mortise at tf 1 vs tf 10.
    "sat-one":   _H + _body("bd", "mortise", length=11),                # dl 11
    "sat-many":  _H + _body("bd", *["mortise"] * 10),                   # dl 11
})

_SALIENCE = re.compile(r'@salience=(\d+)')

def header_salience(raw):
    m = _SALIENCE.search(raw)
    return int(m.group(1)) if m else None

def check(name, cond):
    print(("ok   " if cond else "FAIL ") + name)
    return cond

def main():
    c = Corpus(FIXTURE)
    ok = True
    keys = lambda q: [h.key for h in c.search(q, top_n=5)]

    ok &= check("term match outranks non-match",
                "hit-worktree" in keys("worktree") and "miss-unrelated" not in keys("worktree"))
    ok &= check("header-only match never returned",
                "header-only" not in keys("salience"))
    ok &= check("multi-word query returns results",
                len(keys("bd worktree gotchas")) > 0)
    ok &= check("rare term outranks ubiquitous term",
                keys("bd worktree")[0] != "ubiquitous")
    ok &= check("strip_header removes the leading block",
                not strip_header(FIXTURE["hit-worktree"]).startswith("@type"))
    ok &= check("body-less entry leaks no header tokens into the index",
                not any("bodyless" in keys(q)
                        for q in ("type", "semantic", "pattern", "salience", "4")))

    def score(q, key):
        for h in c.search(q, top_n=len(FIXTURE)):
            if h.key == key:
                return h.score
        return 0.0

    # B > 0 — length normalisation is on. At B=0 length is ignored entirely and
    # these two score exactly the same.
    ok &= check("shorter document outranks longer one at equal term frequency",
                score("ledger", "len-short") > score("ledger", "len-long"))
    # B < 1 — normalisation is partial. At B=1 it is total: a document
    # concatenated with itself scores exactly what the original scored, so the
    # doubled evidence buys nothing.
    ok &= check("duplicating a document raises its score",
                score("sextant", "dup-twice") > score("sextant", "dup-once"))
    # Saturation exists — four occurrences are worth less than four separate
    # single occurrences. Linear term frequency makes this an exact equality.
    ok &= check("term frequency is sublinear",
                score("quarry", "rep-four") < 4 * score("quarry", "cov-three"))
    # K1 upper bracket — saturation is strong enough that matching every query
    # term once beats piling up one of them. Fails once tf goes near-linear.
    ok &= check("covering all query terms outranks repeating one of them",
                score("quarry piston girder", "cov-three")
                > score("quarry piston girder", "rep-four"))
    # K1 lower bracket — saturation is not extreme. One occurrence must be worth
    # less than half of everything the term can ever earn (the half-saturation
    # point sits above tf=1), so a pile of matches at least doubles it. Fails
    # once the first occurrence already takes almost all the credit.
    ok &= check("a pile of matches more than doubles a single match",
                score("mortise", "sat-many") > 2 * score("mortise", "sat-one"))

    # Hit.salience must never be invented. Either it is the disclosed
    # not-yet-populated sentinel, or it is the entry's own @salience. The
    # spread check keeps this honest: the sample must span more than one
    # header value, so no single hardcoded constant can satisfy it.
    sal = [(h.salience, header_salience(FIXTURE[h.key]))
           for h in c.search("bd", top_n=len(FIXTURE))]
    ok &= check("salience is never fabricated (unset sentinel or the entry's own header value)",
                len({hdr for _, hdr in sal}) > 1
                and all(got in (SALIENCE_UNSET, hdr) for got, hdr in sal))
    sys.exit(0 if ok else 1)

main()
