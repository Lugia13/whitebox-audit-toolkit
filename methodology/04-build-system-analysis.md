# 3. Build-System Analysis

In embedded and multi-target codebases, whether a security control actually ships is
often a build-system question, not a code question. A protection can exist, be
correctly implemented, and still never be compiled into the artifact that reaches
production — because of how config files are merged, which build type is selected,
or what a CI pipeline actually passes on the command line.

This is one of the easiest places to get a false result in either direction:
concluding a protection is missing when a build-type overlay actually adds it back
in, or concluding it's present when it's only wired up for a debug/test target.

## Technique: find every place configuration can be set, not just the obvious one

For a single logical "is this feature on" question, there are often multiple
candidate sources of truth, and they can conflict or override each other:

- Base config file (`prj.conf`, a default `Kconfig` value)
- Build-type overlay (`release.conf`, `debug.conf` — only merged in under specific
  `CMAKE_BUILD_TYPE` or equivalent conditions)
- Board/target-specific overlay
- CI pipeline command-line flags (`-D` flags passed at build invocation)
- A private/internal overlay not present in the public repo (common in commercial
  embedded projects) — if one exists, explicitly flag it as an unknown rather than
  assuming it does or doesn't change the outcome

```bash
grep -rn "CONFIG_FEATURE_FLAG" \
  --include="*.conf" --include="Kconfig*" --include="*.overlay" \
  --include="CMakeLists.txt" --include="*.yml" .
```

## Technique: verify conditional config-file inclusion, don't assume it

A build-type overlay file existing on disk does **not** mean it's actually included
in a given build. Check the literal logic that decides when it's pulled in:

```bash
grep -n "release.conf\|EXTRA_CONF_FILE\|OVERLAY_CONFIG\|CMAKE_BUILD_TYPE" CMakeLists.txt
```

Common patterns to verify explicitly:
- `if (CMAKE_BUILD_TYPE STREQUAL "Release") list(APPEND EXTRA_CONF_FILE "release.conf")`
  — only wired in for one specific build type string, case-sensitive
- Naming convention mismatches — some build systems only auto-merge a file if it's
  named exactly `prj_<buildtype>.conf`; a similarly-named `release.conf` sitting next
  to it may need explicit wiring and silently won't be picked up otherwise
- CI scripts that pass `-DCMAKE_BUILD_TYPE=Release` but never reference the project's
  own overlay mechanism at all, relying on a different mechanism entirely

## Technique: reproduce the config resolution directly when possible

The most reliable way to settle a "does this ship enabled" question is to actually
run the build system's config-resolution step (which usually happens before full
compilation, so it doesn't require a working toolchain for every dependency) and
inspect the merged output:

```bash
# Zephyr/west example: this fails fast at the Kconfig resolution stage even without
# a full SDK, and the resolved .config file written before failure is still useful
west build project -d /tmp/build -b target-board -- -DCMAKE_BUILD_TYPE=Release
grep "CONFIG_FEATURE_FLAG" /tmp/build/zephyr/.config
```

When a full build environment isn't available, be explicit in any writeup that the
conclusion is based on source-level tracing of the build logic, not an observed
resolved configuration — these are different strengths of evidence.

## Common build-system mistakes

- **Reading only the base config file and stopping.** Overlays and CI flags can
  change the outcome in either direction.
- **Assuming a file's existence means it's used.** Always verify the trigger
  condition in the actual build script logic.
- **Not flagging unknown private/internal overlays.** If a build references
  something outside your visibility, say so explicitly rather than letting the
  analysis silently assume it doesn't matter.
