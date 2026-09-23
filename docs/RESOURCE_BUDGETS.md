# Deterministic Action Resource Budgets

SandboxActor treats resource usage as an execution contract, not only telemetry.

## Semantic bounds

Every Semantic AtomicBehavior Type should expose enough information to construct its maximum-valid representation, for example:

```yaml
type: CustomerName
primitive: string
constraints:
  min_chars: 1
  max_chars: 120
  max_bytes: 480
  encoding: utf8
```

Useful bounds include `max_chars`, `max_bytes`, `max_items`, `max_depth`, `max_properties`, `max_digits`, and `max_scale`.

The Gateway should reject values above those limits before Action state is allocated.

## Generated boundary tests

Generate at least:

```text
min - 1
min
min + 1
max - 1
max
max + 1
wrong primitive type
invalid encoding
invalid structure
MaximumValidPayload
```

`MaximumValidPayload` sets all Action inputs simultaneously to their largest valid representations.

## Budget schema

```yaml
budget:
  input:
    max_bytes: 8192

  memory:
    benchmark: MaximumValidPayload
    measured_peak: 18.4MiB
    offset_percent: 20
    max: 22.08MiB

  cpu:
    benchmark: MaximumValidPayload
    measured_cpu_time: 1.82ms
    offset_percent: 25
    max_cpu_time: 2.275ms

  wall:
    timeout: 10ms

  output:
    max_bytes: 4096

  serialization:
    max_bytes: 16384
    required_before_ok: true

  zeroization:
    required: true
    max_time: 100us

benchmark:
  hardware_profile: allascode-vps-v1
  runtime_version: 0.1.0
  compiler: zig-0.16
  optimization: ReleaseFast
  runs: 10000
```

## Memory planning

Prefer instrumented arenas or fixed buffers for transient Action memory and record:

```text
current_bytes
peak_bytes
allocation_count
free_count
zeroization_bytes
```

A useful envelope is:

```text
base worker
+ maximum input representation
+ Action arena peak
+ serialization peak
+ maximum output
+ safety offset
```

## Commit barrier

Terminal success must be:

```text
execute
  -> serialize required Agent memory
  -> validate
  -> persist/cache required state
  -> COMMIT BARRIER
  -> emit .Ok
  -> zeroize transient arena
  -> release
```

If commit fails, terminal authority remains `.Error`.

## Equivalence keys

In 2flow:

```text
[val1, val2, val3] -> result
```

means OR-equivalence. Multiple inputs map to one canonical result.

Storage may use:

```text
hash(val1) --\
hash(val2) ----> group_id -> result
hash(val3) --/
```

Prefer normalization, ranges, compact finite-state structures, or perfect hashing when they avoid duplicate mappings.
