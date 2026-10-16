///|
/// Grapheme_Cluster_Break values (UAX #29, table 2).
priv enum Gcb {
  Other
  CR
  LF
  Control
  Extend
  ZWJ
  RegionalIndicator
  Prepend
  SpacingMark
  L
  V
  T
  LV
  LVT
}

///|
/// Indic_Conjunct_Break values (UAX #29, rule GB9c).
priv enum Incb {
  NoIncb
  Consonant
  Linker
  IncbExtend
}

///|
/// The properties of one code point.
priv struct Props {
  gcb : Gcb
  ext_pict : Bool
  incb : Incb
}

///|
/// Binary search of a sorted range table.
fn[T] lookup(table : Array[(Int32, Int32, T)], cp : Int32) -> T? {
  let mut lo = 0
  let mut hi = table.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, end, value) = table[mid]
    if cp < start {
      hi = mid - 1
    } else if cp > end {
      lo = mid + 1
    } else {
      return Some(value)
    }
  }
  None
}

///|
fn in_flag_table(table : Array[(Int32, Int32)], cp : Int32) -> Bool {
  let mut lo = 0
  let mut hi = table.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (start, end) = table[mid]
    if cp < start {
      hi = mid - 1
    } else if cp > end {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn props(cp : Int32) -> Props {
  {
    gcb: lookup(gcb_table, cp).unwrap_or(Other),
    ext_pict: in_flag_table(ext_pict_table, cp),
    incb: lookup(incb_table, cp).unwrap_or(NoIncb),
  }
}

///|
/// The code point at UTF-16 offset `i` and its width in code units. A
/// surrogate pair is one code point; a lone surrogate is itself.
fn decode(units : ArrayView[UInt16], i : Int32) -> (Int32, Int32) {
  let u = units[i].to_int()
  if u >= 0xD800 && u < 0xDC00 && i + 1 < units.length() {
    let v = units[i + 1].to_int()
    if v >= 0xDC00 && v < 0xE000 {
      return (0x10000 + ((u - 0xD800) << 10) + (v - 0xDC00), 2)
    }
  }
  (u, 1)
}

///|
/// The run of code points before the current one that rule GB11 looks at.
priv enum Emoji {
  NoEmoji
  AfterPict // Extended_Pictographic Extend*
  AfterZwj // Extended_Pictographic Extend* ZWJ
}

///|
/// The run of code points before the current one that rule GB9c looks at.
priv enum Conjunct {
  NoConjunct
  AfterConsonant(Bool) // Consonant [Extend Linker]*; the Bool: a Linker was seen
}

///|
/// Whether a cluster starts between `prev` and `cur` (rules GB3 to
/// GB999 of UAX #29). `ri_run` is the number of consecutive regional
/// indicators ending at `prev`.
fn breaks(
  prev : Props,
  cur : Props,
  ri_run : Int32,
  emoji : Emoji,
  conjunct : Conjunct,
) -> Bool {
  match (prev.gcb, cur.gcb) {
    (CR, LF) => false // GB3
    (Control | CR | LF, _) => true // GB4
    (_, Control | CR | LF) => true // GB5
    (L, L | V | LV | LVT) => false // GB6
    (LV | V, V | T) => false // GB7
    (LVT | T, T) => false // GB8
    (_, Extend | ZWJ) => false // GB9
    (_, SpacingMark) => false // GB9a
    (Prepend, _) => false // GB9b
    _ =>
      if conjunct is AfterConsonant(true) && cur.incb is Consonant {
        false // GB9c
      } else if prev.gcb is ZWJ && emoji is AfterZwj && cur.ext_pict {
        false // GB11
      } else if prev.gcb is RegionalIndicator &&
        cur.gcb is RegionalIndicator &&
        ri_run % 2 == 1 {
        false // GB12, GB13
      } else {
        true // GB999
      }
  }
}

///|
/// Call `f` with the UTF-16 offset of every cluster start, in order.
fn each_boundary(s : String, f : (Int32) -> Unit) -> Unit {
  let units = s.code_units()
  let n = units.length()
  let mut i = 0
  let mut prev : Props? = None
  let mut ri_run = 0
  let mut emoji : Emoji = NoEmoji
  let mut conjunct : Conjunct = NoConjunct
  while i < n {
    let (cp, w) = decode(units, i)
    let cur = props(cp)
    let starts = match prev {
      None => true
      Some(p) => breaks(p, cur, ri_run, emoji, conjunct)
    }
    if starts {
      f(i)
    }
    ri_run = if cur.gcb is RegionalIndicator { ri_run + 1 } else { 0 }
    emoji = if cur.ext_pict {
      AfterPict
    } else {
      match (emoji, cur.gcb) {
        (AfterPict, Extend) => AfterPict
        (AfterPict, ZWJ) => AfterZwj
        _ => NoEmoji
      }
    }
    conjunct = match (conjunct, cur.incb) {
      (_, Consonant) => AfterConsonant(false)
      (AfterConsonant(_), Linker) => AfterConsonant(true)
      (AfterConsonant(seen), IncbExtend) => AfterConsonant(seen)
      _ => NoConjunct
    }
    prev = Some(cur)
    i += w
  }
}

///|
/// The number of extended grapheme clusters in `s` (UAX #29, Unicode
/// `version()`). A user sees one cluster as one character: `e` with a
/// combining accent, a flag of two regional indicators or an emoji
/// sequence joined with ZWJ is one. `count("")` is 0; a lone surrogate
/// counts as one.
///
/// ```mbt check
/// test {
///   inspect(@grapheme.count("hello"), content="5")
///   inspect(@grapheme.count("e\u{301}"), content="1")
///   inspect(@grapheme.count("\r\n"), content="1")
/// }
/// ```
pub fn count(s : String) -> Int32 {
  let mut n = 0
  each_boundary(s, _ => n += 1)
  n
}

///|
/// The UTF-16 offsets where a cluster of `s` starts, in order; `[]` for
/// `""`. The first offset is 0 and every offset is less than the length of
/// `s`.
///
/// ```mbt check
/// test {
///   debug_inspect(@grapheme.boundaries("ab\u{301}c"), content="[0, 1, 3]")
/// }
/// ```
pub fn boundaries(s : String) -> Array[Int32] {
  let out = []
  each_boundary(s, i => out.push(i))
  out
}

///|
/// The Unicode version of the tables.
pub fn version() -> String {
  unicode_version
}
