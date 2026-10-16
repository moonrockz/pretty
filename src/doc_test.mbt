///|
test "text renders as itself" {
  inspect(@pretty.render(@pretty.text("hello")), content="hello")
}

///|
fn bracket(items : Array[String]) -> @pretty.Doc {
  let docs = items.map(@pretty.text)
  @pretty.group(
    @pretty.text("[") +
    @pretty.nest(
      2,
      @pretty.line() + @pretty.join(docs, @pretty.text(",") + @pretty.line()),
    ) +
    @pretty.line() +
    @pretty.text("]"),
  )
}

///|
test "a group stays flat when it fits and breaks when it does not" {
  @expect.expect_all(s => {
    let d = bracket(["a", "b"])
    s.expect(@pretty.render(d, width=80)).to_equal("[ a, b ]")
    s.expect(@pretty.render(d, width=7)).to_equal("[\n  a,\n  b\n]")
  })
}

///|
test "a hard line breaks every enclosing group" {
  let d = @pretty.group(
    @pretty.text("a") +
    @pretty.line() +
    @pretty.text("b") +
    @pretty.hardline() +
    @pretty.text("c"),
  )
  inspect(@pretty.render(d, width=80), content="a\nb\nc")
}

///|
test "if_break picks the branch of the group's mode" {
  @expect.expect_all(s => {
    let d = @pretty.group(
      @pretty.text("x") +
      @pretty.if_break(@pretty.text("!"), @pretty.text("?")) +
      @pretty.softline() +
      @pretty.text("yyyy"),
    )
    s.expect(@pretty.render(d, width=80)).to_equal("x?yyyy")
    s.expect(@pretty.render(d, width=3)).to_equal("x!\nyyyy")
  })
}

///|
test "a hard line in the broken branch of if_break does not force a break" {
  let d = @pretty.group(
    @pretty.text("a") +
    @pretty.if_break(@pretty.hardline(), @pretty.text(" ")) +
    @pretty.text("b"),
  )
  inspect(@pretty.render(d, width=80), content="a b")
}

///|
test "empty lines have no indentation" {
  let d = @pretty.nest(
    4,
    @pretty.text("a") +
    @pretty.hardline() +
    @pretty.hardline() +
    @pretty.text("b"),
  )
  inspect(@pretty.render(d), content="a\n\n    b")
}

///|
test "a flat line before a break adds no trailing space" {
  let d = @pretty.group(@pretty.text("a") + @pretty.line()) +
    @pretty.hardline() +
    @pretty.text("b")
  inspect(@pretty.render(d), content="a\nb")
}

///|
test "the fit check looks past the group to the next possible break" {
  // Flat, the group gives "a b" and the text after it gives "cccc": 7 columns.
  let d = @pretty.group(@pretty.text("a") + @pretty.line() + @pretty.text("b")) +
    @pretty.text("cccc")
  inspect(@pretty.render(d, width=5), content="a\nbcccc")
}

///|
test "tab indents to the next multiple, after align too" {
  let body = @pretty.text("k") +
    @pretty.tab(4, @pretty.hardline() + @pretty.text("i")) +
    @pretty.hardline() +
    @pretty.text("e")
  @expect.expect_all(s => {
    s.expect(@pretty.render(body)).to_equal("k\n    i\ne")
    s
    .expect(@pretty.render(@pretty.text("(") + @pretty.align(body)))
    .to_equal("(k\n    i\n e")
    s
    .expect(@pretty.render(@pretty.text("1234") + @pretty.align(body)))
    .to_equal("1234k\n        i\n    e")
    s
    .expect(
      @pretty.render(
        @pretty.text("k") +
        @pretty.nest(3, @pretty.tab(0, @pretty.hardline() + @pretty.text("i"))),
      ),
    )
    .to_equal("k\n   i")
  })
}

///|
test "align indents to the current column" {
  let d = @pretty.text("let ") +
    @pretty.align(@pretty.text("a") + @pretty.hardline() + @pretty.text("b"))
  inspect(@pretty.render(d), content="let a\n    b")
}

///|
test "text with a line feed is text joined by hard lines" {
  let d = @pretty.nest(
    2,
    @pretty.text("x") + @pretty.hardline() + @pretty.text("a\nb"),
  )
  inspect(@pretty.render(d), content="x\n  a\n  b")
}

///|
test "verbatim adds no indentation" {
  let d = @pretty.nest(
    4,
    @pretty.text("x") + @pretty.hardline() + @pretty.verbatim("{-| a\n  b\n-}"),
  )
  inspect(@pretty.render(d), content="x\n    {-| a\n  b\n-}")
}

///|
test "width counts code points" {
  @expect.expect_all(s => {
    let d = @pretty.group(
      @pretty.text("é😀") + @pretty.line() + @pretty.text("x"),
    )
    s.expect(@pretty.render(d, width=4)).to_equal("é😀 x")
    s.expect(@pretty.render(d, width=3)).to_equal("é😀\nx")
  })
}

///|
test "a text wider than the width stays whole" {
  let d = @pretty.group(
    @pretty.text("f") +
    @pretty.nest(4, @pretty.line() + @pretty.text("\"a very long text\"")),
  )
  inspect(@pretty.render(d, width=10), content="f\n    \"a very long text\"")
}

