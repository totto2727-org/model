///|
test "Serde decodes business-invalid data before explicit garde validation" {
  let value : @models.Account = @json.from_json({
    "displayName": "x",
    "level": 11,
    "address": { "code": "" },
    "locations": [{ "code": "JP" }, { "code": "A" }],
    "notes": "",
  })
  assert_eq(value.name, "x")
  assert_true(value.contact is None)
  guard @garde_api.validate(value) is Err(report) else {
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
  assert_true(segments[0] is @garde_api.Field("locations"))
  assert_true(segments[1] is @garde_api.Index(1))
  assert_true(segments[2] is @garde_api.Field("code"))
}

///|
test "valid data accepts inclusive boundaries and skips unset optional fields" {
  let value : @models.Account = @json.from_json({
    "displayName": "名😀",
    "level": -1,
    "contact": "ok",
    "locations": [{ "code": "JP" }],
    "notes": "",
  })
  assert_true(@garde_api.validate(value) is Ok(_))
  assert_true(@garde_api.validate({ ..value, name: "名", }) is Err(_))
  assert_true(@garde_api.validate({ ..value, level: 10, }) is Ok(_))
  let wrong_shape : @models.Account? = Some(
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
  let queue : @models.Queue = {
    batches: [[Some(1), None], [Some(-2)]],
    name: "",
  }
  guard @garde_api.validate(queue) is Err(report) else {
    fail("expected the directly constructed value to fail validation")
  }
  let paths = [
    for issue in report.violations() => Show::to_string(issue.path)
  ]
  assert_eq(paths, ["batches[0][1]", "batches[1][0]"])
}

///|
fn[T : @garde_api.Validate] invalid_paths(value : T) -> Array[String] raise {
  guard @garde_api.validate(value) is Err(report) else {
    fail("expected a validation error")
  }
  [
    for issue in report.violations() => Show::to_string(issue.path)
  ]
}

///|
test "contact rules check formats only after a successful decode" {
  let contact : @models.ContactDetails = @json.from_json({
    "email": "ü@bücher.example",
    "website": "https://example.com/profile",
    "addresses": ["192.0.2.20", "2001:db8::1"],
    "v4": "192.0.2.20",
    "v6": "2001:db8::1",
    "phone": "+81 90-1234-5678",
  })
  assert_true(@garde_api.validate(contact) is Ok(_))
  let invalid : @models.ContactDetails = {
    email: "no-domain@",
    website: "/profile",
    addresses: ["example.com"],
    v4: Some("2001:db8::1"),
    v6: Some("192.0.2.20"),
    phone: Some("+81 90-1234"),
  }
  assert_eq(invalid_paths(invalid), [
    "email", "website", "addresses[0]", "v4", "v6", "phone",
  ])
}

///|
test "typed bounds, sibling context, and conditional transparent validation preserve paths" {
  let defaults : @models.OrderChecks = {
    strict: false,
    product: Some(@models.ProductCode("missing-prefix")),
    quantity: 9007199254740993L,
    multiplier: 0.5,
    policy: { max_count: 2, },
    allocations: [{ count: 2, }],
  }
  assert_true(@garde_api.validate(defaults) is Ok(_))
  assert_eq(invalid_paths({ ..defaults, strict: true, }), ["product"])
  assert_eq(invalid_paths({ ..defaults, strict: true, product: None, }), [
    "product",
  ])
  assert_eq(
    invalid_paths({
      ..defaults,
      quantity: 9007199254740992L,
      multiplier: 2.6,
      allocations: [{ count: 3, }],
    }),
    ["quantity", "multiplier", "allocations[0].count"],
  )
}

///|
test "regex and sibling constraints run only after JSON decoding" {
  let value : @models.Confirmation = @json.from_json({
    "code": "prefix-ID-42.",
    "repeatedCode": "ID-42.",
  })
  guard @garde_api.validate(value) is Err(report) else {
    fail("expected two validation failures")
  }
  let issues = report.violations()
  assert_eq(issues.length(), 2)
  assert_eq(Show::to_string(issues[0].path), "repeated")
  assert_eq(issues[0].message, "must match code")
  assert_eq(Show::to_string(issues[1].path), "code")
  assert_eq(issues[1].message, "does not match the pattern")
  let valid : @models.Confirmation = {
    code: Some("ID-42."),
    repeated: Some("ID-42."),
  }
  let absent : @models.Confirmation = { code: None, repeated: None, }
  assert_true(@garde_api.validate(valid) is Ok(_))
  assert_true(@garde_api.validate(absent) is Ok(_))
  assert_eq(invalid_paths({ ..valid, repeated: None, }), ["repeated"])
}

///|
test "sibling equality infers Eq for generic fields" {
  let same : @models.Same[Int32] = { original: 1, repeated: 1, }
  assert_true(@garde_api.validate(same) is Ok(_))
  assert_eq(invalid_paths({ ..same, repeated: 2, }), ["repeated"])
}

///|
test "generic record and tuple/newtype validation preserve nested paths" {
  let batch : @models.Batch[@models.Pair, Bool] = @json.from_json({
    "items": [["Å!", null]],
    "metadata": false,
  })
  assert_eq(invalid_paths(batch), [
    "items[0][0][0]", "items[0][0][0]", "items[0][0][0]", "items[0][1]",
  ])
  let valid : @models.Pair = @json.from_json(["ABC123", "ok"])
  assert_true(@garde_api.validate(valid) is Ok(_))
  let sized : @models.NestedSized[Array[Int32]] = @models.NestedSized(
    @models.Sized([1]),
  )
  assert_eq(invalid_paths(sized), ["[0][0]"])
  let measured = @models.Measured(@models.Code("B"))
  assert_eq(invalid_paths(measured), ["[0]", "[0][0]"])
}

///|
test "generic enum validates only its active payload using MoonBit names" {
  let positional : @models.Entry[@models.Code] = @json.from_json({
    "kind": "code_entry",
    "data": ["B", 7],
  })
  assert_eq(invalid_paths(positional), ["CodeEntry[0][0]"])
  let named : @models.Entry[@models.Code] = @json.from_json({
    "kind": "named",
    "data": { "label": "plain" },
  })
  assert_eq(invalid_paths(named), ["Named.label", "Named.label"])
  let works : @models.Entry[@models.Code] = @json.from_json({
    "kind": "named",
    "data": { "label": "say \"hi\"!" },
  })
  let empty : @models.Entry[@models.Code] = @json.from_json({ "kind": "empty" })
  let skipped : @models.Entry[@models.Code] = @json.from_json({
    "kind": "unchecked",
    "data": "",
  })
  assert_true(@garde_api.validate(works) is Ok(_))
  assert_true(@garde_api.validate(empty) is Ok(_))
  assert_true(@garde_api.validate(skipped) is Ok(_))
}

///|
test "range bounds follow the field's numeric type" {
  let valid : @models.NumericRanges = {
    wide: 9007199254740993L,
    unsigned: 18446744073709551615UL,
    huge: 1000000000000000000000000000001N,
    single: 1.0F,
    double: -0.125,
    base16: 0x20,
  }
  assert_true(@garde_api.validate(valid) is Ok(_))
  let invalid : @models.NumericRanges = {
    wide: 9007199254740992L,
    unsigned: 18446744073709551613UL,
    huge: 1000000000000000000000000000000N,
    single: 1.0000002F,
    double: -0.25,
    base16: 0x21,
  }
  assert_eq(invalid_paths(invalid), [
    "wide", "unsigned", "huge", "single", "double", "base16",
  ])
}

///|
test "adjacent wide integers do not collapse when checking a reversed range" {
  let lower : @models.ReversedRange = { wide: 9007199254740992L, }
  let upper : @models.ReversedRange = { wide: 9007199254740993L, }
  assert_eq(invalid_paths(lower), ["wide"])
  assert_eq(invalid_paths(upper), ["wide"])
}

///|
test "same decoded value validates independently with two typed policies" {
  let request : @models.Request = @json.from_json({
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
