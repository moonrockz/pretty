///|
/// Any UTF-16 text: code units picked from the classes the rules look at,
/// so it holds surrogates in every combination, control characters, marks,
/// joiners, regional indicators and conjuncts.
struct Units(String) derive(Debug)

///|
let picks : Array[Int32] = [
  0x61, 0x301, 0x200D, 0x1F1E6, 0x1F469, 0x1F680, 0x915, 0x94D, 0xD, 0xA, 0x600,
  0x1100, 0x1161, 0xD800, 0xDC00, 0x41,
]

///|
impl @quickcheck.Arbitrary for Units with fn arbitrary(size, rs) {
  let n = rs
    .next_uint(limit=(size + 1).reinterpret_as_uint())
    .reinterpret_as_int()
  let sb = StringBuilder()
  for _ in 0..<n {
    let cp = picks[rs
      .next_uint(limit=picks.length().reinterpret_as_uint())
      .reinterpret_as_int()]
    if cp >= 0xD800 && cp <= 0xDFFF {
      sb.write_char(cp.unsafe_to_char())
    } else {
      sb.write_char(cp.to_char().unwrap())
    }
  }
  Units(sb.to_string())
}

///|
impl @quickcheck.Shrink for Units

///|
test "law: boundaries start at 0, increase strictly and stay inside the text; count is their number" {
  @quickcheck.check(
    (u : Units) => {
      let Units(s) = u
      let b = @grapheme.boundaries(s)
      let ok_first = s.is_empty() || (b.length() > 0 && b[0] == 0)
      let mut increasing = true
      for i in 1..<b.length() {
        if b[i] <= b[i - 1] || b[i] >= s.length() {
          increasing = false
        }
      }
      ok_first && increasing && @grapheme.count(s) == b.length()
    },
    count=300,
    max_size=30,
    seed=2026,
  )
}

///|
test "law: count is at most the number of code points and at least 1 for non-empty text" {
  @quickcheck.check(
    (u : Units) => {
      let Units(s) = u
      let mut cps = 0
      for _ in s {
        cps += 1
      }
      let c = @grapheme.count(s)
      c <= cps && (s.is_empty() || c >= 1)
    },
    count=300,
    max_size=30,
    seed=2027,
  )
}

///|
test "law: count of a concatenation is at most the sum of the counts" {
  @quickcheck.check(
    (p : (Units, Units)) => {
      let (Units(a), Units(b)) = p
      @grapheme.count(a + b) <= @grapheme.count(a) + @grapheme.count(b)
    },
    count=300,
    max_size=20,
    seed=2028,
  )
}
