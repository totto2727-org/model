///|
test "Record FromJson::from_json - missing option and defaults" {
  let decoded : @roundtrip.Record = @json.from_json({
    "required": 7,
    "displayName": "Ada",
  })
  @test.assert_eq(decoded, {
    required: 7,
    optional: None,
    count: 0,
    name: "Ada",
    transient: 0,
    omitted: None,
  })
}

///|
test "Record FromJson::from_json - null option and ignored fields" {
  let decoded : @roundtrip.Record = @json.from_json({
    "required": 7,
    "optional": null,
    "displayName": "Ada",
    "transient": "ignored even when malformed",
    "unknown": true,
  })
  @test.assert_eq(decoded, {
    required: 7,
    optional: None,
    count: 0,
    name: "Ada",
    transient: 0,
    omitted: None,
  })
}

///|
test "Record ToJson::to_json - null option and skipped fields" {
  let record : @roundtrip.Record = {
    required: 7,
    optional: None,
    count: 0,
    name: "Ada",
    transient: 42,
    omitted: None,
  }
  json_inspect(record, content={
    "required": 7,
    "optional": null,
    "count": 0,
    "displayName": "Ada",
  })
}

///|
test "Record ToJson::to_json - present option survives roundtrip" {
  let record : @roundtrip.Record = {
    required: 7,
    optional: Some("present"),
    count: 3,
    name: "Ada",
    transient: 0,
    omitted: Some(9),
  }
  json_inspect(record, content={
    "required": 7,
    "optional": "present",
    "count": 3,
    "displayName": "Ada",
    "omitted": 9,
  })
  let decoded : @roundtrip.Record = @json.from_json(ToJson::to_json(record))
  @test.assert_eq(decoded, record)
}

///|
test "Record FromJson::from_json - alias decodes to canonical field" {
  let record : @roundtrip.Record = @json.from_json({
    "required": 7,
    "legacy_name": "Ada",
  })
  json_inspect(record, content={
    "required": 7,
    "optional": null,
    "count": 0,
    "displayName": "Ada",
  })
}

///|
test "panic_Record FromJson::from_json - required field is missing" {
  try! ((@json.from_json({ "displayName": "Ada" }) : @roundtrip.Record)
  |> ignore)
}

///|
test "panic_Record FromJson::from_json - required field is null" {
  try! ((
    @json.from_json({ "required": null, "displayName": "Ada" }) :
    @roundtrip.Record)
  |> ignore)
}

///|
test "panic_Record FromJson::from_json - default does not replace explicit null" {
  try! ((
    @json.from_json({ "required": 7, "displayName": "Ada", "count": null }) :
    @roundtrip.Record)
  |> ignore)
}

///|
test "panic_Record FromJson::from_json - canonical and alias are duplicates" {
  try! ((
    @json.from_json({
      "required": 7,
      "displayName": "Ada",
      "legacy_name": "Ada",
    }) : @roundtrip.Record)
  |> ignore)
}

///|
test "panic_StrictRecord FromJson::from_json - unknown field is rejected" {
  try! ((
    @json.from_json({ "value": 1, "extra": true }) : @roundtrip.StrictRecord)
  |> ignore)
}

///|
test "CamelRecord codec - container casing and explicit rename" {
  let value : @roundtrip.CamelRecord = {
    first_name: "Ada",
    last_name: "Lovelace",
  }
  json_inspect(value, content={ "firstName": "Ada", "fixed_name": "Lovelace" })
  let decoded : @roundtrip.CamelRecord = @json.from_json(ToJson::to_json(value))
  @test.assert_eq(decoded, value)
}

///|
test "External codec - all constructor shapes and variant rename" {
  let cases : Array[(@roundtrip.External, Json)] = [
    (Idle, "idle"),
    (NewValue(8), { "new_value": 8 }),
    (Pair("a", 2), { "pair": ["a", 2] }),
    (
      Named(label="a", child={ value: 3, }),
      { "named": { "label": "a", "child": { "value": 3 } } },
    ),
    (Special, "renamed"),
    (Maybe(None), { "Maybe": null }),
    (Maybe(Some("a")), { "Maybe": "a" }),
  ]
  for pair in cases {
    let (value, wire) = pair
    let encoded = ToJson::to_json(value)
    @test.assert_eq(encoded, wire)
    let decoded : @roundtrip.External = @json.from_json(wire)
    @test.assert_eq(decoded, value)
  }
}

///|
test "panic_External FromJson::from_json - absent newtype payload is not null" {
  try! ((@json.from_json("Maybe") : @roundtrip.External) |> ignore)
}

