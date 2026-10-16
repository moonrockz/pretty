///|
/// A document built from the pretty-arena forms. Texts hold no spaces and
/// no line feeds, so a line's width is its length.
enum Arena {
  AText(String)
  AZero(String)
  ALines(Int32)
  ABreak(String, String, Bool) // broken, unbroken, flex
  AGroup(Arena)
  AForce(Arena)
  ANext(Arena, Bool) // enabled
  ANest(Int32, Arena)
  ANestIfBroken(Int32, Arena)
  ASetNesting(Int32, Arena)
  ACat(Arena, Arena)
} derive(Debug)

///|
fn arena_pick(rs : @splitmix.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn gen_arena(size : Int32, rs : @splitmix.RandomState) -> Arena {
  if size <= 1 {
    return match arena_pick(rs, 10) {
      0 => ALines(1 + arena_pick(rs, 2))
      1 => AZero(["//c", "//comment"][arena_pick(rs, 2)])
      2 | 3 | 4 =>
        ABreak(
          ["", ","][arena_pick(rs, 2)],
          ["", " ", ", "][arena_pick(rs, 3)],
          arena_pick(rs, 2) == 0,
        )
      _ => AText(["a", "bb", "ccc", "dddd", "e😀"][arena_pick(rs, 5)])
    }
  }
  let s = size / 2
  match arena_pick(rs, 10) {
    0 => ANest(arena_pick(rs, 4), gen_arena(s, rs))
    1 => ANestIfBroken(arena_pick(rs, 4), gen_arena(s, rs))
    2 => ASetNesting(arena_pick(rs, 4), gen_arena(s, rs))
    3 => AForce(gen_arena(s, rs))
    4 => ANext(gen_arena(s, rs), arena_pick(rs, 2) == 0)
    5 | 6 => AGroup(gen_arena(s, rs))
    _ => ACat(gen_arena(s, rs), gen_arena(s, rs))
  }
}

///|
struct ArbArena(Arena) derive(Debug)

///|
impl @quickcheck.Arbitrary for ArbArena with fn arbitrary(size, rs) {
  ArbArena(gen_arena(size, rs))
}

///|
impl @quickcheck.Shrink for ArbArena

///|
fn arena_doc(a : Arena) -> @pretty.Doc {
  match a {
    AText(t) => @pretty.text(t)
    AZero(t) => @pretty.zero_width(t)
    ALines(n) => @pretty.lines(n)
    ABreak(b, u, true) => @pretty.flex_break(b, u)
    ABreak(b, u, false) => @pretty.break_(b, u)
    AGroup(x) => @pretty.group_alone(arena_doc(x))
    AForce(x) => @pretty.force_break(arena_doc(x))
    ANext(x, true) => @pretty.next_break_fits(arena_doc(x), Enabled)
    ANext(x, false) => @pretty.next_break_fits(arena_doc(x), Disabled)
    ANest(n, x) => @pretty.nest(n, arena_doc(x))
    ANestIfBroken(n, x) => @pretty.nest_if_broken(n, arena_doc(x))
    ASetNesting(n, x) => @pretty.set_nesting(n, arena_doc(x))
    ACat(x, y) => arena_doc(x) + arena_doc(y)
  }
}

///|
/// pretty-arena's `Mode`.
enum AMode {
  MUnbroken
  MBroken
  MForcedBroken
  MForcedUnbroken
} derive(Eq)

///|
/// A queue item of the reference model: indentation, mode, document.
struct AItem {
  indent : Int32
  mode : AMode
  doc : Arena
}

///|
fn width_of(t : String) -> Int32 {
  @grapheme.count(t)
}

///|
/// pretty-arena's `fits`, written from `pretty-arena/src/lib.rs` as it is:
/// a queue, popped from the front.
fn arena_fits(limit : Int32, width : Int32, docs : @list.List[AItem]) -> Bool {
  let mut current = width
  let mut queue = docs
  while true {
    if current > limit {
      return false
    }
    let item = match queue {
      Empty => return true
      More(i, tail~) => {
        queue = tail
        i
      }
    }
    let same = (d : Arena) => queue = queue.prepend({ ..item, doc: d, })
    match item.doc {
      AForce(d) =>
        match item.mode {
          MForcedBroken => same(d)
          MBroken | MUnbroken | MForcedUnbroken => return false
        }
      ALines(_) => return true
      ANest(i, d) =>
        queue = queue.prepend({ ..item, indent: item.indent + i, doc: d, })
      ASetNesting(i, d) => queue = queue.prepend({ ..item, indent: i, doc: d, })
      ANestIfBroken(_, d) => same(d)
      AGroup(d) =>
        match item.mode {
          MBroken => queue = queue.prepend({ ..item, mode: MUnbroken, doc: d, })
          MUnbroken | MForcedBroken | MForcedUnbroken => same(d)
        }
      AText(t) => current += width_of(t)
      AZero(_) => ()
      ABreak(_, unbroken, _) =>
        match item.mode {
          MBroken | MForcedBroken => return true
          MUnbroken | MForcedUnbroken => current += width_of(unbroken)
        }
      ANext(d, false) =>
        queue = queue.prepend({ ..item, mode: MForcedUnbroken, doc: d, })
      ANext(d, true) =>
        match item.mode {
          MForcedUnbroken => same(d)
          MBroken | MUnbroken | MForcedBroken =>
            queue = queue.prepend({ ..item, mode: MForcedBroken, doc: d, })
        }
      ACat(a, b) =>
        queue = queue.prepend({ ..item, doc: b, }).prepend({ ..item, doc: a, })
    }
  }
  false
}

///|
/// pretty-arena's `format`, written from `pretty-arena/src/lib.rs` as it
/// is: it writes the indentation right after every line feed.
fn arena_format(limit : Int32, doc : Arena) -> String {
  let out = StringBuilder()
  let mut width = 0
  let mut queue : @list.List[AItem] = @list.List([]).prepend({
    indent: 0,
    mode: MUnbroken,
    doc,
  })
  let newline = (indent : Int32) => {
    out.write_char('\n')
    out.write_string(" ".repeat(indent))
    width = indent
  }
  while queue is More(item, tail~) {
    queue = tail
    let same = (d : Arena) => queue = queue.prepend({ ..item, doc: d, })
    match item.doc {
      ALines(n) => {
        for _ in 0..<n {
          out.write_char('\n')
        }
        out.write_string(" ".repeat(item.indent))
        width = item.indent
      }
      ABreak(broken, unbroken, true) => {
        let unbroken_width = width + width_of(unbroken)
        if item.mode == MUnbroken || arena_fits(limit, unbroken_width, queue) {
          out.write_string(unbroken)
          width = unbroken_width
        } else {
          out.write_string(broken)
          newline(item.indent)
        }
      }
      ABreak(broken, unbroken, false) =>
        match item.mode {
          MBroken | MForcedBroken => {
            out.write_string(broken)
            newline(item.indent)
          }
          MUnbroken | MForcedUnbroken => {
            out.write_string(unbroken)
            width += width_of(unbroken)
          }
        }
      AText(t) => {
        width += width_of(t)
        out.write_string(t)
      }
      AZero(t) => out.write_string(t)
      ACat(a, b) =>
        queue = queue.prepend({ ..item, doc: b, }).prepend({ ..item, doc: a, })
      ANest(i, d) =>
        queue = queue.prepend({ ..item, indent: item.indent + i, doc: d, })
      ASetNesting(i, d) => queue = queue.prepend({ ..item, indent: i, doc: d, })
      ANestIfBroken(i, d) =>
        match item.mode {
          MBroken =>
            queue = queue.prepend({ ..item, indent: item.indent + i, doc: d, })
          MUnbroken | MForcedBroken | MForcedUnbroken => same(d)
        }
      AGroup(d) => {
        let group = @list.List([]).prepend({ ..item, mode: MUnbroken, doc: d, })
        if arena_fits(limit, width, group) {
          queue = queue.prepend({ ..item, mode: MUnbroken, doc: d, })
        } else {
          queue = queue.prepend({ ..item, mode: MBroken, doc: d, })
        }
      }
      AForce(d) | ANext(d, _) => same(d)
    }
  }
  out.to_string()
}

///|
/// Trailing spaces removed from every line: the model writes the
/// indentation at once, the engine writes it before the next text.
fn trimmed(s : String) -> String {
  s.split("\n").map(l => l.trim_end(chars=" ").to_owned()).collect().join("\n")
}

///|
let arena_widths : Array[Int32] = [0, 1, 4, 8, 16, 80]

///|
test "law: render agrees with a port of pretty-arena's format and fits at every width, up to trailing spaces" {
  @quickcheck.check(
    (a : ArbArena) => {
      let ArbArena(spec) = a
      let doc = arena_doc(spec)
      arena_widths
      .iter()
      .all(w => {
        trimmed(@pretty.render(doc, width=w, start=Unbroken)) ==
        trimmed(arena_format(w, spec))
      })
    },
    count=500,
    max_size=40,
    seed=2029,
  )
}

///|
test "law: zero_width text never changes the layout of the text around it" {
  @quickcheck.check(
    (a : ArbArena) => {
      let ArbArena(spec) = a
      let with_comment = @pretty.zero_width("//xxxxxxxx") + arena_doc(spec)
      let without = arena_doc(spec)
      arena_widths
      .iter()
      .all(w => {
        @pretty.render(with_comment, width=w, start=Unbroken) ==
        "//xxxxxxxx" + @pretty.render(without, width=w, start=Unbroken)
      })
    },
    count=200,
    max_size=30,
    seed=2030,
  )
}

///|
test "law: a disabled next_break_fits with no enabled one inside renders as its document" {
  @quickcheck.check(
    (a : ArbArena) => {
      let ArbArena(spec) = a
      let doc = arena_doc(spec)
      arena_widths
      .iter()
      .all(w => {
        @pretty.render(
          @pretty.next_break_fits(doc, Disabled),
          width=w,
          start=Unbroken,
        ) ==
        @pretty.render(doc, width=w, start=Unbroken)
      })
    },
    count=200,
    max_size=30,
    seed=2031,
  )
}
