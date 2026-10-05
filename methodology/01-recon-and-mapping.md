# 1. Recon & Mapping

Before reading a single function, build an accurate picture of what you're actually
looking at. Skipping this step is the single biggest cause of wasted audit time —
it's easy to assume a repo name tells you what's inside it, and that assumption is
wrong often enough to matter.

## Goals of this phase

- Know every repository/crate/module in scope and its actual language/toolchain
- Know what's vendored, what's generated, and what's a thin wrapper vs. real logic
- Know the build system(s) in play before forming any hypothesis about configuration
- Catch scope surprises early (a repo that "should" contain X but doesn't yet, or
  a crate that's been renamed/moved since a pinned dependency reference was set)

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

## Common recon mistakes

- **Trusting a repo's name over its contents.** A "secure element" repo that turns out
  to be a thin host-side wrapper, or a crate that's been renamed since the version
  your target pins, are both normal and will mislead you if you don't check.
- **Reading HEAD when a pin exists.** This silently invalidates everything you find.
- **Skipping the "what's actually vendored here" question.** A lot of embedded repos
  pull their real security-critical logic (bootloader internals, crypto libraries)
  from an external, separately-versioned project. Know where the boundary is before
  you start tracing.
