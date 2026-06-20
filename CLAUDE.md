# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ConfigKeyKit is a tiny, **dependency-free, Foundation-only** Swift 6.2 library (single `ConfigKeyKit` library product). It defines configuration keys whose base name resolves to per-source key strings — e.g. `cloudkit.container_id` on the CLI vs. `MYAPP_CLOUDKIT_CONTAINER_ID` in the environment. It deliberately does **not** depend on `apple/swift-configuration`; it produces key strings you feed into whatever provider stack you use. Keep it dependency-free — adding a dependency is a design change, not a routine edit.

## Commands

- `make build` / `swift build` — build
- `make test` / `swift test` — run the full suite (Swift Testing, not XCTest)
- Run one test: `swift test --filter ConfigKeyTests` (suite) or `swift test --filter "ConfigKey with default"` (by `@Test` display name)
- `make lint` — runs `Scripts/lint.sh`: swift-format, SwiftLint, license-header check, and `periphery` dead-code scan
- `make clean`

Lint/format tooling is pinned via **mise** (`mise.toml`): swift-format 602.0.0, SwiftLint 0.62.2, periphery 3.7.4. Run `mise install` once so `Scripts/lint.sh` can find them outside CI. `Scripts/lint.sh` is env-driven: `LINT_MODE` (`STRICT` adds `--strict`/`--configuration`; `NONE`/`INSTALL` short-circuit), `FORMAT_ONLY=1` skips lint+build, and outside CI it auto-formats in place before linting.

## Architecture

Two loosely-related feature sets live in one product:

**Config keys** (the core purpose) — A `ConfigurationKey` protocol exposes one method: `key(for: ConfigKeySource) -> String?`. Two concrete value types implement it:
- `ConfigKey<Value>` — has a required `defaultValue` (resolution is non-optional).
- `OptionalConfigKey<Value>` — no default (resolves to optional).

Both store the same three fields: `baseKey`, a `styles` map (`ConfigKeySource -> NamingStyle`), and an `explicitKeys` override map. `key(for:)` checks `explicitKeys` first, otherwise transforms `baseKey` through the source's `NamingStyle`. `ConfigKeySource` is just `.commandLine` / `.environment`. `NamingStyle` is a protocol; `StandardNamingStyle` provides `.dotSeparated` (CLI, identity) and `.screamingSnakeCase(prefix:)` (ENV, uppercases + replaces `.` with `_`, optional prefix). The convenience init `ConfigKey("base", envPrefix:, default:)` wires these two standard styles automatically. `ConfigKey+Bool.swift` adds `Bool`-specialized inits; `+Debug` files add `CustomDebugStringConvertible`.

**CLI scaffolding** (optional, ignore if you only need keys) — A lightweight command-dispatch layer: `Command` protocol (associated `Config: ConfigurationParseable`, static metadata, async `createInstance()`/`execute()`), the `CommandRegistry` **actor** (concurrency-safe registry, `.shared` singleton plus `internal init()` for isolated test instances), `CommandLineParser` (splits argv into command name + args), and `ConfigurationParseable` (async parse-from-sources protocol; `BaseConfig == Never` means a root config and unlocks the parentless convenience init).

## Conventions

- **Swift 6.2** with these upcoming features enabled in `Package.swift` (apply them in new code): `ExistentialAny` (write `any NamingStyle`), `InternalImportsByDefault` (mark imports `public import` / `internal import` explicitly — e.g. Foundation is `internal import Foundation`), `MemberImportVisibility`, `FullTypedThrows`.
- Everything is `Sendable`; preserve that.
- SwiftLint runs with many opt-in rules including `explicit_acl` / `explicit_top_level_acl` (declare access control explicitly on every declaration) and `force_unwrapping` (no `!`). `file_name` is enforced — the primary type's name must match the filename; extensions use the `Type+Feature.swift` pattern.
- Every source file carries the MIT license header (copyright "Leo Dion" / "BrightDigit"); `Scripts/header.sh` enforces it. New files need it.
- `periphery.yml` sets `retain_public: true`, so public API is never flagged as dead code.

## Note

`ConfigKeyKit.git/` in the working tree is a bare git repo (a mirror clone), not part of the package — leave it alone.