///|
test "empty, concat and join" {
  @expect.expect_all(s => {
    s.expect(@pretty.render(@pretty.empty())).to_equal("")
    s
    .expect(
      @pretty.render(@pretty.concat([@pretty.text("a"), @pretty.text("b")])),
    )
    .to_equal("ab")
    s.expect(@pretty.render(@pretty.join([], @pretty.text(",")))).to_equal("")
    s
    .expect(
      @pretty.render(
        @pretty.join([@pretty.text("a"), @pretty.text("b")], @pretty.text(",")),
      ),
    )
    .to_equal("a,b")
  })
}

///|
test "deep documents render without recursion" {
  let mut d = @pretty.text("x")
  for _ in 0..<100_000 {
    d = @pretty.group(
      @pretty.nest(1, @pretty.text("(") + d + @pretty.text(")")),
    )
  }
  inspect(@pretty.render(d, width=80).length(), content="200001")
}

///|
test "a line outside every group breaks by default and is a space with start=Unbroken" {
  let d = @pretty.text("a") + @pretty.line() + @pretty.text("b")
  @expect.expect_all(s => {
    s.expect(@pretty.render(d)).to_equal("a\nb")
    s.expect(@pretty.render(d, start=Broken)).to_equal("a\nb")
    s.expect(@pretty.render(d, start=Unbroken)).to_equal("a b")
  })
}

///|
test "lines writes line feeds, indents only the last line and does not force the group" {
  @expect.expect_all(s => {
    s
    .expect(
      @pretty.render(
        @pretty.nest(
          2,
          @pretty.text("a") + @pretty.lines(2) + @pretty.text("b"),
        ),
      ),
    )
    .to_equal("a\n\n  b")
    // The group fits: `lines` is a break point, not a forced break.
    let g = @pretty.group(
      @pretty.text("a") +
      @pretty.lines(1) +
      @pretty.text("b") +
      @pretty.line() +
      @pretty.text("c"),
    )
    s.expect(@pretty.render(g, width=80)).to_equal("a\nb c")
    s.expect(@pretty.render(@pretty.lines(0))).to_equal("")
  })
}

///|
test "zero_width text is written but has no width" {
  let d = @pretty.group(
    @pretty.text("x") +
    @pretty.zero_width("// a comment longer than the width") +
    @pretty.line() +
    @pretty.text("y"),
  )
  inspect(
    @pretty.render(d, width=5),
    content="x// a comment longer than the width y",
  )
}

///|
test "a strict break is its unbroken text in a flat group and its broken text then a line feed in a broken one" {
  let d = @pretty.group(
    @pretty.text("[") +
    @pretty.nest(
      2,
      @pretty.break_("", " ") +
      @pretty.text("a") +
      @pretty.break_(",", ", ") +
      @pretty.text("b"),
    ) +
    @pretty.break_("", " ") +
    @pretty.text("]"),
  )
  @expect.expect_all(s => {
    s.expect(@pretty.render(d, width=80)).to_equal("[ a, b ]")
    s.expect(@pretty.render(d, width=5)).to_equal("[\n  a,\n  b\n]")
  })
}

///|
test "a flex break breaks only when the rest up to the next break does not fit" {
  let d = @pretty.text("a") +
    @pretty.flex_break("", " ") +
    @pretty.text("bbb") +
    @pretty.flex_break("", " ") +
    @pretty.text("ccc")
  @expect.expect_all(s => {
    s.expect(@pretty.render(d, width=7)).to_equal("a bbb\nccc")
    s.expect(@pretty.render(d, width=80)).to_equal("a bbb ccc")
    // In Unbroken mode a flex break never breaks.
    s.expect(@pretty.render(d, width=3, start=Unbroken)).to_equal("a bbb ccc")
  })
}

///|
test "group_alone fits its own document, group fits the rest of the line too" {
  let body = @pretty.text("a") + @pretty.line() + @pretty.text("b")
  @expect.expect_all(s => {
    s
    .expect(
      @pretty.render(@pretty.group_alone(body) + @pretty.text("cccc"), width=4),
    )
    .to_equal("a bcccc")
    s
    .expect(@pretty.render(@pretty.group(body) + @pretty.text("cccc"), width=4))
    .to_equal("a\nbcccc")
  })
}

///|
test "a nested group_alone that does not fit breaks inside a flat outer group" {
  // The outer group is checked alone and fits in 80 columns; the inner one
  // is checked again on its own line and does not fit in 5.
  let inner = @pretty.group_alone(
    @pretty.text("xx") + @pretty.break_(",", ", ") + @pretty.text("yy"),
  )
  let outer = @pretty.group_alone(
    @pretty.text("[") +
    @pretty.break_("", "") +
    inner +
    @pretty.break_("", "") +
    @pretty.text("]"),
  )
  @expect.expect_all(s => {
    s.expect(@pretty.render(outer, width=80)).to_equal("[xx, yy]")
    s.expect(@pretty.render(outer, width=5)).to_equal("[\nxx,\nyy\n]")
    s.expect(@pretty.render(outer, width=7)).to_equal("[\nxx, yy\n]")
  })
}
