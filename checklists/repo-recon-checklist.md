# Repo Recon Checklist

Run through this before forming any hypothesis about where bugs might live.

## Mapping

- [ ] Shallow-cloned every in-scope repository
- [ ] Ran a depth-limited `find` on each repo to see real top-level structure
- [ ] Ran a file-extension histogram to confirm actual languages/formats in use
      (don't assume from the repo name)
- [ ] Read every README — noted any explicit statements about maturity
      ("doesn't compile yet", "stub", "deprecated", etc.)
- [ ] Identified which repos are primarily logic vs. primarily config/docs/build
      tooling around a much smaller logic surface

## Dependency pinning

- [ ] For every cross-repo dependency with a pinned revision (`rev =`, submodule
      pointer, lockfile hash), checked out that **exact** commit before analyzing it
- [ ] Verified the checkout actually succeeded and landed on the expected commit
      (`git rev-parse HEAD`) rather than trusting a pathspec-limited checkout silently
- [ ] Confirmed the pinned version's API/file layout before writing any code that
      assumes it matches current upstream HEAD

## Build system

- [ ] Identified every build system in play (CMake, Cargo, protobuf/codegen, etc.)
- [ ] Located every config file that could plausibly set a security-relevant flag:
      base config, build-type overlays, board/target overlays, CI pipeline flags
- [ ] Checked for references to private/internal/unavailable overlays and explicitly
      noted them as unknowns rather than assuming they don't change the outcome

## Trust boundaries

- [ ] Listed every place external/attacker-influenced input enters the system
      (network protocols, QR/barcode input, removable media, IPC, CAN/serial buses,
      file parsing)
- [ ] For each entry point, noted whether reaching it requires physical access,
      prior compromise, or privileged position — this determines reportability later,
      not just exploitability
- [ ] Identified which components are "trusted source" vs. which validate input from
      an untrusted or lower-privilege boundary
