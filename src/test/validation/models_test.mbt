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
