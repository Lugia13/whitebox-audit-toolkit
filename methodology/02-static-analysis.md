# 2. Static Analysis & Symbol Tracing

The core skill in a whitebox audit isn't finding a suspicious-looking line — it's
following a security-relevant symbol (a config flag, a validation function, a trust
boundary check) all the way from its declaration to the exact point where it's
consumed or enforced, across file and even language boundaries.

## Technique: grep-first, read-second

Before reading a module end-to-end, grep broadly for the vocabulary of the control
you're interested in:

```bash
grep -rn "downgrade\|rollback\|security_cnt\|anti.?rollback" --include="*.c" --include="*.h" .
grep -rn "verify\|authenticate\|trust" --include="*.rs" .
```

This surfaces every file that touches the concept, including ones you wouldn't have
guessed from directory names. If a tool like `ripgrep` (`rg`) isn't available in the
environment, fall back to `grep -rn` — functionally equivalent for this purpose, just
slower on very large trees.

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

## Common static-analysis mistakes

- **Stopping at the first layer.** Finding `CONFIG_FOO` unset doesn't tell you the
  security impact until you've traced what code path that actually disables.
- **Assuming a disabled feature is automatically a bug.** Many conditionally-compiled
  features fail closed by design; the interesting question is always "what's the
  fallback," not "is it off."
- **Treating `unsafe` or `.unwrap()` counts as findings by themselves.** They're a
  prioritization signal for where to look closer, not a conclusion.
