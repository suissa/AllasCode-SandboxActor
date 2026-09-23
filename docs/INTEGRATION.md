# Integration contract

SandboxActor can be embedded by any host Runtime.

## Direct versus sandboxed execution

```text
sandbox.enabled = false
  -> trusted host path may load directly

sandbox.enabled = true
  -> spawn non-privileged worker
  -> install host-authorized controls
  -> load module only inside worker
```

For AllasCode, the intended mapping is:

```text
Action
  -> Actor/SandboxActor
  -> Supervisor
  -> Action dynamic module
```

## Host responsibilities

The embedding Runtime remains responsible for:

- capability authorization;
- resolving manifest requests against a policy ceiling;
- creating/delegating cgroup v2 directories when strict CPU quota is required;
- installing a network allow-list enforcer when a manifest requests hosts;
- owning persistence/cache policy;
- emitting canonical terminal `.Ok/.Error` events;
- supplying semantic bounds generated from AtomicBehavior Types.

## Worker responsibilities

SandboxActor handles:

- no-new-privileges;
- filesystem allow-list via Landlock;
- baseline rlimits;
- optional cgroup v2 hard limits;
- syscall denials via seccomp;
- isolated dynamic-module loading;
- explicit zeroization helpers;
- resource budget primitives;
- commit-barrier primitive;
- equivalence-key primitive.

## Important ordering

Security controls are installed before untrusted Action code is loaded.

```text
manifest -> policy ceiling -> worker
  -> no_new_privs
  -> resource controls
  -> Landlock
  -> seccomp
  -> dlopen
  -> execute
```
