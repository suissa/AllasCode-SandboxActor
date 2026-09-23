# Security model

## Invariants

1. Sandbox-enabled native Action modules are never loaded into the privileged host Runtime.
2. The worker enables `PR_SET_NO_NEW_PRIVS` before Action code is loaded.
3. Landlock reduces filesystem rights monotonically.
4. The Action directory is read/execute only by default.
5. Writable temporary/state locations must be explicitly declared.
6. Process spawning is denied by default.
7. Memory and CPU have hard enforcement hooks.
8. Mandatory controls fail closed when unsupported.
9. A manifest requests rights; host policy remains authoritative.
10. Terminal `.Ok` belongs to the embedding Runtime and occurs only after its commit barrier.

## Recommended OS identities

```text
allascode-admin
  owns code/config and deploys

allascode-runtime
  orchestrates with project read access

allascode-action
  non-privileged worker identity
```

Prefer SSH keys and narrow sudo rules over direct password login.

## Why not dynamic chmod?

Changing global file modes per execution introduces shared mutable security state and race windows. SandboxActor keeps host permissions stable and creates a per-process kernel security domain instead.

## Native modules

A native `.so` loaded into the Runtime shares its address space, so filesystem restrictions cannot protect Runtime heap, secrets, stacks, or libraries. The worker-process boundary is therefore mandatory when sandboxing native modules.

## Network and seccomp

The manifest can request network allow-lists, but production enforcement must come from a configured network namespace/eBPF/cgroup network controller or equivalent. Unsupported requested enforcement must fail closed.

Seccomp is intended as a second syscall boundary generated from the Action execution class rather than one universal permissive profile.

## Healers

Sandbox healers too. CodeHealer should receive write access only to the intended `implementation.zig`; SystemHealer only to the intended config path.
