///|
test "length uses MoonBit string length and counts array elements" {
  assert_eq(@garde.length("Aé名😀", Some(5), Some(5)), None)
  assert_eq(
    @garde.length("Aé名😀", None, Some(4)),
    Some("length must be at most 4"),
  )
  assert_eq(@garde.length([1, 2], Some(2), Some(2)), None)
}

///|
test "ascii and alphanumeric check distinct character classes" {
  assert_eq(@garde.ascii(""), None)
  assert_eq(@garde.ascii("A_~\n"), None)
  assert_true(@garde.ascii("é") is Some(_))
  assert_eq(@garde.alphanumeric(""), None)
  assert_eq(@garde.alphanumeric("Az09"), None)
  assert_true(@garde.alphanumeric("A_9") is Some(_))
  assert_eq(@garde.alphanumeric("é漢９²"), None)
  assert_true(@garde.alphanumeric("😀") is Some(_))
}

///|
test "contains, prefix and suffix match literal strings at the right positions" {
  assert_eq(@garde.contains("前.😀後", ".😀"), None)
  assert_true(@garde.contains("abc", "B") is Some(_))
  assert_eq(@garde.prefix("前.😀後", "前."), None)
  assert_true(@garde.prefix("前.😀後", "😀後") is Some(_))
  assert_eq(@garde.suffix("前.😀後", "😀後"), None)
  assert_true(@garde.suffix("前.😀後", "前.") is Some(_))
  assert_eq(@garde.contains("abc", ""), None)
  assert_eq(@garde.prefix("abc", ""), None)
  assert_eq(@garde.suffix("abc", ""), None)
}

///|
struct ValidationContext {
  min : Int32
  max : Int32
}

///|
test "validate_using captures a typed context and returns ordered violations" {
  let context = { min: 5, max: 10, }
  let collect : (Int32, @garde.Report, @garde.Path) -> Unit = fn(
    value,
    report,
    path,
  ) {
    if value < context.min {
      report.add(path, "below minimum")
      report.add(path.field("items").index(2), "check item")
    }
    if value > context.max {
      report.add(path, "above maximum")
    }
  }
  assert_true(@garde.validate_using(7, collect) is Ok(_))
  match @garde.validate_using(4, collect) {
    Ok(_) => fail("expected violations")
    Err(report) => {
      let violations = report.violations()
      assert_eq(violations.length(), 2)
      assert_eq(violations[0].path.segments().length(), 0)
      assert_true(violations[1].path.segments() == [Field("items"), Index(2)])
      assert_eq(
        Show::to_string(report),
        "<root>: below minimum\nitems[2]: check item",
      )
    }
  }
}

///|
test "regular expressions search unless anchored" {
  assert_true(@garde.pattern("ref-ID-42", "ID-[0-9]+") is None)
  assert_true(@garde.pattern("ref-ID-42", "^ID-[0-9]+$") is Some(_))
  assert_true(@garde.pattern("ID-42", "[") is Some(_))
}
