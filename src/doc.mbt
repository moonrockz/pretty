///|
/// A document: pieces of text and places where `render` may break a line.
/// Build documents with the functions of this package and join them with
/// `+`. The representation is private, so it can change without a breaking
/// release.
struct Doc {
  node : DocNode
  // Whether the flat form holds a hard line. A group that holds one always
  // breaks.
  has_hardline : Bool
}

///|
priv enum DocNode {
  Empty
  Text(String, Int32) // the text and its width in code points
  ZeroWidth(String) // text written with width 0
  Lines(Int32) // n line feeds and the indentation; a break point that does not force the group
  Break(String, Int32, String, Int32, BreakKind) // broken text and width, unbroken text and width, kind
  Line(Int32) // the width of the flat form: 1 for `line`, 0 for `softline`
  HardLine
  VerbatimLine // a line break with no indentation
  Nest(Int32, Doc)
  Align(Doc)
  Tab(Int32, Doc) // indentation: the next multiple of the Int
  Group(Doc)
  IfBreak(Doc, Doc) // broken, flat
  Concat(Doc, Doc)
}

///|
/// How a `Break` decides: a strict break follows the mode of its group, a
/// flex break checks on its own whether the rest fits.
priv enum BreakKind {
  Strict
  Flex
}

///|
fn make(node : DocNode, has_hardline : Bool) -> Doc {
  { node, has_hardline, }
}

///|
/// The empty document. `empty() + d` and `d + empty()` render as `d`.
pub fn empty() -> Doc {
  make(Empty, false)
}

///|
fn columns(s : String) -> Int32 {
  let mut n = 0
  for _ in s {
    n += 1
  }
  n
}

///|
fn atom(s : String) -> Doc {
  if s.is_empty() {
    empty()
  } else {
    make(Text(s, columns(s)), false)
  }
}

///|
/// The text `s`. A line feed in `s` is a `hardline()`, so the lines after it
/// get the current indentation. Width counts code points.
///
/// ```mbt check
/// test {
///   inspect(
///     @pretty.render(@pretty.nest(2, @pretty.text("a\nb"))),
///     content="a\n  b",
///   )
/// }
/// ```
pub fn text(s : String) -> Doc {
  let parts = s.split("\n").map(p => atom(p.to_owned())).collect()
  join(parts, hardline())
}

///|
/// The text `s` as it is: a line feed in `s` starts a new line with no
/// indentation. Use it for text whose bytes must not change, such as a doc
/// comment. A group that holds a line feed this way always breaks.
pub fn verbatim(s : String) -> Doc {
  let parts = s.split("\n").map(p => atom(p.to_owned())).collect()
  join(parts, make(VerbatimLine, true))
}

///|
/// `n` line feeds, then the indentation (pretty-arena's `Line(n)`). Unlike
/// `hardline`, it does not force the enclosing group to break: the group
/// is flat when the text up to the `lines` fits. `lines(0)` is `empty()`.
///
/// ```mbt check
/// test {
///   inspect(
///     @pretty.render(
///       @pretty.nest(2, @pretty.text("a") + @pretty.lines(2) + @pretty.text("b")),
///     ),
///     content="a\n\n  b",
///   )
/// }
/// ```
pub fn lines(n : Int32) -> Doc {
  if n <= 0 {
    empty()
  } else {
    make(Lines(n), false)
  }
}

///|
/// The text `s` with width 0: it is written, but it does not count toward
/// the line width. Use it for text the layout must not react to, such as
/// a comment. `s` must hold no line feed.
pub fn zero_width(s : String) -> Doc {
  if s.is_empty() {
    empty()
  } else {
    make(ZeroWidth(s), false)
  }
}

///|
/// A strict break (pretty-arena's `break_`): `unbroken` when the enclosing
/// group is flat; `broken`, then a line feed and the indentation, when it
/// is broken. `break_("", " ")` is a `line()` whose group `fits` checks
/// alone; `break_(",", ", ")` writes a trailing comma when broken.
///
/// ```mbt check
/// test {
///   let d = @pretty.group(
///     @pretty.text("a") + @pretty.break_(",", ", ") + @pretty.text("b"),
///   )
///   inspect(@pretty.render(d, width=80), content="a, b")
///   inspect(@pretty.render(d, width=3), content="a,\nb")
/// }
/// ```
pub fn break_(broken : String, unbroken : String) -> Doc {
  make(
    Break(broken, columns(broken), unbroken, columns(unbroken), Strict),
    false,
  )
}

