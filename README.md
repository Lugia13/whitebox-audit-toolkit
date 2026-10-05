# Whitebox Audit Toolkit

A reusable methodology, checklist set, and tooling kit for conducting source-available
(whitebox) security audits of multi-repository codebases — covering embedded firmware,
Rust/C workspaces, build-system configuration, and dependency risk.

This repo documents **how I approach an audit**, not any specific target or finding.
Everything here is written to be dropped into a new engagement and adapted in minutes.

## Why this exists

Most writeups about security research focus on the punchline (the bug). This repo focuses
on the part that actually takes the time and determines whether an audit is any good:

- How to map an unfamiliar multi-repo codebase before touching a line of logic
- How to trace a security control from its configuration flag all the way to the code
  that enforces (or fails to enforce) it
- How to tell a real, exploitable finding apart from a plausible-looking dead end
- How to cross-reference dependency trees against vulnerability databases when the
  standard tooling isn't available
- How to evaluate a finding against program/engagement scope *before* spending a
  limited reporting budget on it

## Contents

```
.
├── methodology/
│   ├── 01-recon-and-mapping.md          # First-pass repo/codebase mapping
│   ├── 02-static-analysis.md            # Symbol tracing, config→code tracing
│   ├── 03-build-system-analysis.md      # Kconfig/CMake/build-flag resolution
│   ├── 04-dependency-audit.md           # CVE/advisory cross-referencing
│   └── 05-verification-discipline.md    # Hypothesis → verify → kill workflow
├── scripts/
│   └── advisory_cross_reference.py      # Standalone Cargo.lock ↔ advisory-db checker
├── checklists/
│   ├── repo-recon-checklist.md
│   └── finding-eligibility-checklist.md
└── examples/
    └── sample-trace-writeup.md          # Generic, sanitized example of a full trace
```

## Who this is for

- Security researchers doing source-review-based audits across unfamiliar codebases
- Anyone auditing embedded/firmware projects (Zephyr, mcuboot-style bootloaders, etc.)
  who wants a repeatable way to resolve "is this protection actually compiled in?"
- Engineers who want a lightweight, no-dependency way to cross-check a Rust workspace's
  `Cargo.lock` against known advisories without relying on `cargo-audit` being installable

## Philosophy

1. **Map before you read.** Understand what's actually in a repo (languages, build
   system, what's vendored vs. generated) before forming hypotheses about where bugs live.
2. **Trace to ground truth, not to a plausible-looking config file.** A flag that looks
   unset doesn't mean a protection is off — follow it all the way into the code that
   consumes it.
3. **Every hypothesis gets killed or confirmed, on evidence.** A finding that "looks like"
   a bug isn't a finding. Most promising leads turn out to be fine; that's a sign the
   process is working, not a wasted afternoon.
4. **Scope and eligibility are part of the technical work.** A perfectly real bug that
   falls outside an engagement's threat model isn't ready to report — checking that
   *before* writing up a finding saves everyone's time.
5. **State your confidence level honestly.** "Confirmed by reading the enforcement code"
   and "confirmed by observing it on real hardware" are different claims. Say which one
   you've actually made.

## About

Built from real audit work across embedded firmware, Rust application code, and protocol
libraries. See [oussamasaddati.vercel.app](https://oussamasaddati.vercel.app) for more.
