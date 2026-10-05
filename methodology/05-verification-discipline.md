# 5. Verification Discipline

This is the methodology piece that actually separates a useful audit from a pile of
speculation. Every lead gets treated as a claim to be disproven, not a finding to be
written up — and most leads should die. That's not a failure of the process; it's
the process working correctly.

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

## Separating levels of confidence

Not all "confirmed" claims are the same strength, and conflating them is a common
source of low-quality reports:

- **Confirmed by reading the enforcement code directly** (e.g., traced a function
  from input to the exact comparison/check that would or wouldn't catch a bad value)
  — strong.
- **Confirmed by configuration/static analysis only** (e.g., a flag that gates a
  protection is unset in every config file you can see) — medium; state explicitly
  what you could and couldn't verify, including any unknowns (private build overlays,
  code outside your visibility).
- **Inferred from documentation or naming** — weak; needs direct code confirmation
  before being treated as anything more than a lead.

A good writeup states which of these applies, explicitly, rather than presenting all
three with the same confident tone.

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
