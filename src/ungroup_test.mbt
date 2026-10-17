///|
test "ungroup lets a parent and its child share line breaks" {
  let child = @pretty.group(
    @pretty.text("long") + @pretty.line() + @pretty.text("value"),
  )
  let d = @pretty.group(
    @pretty.text("(") +
    @pretty.ungroup(child) +
    @pretty.softline() +
    @pretty.text(")"),
  )
  @expect.expect_all(s => {
    s.expect(@pretty.render(d, width=12)).to_equal("(long value)")
    s.expect(@pretty.render(d, width=11)).to_equal("(long\nvalue\n)")
    s.expect(@pretty.can_break(@pretty.ungroup(child))).to_be_true()
    s
    .expect(@pretty.can_break(@pretty.text("very long atomic text")))
    .to_be_false()
  })
}

///|
test "ungroup opens only the outer groups and preserves indentation and child groups" {
  let inner = @pretty.group(
    @pretty.text("a") + @pretty.line() + @pretty.text("b"),
  )
  let outer = @pretty.group(
    @pretty.text("[") +
    @pretty.line() +
    inner +
    @pretty.line() +
    @pretty.text("]"),
  )
  let d = @pretty.group(@pretty.nest(2, @pretty.ungroup(@pretty.align(outer))))
  @expect.expect(@pretty.render(d, width=3)).to_equal("[\na b\n]")
}

///|
test "ungroup opens both conditional branches and group_alone" {
  let arm = (a : String, b : String) => {
    @pretty.group_alone(@pretty.text(a) + @pretty.line() + @pretty.text(b))
  }
  let d = @pretty.group(
    @pretty.text("[") +
    @pretty.line() +
    @pretty.ungroup(@pretty.if_break(arm("b", "c"), arm("a", "z"))),
  )
  @expect.expect_all(s => {
    s.expect(@pretty.render(d, width=80)).to_equal("[ a z")
    s.expect(@pretty.render(d, width=2)).to_equal("[\nb\nc")
    s.expect(@pretty.can_break(@pretty.raw_text("a\nb"))).to_be_false()
    s.expect(@pretty.can_break(@pretty.group(@pretty.hardline()))).to_be_true()
  })
}

///|
test "ungroup traverses deep wrappers without recursion" {
  let mut d = @pretty.group(
    @pretty.text("a") + @pretty.line() + @pretty.text("b"),
  )
  for _ in 0..<10000 {
    d = @pretty.nest(0, d)
  }
  let d = @pretty.ungroup(d)
  @expect.expect(@pretty.render(d)).to_equal("a\nb")
}
