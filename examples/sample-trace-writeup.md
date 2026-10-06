# Sample Trace: Config Flag → Enforcement Code

This is a **generic, illustrative example** of the trace-to-ground-truth technique
described in `methodology/02-static-analysis.md` and `04-build-system-analysis.md`.
It does not describe any real codebase, program, or finding — it's a template for how
a trace like this should read.

---

## Question

Does `CONFIG_ANTI_ROLLBACK_PROTECTION` actually gate anything in the compiled
bootloader, or is it declared but never wired to real enforcement logic?

## Step 1 — locate the config declaration

```
bootloader/Kconfig:
    config ANTI_ROLLBACK_PROTECTION
        bool "Enable monotonic counter rollback protection"
        # no `default`, declared inside an `optional` choice block
```

Observation: this option has no default and belongs to an `optional` choice, meaning
if nothing explicitly selects it, it resolves to **unset**.

## Step 2 — check every config file that could set it

```bash
grep -rn "ANTI_ROLLBACK_PROTECTION" --include="*.conf" --include="*.overlay" .
```

Result: zero matches across base config, release overlay, board-specific overlays,
and CI build flags.

## Step 3 — confirm the macro translation layer

```
include/config_translate.h:
    #ifdef CONFIG_ANTI_ROLLBACK_PROTECTION
    #define ROLLBACK_PROT_ENABLED
    #endif
```

So `ROLLBACK_PROT_ENABLED` is only defined if the Kconfig option is set — and we've
already confirmed it isn't, anywhere in the public config tree.

## Step 4 — trace the macro to its actual consumer

```bash
grep -rn "ROLLBACK_PROT_ENABLED" --include="*.c" .
```

```
image_validate.c:
    #ifdef ROLLBACK_PROT_ENABLED
    case TLV_SECURITY_COUNTER:
        /* compare image counter against stored monotonic counter */
        ...
    #endif
```

This confirms the enforcement branch: it's not just unreachable in theory, it's a
specific `case` arm inside an image-validation TLV parser that **will not exist in
the compiled binary at all** when the flag is unset. There's no runtime fallback —
the counter TLV, if present in an image, is simply never inspected; execution falls
through to whatever the `default` arm of that switch does (in this example, silently
skipping unrecognized TLV types, which is correct behavior for forward-compatibility
but means the security counter is invisible to the validator).

## Step 5 — state confidence and caveats explicitly

- **Confirmed by source**: the Kconfig default state, the absence of any config file
  setting it, and the exact enforcement code that becomes unreachable as a result.
- **Not confirmed**: whether a private/internal build overlay outside the available
  repository sets this flag for production builds specifically. This should be
  stated as an open question, not silently assumed either way.
- **Not attempted**: building the actual firmware and testing against real hardware,
  since no device was available. The finding is reported as "confirmed at the source
  level" rather than "confirmed exploitable on production hardware" — these are
  different claims and should be labeled as such.

---

This is the shape a trace writeup should take regardless of the specific control
being examined: locate the declaration, check every place it could be set, follow
the translation layer, find the actual enforcement code, and state plainly what was
and wasn't verified.
