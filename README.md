# Whitebox Audit Toolkit

A structured, reproducible methodology for source-available ("whitebox") security
audits of embedded firmware and Rust/C codebases including targets that span
**multiple interdependent repositories**, common in embedded systems and IoT device
ecosystems where a single trust boundary (a hardware root of trust, a device-to-cloud
protocol) is implemented across several separately maintained codebases.

Developed and refined during hands-on bug bounty research across mixed Rust/C/
embedded firmware ecosystems: application logic, TEE-style Trusted Applications,
RTOS firmware with secure-boot-style bootloaders, and shared wire-protocol
definition crates.

**This repository documents methodology, tooling, and reusable scripts only.** No
vulnerability details, target names, or specific findings from any engagement are
included those remain subject to each program's responsible disclosure process.

Portfolio: [oussamasaddati.vercel.app](https://oussamasaddati.vercel.app)

## Why this methodology exists

Most security research guidance assumes a single codebase. Real-world hardware/IoT
products rarely look like that: a device's actual security boundary is usually split
across a main application repo, a secure-element/TEE repo, a firmware repo, and one
or more shared protocol-definition repos each independently versioned, each with
its own build constraints, and each individually "fine" when read in isolation.

The interesting bugs live in the *seams* places where one side assumes an invariant
the other side doesn't actually guarantee, or where a layered control (Kconfig →
macro → runtime check) looks complete at one layer but isn't actually wired through.
This methodology is built around making those seams explicit and verifiable, rather
than reviewing each repo, or each layer, as an island.

## Core principles

1. **Map before you hunt.** Build the full crate/dependency/trust-boundary graph
   before reading any single function closely. You cannot judge whether a check is
   missing until you know what's supposed to call what.
2. **Every claim gets a confidence label.** A finding is either (a) confirmed by
   reading the code, (b) confirmed by compiling and running a faithful reproduction,
   (c) a confirmed negative (searched exhaustively, found nothing), or (d) a
   plausible hypothesis with an explicit, named gap. Mixing these up is how
   low-quality reports happen.
3. **A "no callers found" result is only as strong as your search was exhaustive.**
   Distinguish a *proven negative* from an *unproven gap* (the likely caller lives in
   code you don't have access to, e.g. a private backend or closed-source client).
4. **Respect environment constraints instead of fighting them.** If a target requires
   a vendor SDK or hardware toolchain you don't have, say so precisely and adapt the
   verification strategy — don't half-build something and draw conclusions from a
   failure that had nothing to do with the code.
5. **Extract, don't assume.** When you can't run the real system, build a minimal,
   verbatim-logic harness that isolates just the function(s) in question. A compiled,
   executed PoC with deterministic output is categorically stronger evidence than
   "I read it carefully and I'm pretty sure."
6. **Downgrade your own findings before anyone else has to.** Actively look for the
   defense-in-depth layer that might absorb your bug, the config flag that might make
   it unreachable, the caller that might not exist. Report the honest residual risk,
   not the scariest initial read.

## Repository structure

```
methodology/
  01-recon-and-mapping.md            - structural recon + cross-repo dependency mapping
  02-static-analysis.md              - keyword triage, cross-layer symbol tracing, reading discipline
  03-trust-boundary-analysis.md      - identifying and characterizing cross-repo/cross-privilege boundaries
  04-build-system-analysis.md        - Kconfig/CMake/Cargo feature-flag tracing
  05-dependency-audit.md             - Cargo.lock / RustSec advisory cross-referencing
  06-verification-discipline.md      - the four confidence tiers; falsification discipline
  07-extracted-logic-harness-pattern.md - proving logic claims without the full system
  08-environment-constrained-research.md - working around missing toolchains/SDKs/hardware honestly
  09-severity-calibration.md         - avoiding both over- and under-claiming impact

checklists/
  repo-recon-checklist.md            - recon-phase checklist
  finding-eligibility-checklist.md   - scope/eligibility checklist before write-up

examples/
  sample-trace-writeup.md            - illustrative, fictional cross-layer trace write-up

scripts/
  advisory_cross_reference.py        - cross-reference a Cargo.lock against a RustSec-style advisory DB
  repo_structure_map.sh              - crate/workspace/build-file enumeration
  security_keyword_scan.sh           - prioritized, categorized keyword sweep
  unsafe_ffi_scan.sh                 - unsafe blocks / FFI boundaries (Rust + C)
  build_feasibility_check.sh         - pre-flight dependency/toolchain check before attempting a build
  extracted-logic-harness-template/  - minimal cargo project template for isolated logic PoCs
```

## Tooling used

Command-line only, no GUI tools: `git`, `ripgrep`/`grep`, `cargo`, `rustc`,
`gcc`/`clang`, `readelf`, `objdump`, `nm`, `strings`, `radare2`, `gdb`, `pkg-config`,
`jq`, `curl`, `python3`.

## Scope and limitations

This methodology assumes read access to source code (public repos, or repos you're
authorized to audit) and a general-purpose Linux research environment. It does
**not** assume:
- Physical access to target hardware (several techniques here exist specifically to
  substitute for that, via faithful extracted-logic reproduction)
- A full cross-compilation toolchain for every target architecture (the methodology
  includes an explicit workflow for recognizing and working around this rather than
  stalling)

## Skills demonstrated

- Cross-repository trust-boundary analysis in multi-principal embedded/IoT ecosystems
- Cross-layer symbol tracing (Kconfig → macro → runtime check) in C and Rust
- RustSec advisory cross-referencing and dependency auditing
- Execution-based claim verification via extracted-logic harnesses, when the real
  target can't be run directly
- Calibrated, defensible severity assessment and confidence-tiered reporting

## License

MIT — see [LICENSE](./LICENSE). Provided for educational and authorized security
testing purposes only.

---

*This repo is a methodology/tooling reference built from real engagement work. It
intentionally contains no vulnerability details — see the relevant program's
disclosure policy for anything related to a specific engagement.*
