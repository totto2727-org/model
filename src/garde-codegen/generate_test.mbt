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
      ("custom_with(check)", "String", "custom_with requires context"),
      ("dive_with", "String", "dive_with requires context"),
      ("pattern(\"[\")", "String", "invalid regular expression"),
      ("pattern(regex)", "String", "pattern expects one quoted"),
      ("matches(\"value\")", "String", "matches expects one unqualified"),
      ("matches(missing)", "String", "unknown record field: missing"),
      (
        "matches(value)", "String", "matches cannot refer to the annotated field itself",
      ),
      (
        "inner(matches(value))", "Array[String]", "matches is only supported directly on record fields",
      ),
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
test "reject invalid payload selectors and unattached enum attributes" {
  for
    (source, expected) in [
      (
        "#custom.garde(field(index=\"0\", matches(other)))\nstruct S(String)", "matches is only supported directly on record fields",
      ),
      (
        "#custom.garde(field(index=\"0\", skip), field(index=\"1\", ascii))\nstruct S(String)",
        "no payload field for selector index:1",
      ),
      (
        "#custom.garde(field(index=\"0\", skip), field(index=\"0\", ascii))\nstruct S(String)",
        "repeated garde field selector: index:0",
      ),
      (
        "#custom.garde\nenum E {\n  #custom.garde(field(name=\"missing\", ascii))\n  Item\n}",
        "no payload field for selector name:missing",
      ),
      (
        "enum E {\n  #custom.garde(skip)\n  Item(String)\n}", "variant #custom.garde requires #custom.garde on its enum",
      ),
      (
        "#custom.garde(bounds(U, [Length]), allow_unvalidated)\nstruct S[T](T)",
        "unknown or repeated type parameter in bounds: U",
      ),
    ] {
    let result = Ok(@garde_codegen.generate_many([("payloads.mbt", source)])) catch {
      @garde_codegen.GenerateError(message) => Err(message)
    }
    guard result is Err(message) else { fail("accepted \{source}") }
    assert_true(message.has_prefix("payloads.mbt-"), msg=message)
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
