# Notes for coding agents

Use this document as the working guide for changes in this repository. Read [architecture.md](./architecture.md) first when changing composition, host selection, or deployment behavior.

## Start here

The highest-signal files are:

- `flake.nix`: public outputs and per-system package contexts;
- `flake/configurations.nix`: inventory-to-host composition;
- `lib/feature.nix`: discovery, merge order, and feature selection;
- `lib/service.nix`: service roles, IP helpers, and reverse-proxy routes;
- `fleet/config/`: concrete inventory;
- `fleet/options/`: inventory schema and defaults;
- `tests/features.nix` and `tests/services.nix`: executable behavior examples.

Do not add a central feature or package registry. Directories below `features/` and `services/` are discovered automatically, as are directories below `packages/` that contain `package.nix`.

## Repository conventions

- Format Nix with Alejandra through `nix fmt`. Treefmt also runs deadnix, statix, ShellCheck, and Ruff where applicable.
- Prefer small feature fragments joined with `imports` over a monolithic `default.nix`.
- Put cross-platform declarations in `modules.generic` and NixOS-only declarations in `modules.nixos`.
- Consume `fleet`, `host`, `user`, and `helpers` from module arguments. They are supplied centrally; do not re-import the inventory from feature modules.
- Keep pure inventory/topology logic in `lib/` and cover behavior changes with `nix-unit` tests.
- Add persistent state to `persist` or `persistUser` in the feature that owns it. Do not write preservation mappings separately in multiple places.
- Keep runtime theme files in `dotfiles/templates` or `dotfiles/plain` and declare every destination in `dotfiles/manifest.toml`. The generated `dotfiles/built` tree is not source-controlled.
- Preserve existing user changes in a dirty worktree and avoid broad formatting or generated-file churn unrelated to the task.

`nix.settings.abort-on-warn` is enabled on managed hosts, so warnings that might normally seem harmless can break a deployment.

## Common change recipes

### Add or change a host

1. Edit `fleet/config/hosts.nix`; extend `fleet/options/host.nix` first if the data shape is new.
2. Ensure `owner` resolves to `fleet/config/users.nix` and `system` exists in `flake/systems.nix`.
3. Add `secrets/hosts/<name>/host_ed25519.pub`, because the host option defaults to that path.
4. Optionally add `features/boot/hardware/<name>/facter.json`. Hardware detection is skipped when the report is absent.
5. Check every static interface carefully. The first IPv4 address becomes the address used by fleet host mappings and service routes.
6. Use tags or `features` to select behavior; do not manually edit the flake output set.

Preservation-enabled hosts use the disk name and snapshot names from their host record. Changes to disk, ZFS, rollback, or `system.stateVersion` are high-risk and should not be made as incidental cleanup.

### Add a regular feature

1. Create `features/<name>/default.nix` with `modules.generic` and/or the required platform module.
2. Select it through an existing convention: a built-in rule, a `feature:<suffix>` tag for `programs-<suffix>`, or `host.features` for a direct name.
3. If the selection rule itself changes, update `lib/feature.nix` and `tests/features.nix` together.
4. Declare owned state through `persist`/`persistUser` and keep host-specific values in the inventory.

Remember that a selected feature must implement the host's platform. Duplicate directory names across `features/` and `services/` are an evaluation error.

### Add a routed service

1. Add the topology to `fleet/config/services.nix`: `primary`, optional `backups`, `port`, and optional `proxyPort`/`feature`.
2. Create `services/<feature>/default.nix`. By default the service name and feature name are the same.
3. In the module, use `helpers.requireRoutedService host "<service>"` when its port or role must come from the host's routed service record.
4. Add state paths, firewall configuration, and agenix declarations in the implementation.
5. If a secret is new, add its encrypted file policy to `secrets/secrets.nix` with recipients for every host that needs it.
6. Update `tests/services.nix` for changes to placement, addressing, or proxy behavior.

Caddy automatically builds routes for every service except itself, including services placed on a different host. If the public HTTP endpoint differs from the native service port, set `proxyPort`; Pi-hole is the current example.

### Add a local package

Create `packages/<name>/package.nix`. It becomes `pkgs.local.<name>` and a flake package automatically. Add source files beside it. Only add an explicit entry in `flake.nix` when export behavior must be architecture-specific or the package is not part of `pkgs.local`.

### Change secrets

Never commit plaintext secret material. Update recipient policy in `secrets/secrets.nix` and use agenix from the development shell to create/edit encrypted files. Preserve `builtins.pathExists` guards when a service is intentionally evaluable without its local secret. Do not rotate keys, edit recipients, or deploy secret changes unless the task explicitly requires it.

## Validation

Choose the narrowest useful check while iterating, then run the full check for composition changes:

```sh
# Format and run configured static checks.
nix fmt

# Build just the unit-test derivation on the current primary system.
nix build .#checks.x86_64-linux.unit

# Evaluate/build all flake checks, including formatting and unit tests.
nix flake check --print-build-logs

# Evaluate one host without deploying it.
nix eval .#nixosConfigurations.odin.config.system.build.toplevel.drvPath

# Build one host without activating it.
nix build .#nixosConfigurations.odin.config.system.build.toplevel
```

Use the appropriate system key instead of `x86_64-linux` when working on another supported platform. A build/evaluation is not authorization to deploy. Colmena operations and the `odin` development-shell command can modify live machines; run them only when explicitly requested.

## Review checklist

Before handing off a change, verify:

- inventory additions match their option schema and all referenced hosts/users exist;
- feature selection resolves to a real module for every affected platform;
- services have correct primary/backup placement, ports, proxy behavior, and persistence;
- secrets remain encrypted and have the required recipients;
- new stateful paths are represented in `persist` or `persistUser` where appropriate;
- focused tests cover pure logic changes, and relevant flake checks pass;
- no live deployment or destructive disk operation was performed without explicit instruction.