///|
/// A flex break (pretty-arena's `flex_break`): `unbroken` when the rest of
/// the line up to the next break fits after it, or when the mode is
/// `Unbroken`; otherwise `broken`, then a line feed and the indentation.
/// Each flex break decides on its own, so a list of flex breaks fills
/// lines.
pub fn flex_break(broken : String, unbroken : String) -> Doc {
  make(Break(broken, columns(broken), unbroken, columns(unbroken), Flex), false)
}

///|
/// A space in flat mode; a line break and the indentation in break mode.
pub fn line() -> Doc {
  make(Line(1), false)
}

///|
/// Nothing in flat mode; a line break and the indentation in break mode.
pub fn softline() -> Doc {
  make(Line(0), false)
}

///|
/// Always a line break and the indentation. Every group that holds it
/// breaks.
pub fn hardline() -> Doc {
  make(HardLine, true)
}

///|
/// `d` with the indentation of its line breaks increased by `n`.
pub fn nest(n : Int32, d : Doc) -> Doc {
  make(Nest(n, d), d.has_hardline)
}

///|
/// `d` with the indentation of its line breaks set to the next multiple of
/// `n` that is greater than the current indentation (a tab stop). With
/// `n <= 0` the indentation does not change. Use it after `align` to indent
/// to a fixed grid: indentation 6 becomes 8, indentation 8 becomes 12.
///
/// ```mbt check
/// test {
///   let body = @pretty.text("x") +
///     @pretty.tab(4, @pretty.hardline() + @pretty.text("y"))
///   inspect(
///     @pretty.render(@pretty.text("ab") + @pretty.align(body)),
///     content="abx\n    y",
///   )
///   inspect(
///     @pretty.render(@pretty.text("abcd") + @pretty.align(body)),
///     content="abcdx\n        y",
///   )
/// }
/// ```
pub fn tab(n : Int32, d : Doc) -> Doc {
  make(Tab(n, d), d.has_hardline)
}

///|
/// `d` with the indentation of its line breaks set to the column where `d`
/// starts.
pub fn align(d : Doc) -> Doc {
  make(Align(d), d.has_hardline)
}

///|
/// `d` on one line when it fits (with the rest of the line up to the next
/// possible break), otherwise `d` with its line breaks.
///
/// ```mbt check
/// test {
///   let d = @pretty.group(@pretty.text("a") + @pretty.line() + @pretty.text("b"))
///   inspect(@pretty.render(d, width=3), content="a b")
///   inspect(@pretty.render(d, width=2), content="a\nb")
/// }
/// ```
pub fn group(d : Doc) -> Doc {
  make(Group(d), d.has_hardline)
}

///|
/// `broken` when the enclosing group breaks, `flat` when it is flat. Only
/// `flat` decides whether the group can be flat.
pub fn if_break(broken : Doc, flat : Doc) -> Doc {
  make(IfBreak(broken, flat), flat.has_hardline)
}

///|
fn concat2(a : Doc, b : Doc) -> Doc {
  match (a.node, b.node) {
    (Empty, _) => b
    (_, Empty) => a
    _ => make(Concat(a, b), a.has_hardline || b.has_hardline)
  }
}

///|
/// The documents one after the other.
pub fn concat(docs : Array[Doc]) -> Doc {
  let mut d = empty()
  for x in docs {
    d = concat2(d, x)
  }
  d
}

///|
/// The documents with `sep` between them.
pub fn join(docs : Array[Doc], sep : Doc) -> Doc {
  let mut d = empty()
  for i, x in docs {
    d = if i == 0 { x } else { concat2(concat2(d, sep), x) }
  }
  d
}

///|
pub impl Add for Doc with fn add(self, other) {
  concat2(self, other)
}
