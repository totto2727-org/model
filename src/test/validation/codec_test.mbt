///|
test "Serde and Garde decode and encode the same wire model" {
  let input : Json = {
    "endpointUrl": "https://EXAMPLE.org:443/docs",
    "allowed_ip": "192.0.2.10",
    "name": "docs",
    "metadata": 42,
  }
  let wire : @validation.Endpoint[Int32] = @json.from_json(input)
  let codec = @validation.Endpoint::codec()
  guard @garde.decode(wire, codec) is Ok(domain) else {
    fail("valid wire model was rejected")
  }
  let domain : @validation.EndpointDecoded[Int32] = domain
  let url : @garde.Url = domain.url
  assert_eq(url.encode(), "https://example.org/docs")
  guard domain.allowed_ip is Some(ip) else {
    fail("IP address was not decoded")
  }
  assert_true(ip.is_v4())
  assert_eq(domain.metadata, 42)
  guard @garde.encode(domain, codec) is Ok(encoded) else {
    fail("valid domain model was rejected")
  }
  let output : Json = {
    "endpointUrl": "https://example.org/docs",
    "allowed_ip": "192.0.2.10",
    "name": "docs",
    "metadata": 42,
  }
  assert_eq(ToJson::to_json(encoded), output)
}

///|
test "Garde decode validates all wire fields and preserves absent optional values" {
  let invalid : @validation.Endpoint[Int32] = {
    url: "//example.org",
    allowed_ip: Some("::1"),
    name: "",
    metadata: 1,
  }
  let codec = @validation.Endpoint::codec()
  guard @garde.decode(invalid, codec) is Err(report) else {
    fail("invalid wire model was accepted")
  }
  assert_eq(report.violations().map(v => Show::to_string(v.path)), [
    "url", "allowed_ip", "name",
  ])
  let wire = {
    ..invalid,
    url: "https://example.org/",
    allowed_ip: None,
    name: "docs",
  }
  guard @garde.decode(wire, codec) is Ok(domain) else {
    fail("missing optional IP was rejected")
  }
  assert_true(domain.allowed_ip is None)
  guard @garde.encode(domain, codec) is Ok(encoded) else {
    fail("valid model with missing optional IP was rejected")
  }
  assert_true(encoded.allowed_ip is None)
}

///|
test "Garde encode validates the converted wire model" {
  guard @garde.parse_url("https://example.org/") is Some(url) else {
    fail("expected a parsed URL")
  }
  let domain : @validation.EndpointDecoded[Int32] = {
    url,
    allowed_ip: @garde.parse_ip("::1"),
    name: "",
    metadata: 1,
  }
  guard @garde.encode(domain, @validation.Endpoint::codec()) is Err(report) else {
    fail("invalid domain model was accepted")
  }
  assert_eq(report.violations().map(v => Show::to_string(v.path)), [
    "allowed_ip", "name",
  ])
}