///|
test "panic_External FromJson::from_json - tuple arity is exact" {
  try! ((@json.from_json({ "pair": ["a"] }) : @roundtrip.External) |> ignore)
}

///|
test "panic_External FromJson::from_json - multiple tags are rejected" {
  try! ((
    @json.from_json({ "new_value": 1, "Maybe": null }) : @roundtrip.External)
  |> ignore)
}

///|
test "Internal codec - unit and named constructors" {
  let cases : Array[(@roundtrip.Internal, Json)] = [
    (Idle, { "type": "idle" }),
    (Named(value=4, note=None), { "type": "named", "value": 4, "note": null }),
    (
      Named(value=4, note=Some("ok")),
      { "type": "named", "value": 4, "note": "ok" },
    ),
  ]
  for pair in cases {
    let (value, wire) = pair
    @test.assert_eq(ToJson::to_json(value), wire)
    let decoded : @roundtrip.Internal = @json.from_json(wire)
    @test.assert_eq(decoded, value)
  }
  let decoded : @roundtrip.Internal = @json.from_json({
    "type": "named",
    "value": 4,
  })
  @test.assert_eq(decoded, Named(value=4, note=None))
}

///|
test "panic_Internal FromJson::from_json - discriminator is required" {
  try! ((@json.from_json({ "value": 4 }) : @roundtrip.Internal) |> ignore)
}

///|
test "Adjacent codec - all constructor shapes" {
  let cases : Array[(@roundtrip.Adjacent, Json)] = [
    (Idle, { "type": "idle" }),
    (Value(8), { "type": "value", "data": 8 }),
    (Pair("a", 2), { "type": "pair", "data": ["a", 2] }),
    (Named(value=3), { "type": "named", "data": { "value": 3 } }),
    (Maybe(None), { "type": "maybe", "data": null }),
  ]
  for pair in cases {
    let (value, wire) = pair
    @test.assert_eq(ToJson::to_json(value), wire)
    let decoded : @roundtrip.Adjacent = @json.from_json(wire)
    @test.assert_eq(decoded, value)
  }
}

///|
test "panic_Adjacent FromJson::from_json - optional newtype still requires content" {
  try! ((@json.from_json({ "type": "maybe" }) : @roundtrip.Adjacent) |> ignore)
}

///|
test "panic_Adjacent FromJson::from_json - unknown discriminator is rejected" {
  try! ((@json.from_json({ "type": "unknown", "data": 8 }) : @roundtrip.Adjacent)
  |> ignore)
}

///|
test "Untagged codec - scalar and named constructor selection" {
  let cases : Array[(@roundtrip.Untagged, Json)] = [
    (Integer(4), 4),
    (Text("hello"), "hello"),
    (Named(value=3), { "value": 3 }),
  ]
  for pair in cases {
    let (value, wire) = pair
    @test.assert_eq(ToJson::to_json(value), wire)
    let decoded : @roundtrip.Untagged = @json.from_json(wire)
    @test.assert_eq(decoded, value)
  }
}

///|
test "panic_Untagged FromJson::from_json - no matching constructor" {
  try! ((@json.from_json(true) : @roundtrip.Untagged) |> ignore)
}

///|
test "Envelope codec - nested options and enum payloads" {
  let value : @roundtrip.Envelope = {
    records: [{ value: 1, }],
    event: Some(Maybe(None)),
    nested: Some(Some("ok")),
  }
  json_inspect(value, content={
    "records": [{ "value": 1 }],
    "event": { "Maybe": null },
    "nested": "ok",
  })
  let decoded : @roundtrip.Envelope = @json.from_json(ToJson::to_json(value))
  @test.assert_eq(decoded, value)
  let from_null : @roundtrip.Envelope = @json.from_json({
    "records": [],
    "event": null,
    "nested": null,
  })
  let from_missing : @roundtrip.Envelope = @json.from_json({ "records": [] })
  @test.assert_eq(from_null, { records: [], event: None, nested: None, })
  @test.assert_eq(from_missing, from_null)
}

///|
test "Envelope FromJson::from_json - nested array error preserves JSON path" {
  let path = try {
    let _ : @roundtrip.Envelope = @json.from_json({
      "records": [{ "value": "bad" }],
    })
    "unexpected success"
  } catch {
    @json.JsonDecodeError((path, _)) => path.to_string()
  }
  inspect(path, content="/records/0/value")
}

///|
test "Envelope FromJson::from_json - nested enum error preserves JSON path" {
  let path = try {
    let _ : @roundtrip.Envelope = @json.from_json({
      "records": [],
      "event": { "named": { "label": "a", "child": { "value": null } } },
    })
    "unexpected success"
  } catch {
    @json.JsonDecodeError((path, _)) => path.to_string()
  }
  inspect(path, content="/event/named/child/value")
}

