<img width="1586" height="992" alt="file_00000000b1c0820eb1e9ade2739c55f2" src="https://github.com/user-attachments/assets/d99df826-9acc-43f3-b459-8e851b4cadbb" />


# AllasCode SandboxActor

Sandboxed Action execution for AllasCode with filesystem, process, network, memory, CPU, and capability isolation.

SandboxActor is a lightweight Linux execution layer for untrusted or semi-trusted Action modules. It is usable by any project while keeping a fast path optimized for Zig dynamic modules.

## Execution model

```text
Runtime
  -> reads Action manifest
  -> validates requested policy against host policy
  -> spawns SandboxActor worker
      -> PR_SET_NO_NEW_PRIVS
      -> rlimits / cgroup v2
      -> Landlock filesystem domain
      -> network policy hook
      -> seccomp hook
      -> dlopen(Action module)
      -> execute
      -> serialize required state
      -> commit barrier
      -> Ok/Error
      -> zeroize transient memory
      -> exit
```

A sandboxed native module is never loaded into the privileged Runtime address space.

## Canonical manifest

```yaml
action:
  name: Payment.CreatePix

runtime:
  module: ./implementation.so

sandbox:
  enabled: true
  scope: action

  filesystem:
    self:
      read: true
      execute: true
    tmp:
      write: true

  process:
    spawn: false

  network:
    allow:
      - api.bank.com

  memory:
    max: 64MiB

  cpu:
    max: 100m
```

## Security principles

- stable host ownership/permissions; no per-execution chmod races;
- per-worker Landlock domain;
- no-new-privileges before Action code is loaded;
- native modules execute in a separate worker process;
- read-only Action tree by default;
- explicit writable tmp/state only;
- memory/CPU resource budgets;
- fail closed when a mandatory enforcement primitive is unavailable;
- manifests request capabilities; host policy grants them.

## Semantic bounds and budgets

The maximum-valid payload must be derivable from Semantic AtomicBehavior Type constraints such as `max_chars`, `max_bytes`, `max_items`, `max_depth`, `max_digits`, and `max_scale`.

Generated tests should include `min-1`, `min`, `min+1`, `max-1`, `max`, `max+1`, wrong primitive type, invalid encoding, invalid structure, and an Action-level `MaximumValidPayload` case.

See [Resource Budgets](docs/RESOURCE_BUDGETS.md).

## Dynamic module ABI

```c
int allascode_action_execute(
    const unsigned char *input_ptr,
    size_t input_len,
    unsigned char **output_ptr,
    size_t *output_len
);

void allascode_action_free(unsigned char *ptr, size_t len);
```

## Build

Linux + Zig 0.16+:

```bash
zig build
zig build test
```

The implementation intentionally uses kernel primitives rather than Docker or microVMs.
