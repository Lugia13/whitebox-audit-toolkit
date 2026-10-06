# 1. Recon & Mapping

Before reading a single function, build an accurate picture of what you're actually
looking at. Skipping this step is the single biggest cause of wasted audit time —
it's easy to assume a repo name tells you what's inside it, and that assumption is
wrong often enough to matter. This matters doubly when the target spans more than
one repository: most of the boundaries that matter later are also repo boundaries.

## Goals of this phase

- Know every repository/crate/module in scope and its actual language/toolchain
- Know what's vendored, what's generated, and what's a thin wrapper vs. real logic
- Know the build system(s) in play before forming any hypothesis about configuration
- Catch scope surprises early (a repo that "should" contain X but doesn't yet, or
  a crate that's been renamed/moved since a pinned dependency reference was set)
- For multi-repo targets, know which repos depend on which others, at what pinned
  revision, and which specific types/functions each dependency edge actually uses

## Technique: shallow clone everything first

```bash
mkdir -p ~/audit && cd ~/audit
for repo in repo-a repo-b repo-c; do
  git clone --depth 1 https://github.com/ORG/$repo.git
done
```

Shallow clones are enough for recon. Only go deeper (`git fetch` a specific commit,
or a full clone) once you need history or a specific pinned revision.

## Technique: structural fingerprinting before reading code

```bash
# Tree, 2-3 levels deep, skip VCS internals
find REPO -maxdepth 3 -not -path '*/.git*' | sort

# What languages/formats actually make up this repo?
find REPO -type f -not -path '*/.git*' | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15

# Every build manifest in the tree, with content inline
find REPO -name "Cargo.toml" -o -name "CMakeLists.txt" | xargs -I{} sh -c 'echo "--- {} ---"; cat {}'

# Read the README before anything else — it tells you the actual maturity/state
find REPO -maxdepth 1 -iname 'readme*' -exec cat {} \;
```

A repo's name and description can be stale or aspirational. Extension histograms and
the README itself are cheap, fast ground truth. Watch specifically for:

- READMEs that say a component "doesn't compile yet" or is a stub
- A repo that's mostly config/docs/build scripts around a much smaller amount of logic
- Multiple build systems in one repo (e.g. CMake + Cargo + protobuf codegen) — each
  one is a separate thing to understand before you can reason about what ships

## Technique: pin-aware dependency resolution

When Repo A depends on Repo B at a specific commit (a `rev =` in `Cargo.toml`, a SHA
in a manifest, a submodule pointer), **do not analyze Repo B's current HEAD.** APIs,
file layouts, and security logic all drift. Always check out the exact pinned commit:

```bash
cd repo-b
git log --oneline -1          # confirm current HEAD, for contrast
git checkout <pinned-sha>      # full checkout, not a pathspec-limited one
git rev-parse HEAD             # verify you actually landed where you think you did
```

A `git checkout <sha> -- path/` (pathspec-limited checkout) will silently do nothing
if that path didn't exist at that commit under that name — it fails without clearly
telling you why unless you check the exit status. Prefer a full `git checkout <sha>`
and then look at what's actually there.

## Technique: what to extract, per repository

For each in-scope repository, beyond the structural fingerprint above:

- **Binaries vs. libraries.** Which crates/modules produce an executable/service vs.
  a library consumed elsewhere. Libraries meant for external consumption — especially
  *shared protocol-definition crates* — deserve extra scrutiny: they're often relied
  on by code you can't see.
- **FFI boundaries.** `extern "C"`, `#[no_mangle]`, `unsafe` blocks, `bindgen`-generated
  bindings. These are where memory-safety guarantees from one language stop applying.
- **IPC/message interfaces.** Anything serialized and sent between processes or
  devices — protobuf/prost definitions, D-Bus interfaces, CAN/UART framing, HTTP APIs.
  These define your actual attack surface far more than internal function calls do.

```bash
# Unsafe/FFI surface at a glance
grep -rn "unsafe" --include="*.rs" . | wc -l
grep -rln 'extern "C"\|#\[no_mangle\]\|bindgen' --include="*.rs" .
```

## Building the cross-repo picture

For each pinned external dependency, note which repo it comes from, at what revision,
and — critically — which of *that* repo's types/functions this repo actually uses
(not the whole API surface). This turns into a simple table that becomes the backbone
of trust-boundary analysis (see `03-trust-boundary-analysis.md`):

| This repo | Depends on | At revision | Uses |
|---|---|---|---|
| service-a | shared-protocol | `abc123` | `AuthenticatedPayload::verify()` |
| service-b | shared-protocol | `abc123` | `AuthenticatedPayload::hash()`, `::verify()` |

A dependency used by **two or more** otherwise-unrelated services is a strong signal:
it's exactly the kind of shared code where an inconsistency between how each side
uses it can turn into a real cross-principal vulnerability, independent of either
service's own code being individually correct.

## Common recon mistakes

- **Trusting a repo's name over its contents.** A "secure element" repo that turns out
  to be a thin host-side wrapper, or a crate that's been renamed since the version
  your target pins, are both normal and will mislead you if you don't check.
- **Reading HEAD when a pin exists.** This silently invalidates everything you find.
- **Skipping the "what's actually vendored here" question.** A lot of embedded repos
  pull their real security-critical logic (bootloader internals, crypto libraries)
  from an external, separately-versioned project. Know where the boundary is before
  you start tracing.

## Output of this phase

A short per-repository summary (purpose, crates/binaries, entry points, external
pins) and, for multi-repo targets, a cross-repo dependency table. Do not start
reading security logic until this exists — it's what lets you recognize, later,
when something is a self-contained bug vs. a trust-boundary bug that spans repos.
