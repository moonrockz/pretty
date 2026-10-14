# Changelog

All notable changes to `moonrockz/pretty` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.1.1] - 2026-10-14

This release moves `moonrockz/pretty` to MoonBit toolchain
0.10.15+943464bfa. The library and its public interface do not change. The
sources use the new `moon fmt` output, and the tests no longer use the
deprecated `@list` functions.

### 🏗️ Build and CI

- Add ci-ok job as the single required check ([#2](https://github.com/moonrockz/pretty/pull/2)) by @DamianReeves
- Move to MoonBit toolchain 0.10.15+943464bfa ([#3](https://github.com/moonrockz/pretty/pull/3)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/pretty/compare/v0.1.0...v0.1.1

## [0.1.0] - 2026-10-02

The first release. `moonrockz/pretty` is a Wadler-style pretty printer for
MoonBit: build a document from text, line breaks and groups, and `render`
lays it out to fit a line width. Evaluation is strict and uses explicit
stacks, so deep documents render on wasm, wasm-gc, js and native. The
engine started as a workspace module of
[moonrockz/krueger](https://github.com/moonrockz/krueger), where it lays
out the Elm printer.

### 🚀 Features

- `Doc` and its builders: `text`, `verbatim`, `line`, `softline`,
  `hardline`, `nest`, `align`, `tab`, `group`, `if_break`, `empty`,
  `concat`, `join` and `+`
- `render(doc, width?)` with the fit rule of Wadler's "A prettier printer"
- No trailing whitespace and no indentation on empty lines; width counts
  code points
