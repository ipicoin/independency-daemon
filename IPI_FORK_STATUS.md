# IPI fork status and provenance

- Upstream: [`CosmWasm/wasmd`](https://github.com/CosmWasm/wasmd)
- Fork relationship: GitHub-native public fork
- Upstream license: Apache License 2.0
- IPI-specific changes: provenance documentation and fork-safe CI permissions;
  no consensus or application changes
- IPI maturity: research base, not a released node

The Git history, upstream contributors, `LICENSE`, `NOTICE`, security guidance,
and other attribution must be preserved. A future IPI node must distinguish its
changes from upstream and publish:

1. a reviewed protocol and threat model;
2. an exact upstream base and dependency lock;
3. deterministic build instructions and signed checksums;
4. a genesis and chain-identity verification procedure;
5. consensus, upgrade, migration, and rollback tests;
6. operator documentation for independent deployment; and
7. independent review and release ownership.

Until those artifacts exist, this fork must not be presented as a production
IPI network implementation.
