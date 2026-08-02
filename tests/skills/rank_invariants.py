import sys, os, re, pathlib
# RANK_DIR lets the guard-the-guards mutation (Task 5) point this at a mutated
# COPY. Without the override, sys.path.insert(0, ...) would always win over
# PYTHONPATH and the mutation would be silently inert.
_dir = os.environ.get("RANK_DIR") or str(
    pathlib.Path(__file__).resolve().parents[2] / "skills/knowledge-retrieval/scripts")
sys.path.insert(0, _dir)
from rank import Corpus, strip_header, tokenize, SALIENCE_UNSET

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

    # Raw BM25, deliberately NOT search(). Since Task 3, search() scores carry the
    # salience/hazard/recency boosts AND the diversity halving, and either can move
    # a comparison on its own — reading the five bracket assertions below through
    # search() lets a B=0 mutation pass the WHOLE suite green, because len-short
    # and len-long tie and the halving of len-long then fakes the expected order.
    # B and K1 govern the core, so the core is what these five assert.
    def score(q, key):
        return c._bm25(key, tokenize(q))

    # IDF is real. Same document, same term frequency (1), same length, so the
    # tf/length factor cancels exactly and ONLY IDF can move this: "worktree"
    # sits in 2 of the 15 documents, "bd" in 14. Asserted on the raw core for
    # the same reason as the brackets below — read through search(), a flat
    # idf=1.0 passes the whole suite green: ubiquitous does take the raw top
    # spot, but hit-gotcha's +0.5 salience boost overtakes it and the existing
    # "rare term outranks ubiquitous term" check never notices.
    ok &= check("a rare term scores higher than a ubiquitous one in the same document",
                score("worktree", "hit-worktree") > score("bd", "hit-worktree"))

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
    # not-yet-populated sentinel (only when the entry's OWN header carries no
    # @salience), or it is that entry's own @salience value. Checked against
    # `got` per row, not just `hdr`'s spread: `all(got in (SALIENCE_UNSET, hdr)
    # for got, hdr in sal)` is satisfied when got == SALIENCE_UNSET for EVERY
    # row, because SALIENCE_UNSET is always a member of that tuple regardless
    # of hdr — verified by mutation: hardcoding `salience = SALIENCE_UNSET`
    # left this exact line at exit 0 (beads-superpowers-eo9z2, FR3a). The
    # spread requirement is kept (a single hardcoded got value must fail
    # against more than one distinct hdr), but it is no longer what does the
    # catching — the per-row equality is.
    sal = [(h.salience, header_salience(FIXTURE[h.key]))
           for h in c.search("bd", top_n=len(FIXTURE))]
    ok &= check("salience is never fabricated (matches the entry's own header value, or the disclosed sentinel when that entry's header truly has none)",
                len({hdr for _, hdr in sal}) > 1
                and all((got == hdr) if hdr is not None else got == SALIENCE_UNSET
                        for got, hdr in sal))
    ok = extra_checks(ok)
    sys.exit(0 if ok else 1)

