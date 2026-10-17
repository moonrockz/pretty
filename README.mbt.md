# moonrockz/pretty

A Wadler-style pretty printer for MoonBit. Build a document from text,
line breaks and groups; `render` lays it out to fit a line width.

```moonbit
let items = [@pretty.text("a"), @pretty.text("b"), @pretty.text("c")]
let doc = @pretty.group(
  @pretty.text("[") +
  @pretty.nest(2, @pretty.line() + @pretty.join(items, @pretty.text(",") + @pretty.line())) +
  @pretty.line() +
  @pretty.text("]"),
)
@pretty.render(doc) // "[ a, b, c ]"
@pretty.render(doc, width=6) // "[\n  a,\n  b,\n  c\n]"
```

| Function | Flat | Broken |
|---|---|---|
| `text(s)` | `s` | `s` |
| `verbatim(s)` | `s` | `s`, no indentation after its line feeds |
| `line()` | a space | a line break |
| `softline()` | nothing | a line break |
| `hardline()` | always a line break | |
| `nest(n, d)` | `d` | `d`, indented by `n` more |
| `align(d)` | `d` | `d`, indented to its start column |
| `tab(n, d)` | `d` | `d`, indented to the next multiple of `n` |
| `group(d)` | flat if it fits | else broken |
| `ungroup(d)` | outer groups removed so their breaks follow the enclosing group | |
| `if_break(b, f)` | `f` | `b` |
| `group_alone(d)` | flat if `d` alone fits | else broken |
| `break_(b, u)` | `u` | `b`, then a line break |
| `flex_break(b, u)` | `u` | `u` when the rest fits, else `b` and a line break |
| `lines(n)` | `n` line breaks (does not force the group) | |
| `zero_width(s)` | `s`, width 0 | `s`, width 0 |
| `raw_text(s)` | `s` as one atom: line feeds kept, no indentation, every cluster counts | |
| `force_break(d)` | `d`; its group never fits | |
| `next_break_fits(d, m)` | `d`; `Enabled` lets the group fit up to the first break in `d` | |
| `nest_if_broken(n, d)` | `d` | `d`, indented by `n` more |
| `set_nesting(n, d)` | `d` | `d`, indented to column `n` |

- A group is flat when it fits together with the rest of its line, up to
  the next possible break (the fit rule of Wadler's "A prettier printer").
- Evaluation is strict (Lindig, "Strictly Pretty") and uses explicit
  stacks, so deep documents render on wasm, wasm-gc, js and native.
- The engine writes indentation and the spaces of flat lines only before
  the next text, so a line break never leaves trailing whitespace and an
  empty line has no indentation. (A `break_` whose unbroken text ends in a
  space, followed by a `lines`, keeps that space: it is text.) Width counts
  extended grapheme clusters (UAX #29, Unicode 17.0.0; `@grapheme.count`).
- `render(doc, width?, start?)`: `start=Unbroken` keeps a line outside
  every group flat, as the Gleam compiler's pretty-arena does. The forms
  `group_alone`, `break_`, `flex_break`, `lines`, `force_break`,
  `next_break_fits`, `nest_if_broken`, `set_nesting` and `zero_width`
  have pretty-arena's semantics; `group` keeps Wadler's rule.

`can_break(d)` reports a break controlled by the enclosing group, or a
forced line break. Optional breaks inside nested groups do not count.
For a parent whose closing token follows its child's shape, open the
child's outer groups first:

```mbt check
test {
  let child = @pretty.group(@pretty.text("long") + @pretty.line() + @pretty.text("value"))
  let child = @pretty.ungroup(child)
  let closing = if @pretty.can_break(child) { @pretty.softline() } else { @pretty.empty() }
  let doc = @pretty.group(@pretty.text("(") + child + closing + @pretty.text(")"))
  inspect(@pretty.render(doc, width=11), content="(long\nvalue\n)")
}
```
