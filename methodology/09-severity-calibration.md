# 7. Severity Calibration

The gap between "this is a real code defect" and "this is a Critical-severity, bounty-worthy vulnerability" is usually the single most important judgment call in a report, and it's where overclaiming does the most damage to a researcher's credibility.

## Questions to answer honestly before assigning severity

1. **Is there a downstream layer that independently catches this?** A bug that's fully absorbed by a separate, independently-functioning validation step (a second cryptographic check, a hardware interlock, a cross-checking service) has much lower real-world severity than the same code defect with nothing downstream — even though the code defect itself is identical. Trace downstream before scoring.
2. **Who can actually trigger this, and what do they need first?** "Reachable by anyone with zero interaction" and "reachable only after first achieving code execution inside an already-sandboxed low-privilege component" are wildly different severities, even for an identical underlying bug. Be precise about preconditions.
3. **Is the affected data/action actually sensitive, or incidental?** Leaking a key's *name* is not the same as leaking its *value*. Triggering a state flag that's independently re-validated before use is not the same as triggering an action with no further checks.
4. **Could this plausibly be intentional design rather than a bug?** Especially for things like recovery/bootstrap paths that intentionally bypass normal checks (e.g. a field-service reset mechanism designed to work without network connectivity). If a defensible design rationale exists, say so in the report rather than letting the reviewer find it themselves — it builds trust and doesn't meaningfully weaken a report that's genuinely still worth raising.
5. **What's the actual realistic attacker, not the maximally scary one?** A bug that requires physical proximity, a specific hardware revision, and a non-default configuration flag is real and worth reporting, but its severity should reflect those real preconditions, not the theoretical maximum if all constraints were removed.

## A practical severity-notes template

For each candidate finding, write out (even just for yourself, before deciding whether/how to report):

- **Mechanism**: the exact code-level defect, in one or two sentences
- **Preconditions**: everything an attacker needs before this is triggerable
- **Downstream mitigations checked**: what you looked at that *could* have absorbed this, and whether it does
- **Confirmed reachability tier**: per `06-verification-discipline.md` (confirmed / confirmed-negative / open gap)
- **Realistic worst case**: stated plainly, without inflating
- **What would change this assessment**: the specific fact that, if learned, would move severity up or down

## Why this discipline protects reputation, not just correctness

Programs and triagers see far more overclaimed reports than underclaimed ones. A track record of findings that are precisely scoped — including the ones you flag as lower-severity than your first instinct suggested — is what earns a researcher's future reports faster, more trusting review. Downgrading your own finding after honest additional verification is not a loss; it's the deliverable working as intended.
