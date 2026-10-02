# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Overview

`moonrockz/pretty` is a Wadler-style pretty printer: build a `Doc` from
text, line breaks and groups, and `render` lays it out to fit a line width.
It has no knowledge of any one language. It started as a workspace module of
[moonrockz/krueger](https://github.com/moonrockz/krueger), whose Elm printer
uses it.

```
moonrockz/pretty
├── moon.mod          # Module metadata (published to mooncakes.io)
├── README.mbt.md     # mooncakes.io landing page
├── CHANGELOG.md      # One section per release (git-cliff)
├── cliff.toml        # git-cliff configuration
├── src/              # The library (one package)
├── scripts/          # MoonBit tooling scripts (.mbtx) and their features
├── mise-tasks/       # File-based mise tasks
└── .github/workflows # CI and Release
```

## Design

- The fit rule is the one of Wadler's "A prettier printer": a group is flat
  when it fits together with the rest of its line, up to the next possible
  break.
- Evaluation is strict (Lindig, "Strictly Pretty") and uses explicit stacks,
  not recursion, so deep documents render on every target. wasm overflows at
  a few hundred frames.
- The engine writes no trailing whitespace and no indentation on empty
  lines. Width counts code points.
- Functional design: algebraic data types, immutability, total functions,
  exhaustive `match`.

## Toolchain

- Supported targets: wasm, wasm-gc, js and native (`mise run test:targets`,
  CI job `targets`). llvm is left out because the toolchain does not ship
  `moonbitlang/core` for it.
- Library code uses only `moonbitlang/core`. `moonrockz/expect` is the only
  module import (the package tests use it).
- The MoonBit toolchain version is pinned in `.github/workflows/*.yml`
  (`MOONBIT_VERSION`). Keep your local toolchain on the same version.
- Use `derive(Debug)` (not `derive(Show)`) for data types.

## Tests

- Test-driven development: write a failing test first.
- Write assertions with [moonrockz/expect](https://mooncakes.io/docs/moonrockz/expect).
  Use soft assertions (`@expect.expect_all(s => { ... })`) when a test checks
  more than one fact.
- Laws (property tests) use `moonbitlang/core/quickcheck` with a fixed
  `seed`. Test names start with `law:` and state the rule.
- Doc comment examples in `mbt check` blocks run as black-box tests.

## Mise Tasks

All operations use file-based mise tasks in `mise-tasks/`.

| Task | Purpose |
|------|---------|
| `info:generate` | Run `moon info` to generate interfaces |
| `lint:check` | Run `moon check` |
| `format:check` | Run `moon fmt --check` (also on `scripts/*.mbtx`) |
| `check` | Run all checks (info, lint, format, tests) |
| `test:unit` | Run the unit tests |
| `test:targets` | Check and test on wasm, wasm-gc, js and native |
| `test:scripts` | Run the script tests (`scripts/*.mbtx`) |
| `test` | Run all tests |
| `release:prepare` | Open the release pull request (version bump and changelog section) |
| `release:version` | Compute the next version from conventional commits |
| `release:plan` | Decide whether a Release workflow run releases (CI) |
| `release:notes` | Print a version's GitHub release notes from `CHANGELOG.md` |
| `release:status` | Check that main, the tags, the GitHub release and mooncakes.io agree |
| `release:credentials` | Set up mooncakes.io credentials (CI only) |
| `release:publish` | Publish the module to mooncakes.io |

## Scripts

Tooling logic is written in MoonBit, not bash.

- Put tooling logic in `scripts/<name>.mbtx`. Keep each mise task a one-line
  launcher: `exec moon run -q --target wasm scripts/<name>.mbtx -- <args>`.
- Specify each script's behavior in `scripts/features/<name>.feature`, run
  with moonspec from an `async test` in the script.
- Pin module imports in each script to exact versions.

## Conventional Commits

All commits use [Conventional Commits](https://www.conventionalcommits.org):
`type(scope): description`. Types: `feat`, `fix`, `docs`, `refactor`,
`perf`, `test`, `build`, `ci`, `chore`, `style`. Add `!` for a breaking
change. The squash-merge title is the changelog line.

## Release Process

- Run `mise run release:prepare` on a clean working tree. It computes the
  next version with git-cliff (on 0.x a `feat` or a breaking change bumps
  the minor, anything else the patch), sets `version` in `moon.mod`,
  prepends the version's section to `CHANGELOG.md`, commits
  `chore(release): v<version>` on branch `release/v<version>`, pushes it and
  opens the pull request. Give a version to override git-cliff; `--local`
  stops before the push.
- In the pull request, replace the highlights comment with a few sentences
  on what the release brings. Then merge.
- The merge changes `moon.mod` on `main`, so the Release workflow runs:
  `plan` releases when `v<version>` has no tag and `CHANGELOG.md` has its
  section; `validate` runs the checks; `publish` publishes to mooncakes.io
  (org secret `MOONCAKES_USER_TOKEN`); `release` creates the tag and the
  GitHub release from the changelog section.
- A release run is safe to repeat. `mise run release:status` shows what is
  out of step and the command that fixes it.

## Documentation

Write documentation in ASD-STE100 Simplified Technical English: short
sentences, active voice, one word for one meaning.

## The `.dev/` Working Area

`.dev/` is a gitignored scratch area for specs, plans and scratch files.
Never commit it.