///|
test "DecodeOnlyEvent - decode positional payload from the tagged object" {
  let event : @roundtrip.DecodeOnlyEvent = @json.from_json({
    "type": "data",
    "count": 3,
  })
  guard event is Data(payload) else { fail("expected data variant") }
  assert_eq(payload.count, 3)
  assert_eq(ToJson::to_json(payload), { "count": 3 })

  let done : @roundtrip.DecodeOnlyEvent = @json.from_json({ "type": "done" })
  assert_true(done is Done)
  let named : @roundtrip.DecodeOnlyEvent = @json.from_json({
    "type": "named",
    "text": "hello",
  })
  assert_true(named is Named(text="hello"))
}

///|
test "DecodeOnlyEvent - discriminator and field errors keep their original paths" {
  for
    (value, expected) in [
      (Json::empty_object(), "/type"),
      ({ "type": 0 }, "/type"),
      ({ "type": "unknown" }, "/type"),
      ({ "type": "data", "count": "no" }, "/count"),
      ({ "type": "data", "Data": { "count": 3 } }, "/count"),
    ] {
    let path = try {
      let _ : @roundtrip.DecodeOnlyEvent = @json.from_json(value)
      fail("expected decode error at \{expected}")
    } catch {
      @json.JsonDecodeError((path, _)) => path.to_string()
      error => raise error
    }
    assert_eq(path, expected)
  }
}

///|
test "FixedPath - merges shared parents and omits absent optional subtrees" {
  let input : Json = {
    "label": "x",
    "part": { "state": { "status": "ok", "count": 3 }, "note": "n" },
  }
  let decoded : @roundtrip.FixedPath = @json.from_json(input)
  assert_eq(decoded.status, "ok")
  assert_eq(decoded.note, Some("n"))
  assert_eq(decoded.count, 3)
  assert_eq(decoded.extra, None)
  assert_eq(ToJson::to_json(decoded), input)
  let minimal : @roundtrip.FixedPath = @json.from_json({
    "legacy": "x",
    "part": { "state": { "status": "ok" } },
  })
  assert_eq(ToJson::to_json(minimal), {
    "label": "x",
    "part": { "state": { "status": "ok", "count": 0 } },
  })
  let explicit : Json = {
    "label": "x",
    "part": { "state": { "status": "ok", "count": 0 } },
    "extras": { "a/b~.c": "yes", "quote\"\\": "escaped" },
  }
  let with_extra : @roundtrip.FixedPath = @json.from_json(explicit)
  assert_eq(with_extra.extra, Some("yes"))
  assert_eq(with_extra.escaped, Some("escaped"))
  assert_eq(ToJson::to_json(with_extra), explicit)
}

///|
test "FixedPath - errors point at missing keys, invalid objects, values, and unknown nested keys" {
  let invalid : Array[(Json, String)] = [
    ({ "label": "x" }, "/part"),
    ({ "label": "x", "part": false }, "/part"),
    ({ "label": "x", "part": { "state": null } }, "/part/state"),
    (
      { "label": "x", "part": { "state": Json::empty_object() } },
      "/part/state/status",
    ),
    (
      { "label": "x", "part": { "state": { "status": "ok", "count": null } } },
      "/part/state/count",
    ),
    (
      { "label": "x", "part": { "state": { "status": "ok", "bad": 0 } } },
      "/part/state/bad",
    ),
    (
      {
        "label": "x",
        "part": { "state": { "status": "ok" } },
        "extras": { "a/b~.c": 1 },
      },
      "/extras/a~1b~0.c",
    ),
  ]
  for (value, expected) in invalid {
    let actual = try {
      let _ : @roundtrip.FixedPath = @json.from_json(value)
      fail("expected decode error at \{expected}")
    } catch {
      @json.JsonDecodeError((path, _)) => path.to_string()
      error => raise error
    }
    assert_eq(actual, expected)
  }
}

///|
test "fixed path identifies the first missing key in the message" {
  let err = try {
    let _ : @roundtrip.FixedPath = @json.from_json({ "label": "x" })
    fail("expected missing key")
  } catch {
    @json.JsonDecodeError((path, message)) => (path.to_string(), message)
    error => raise error
  }
  assert_eq(err, ("/part", "missing field: part"))
}

///|
test "untagged enum reports each failed variant and its own JSON Pointer" {
  let input : Json = [{ "value": false }]
  let (path, message) = try {
    let _ : Array[@roundtrip.Untagged] = @json.from_json(input)
    fail("expected no matching variant")
  } catch {
    @json.JsonDecodeError((path, message)) => (path.to_string(), message)
    error => raise error
  }
  assert_eq(path, "/0")
  assert_true(message.contains("Integer at /0:"), msg=message)
  assert_true(message.contains("Text at /0:"), msg=message)
  assert_true(message.contains("Named at /0/value:"), msg=message)
}

