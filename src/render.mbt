///|
/// The layout mode of a command, as in the Gleam compiler's pretty-arena:
/// `Unbroken` keeps the breaks of a group on one line, `Broken` splits
/// them; `ForcedBroken` and `ForcedUnbroken` are set by `next_break_fits`
/// and only change what `fits` answers.
priv enum Mode {
  Unbroken
  Broken
  ForcedBroken
  ForcedUnbroken
}

///|
/// The mode `render` starts in. `Broken` (the default) breaks a line that
/// is outside every group; `Unbroken` keeps it flat, as pretty-arena's
/// `pretty_print` does.
pub(all) enum Start {
  Broken
  Unbroken
} derive(Eq, Debug)

///|
priv struct Cmd {
  indent : Int32
  mode : Mode
  doc : Doc
}

///|
/// The output. Indentation and the spaces of flat lines are written only
/// before the next text, so the engine writes no trailing whitespace.
priv struct Out {
  buf : StringBuilder
  mut column : Int32
  mut indent : Int32? // indentation not written yet, at the start of a line
  mut spaces : Int32 // spaces of flat lines not written yet
}

///|
fn Out::text(self : Out, s : String, width : Int32) -> Unit {
  if self.indent is Some(i) {
    self.buf.write_string(" ".repeat(i))
    self.indent = None
  }
  if self.spaces > 0 {
    self.buf.write_string(" ".repeat(self.spaces))
    self.spaces = 0
  }
  self.buf.write_string(s)
  self.column += width
}

///|
fn Out::space(self : Out, n : Int32) -> Unit {
  self.spaces += n
  self.column += n
}

///|
fn Out::newline(self : Out, indent : Int32) -> Unit {
  self.buf.write_char('\n')
  self.indent = Some(indent)
  self.spaces = 0
  self.column = indent
}

///|
/// Lay out `doc` in lines of at most `width` columns where its groups
/// allow. A group is flat when it fits, together with the rest of its line
/// up to the next possible break. Text wider than `width` stays whole.
/// `start` is the mode outside every group: `Broken` (the default) breaks
/// a bare line, `Unbroken` keeps it flat. Uses explicit stacks, so deep
/// documents render on every target.
///
/// ```mbt check
/// test {
///   let items = [@pretty.text("a"), @pretty.text("b")]
///   let d = @pretty.group(
///     @pretty.text("[") +
///     @pretty.nest(
///       2,
///       @pretty.line() + @pretty.join(items, @pretty.text(",") + @pretty.line()),
///     ) +
///     @pretty.line() +
///     @pretty.text("]"),
///   )
///   inspect(@pretty.render(d), content="[ a, b ]")
///   inspect(@pretty.render(d, width=4), content="[\n  a,\n  b\n]")
/// }
/// ```
pub fn render(
  doc : Doc,
  width~ : Int32 = 80,
  start~ : Start = Broken,
) -> String {
  let out : Out = { buf: StringBuilder(), column: 0, indent: None, spaces: 0, }
  let mode : Mode = match start {
    Broken => Mode::Broken
    Unbroken => Mode::Unbroken
  }
  let stack : Array[Cmd] = [{ indent: 0, mode, doc, }]
  while stack.pop() is Some(cmd) {
    match cmd.doc.node {
      Empty => ()
      Text(s, n) => out.text(s, n)
      ZeroWidth(s) => out.text(s, 0)
      Lines(n) =>
        for _ in 0..<n {
          out.newline(cmd.indent)
        }
      Line(n) =>
        match cmd.mode {
          Unbroken | ForcedUnbroken => out.space(n)
          Broken | ForcedBroken => out.newline(cmd.indent)
        }
      HardLine => out.newline(cmd.indent)
      VerbatimLine => out.newline(0)
      Nest(n, d) => stack.push({ ..cmd, indent: cmd.indent + n, doc: d, })
      Align(d) => stack.push({ ..cmd, indent: out.column, doc: d, })
      Tab(n, d) =>
        stack.push({ ..cmd, indent: next_stop(cmd.indent, n), doc: d, })
      Group(d) =>
        match cmd.mode {
          Unbroken | ForcedUnbroken => stack.push({ ..cmd, doc: d, })
          Broken | ForcedBroken => {
            let flat = !d.has_hardline &&
              fits(
                width - out.column,
                [{ ..cmd, mode: Mode::Unbroken, doc: d, }],
                stack,
              )
            stack.push({
              ..cmd,
              mode: if flat {
                Mode::Unbroken
              } else {
                Mode::Broken
              },
              doc: d,
            })
          }
        }
      IfBreak(broken, flat) =>
        stack.push({
          ..cmd,
          doc: match cmd.mode {
            Unbroken | ForcedUnbroken => flat
            Broken | ForcedBroken => broken
          },
        })
      Concat(a, b) => {
        stack.push({ ..cmd, doc: b, })
        stack.push({ ..cmd, doc: a, })
      }
    }
  }
  out.buf.to_string()
}

///|
/// Whether the commands of `pending` (last element first), then the
/// commands of `rest` (top of the stack first), fit in `remaining`
/// columns up to the next line break. A line in a broken mode ends the
/// check: the line can break there.
fn fits(remaining : Int32, pending : Array[Cmd], rest : Array[Cmd]) -> Bool {
  let mut left = remaining
  let mut next = rest.length() - 1
  while left >= 0 {
    let cmd = match pending.pop() {
      Some(c) => c
      None => {
        if next < 0 {
          return true
        }
        let c = rest[next]
        next -= 1
        c
      }
    }
    match cmd.doc.node {
      Empty => ()
      Text(_, n) => left -= n
      ZeroWidth(_) => ()
      Lines(_) => return true
      Line(n) =>
        match cmd.mode {
          Unbroken | ForcedUnbroken => left -= n
          Broken | ForcedBroken => return true
        }
      HardLine | VerbatimLine => return true
      Nest(_, d) | Align(d) | Tab(_, d) => pending.push({ ..cmd, doc: d, })
      Group(d) =>
        pending.push({
          ..cmd,
          mode: if d.has_hardline {
            Mode::Broken
          } else {
            cmd.mode
          },
          doc: d,
        })
      IfBreak(broken, flat) =>
        pending.push({
          ..cmd,
          doc: match cmd.mode {
            Unbroken | ForcedUnbroken => flat
            Broken | ForcedBroken => broken
          },
        })
      Concat(a, b) => {
        pending.push({ ..cmd, doc: b, })
        pending.push({ ..cmd, doc: a, })
      }
    }
  }
  false
}

///|
/// The next multiple of `n` greater than `indent`; `indent` when `n <= 0`.
fn next_stop(indent : Int32, n : Int32) -> Int32 {
  if n <= 0 {
    indent
  } else {
    (indent / n + 1) * n
  }
}
