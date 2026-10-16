Feature: Unicode data tables
  `ucd.mbtx` reads the Unicode Character Database files that UAX #29
  grapheme segmentation needs and writes MoonBit tables and the
  conformance test.

  Scenario Outline: Parse a property line
    When I parse the property line "<line>"
    Then the range is <lo> to <hi> with value "<value>"

    Examples:
      | line                                                         | lo   | hi   | value       |
      | 0600..0605    ; Prepend # Cf   [6] ARABIC NUMBER SIGN..       | 1536 | 1541 | Prepend     |
      | 06DD          ; Prepend # Cf       ARABIC END OF AYAH         | 1757 | 1757 | Prepend     |
      | 094D          ; InCB; Linker # Mn       DEVANAGARI SIGN VIRAMA | 2381 | 2381 | InCB Linker |

  Scenario Outline: Skip a line that is not a property line
    When I parse the property line "<line>"
    Then there is no range

    Examples:
      | line                                      |
      | # GraphemeBreakProperty-17.0.0.txt        |
      |                                           |
      | # @missing: 0000..10FFFF; InCB; None      |

  Scenario: Merge adjacent ranges of one value
    Given the ranges "0x41-0x5A Extend, 0x5B-0x60 Extend, 0x61-0x7A Other, 0x7B-0x7B Other"
    When I merge the ranges
    Then the ranges are "0x41-0x60 Extend, 0x61-0x7B Other"

  Scenario: Read the Unicode version from the file header
    When I read the version of "# GraphemeBreakProperty-17.0.0.txt"
    Then the version is "17.0.0"

  Scenario: Parse a conformance line
    When I parse the conformance line "÷ 0020 × 0308 ÷ 1F1E6 × 1F1E7 ÷	#  ÷ [0.2] SPACE (Other) × [9.0] COMBINING DIAERESIS"
    Then the code points are "0x20, 0x308, 0x1F1E6, 0x1F1E7"
    And the boundaries are "0, 2"

  Scenario: Render a table
    Given the ranges "0x41-0x60 Extend, 0x61-0x7B Other"
    When I render the table "gcb_table" of "Gcb"
    Then the rendered text is:
      """
      let gcb_table : Array[(Int, Int, Gcb)] = [
        (0x41, 0x60, Extend),
        (0x61, 0x7B, Other),
      ]
      """
