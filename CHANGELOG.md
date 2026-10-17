# Changelog

All notable changes to `moonrockz/pretty` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.3.0] - 2026-10-17

`ungroup` lets a child share the enclosing group's break decision.
`can_break` reports exposed optional breaks and forced breaks, so a
formatter can keep long atoms intact while breaking compound children.
Both operations preserve nested groups; `ungroup` uses an explicit stack.

### 🚀 Features

- *(doc)* Let outer groups share parent breaks ([#7](https://github.com/moonrockz/pretty/pull/7)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/pretty/compare/v0.2.0...v0.3.0

## [0.2.0] - 2026-10-16

The Gleam compiler's pretty-arena document forms: `break_`, `flex_break`,
`lines`, `zero_width`, `raw_text`, `group_alone`, `force_break`,
`next_break_fits`, `nest_if_broken` and `set_nesting`, four layout modes
and a `render` start mode (`start=Unbroken`). Every current builder keeps
its output; `group` keeps Wadler's fit rule and `group_alone` has
pretty-arena's. A new package `moonrockz/pretty/grapheme` counts extended
grapheme clusters (UAX #29, Unicode 17.0.0) from generated tables, checked
by the 766 cases of GraphemeBreakTest; text widths now count clusters, not
code points. Laws check the engine against a port of pretty-arena's
`format` and `fits`.

### ⚠️ Breaking changes

- *(doc)* Text widths count extended grapheme clusters instead of code points; a text with combining marks, flags or ZWJ emoji sequences is narrower, so a group holding one can stay flat where it broke before. ([#5](https://github.com/moonrockz/pretty/pull/5))

### 🚀 Features

- *(doc)* [**breaking**] Pretty-arena document forms and grapheme widths ([#5](https://github.com/moonrockz/pretty/pull/5)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/pretty/compare/v0.1.1...v0.2.0

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
