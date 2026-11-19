///|
test "length counts UTF-8 bytes for strings and elements for arrays" {
  assert_eq(@garde.length("Aé名😀", Some(10), Some(10)), None)
  assert_eq(
    @garde.length("Aé名😀", None, Some(9)),
    Some("length must be at most 9"),
  )
  assert_eq(@garde.length([1, 2], Some(2), Some(2)), None)
}
