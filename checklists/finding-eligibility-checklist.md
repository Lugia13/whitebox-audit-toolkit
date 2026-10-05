# Finding Eligibility Checklist

Run through this before writing up or submitting any finding, especially under a
limited reporting budget. A technically real bug can still be the wrong thing to
submit if it doesn't clear these bars.

## Confidence level

- [ ] Stated explicitly whether the finding is confirmed by reading the actual
      enforcement/validation code, or inferred from configuration/documentation alone
- [ ] If any part of the build/config chain is outside your visibility (a private
      overlay, an internal pipeline, upstream code you couldn't fetch), stated that
      explicitly as a caveat rather than asserting full certainty
- [ ] Distinguished "confirmed in source" from "confirmed on a running instance/device"
      if those are different claims

## Reachability

- [ ] Confirmed the vulnerable code path is actually compiled into the shipping build,
      not gated out by a feature flag or build configuration
- [ ] Confirmed attacker-controlled input can actually reach the vulnerable function,
      not just that the function exists and looks unsafe in isolation

## Scope and threat model

- [ ] Confirmed the affected component is in the engagement/program's defined scope
      (not an out-of-scope dependency, archived component, or excluded asset type)
- [ ] Checked whether exploitation requires preconditions the program explicitly
      excludes (physical device access, MITM position, prior compromise, insider
      access, social engineering)
- [ ] If the only exploitation path requires hardware/device access you don't have,
      checked whether the program offers a path to get that access (test environment,
      supervised live testing) before assuming the finding is unsubmittable
- [ ] Checked the program's specific exclusion list for the finding's *class* of bug
      (e.g., many programs exclude pure DoS, or third-party library CVEs without an
      application-specific PoC) even if the underlying bug is real

## Proof of concept

- [ ] Have a concrete, minimal reproduction — not just a description of what *should*
      happen
- [ ] If a full PoC isn't achievable in your environment (no hardware, no production
      access), stated clearly what you could and couldn't demonstrate, and what
      would be needed to close that gap
- [ ] Removed any investigative noise from the writeup — the final report should
      walk a reader through the confirmed chain, not the full history of hypotheses
      that were explored and ruled out
