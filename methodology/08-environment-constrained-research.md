# 6. Working Honestly Within Environment Constraints

Real research environments are almost never fully equipped for every target. Embedded/IoT ecosystems in particular routinely require vendor SDKs, hardware-specific client libraries, and cross-compilation toolchains that aren't available on a generic research machine. The goal isn't to avoid this reality — it's to recognize it quickly, diagnose it precisely, and adapt the verification strategy instead of either stalling or quietly drawing conclusions from a broken build.

## Fast pre-flight checks before attempting a real build

```bash
# Is a required system library actually present?
pkg-config --exists <library> && echo OK || echo MISSING

# Does a given crate/dependency even attempt to build here, independent
# of the rest of the workspace? (isolates the blocker fast)
mkdir -p /tmp/check/src && cd /tmp/check
cat > Cargo.toml <<EOF
[package]
name = "check"
version = "0.1.0"
edition = "2021"
[dependencies]
<suspect-crate> = "*"
EOF
echo 'fn main() {}' > src/main.rs
cargo build 2>&1 | tail -40
```

Reading the *actual* build-script failure (not just "it didn't build") usually tells you immediately whether the blocker is:
- a missing system package (fixable — install it)
- a missing vendor SDK / hardware client library tied to an environment variable (e.g. a build script that panics on a specific unset env var) — this is a hard blocker that no amount of package installation fixes, and is worth stating plainly rather than fighting
- a genuine code issue (interesting on its own)

## When a full build is genuinely not achievable

- **Say so precisely**, including the specific error, not a vague "couldn't get it working."
- **Fall back to the extracted-logic harness pattern** (see `07-extracted-logic-harness-pattern.md`) for the specific logic you need to verify, if it's pure enough to isolate.
- **Use reference-only clones of adjacent public repos** to answer factual questions you can't otherwise close (e.g. "does any production caller actually invoke this function?") — this is legitimate and often sufficient, but keep clear in your own notes (and in any eventual report) which repos were in-scope targets versus read-only reference material used to answer a specific question.
- **Be explicit about what would close the gap** (a specific toolchain, a specific piece of hardware, access to a specific private repo) rather than leaving it vague — this is actionable information for whoever picks up the work next, including yourself later.

## Memory and resource awareness

Heavy native builds (large dependency trees, LTO, parallel compilation) can exhaust memory on a constrained research VM, causing swapping or OOM kills that look like mysterious hangs. Check available memory before kicking off a large build, and understand that a "stuck" build may actually be a slow, legitimate compile of a large dependency tree rather than a hang — give it a real diagnostic pass (check CPU/memory usage, don't just assume and kill it, but also don't wait indefinitely without checking) before deciding it's broken.

```bash
free -h
```

## Output of this phase

For each target that couldn't be fully built/run: a one-line, specific note on exactly what was missing and why, plus whatever alternative verification (harness, reference-repo cross-check) was used instead.
