///|
test "each decoder produces the complete expected output" {
  let input = @json.parse(fixture)
  for entry in decoders {
    let (_, decode) = entry
    assert_eq(decode(input), expected)
  }
}

///|
test "each decoder rejects invalid required data" {
  let invalid = [
    "null",
    fixture.replace(old="\"requestId\"", new="\"unusedId\""),
    fixture.replace(old="\"metadata\":{", new="\"unusedMetadata\":{"),
    fixture.replace(old="\"active\":true", new="\"active\":null"),
    fixture.replace(old="\"name\":\"Ada Lovelace\"", new="\"name\":7"),
    fixture.replace(old="[\"owner\",\"reviewer\",\"operator\"]", new="{}"),
    fixture.replace(old="\"reviewer\"", new="null"),
    fixture.replace(old="\"version\":7", new="\"version\":2147483648"),
    fixture.replace(old="\"latencyMs\":12.5", new="\"latencyMs\":\"12.5\""),
  ]
  for text in invalid {
    let input = @json.parse(text)
    for entry in decoders {
      let (name, decode) = entry
      match (Some(decode(input)) catch { _ => None }) {
        Some(_) => fail("\{name} accepted invalid input: \{text}")
        None => ()
      }
    }
  }
}