///|
test "newtype - the wrapped value has no object or array envelope" {
  let measured : @roundtrip.Distance = @json.from_json(12)
  assert_eq(ToJson::to_json(measured), 12)
}

///|
test "tuple struct - elements preserve declaration order and an absent Option is null" {
  for input in ([[12, "m"], [12, null]] : Array[Json]) {
    let measured : @roundtrip.Measurement = @json.from_json(input)
    assert_eq(ToJson::to_json(measured), input)
  }
}

///|
test "tuple struct - a missing or extra element fails at the tuple and a bad value fails at its index" {
  let cases : Array[(Json, String, String)] = [
    ([[12]], "/0", "expected a tuple of length 2"),
    ([[12, null, false]], "/0", "expected a tuple of length 2"),
    ([[12, false]], "/0/1", ""),
  ]
  for (input, expected_path, expected_message) in cases {
    let (path, message) = try {
      let _ : Array[@roundtrip.Measurement] = @json.from_json(input)
      fail("expected a tuple decode error")
    } catch {
      @json.JsonDecodeError((path, message)) => (path.to_string(), message)
      error => raise error
    }
    assert_eq(path, expected_path)
    if !expected_message.is_empty() {
      assert_eq(message, expected_message)
    }
  }
}

///|
test "generic record - a nested collection delegates to its item codec and preserves errors" {
  let decoded : @roundtrip.GenericRecord[@roundtrip.GenericBox[Int32], String] = @json.from_json({
      "data": { "items": [1, 2] },
    },
  )
  assert_eq(ToJson::to_json(decoded), {
    "data": { "items": [1, 2] },
    "fallback": "",
  })
  let path = try {
    let _ : @roundtrip.GenericRecord[@roundtrip.GenericBox[Int32], String] = @json.from_json({
        "data": { "items": [1, false] },
      },
    )
    fail("expected the type argument's decode error")
  } catch {
    @json.JsonDecodeError((path, _)) => path.to_string()
    error => raise error
  }
  assert_eq(path, "/data/items/1")
}

///|
test "generic tuple struct - a generic newtype is transparent and an optional slot remains null" {
  let input : Json = ["name", null]
  let decoded : @roundtrip.GenericPair[String, Int32] = @json.from_json(input)
  assert_eq(ToJson::to_json(decoded), input)
}

///|
test "generic adjacent enum - unit, positional, and named variants infer their type arguments" {
  let inputs : Array[Json] = [
    { "type": "Empty" },
    { "type": "Positional", "data": 42 },
    { "type": "Named", "data": { "value": "name" } },
  ]
  for input in inputs {
    let decoded : @roundtrip.GenericAdjacent[Int32, String] = @json.from_json(
      input,
    )
    assert_eq(ToJson::to_json(decoded), input)
  }
}

///|
test "generic untagged enum - each candidate uses its generic payload codec" {
  for input in ([1, { "items": [2, 3] }] : Array[Json]) {
    let decoded : @roundtrip.GenericUntagged[Int32] = @json.from_json(input)
    assert_eq(ToJson::to_json(decoded), input)
  }
}

///|
test "generic directional bounds - decode_only and skipped fields do not require an encoder" {
  let decoded : @roundtrip.WithSkipped[
    @roundtrip.ReadOnlyBox[Int32],
    @roundtrip.DefaultOnly,
  ] = @json.from_json({ "value": 4 })
  assert_eq(ToJson::to_json(decoded.hidden.0), 0)
  let encoded : @roundtrip.WithSkipped[Int32, @roundtrip.DefaultOnly] = @json.from_json({
      "value": 4,
    },
  )
  assert_eq(ToJson::to_json(encoded), { "value": 4 })
}

///|
priv struct ToJsonOnly(Int32)

///|
impl ToJson for ToJsonOnly with fn to_json(self) {
  let ToJsonOnly(value) = self
  ToJson::to_json(value)
}

///|
test "encode_only supports records, tuples, and enums without FromJson" {
  let value = ToJsonOnly(42)
  assert_eq(
    ToJson::to_json(@roundtrip.WriteOnlyRecord::{ identifier: value, }),
    { "id": 42 },
  )
  assert_eq(ToJson::to_json(@roundtrip.WriteOnlyTuple(value, true)), [42, true])
  let event : @roundtrip.WriteOnlyEvent[ToJsonOnly] = Value(value)
  assert_eq(ToJson::to_json(event), { "type": "Value", "data": 42 })
}
