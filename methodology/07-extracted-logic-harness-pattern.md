# 5. The Extracted-Logic Harness Pattern

A recurring, high-value technique: when you cannot run the real target (no hardware, no vendor toolchain, no network access to a live service), you can still get execution-based confidence by building a minimal, honest reproduction of just the logic you're testing.

## When to use this

- The logic under test is pure (no hardware I/O, no OS-specific syscalls) even if it's embedded inside a larger system that does require those things
- You can identify the *exact* function signatures, struct shapes, and algorithm steps from source
- A full build of the real target is blocked by something unrelated to the logic itself (missing system libraries, missing cross-compilation toolchain, missing vendor SDK)

## Construction steps

1. **Create an isolated project.** A throwaway `cargo new` / minimal `gcc`-compiled C file, with only the dependencies the specific logic actually needs (e.g. just a hashing crate, not the whole workspace).
2. **Copy the algorithm verbatim.** Don't paraphrase or "improve" the logic — the whole point is that the harness proves something about the *actual* code, not about your mental model of it.
3. **Mock only what's unavoidable**, and mock it to the *documented* contract, not to whatever's convenient. If the real function is supposed to write exactly N bytes, the mock should write exactly N bytes — the goal is to surface what happens when the *calling* code's assumptions are wrong, not to prove something about your mock.
4. **Instrument for a clear verdict.** Use explicit before/after state comparison, canary values, or deterministic counters — something a reader can verify from the printed output without re-deriving your reasoning.
5. **Run it more than once if there's any possibility of a probabilistic or environment-dependent result**, and report the actual success rate, not just "it worked."

## Worked pattern (illustrative, generic)

```rust
// Step 1: verbatim struct/logic extracted from source
struct Target { /* exact fields */ }
impl Target {
    fn suspect_function(&self, input: &[u8]) -> bool {
        // exact logic copied from the real implementation
    }
}

fn main() {
    // Step 2: construct the exact adversarial input your analysis predicts
    // breaks the invariant
    let crafted_input = /* ... */;

    // Step 3: instrumented, falsifiable assertion
    let result = Target { /* ... */ }.suspect_function(&crafted_input);
    assert!(result, "expected the invariant to break under this input");
    println!("CONFIRMED: invariant broken as predicted");
}
```

## What this pattern does and doesn't prove

**Does prove:** that the specific logic, as extracted, behaves the way your static analysis predicted — removing the risk that you misread control flow, operator precedence, or a subtle type coercion.

**Does not prove:** that the real, full system is reachable this way in production — that's a separate question (see `03-trust-boundary-analysis.md` and `06-verification-discipline.md`). A harness proves the *mechanism*; it does not by itself prove *reachability* or *real-world impact*. State both halves separately in any write-up.

## Minimal template

See `scripts/extracted-logic-harness-template/` for a ready-to-copy Cargo project skeleton with the instrumentation pattern (canary values, deterministic pass/fail output) pre-wired.
