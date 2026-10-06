# 6. Verification Discipline

This is the methodology piece that actually separates a useful audit from a pile of
speculation. Every lead gets treated as a claim to be disproven, not a finding to be
written up — and most leads should die. That's not a failure of the process; it's
the process working correctly. The single biggest driver of report quality (and
researcher reputation) is being precise about *how confident* a claim is, and never
letting that precision slip during write-up.

## The core loop

1. **Form a specific, falsifiable hypothesis.** Not "this parser looks sketchy" but
   "if field X exceeds length Y, function Z will index past the buffer without a
   bounds check." Vague suspicion can't be killed or confirmed — only specific claims
   can.
2. **Identify the exact evidence that would confirm or kill it**, and go get that
   evidence directly — read the actual function, trace the actual call site, run the
   actual test — rather than reasoning further from assumptions.
3. **Update immediately on what the evidence shows.** If the hypothesis is wrong,
   say so plainly and move to the next one. Don't reframe a dead hypothesis to keep
   it alive.
4. **Only a confirmed hypothesis becomes a finding.** Everything else is a dead end
   that cost some time and taught you more about the codebase — which is still worth
   something, but isn't reportable.

## The four confidence tiers

Not all "confirmed" claims are the same strength, and conflating them is a common
source of low-quality reports.

### 1. Confirmed by static reading
You've read the exact lines, traced the control flow by hand, and you're confident in
the logic claim. This is necessary but not sufficient for anything but the simplest
bugs — human reading of control flow, especially across async code, macros, or
generated code, is fallible.

### 2. Confirmed by execution
You've either run the actual target code (ideal, not always possible), or built a
**faithful, verbatim-logic extraction** of just the function(s) in question in an
isolated, compilable harness, instrumented to prove the specific claim (e.g.
"function B is never called before function A returns success" — see
`07-extracted-logic-harness-pattern.md`). Execution-based confirmation is
categorically stronger than reading-based confirmation, because it removes the
possibility that you misread a subtlety (operator precedence, short-circuit
evaluation, an off-by-one, a macro expansion you didn't fully trace).

### 3. Confirmed negative
You searched *exhaustively* (every repo you have access to, every call-site pattern
you can think of: direct calls, trait implementations, reflection/dynamic dispatch
where applicable) and found zero matches. This is a real, useful result — but it's
only as strong as the exhaustiveness of the search, and it says nothing about code
you don't have access to.

### 4. Open gap
You have a plausible mechanism and supporting circumstantial evidence (e.g. a test
file whose name strongly implies the exact property you're worried about; a doc
comment describing exactly the threat model), but the concrete, real-world call site
lives outside your source access (a private backend, a closed-source client, hardware
you don't have). This is **not** the same as tier 3, and conflating them is the single
most common way an otherwise-good report loses credibility.

**Rules for combining tiers in one finding:**

- State the tier explicitly for every non-trivial claim, in plain language a
  non-researcher reviewer can parse ("I could not find a production caller of this
  function in the public source; the likely real caller is backend code I don't have
  access to").
- A finding resting entirely on tier 4 is still worth reporting if the underlying
  code defect (tier 1 or 2) is unambiguous — but say so, and let the program's own
  team close the gap, since they can see what you can't.
- Never upgrade a tier-4 gap to a tier-3 "confirmed unreachable" or a tier-1
  "confirmed exploitable" claim because closing the loop felt tedious. This is the
  exact failure mode that damages research reputation.

A good writeup states which tier applies, explicitly, rather than presenting
everything with the same confident tone.

## Catching your own process errors

Mistakes happen mid-audit — running a command in the wrong environment, analyzing
the wrong commit, misreading a config's wiring. The discipline isn't avoiding every
mistake; it's:

- Noticing the mistake as soon as evidence contradicts the earlier conclusion
- Stating it plainly rather than quietly patching around it
- Re-deriving the conclusion from corrected evidence before continuing

A session where an early conclusion gets revised on better evidence is a sign the
process is working. A session where every early guess turns out right on the first
try is a sign the hypotheses weren't being tested hard enough.

## Scope and eligibility as part of verification

For any engagement with defined scope or a bounty program's rules, eligibility is
part of what needs verifying — not an afterthought once a bug is confirmed:

- Does the exploit path require preconditions (physical access, prior compromise,
  a trusted insider) that the program's threat model excludes?
- Is the affected component actually in scope, or does it belong to a dependency/
  upstream project that should be reported elsewhere?
- Is there a working proof of concept, or does the finding rest on source review
  alone — and does the program's policy require more than that?

Checking these before writing up a finding (especially under a limited submission
budget) is as much a part of the technical work as the vulnerability analysis itself.

## Output of this phase

Each candidate finding tagged with its confidence tier and an explicit statement of
what would be needed to raise it further (e.g. "confirming this requires access to
X, which I don't have").
