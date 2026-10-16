///|
/// The string of these code points (no surrogate code points).
fn from_code_points(cps : Array[Int32]) -> String {
  let sb = StringBuilder()
  for cp in cps {
    sb.write_char(cp.to_char().unwrap())
  }
  sb.to_string()
}

///|
test "count of plain text is its length; the empty string has no cluster" {
  @expect.expect_all(s => {
    s.expect(@grapheme.count("")).to_equal(0)
    s.expect(@grapheme.boundaries("")).to_equal([])
    s.expect(@grapheme.count("hello")).to_equal(5)
    s.expect(@grapheme.boundaries("ab")).to_equal([0, 1])
  })
}

///|
test "combining marks, CRLF, ZWJ emoji, flags, Hangul and prepend join as UAX #29 says" {
  @expect.expect_all(s => {
    // e + combining acute: one cluster (GB9)
    s.expect(@grapheme.count(from_code_points([0x65, 0x301]))).to_equal(1)
    // CR LF: one cluster (GB3); LF CR: two (GB4, GB5)
    s.expect(@grapheme.count("\r\n")).to_equal(1)
    s.expect(@grapheme.count("\n\r")).to_equal(2)
    // woman + ZWJ + rocket: one cluster (GB11) in a 5-unit string
    s
    .expect(@grapheme.boundaries(from_code_points([0x1F469, 0x200D, 0x1F680])))
    .to_equal([0])
    // two flags (four regional indicators): two clusters (GB12)
    s
    .expect(
      @grapheme.boundaries(
        from_code_points([0x1F1E6, 0x1F1E7, 0x1F1E8, 0x1F1E9]),
      ),
    )
    .to_equal([0, 4])
    // Hangul L V T: one cluster (GB6, GB7)
    s
    .expect(@grapheme.count(from_code_points([0x1100, 0x1161, 0x11A8])))
    .to_equal(1)
    // Devanagari ka + virama + ka: one cluster (GB9c)
    s
    .expect(@grapheme.count(from_code_points([0x915, 0x94D, 0x915])))
    .to_equal(1)
    // prepend (Arabic number sign) + digit: one cluster (GB9b); a prepend at the end stays one
    s.expect(@grapheme.count(from_code_points([0x600, 0x661]))).to_equal(1)
    s.expect(@grapheme.count(from_code_points([0x61, 0x600]))).to_equal(2)
    // a lone surrogate is one cluster (Control), and a pair is one
    s
    .expect(@grapheme.count(String::from_array([(0xD800).unsafe_to_char()])))
    .to_equal(1)
    s.expect(@grapheme.count(from_code_points([0x1F600]))).to_equal(1)
  })
}
