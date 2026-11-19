///|
priv struct TestContext(@json.DecodeContext)

///|
impl @json.FromJson for TestContext with fn from_json(_value, path) {
  TestContext(path.copy())
}

///|
test "external tags distinguish unit variants and explicit null content" {
  let TestContext(path) = @json.from_json(null)
  let (tag, body) = @serde.external("Unit", path)
  assert_eq(tag, "Unit")
  assert_eq(body, None)
  let (tag, body) = @serde.external({ "Value": null }, path)
  assert_eq(tag, "Value")
  assert_eq(body, Some(Json::null()))
}

///|
test "an alias collision reports the canonical path even when a value is null" {
  let TestContext(root) = @json.from_json(null)
  let path = root.add_key("outer")
  let value = @serde.object({ "canonical": null, "legacy": 5 }, path)
  let result = try {
    @serde.field(value, "canonical", ["legacy"], path) |> ignore
    "accepted duplicate"
  } catch {
    @json.JsonDecodeError((path, _)) => path.to_string()
  }
  assert_eq(result, "/outer/canonical")
}
