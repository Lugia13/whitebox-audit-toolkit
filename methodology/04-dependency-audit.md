# 4. Dependency & Advisory Auditing

A fast, mechanical pass across a project's dependency tree can surface real findings
with much less manual effort than logic review — but it also produces a lot of noise,
and the noise needs to be triaged carefully before anything gets reported.

## Technique: use the standard tool, with a version-pinning fallback

```bash
cargo install cargo-audit --locked
```

In constrained environments, the latest `cargo-audit` release may require a newer
Rust toolchain than what's installed. Pin to an older compatible version rather than
giving up:

```bash
cargo install cargo-audit --locked --version 0.22.1
```

## Technique: build a standalone fallback when the tool isn't installable at all

When no compatible version installs (network restrictions, no matching toolchain,
sandboxed environment), the underlying data is still usable directly. The
[RustSec Advisory Database](https://github.com/RustSec/advisory-db) is just a folder
of TOML-frontmattered markdown files — it can be cloned and parsed standalone:

```bash
git clone --depth 1 https://github.com/RustSec/advisory-db.git
```

See `scripts/advisory_cross_reference.py` in this repo for a self-contained Python
implementation: it parses every advisory's TOML frontmatter, parses every `Cargo.lock`
in scope, and reports every (package, version, advisory) combination where the pinned
version isn't covered by a `patched` or `unaffected` range. No external dependencies
beyond the standard library's `tomllib` (Python 3.11+; falls back to `tomli` on older
versions).

## Technique: triage before reporting anything

Raw advisory-matcher output is **not** a findings list. In practice, most hits fall
into one of these buckets, and only one of them is usually worth pursuing further:

| Category | Action |
|---|---|
| "Unmaintained crate" notices | Not vulnerabilities — informational only, filter out |
| DoS-class (panic on malformed/oversized input) | Often explicitly excluded by bounty/engagement scope; low priority unless scope says otherwise |
| Memory-corruption / crypto-failure in a *reachable* code path | Worth pursuing — confirm reachability before writing up |
| Memory-corruption / crypto-failure in an *unreachable* code path (feature-gated out, dead code) | Not exploitable in this build; verify compilation gates before concluding either way |

The single highest-value step after an automated match is confirming **reachability**:
is the vulnerable function actually called, with attacker-influenced input, in the
build configuration that ships? A CVE in a dependency that's pinned but never invoked
on any attacker-reachable path is not a finding.

## Common dependency-audit mistakes

- **Treating a version-range match as proof of exploitability.** It's a lead, not a
  conclusion — go confirm the code path is reachable before spending more effort.
- **Including "unmaintained" notices in a findings list.** They're a different
  category (maintenance risk, not a vulnerability) and including them undermines the
  credibility of real findings in the same report.
- **Stopping at "patched version exists."** Also check whether the engagement/program
  scope even accepts third-party-library findings without an application-specific
  proof of concept — many do not.