def extra_checks(ok):
    from rank import redact
    # Runtime-assembled fake token: never a contiguous literal in a committed
    # file (GH013 push protection — lesson-a-secret-scanner-s-own-test-fixtures).
    fake = "ghp_" + ("A" * 36)
    poisoned = {"leak": "@type=semantic:lesson @salience=3 the token is %s trailing text" % fake}
    c2 = Corpus(poisoned)
    hit = c2.search("token", top_n=1)[0]
    ok &= check("secret redacted in output", "[REDACTED]" in hit.sentence)
    ok &= check("no partial secret survives", "ghp_A" not in hit.sentence)
    ok &= check("sentence contains the matched term", "token" in hit.sentence.lower())

    # Separate corpus, deliberately NOT the main FIXTURE: adding documents there
    # would move N and avgdl and invalidate the B/K1 brackets Task 2's fix round
    # measured. The filler docs exist to make "argosy" rare (df=2 of N=8) so IDF
    # is real — in a 2-document corpus df==N, IDF collapses to ~0.18, and every
    # score is so small that a 0.5 boost dominates. That is what made the
    # original version of this fixture fail.
    filler = {"noise%d" % i: "@salience=3 bd staging directory notes" for i in range(6)}
    strong = dict(filler)
    strong["a"] = "@salience=1 bd argosy argosy argosy argosy"     # BM25 2.34
    strong["b"] = "@salience=5 bd argosy " + " ".join(["pad"] * 10)  # BM25 0.80
    c3 = Corpus(strong)
    # Measured raw gap 1.54 — above the acceptance criterion's 1.0 threshold, so
    # the +0.5 boost on b provably cannot reorder them. Re-measure if you retune.
    ok &= check("salience does not flip a clear BM25 win",
                c3.search("argosy", top_n=2)[0].key == "a")

    # --- acceptance criteria the block above does not reach -----------------
    # "no partial secret at ANY truncation boundary". The poisoned body above is
    # ~67 chars, so the 150-char excerpt never actually cuts it and BOTH orderings
    # look identical — verified by mutation: swapping search() to truncate-then-
    # redact leaves the block above fully green. This fixture makes the secret
    # STRADDLE the window, which is the only shape that can tell the two apart.
    # Runtime-assembled, same reason as above.
    fake2 = "ghp_" + ("B" * 36)
    head = "the token is here "               # "token" at index 4, so the window starts at 0
    # 18 + 120 == 138: the secret starts inside the window and runs past its
    # 150-char end. Cut first and the tail that survives is "ghp_" + 8 chars —
    # too short for the {20,} pattern to match, so it prints in the clear.
    straddle = {"leak2": "@type=semantic:lesson @salience=3 "
                         + head + ("pad " * 30) + fake2 + " tail"}
    hit2 = Corpus(straddle).search("token", top_n=1)[0]
    ok &= check("secret straddling the truncation boundary is redacted",
                "[REDACTED]" in hit2.sentence)
    ok &= check("no partial secret survives the truncation boundary",
                "ghp_B" not in hit2.sentence)

    # The excerpt must anchor on a query term the document ACTUALLY contains.
    # _bm25 returns a hit when ANY term matches, so a document that matched only
    # a LATER term has no qterms[0] to find: anchoring on qterms[0] alone gives
    # idx == -1, start == 0, and exactly the fixed-length prefix acceptance
    # criterion 3 rejects. The main FIXTURE cannot catch this — its design note
    # deliberately puts "bd" in every bodied document, so qterms[0] always hits.
    # "late-match" carries no "bd" at all and matches only the second term.
    later = {"noise%d" % i: "@salience=1 bd staging directory notes" for i in range(5)}
    later["late-match"] = "@salience=1 " + " ".join(["alpha"] * 40) + " worktree tail"
    sent3 = next(h.sentence for h in Corpus(later).search("bd worktree", top_n=10)
                 if h.key == "late-match")
    ok &= check("excerpt anchors on the query term the document actually matched",
                "worktree" in sent3.lower())

    # Criterion 3's other half: "not a fixed-length prefix of the body". Every
    # other fixture puts its match within the first few characters, where
    # start = max(0, idx - 60) and a constant start = 0 are observationally
    # identical — mutating the centring to 0 left the entire suite green, which
    # is exactly why the qterms[0] anchoring defect above went undetected.
    # "preamble" sits at offset 0 and "mortise" at offset 169: a body-prefix
    # excerpt necessarily contains preamble and misses mortise, a centred one
    # necessarily does the reverse.
    far = {"noise%d" % i: "@salience=1 bd staging directory notes" for i in range(5)}
    far["far-match"] = "@salience=1 preamble " + " ".join(["pad"] * 40) + " mortise tail"
    sent4 = next(h.sentence for h in Corpus(far).search("mortise", top_n=10)
                 if h.key == "far-match")
    ok &= check("excerpt is centred on the match, not a fixed-length body prefix",
                "preamble" not in sent4.lower() and "mortise" in sent4.lower())

    # Recency is asserted on the pure helper, not through search(): inside
    # search() the diversity demotion moves scores too, so a corpus-level
    # comparison cannot show WHICH of the two moved a hit. A separate import
    # line keeps the prescribed block above byte-identical.
    import datetime
    from rank import _recency
    day = datetime.date(2026, 8, 1)
    ok &= check("recency is 1.0 today, 0.5 at 30 days, 0.0 at 60 days",
                _recency("@created=2026-08-01 ", day) == 1.0
                and _recency("@created=2026-07-02 ", day) == 0.5
                and _recency("@created=2026-06-02 ", day) == 0.0)
    # An unparsed date must never read as new: both the absent header and the
    # regex-shaped but impossible date have to land on 0.0, not on the 1.0 that
    # a today-defaulting implementation would hand them.
    ok &= check("an entry with no parseable @created is old, never new",
                _recency("@salience=3 ", day) == 0.0
                and _recency("@created=2026-13-45 ", day) == 0.0)
    # A future @created must never out-earn today. The three probes above all sit
    # on the clamped side of the floor, so they say nothing about the ceiling:
    # unclamped, (60 - age) / 60 at a negative age is unbounded — 31 days out
    # yields 1.52 and 2099-01-01 yields 441.85. @created is store-supplied text,
    # so one typo'd entry would pin itself to rank 1 on scores of 15-48. The spec
    # allows these signals only as a tiebreak, never as a gate.
    ok &= check("a future @created is clamped to today's boost, never above it",
                _recency("@created=2026-09-01 ", day) == 1.0
                and _recency("@created=2099-01-01 ", day) == 1.0)

    # Diversity. Fourth corpus for the same reason as the third — the main
    # FIXTURE's measured B/K1 brackets must not move. variant-b shares 3 of its
    # 4 top terms with variant-a and is demoted; distinct scores LOWER than
    # either variant on raw BM25 but shares only 2 of its 5, so it survives and
    # overtakes. Without _diversify the order is a, b, distinct.
    lesson = {"noise%d" % i: "@salience=1 bd staging directory notes" for i in range(5)}
    lesson["variant-a"] = "@salience=1 bd zephyr harness rig"       # BM25 0.958
    lesson["variant-b"] = "@salience=1 bd zephyr harness clamp"     # BM25 0.958
    lesson["distinct"] = "@salience=1 bd zephyr alpha beta gamma"   # BM25 0.862
    c4 = Corpus(lesson)
    # The invariant the name states, NOT a golden top-N ordering. Full-list
    # equality against a hand-measured order encodes the weights: every tune to
    # K1, B, the 0.5 halving or most_common(8) breaks it, and the cheap repair is
    # to paste in the new output — a test that ratifies rather than constrains.
    # It also pinned WHICH of the two variants is demoted, and they tie exactly
    # at 0.958, so that rested on dict insertion order plus sort stability rather
    # than on anything the ranker promises. max() of the two indices asserts the
    # actual promise: whichever variant is the redundant one lands below
    # "distinct", even though distinct scores lower than both on raw BM25.
    keys4 = [h.key for h in c4.search("zephyr", top_n=3)]
    ok &= check("a redundant variant is demoted below a distinct lower-scoring hit",
                keys4.index("distinct")
                < max(keys4.index("variant-a"), keys4.index("variant-b")))

    # Boost wiring (FR3b, beads-superpowers-eo9z2): nothing in the suite above
    # asserts that search()'s score += 0.5*(salience>=4) + 0.5*hazard +
    # _recency(...) line is actually REACHED — _recency is asserted as a pure
    # helper and _bm25 as a raw core, but the wiring between them (the design's
    # central claim: "signals are tiebreaks, never gates") had zero coverage.
    # Verified by mutation (before writing this): all three of `score += 0.0`,
    # `hazard = False`, and `salience = SALIENCE_UNSET` left the pre-existing
    # 25/25 suite at exit 0.
    #
    # Each pair below has an IDENTICAL raw BM25 for the query term — same tf,
    # same dl (padded to match), same idf (the term appears in ONLY these two
    # docs) — so ONLY a live boost can separate them. The plain variant is
    # inserted FIRST in the dict: Corpus.search()'s hits.sort() is stable, so a
    # zeroed boost leaves them tied and the stable sort keeps the
    # first-inserted (plain) doc on top, flipping "boosted ranks first" to
    # false. This tests the WIRING, not the magnitude — see rank.py:120.
    salw = {"noise%d" % i: "@salience=1 bd staging directory notes" for i in range(4)}
    salw["plain-salience"] = "@salience=1 zeolite pad pad pad pad"      # dl 6, no boost
    salw["boosted-salience"] = "@salience=5 zeolite pad pad pad pad"    # dl 6, salience>=4
    keys5 = [h.key for h in Corpus(salw).search("zeolite", top_n=2)]
    # Kills BOTH `score += 0.0` (boost never added, tie -> plain stays first)
    # and `salience = SALIENCE_UNSET` (salience>=4 never true for either doc).
    ok &= check("salience>=4 boost is wired into the score, not just computed",
                bool(keys5) and keys5[0] == "boosted-salience")

    hazw = {"noise%d" % i: "@salience=1 bd staging directory notes" for i in range(4)}
    hazw["plain-hazard"] = "@salience=1 tourmaline pad pad pad pad"       # dl 6, no hazard word
    hazw["hazard-hazard"] = "@salience=1 tourmaline never pad pad pad"    # dl 6, one pad -> "never"
    keys6 = [h.key for h in Corpus(hazw).search("tourmaline", top_n=2)]
    # Kills BOTH `score += 0.0` and `hazard = False` (hazard boost never true
    # for either doc). Salience is equal (both 1, both < 4) so this pair is
    # blind to the salience mutation, by design — isolates the hazard wiring.
    ok &= check("hazard boost is wired into the score, not just computed",
                bool(keys6) and keys6[0] == "hazard-hazard")

    # eo9z2.4: the module docstring declares this body pure, but search() read the
    # wall clock per call. Harmless while no FIXTURE entry carries @created, and
    # non-deterministic the moment one does — a Corpus could straddle midnight and
    # two calls would disagree. The date is now frozen once, at construction.
    import datetime as _dt
    _c = Corpus({"aged": "@created=2026-08-02\ntourmaline body text"},
                today=_dt.date(2026, 8, 2))
    ok &= check("date frozen at construction (today= honoured by __init__)",
                _c.today == _dt.date(2026, 8, 2))
    # Not a tautology: @created=2026-08-02 sits at age 0 against the frozen date
    # (full recency boost) and ages out against an explicit far-future today=. A
    # search() that ignored self.today and re-read the wall clock would drift with
    # the calendar instead of tracking the frozen value.
    _near = _c.search("tourmaline")[0].score
    _far = _c.search("tourmaline", today=_dt.date(2027, 1, 1))[0].score
    ok &= check("search() inherits the frozen date, and today= still overrides",
                _near > _far)

    # eo9z2.5 property (2): a hit ALREADY judged redundant must not be able to
    # demote a third hit. Standard MMR diversifies against the SELECTED set, not
    # the rejected one. Fixture is built so the distinction is the only thing that
    # decides the outcome: each doc has exactly 8 distinct terms, so most_common(8)
    # returns all of them and the threshold is >4.
    #   a vs nothing        -> kept
    #   b vs a: overlap 5   -> demoted
    #   c vs a: overlap 2   -> NOT demoted by a
    #   c vs b: overlap 5   -> demoted ONLY IF the rejected b is in `seen`
    from rank import _diversify as _dv, Hit
    _dtoks = {"a": ["p", "q", "r", "s", "t", "u", "v", "w"],
              "b": ["p", "q", "r", "s", "t", "m", "n", "o"],
              "c": ["m", "n", "o", "t", "q", "aa", "bb", "cc"]}
    _dhits = [Hit(key="a", score=3.0, sentence="", salience=3, hazard=False),
              Hit(key="b", score=2.0, sentence="", salience=3, hazard=False),
              Hit(key="c", score=1.0, sentence="", salience=3, hazard=False)]
    # Flat IDF reproduces the original count-based bar exactly (mass == cardinality),
    # so this assertion keeps testing property (2) and nothing else even after the
    # overlap became IDF-weighted (eo9z2.14).
    _dout = {h.key: h.score for h in _dv(_dhits, _dtoks, lambda t: 1.0)}
    ok &= check("a demoted hit does not poison later comparisons (eo9z2.5)",
                abs(_dout["c"] - 1.0) < 1e-9)
    ok &= check("the genuinely redundant hit is still demoted",
                abs(_dout["b"] - 1.0) < 1e-9)

    # eo9z2.14: overlap must be weighted by IDF, not counted. The failing design
    # criterion. A count-based bar cannot separate stopword overlap from topical
    # overlap — the measured false positive shared {the, worktree, bd, it, a},
    # three of which are function words. Asserted on SCORES through _diversify,
    # never on presence through search(): _diversify DEMOTES rather than drops, so
    # every hit is always present and a presence check can never fail.
    _idf = lambda t: 0.05 if t in {"the", "it", "a", "bd", "worktree"} else 3.0
    _mk = lambda k: Hit(key=k, score=2.0, sentence="", salience=3, hazard=False)
    # shared mass 5x0.05=0.25 vs bar 9.25x0.5=4.625 -> NO demotion.
    # Under the count-based bar this is 5 shared of 8 > 4 -> s2 halved to 1.0.
    _stop = {"s1": ["the", "it", "a", "bd", "worktree", "alpha", "beta", "gamma"],
             "s2": ["the", "it", "a", "bd", "worktree", "delta", "epsilon", "zeta"]}
    _so = {h.key: h.score for h in _dv([_mk("s1"), _mk("s2")], _stop, _idf)}
    ok &= check("function-word overlap does not demote (eo9z2.14)",
                abs(_so["s2"] - 2.0) < 1e-9)
    # shared mass 5x3.0=15.0 vs bar 24.0x0.5=12.0 -> DEMOTES. Stops "disable
    # demotion entirely" from being a passing fix.
    _cont = {"c1": ["shellcheck", "pipefail", "sigpipe", "mutation", "idf", "alpha", "beta", "gamma"],
             "c2": ["shellcheck", "pipefail", "sigpipe", "mutation", "idf", "delta", "epsilon", "zeta"]}
    _co = {h.key: h.score for h in _dv([_mk("c1"), _mk("c2")], _cont, _idf)}
    ok &= check("content-word overlap still demotes (diversify still works)",
                abs(_co["c2"] - 1.0) < 1e-9)
    # Pins the LOWER bound of DIVERSIFY_FRACTION. Without this the sweep showed
    # 0.3 and 0.5 behaving identically — any value below 0.625 passed, so the
    # constant was only half-constrained, and .14's failure mode is OVER-demotion
    # (a bar that is too low). Shared mass 3x3.0=9.0 against a total of 24.0 is a
    # ratio of 0.375, which sits between the candidates: at 0.3 the bar is 7.2 and
    # this pair demotes (RED); at 0.5 the bar is 12.0 and it does not (GREEN).
    _mid = {"m1": ["shellcheck", "pipefail", "sigpipe", "aa", "bb", "cc", "dd", "ee"],
            "m2": ["shellcheck", "pipefail", "sigpipe", "ff", "gg", "hh", "ii", "jj"]}
    _mo = {h.key: h.score for h in _dv([_mk("m1"), _mk("m2")], _mid, _idf)}
    ok &= check("a 0.375 mass-ratio overlap does NOT demote (pins the lower bound)",
                abs(_mo["m2"] - 2.0) < 1e-9)

    # eo9z2.6 SECURITY FLOOR — pins FAIL-CLOSED unterminated-PEM redaction.
    # The second alternation in _SECRET is deliberately unbounded: an unterminated
    # BEGIN header redacts to end of body. The accepted cost is that a knowledge
    # entry ABOUT PEM redaction loses its tail. DO NOT "fix" this by narrowing the
    # match — that is a security regression, and it is the change a future reader
    # will be tempted to make after seeing the finding described as a bug.
    # Header assembled at runtime so no committed file carries a contiguous PEM
    # marker (GH013 push protection), same idiom as the ghp_ fixture above.
    from rank import redact as _redact
    _pem = "-----BEGIN " + "RSA PRIVATE KEY" + "-----"
    _leak = "intro text %s\nMIIsecretsecretsecret\ntrailing sentence that must not survive" % _pem
    _out_r = _redact(_leak)
    ok &= check("unterminated PEM redacts to end of body (fail-closed floor)",
                "trailing sentence" not in _out_r and "MIIsecret" not in _out_r)
    ok &= check("text before an unterminated PEM survives redaction",
                "intro text" in _out_r)

    # beads-superpowers-eo9z2.16 — __main__ argument and BSP_TOP_N edges.
    # The helpers are PURE: _resolve_top_n RETURNS its notice instead of printing
    # it, so the module keeps the no-I/O contract its own docstring states, and
    # the caller decides where the notice lands relative to the coverage line.
    from rank import _parse_query, _resolve_top_n, _zero_reason
    ok &= check("--stdin is consumed once as a mode flag",
                _parse_query(["--stdin", "worktree"]) == ["worktree"])
    ok &= check("a SECOND --stdin is a query term, not a repeated flag",
                _parse_query(["--stdin", "--stdin"]) == ["--stdin"])
    ok &= check("non-integer BSP_TOP_N falls back to 5 and says so",
                _resolve_top_n("banana")[0] == 5
                and _resolve_top_n("banana")[1] is not None)
    ok &= check("negative BSP_TOP_N falls back to 5 and says so",
                _resolve_top_n("-3")[0] == 5
                and _resolve_top_n("-3")[1] is not None)
    ok &= check("a valid BSP_TOP_N passes through silently",
                _resolve_top_n("7") == (7, None))
    # BSP_TOP_N is externally controlled and the notice flows into agent context,
    # and from there into specs and commits. Bound what gets echoed onward.
    ok &= check("an oversized BSP_TOP_N is not echoed whole into the notice",
                len(_resolve_top_n("x" * 500)[1]) < 120)
    ok &= check("BSP_TOP_N=0 does not report 'no hits' — it was told to return none",
                _zero_reason(0) != _zero_reason(5)
                and "not a search result" in _zero_reason(0))
    return ok

main()
