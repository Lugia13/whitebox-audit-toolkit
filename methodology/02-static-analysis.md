# 2. Static Analysis & Symbol Tracing

The core skill in a whitebox audit isn't finding a suspicious-looking line — it's
following a security-relevant symbol (a config flag, a validation function, a trust
boundary check) all the way from its declaration to the exact point where it's
consumed or enforced, across file, module, and even repo boundaries.

## Technique: grep-first, read-second, in priority order

Before reading a module end-to-end, grep broadly for the vocabulary of the controls
that matter most, roughly in this order:

- **Authentication/authorization**: `verify`, `authenticate`, `authoriz`, `challenge`,
  `nonce`, `signature`, `attest`, `capability`
- **Trust/update chain**: `boot`, `manifest`, `rollback`, `security_cnt`, `update`,
  `firmware`, `downgrade`
- **Memory/parsing**: `unsafe`, `deserialize`, `decode`, `memcpy`, `sizeof`
- **IPC/message boundaries**: `ipc`, plus the project's own message/command dispatch
  keywords — these vary per codebase, so find the dispatch table first, then search
  for how entries are added to it

```bash
grep -rn "downgrade\|rollback\|security_cnt\|anti.?rollback" --include="*.c" --include="*.h" .
grep -rEl "verify|signature|attest|rollback|manifest|nonce|authoriz|authenticat" --include="*.rs" --include="*.c" .
```

This surfaces every file that touches the concept, including ones you wouldn't have
guessed from directory names. If a tool like `ripgrep` (`rg`) isn't available in the
environment, fall back to `grep -rn` — functionally equivalent for this purpose, just
slower on very large trees. A keyword hit is a starting point for *where to look
first* — it is never, by itself, a finding.

## Technique: cross-layer symbol tracing

Security controls in layered systems (Kconfig → preprocessor macro → runtime check;
or protobuf schema → generated code → application logic) require tracing *through*
each layer, not just reading the layer you started in. A flag can exist, be documented,
and still never actually gate anything if the wiring between layers is broken or
incomplete.

Worked pattern:

1. Find the human-facing config option (`CONFIG_FOO=y` in a `.conf`/`Kconfig` file).
2. Find where it's translated into a preprocessor symbol (`#ifdef CONFIG_FOO` →
   `#define FOO_ENABLED`).
3. Find every place `FOO_ENABLED` (not `CONFIG_FOO`) is actually tested in logic —
   these are often in a *different* source file, sometimes in a different repository
   entirely (e.g. a vendored upstream library).
4. Confirm what happens on **both branches** of that `#ifdef`/`if` — not just "is the
   feature off" but "what is the actual fallback behavior when it's off." A feature
   being disabled is not automatically a vulnerability; what matters is whether the
   disabled path fails open (silently skips a check) or fails closed (rejects safely).

```bash
# Step 1-2: find the symbol in config and its macro translation
grep -rn "CONFIG_FOO" --include="Kconfig*" --include="*.conf" .
grep -rn "define FOO_ENABLED" .

# Step 3: find where it's actually tested in logic (often a different repo/file)
grep -rn "ifdef FOO_ENABLED\|ifndef FOO_ENABLED" .
```

## Technique: bounds-safety and panic-surface review (Rust)

For Rust code specifically, a fast triage pass before deep logic review:

```bash
# Inventory of unsafe blocks — not inherently bad, but each one deserves a look
grep -rn "unsafe" src/ --include="*.rs"

# Panic-prone indexing vs. bounds-checked access patterns
grep -rn "\.unwrap()\|\[0\.\." src/ --include="*.rs"
```

Prefer code using `.get()`/`.get(a..b)` (returns `Option`, no panic) over direct slice
indexing when reviewing parsers that handle externally-controlled input. A single
`.unwrap()` following a length check elsewhere in the function is usually fine — the
goal of this pass is to find `.unwrap()` calls with *no* preceding validation.

## Reading discipline once a hit is found

1. **Read the whole function, not the matched line.** Keyword matches are an index,
   not a diagnosis.
2. **Read every doc comment for the function and compare it to what the code actually
   does.** A documented contract ("returns error if X") that the implementation
   doesn't actually deliver is one of the strongest and most defensible bug patterns
   to report — you're not asserting your own opinion of correct behavior, you're
   pointing out the code doesn't do what its own author said it does.
3. **Check the sibling functions.** If this is one of N similar handlers/validators,
   read all N and diff their logic mentally. Asymmetry is signal.
4. **Trace both forward and backward.** Forward: what does this function actually
   gate/protect? Backward: what calls it, and does the caller already filter out the
   cases that would make this function's gap matter?
5. **Don't stop at the first repo.** If the function's effect (e.g. a flag, a state
   transition) is consumed by a *different* repo or component, go read that too
   before judging impact.

## Avoiding false signal

- **Stopping at the first layer.** Finding `CONFIG_FOO` unset doesn't tell you the
  security impact until you've traced what code path that actually disables.
- **Assuming a disabled feature is automatically a bug.** Many conditionally-compiled
  features fail closed by design; the interesting question is always "what's the
  fallback," not "is it off."
- **Treating `unsafe`/`.unwrap()`/keyword-hit counts as findings by themselves.**
  They're a prioritization signal for where to look closer, not a conclusion. Most
  hits, in a mature codebase, are fine.
- **Auditing vendored code first.** Third-party code (clearly marked license headers
  from upstream projects) is usually lower-value to audit directly — it's typically
  already heavily reviewed, and a program will often (reasonably) decline reports
  against upstream dependencies rather than the program's own integration code.
  Identify it early and deprioritize it in favor of the project's own glue/integration
  code, which is far more likely to contain novel, in-scope defects.
- **Not tracking what you ruled out.** Track what you've checked and *why* it's fine,
  not just what you found. A clean audit trail of "checked X, here's why it's fine" is
  what lets you (or a reviewer) trust the final list of things you *didn't* rule out.

## Output of this phase

A short list of specific functions worth deep verification, each with a one-line note
on why it was flagged and what's already been ruled out about it.
