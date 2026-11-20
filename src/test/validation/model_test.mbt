///|
test "Serde decodes business-invalid data before explicit garde validation" {
  let value : @validation.Account = @json.from_json({
    "displayName": "x",
    "level": 11,
    "address": { "code": "" },
    "locations": [{ "code": "JP" }, { "code": "A" }],
    "notes": "",
  })
  assert_eq(value.name, "x")
  assert_true(value.contact is None)
  guard @garde.validate(value) is Err(report) else {
    fail("expected the decoded value to fail explicit validation")
  }
  let issues = report.violations()
  assert_eq(issues.length(), 6)
  let paths = [ for issue in issues => Show::to_string(issue.path) ]
  assert_eq(paths, [
    "name", "name", "level", "contact", "address.code", "locations[1].code",
  ])
  assert_eq(issues[1].message, "name is reserved")
  assert_eq(issues[3].message, "is required")
  let segments = issues[5].path.segments()
  assert_eq(segments.length(), 3)
  assert_true(segments[0] is @garde.Field("locations"))
  assert_true(segments[1] is @garde.Index(1))
  assert_true(segments[2] is @garde.Field("code"))
}

///|
test "valid data accepts inclusive boundaries and skips unset optional fields" {
  let value : @validation.Account = @json.from_json({
    "displayName": "名",
    "level": -1,
    "contact": "ok",
    "locations": [{ "code": "JP" }],
    "notes": "",
  })
  assert_true(@garde.validate(value) is Ok(_))
  assert_true(@garde.validate({ ..value, level: 10, }) is Ok(_))
  let wrong_shape : @validation.Account? = Some(
    @json.from_json({
      "displayName": "Ada",
      "level": "high",
      "contact": "ok",
      "locations": [{ "code": "JP" }],
      "notes": "",
    }),
  ) catch {
    _ => None
  }
  assert_true(wrong_shape is None)
}

///|
test "nested inner validation works without a JSON codec" {
  let queue : @validation.Queue = {
    batches: [[Some(1), None], [Some(-2)]],
    name: "",
  }
  guard @garde.validate(queue) is Err(report) else {
    fail("expected the directly constructed value to fail validation")
  }
  let paths = [
    for issue in report.violations() => Show::to_string(issue.path)
  ]
  assert_eq(paths, ["batches[0][1]", "batches[1][0]"])
}

///|
fn[T : @garde.Validate] invalid_paths(value : T) -> Array[String] raise {
  guard @garde.validate(value) is Err(report) else {
    fail("expected a validation error")
  }
  [
    for issue in report.violations() => Show::to_string(issue.path)
  ]
}

///|
test "generic record and tuple/newtype validation preserve nested paths" {
  let batch : @validation.Batch[@validation.Pair, Bool] = @json.from_json({
    "items": [["Å!", null]],
    "metadata": false,
  })
  assert_eq(invalid_paths(batch), [
    "items[0][0][0]", "items[0][0][0]", "items[0][0][0]", "items[0][1]",
  ])
  let valid : @validation.Pair = @json.from_json(["ABC123", "ok"])
  assert_true(@garde.validate(valid) is Ok(_))
  let sized : @validation.NestedSized[Array[Int32]] = @validation.NestedSized(
    @validation.Sized([1]),
  )
  assert_eq(invalid_paths(sized), ["[0][0]"])
  let measured = @validation.Measured(@validation.Code("B"))
  assert_eq(invalid_paths(measured), ["[0]", "[0][0]"])
}

///|
test "generic enum validates only its active payload using MoonBit names" {
  let positional : @validation.Entry[@validation.Code] = @json.from_json({
    "kind": "code_entry",
    "data": ["B", 7],
  })
  assert_eq(invalid_paths(positional), ["CodeEntry[0][0]"])
  let named : @validation.Entry[@validation.Code] = @json.from_json({
    "kind": "named",
    "data": { "label": "plain" },
  })
  assert_eq(invalid_paths(named), ["Named.label", "Named.label"])
  let works : @validation.Entry[@validation.Code] = @json.from_json({
    "kind": "named",
    "data": { "label": "say \"hi\"!" },
  })
  let empty : @validation.Entry[@validation.Code] = @json.from_json({
    "kind": "empty",
  })
  let skipped : @validation.Entry[@validation.Code] = @json.from_json({
    "kind": "unchecked",
    "data": "",
  })
  assert_true(@garde.validate(works) is Ok(_))
  assert_true(@garde.validate(empty) is Ok(_))
  assert_true(@garde.validate(skipped) is Ok(_))
}

///|
test "same decoded value validates independently with two typed policies" {
  let request : @validation.Request = @json.from_json({
    "allocations": [{ "count": 3 }, { "count": 8 }],
  })
  assert_true(request.validate_with({ max_count: 9, }) is Ok(_))
  guard request.validate_with({ max_count: 5, }) is Err(report) else {
    fail("expected a quota violation")
  }
  assert_eq(report.violations().length(), 1)
  assert_eq(
    Show::to_string(report.violations()[0].path),
    "allocations[1].count",
  )
  assert_eq(report.violations()[0].message, "exceeds quota")
}
