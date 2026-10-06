# 2. Trust Boundary Analysis

A trust boundary is any point where data or control crosses between two components that don't fully trust each other — different processes, different privilege levels, different physical devices, or different organizations' code. In a multi-repo ecosystem, most of the boundaries that matter are also *repo* boundaries, which makes them easy to under-audit: each side's maintainers may reasonably assume the other side enforces something neither actually does.

## For every boundary, characterize

- **Caller and callee** — which component initiates, which receives
- **Privilege level on each side** — e.g. unprivileged app vs. root daemon, Normal World vs. Secure World, cloud service vs. edge device
- **Authentication** — how does the receiving side know who's really calling? (Nothing? A shared secret? A platform-enforced identity like a kernel-verified UID? A cryptographic signature?)
- **Authorization** — even if identity is known, is the specific action actually checked against what that identity is allowed to do?
- **Serialization format** — protobuf, JSON, custom binary framing, etc. — and whether the format itself enforces any invariants (fixed lengths, required fields) or leaves that entirely to application code

## A concrete checklist to apply at each boundary

1. Find every function that is reachable *from* the boundary (e.g. every CAN/IPC message handler, every exposed RPC method).
2. For each, trace backward: what, if anything, validates the caller's identity or the message's integrity before this handler's logic executes?
3. Explicitly ask: **is there a sibling function at the same boundary that performs a check this one skips?** Inconsistency between parallel code paths (e.g. four message handlers, three of which validate a precondition and one of which doesn't) is one of the highest-signal patterns in this kind of audit — it's much rarer for a security check to be uniformly absent by design than for one path to have been overlooked.
4. Identify what sits *downstream* of this boundary that might independently catch a bypass — a second layer of validation, a cryptographic verification at a later stage, a hardware interlock. A bug that's fully absorbed by a downstream defense-in-depth layer is a real code defect but not necessarily a live vulnerability; say both, honestly.

## Multi-principal reasoning

Many ecosystems have *shared* backend components (a single service, a single secure-storage domain, a single Trusted Application) used by multiple, otherwise-unrelated front-end components. This is where authorization bugs hide best, because:

- Each front-end component's own code may be correct in isolation
- The shared component may have been written assuming a single trusted caller, then later reused by a second, differently-privileged caller without re-auditing the authorization model
- Reachability isn't about whether *a* caller exists — it's about whether *two distinct, differently-privileged* callers exist that the shared component fails to distinguish between

When evaluating this, trace every real caller you can find in source, and be explicit about whether you found:
- **Two or more distinct principals genuinely using the shared path today** (strong evidence)
- **Zero callers of the vulnerable path anywhere in accessible source** (this is a *negative* result — note it as such, don't call the finding "exploitable")
- **A plausible caller that must exist but lives outside your source access** (e.g. a private backend, a closed-source client) — this is an open gap, not a confirmed positive or negative. State it as exactly that.

## Output of this phase

A boundary-by-boundary table (caller, callee, privilege, auth, authz, format) plus, for each boundary, a short note on what downstream validation (if any) exists and what the honest reachability picture looks like.
