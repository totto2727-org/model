///|
test "reject invalid rules at the field's source location" {
  for
    (attribute, field_type, expected) in [
      ("length(min=2)", "String", "malformed #custom.garde"),
      ("length(min=\"-1\")", "String", "bounds must be non-negative"),
      ("range(min=\"2147483648\")", "Int", "must be a decimal Int"),
      ("range(min=\"2\", max=\"1\")", "Int", "min cannot exceed max"),
      ("length(min=\"1\", equal=\"2\")", "String", "equal cannot be combined"),
      ("inner(required)", "String", "inner expects an Array"),
      ("required", "Int", "required expects Option"),
      ("skip, dive", "String", "unknown or invalid garde rule"),
    ] {
    let source = "#custom.garde\nstruct S {\n  #custom.garde(\{attribute})\n  value : \{field_type}\n}\n"
    let result = Ok(@garde_codegen.generate_many([("rules.mbt", source)])) catch {
      @garde_codegen.GenerateError(message) => Err(message)
    }
    guard result is Err(message) else { fail("accepted \{attribute}") }
    assert_true(message.has_prefix("rules.mbt-3:"), msg=message)
    assert_true(message.contains(expected), msg=message)
  }
}

///|
test "reject an unmarked field unless the struct opts in" {
  let source = "#custom.garde\nstruct S { value : Int }\n"
  let result = Ok(@garde_codegen.generate_many([("rules.mbt", source)])) catch {
    @garde_codegen.GenerateError(message) => Err(message)
  }
  guard result is Err(message) else { fail("accepted an unmarked field") }
  assert_true(message.contains("field needs a garde rule"), msg=message)
}
