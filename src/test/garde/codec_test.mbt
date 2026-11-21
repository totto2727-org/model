///|
test "Serde and Garde decode and encode the same wire model" {
  let input : Json = {
    "endpointUrl": "https://EXAMPLE.org:443/docs",
    "allowed_ip": "192.0.2.10",
    "phone": "+81 90-1234-5678 ext. 42",
    "name": "docs",
    "metadata": 42,
  }
  let wire : @models.Endpoint[Int32] = @json.from_json(input)
  let codec = @models.Endpoint::codec()
  guard @garde_api.decode(wire, codec) is Ok(domain) else {
    fail("valid wire model was rejected")
  }
  let domain : @models.EndpointDecoded[Int32] = domain
  let url : @garde_api.Url = domain.url
  assert_eq(url.encode(), "https://example.org/docs")
  guard domain.allowed_ip is Some(ip) else {
    fail("IP address was not decoded")
  }
  assert_true(ip.is_v4())
  guard domain.phone is Some(phone) else {
    fail("phone number was not decoded")
  }
  let phone : @garde_api.PhoneNumber = phone
  assert_eq(phone.country_code, 81)
  assert_eq(phone.national_number, "9012345678")
  assert_eq(phone.extension, "42")
  assert_eq(domain.metadata, 42)
  guard @garde_api.encode(domain, codec) is Ok(encoded) else {
    fail("valid domain model was rejected")
  }
  let output : Json = {
    "endpointUrl": "https://example.org/docs",
    "allowed_ip": "192.0.2.10",
    "phone": "+81 9012345678 x42",
    "name": "docs",
    "metadata": 42,
  }
  assert_eq(ToJson::to_json(encoded), output)
}

///|
test "Garde decode validates all wire fields and preserves absent optional values" {
  let invalid : @models.Endpoint[Int32] = {
    url: "//example.org",
    allowed_ip: Some("::1"),
    phone: Some("09012345678"),
    name: "",
    metadata: 1,
  }
  let codec = @models.Endpoint::codec()
  guard @garde_api.decode(invalid, codec) is Err(report) else {
    fail("invalid wire model was accepted")
  }
  assert_eq(report.violations().map(v => Show::to_string(v.path)), [
    "url", "allowed_ip", "phone", "name",
  ])
  let wire = {
    ..invalid,
    url: "https://example.org/",
    allowed_ip: None,
    phone: None,
    name: "docs",
  }
  guard @garde_api.decode(wire, codec) is Ok(domain) else {
    fail("missing optional IP was rejected")
  }
  assert_true(domain.allowed_ip is None)
  assert_true(domain.phone is None)
  guard @garde_api.encode(domain, codec) is Ok(encoded) else {
    fail("valid model with missing optional fields was rejected")
  }
  assert_true(encoded.allowed_ip is None)
  assert_true(encoded.phone is None)
}

///|
test "Garde encode validates the converted wire model" {
  guard @garde_api.parse_url("https://example.org/") is Some(url) else {
    fail("expected a parsed URL")
  }
  let domain : @models.EndpointDecoded[Int32] = {
    url,
    allowed_ip: @garde_api.parse_ip("::1"),
    phone: Some(@garde_api.PhoneNumber::new(81, "1")),
    name: "",
    metadata: 1,
  }
  guard @garde_api.encode(domain, @models.Endpoint::codec()) is Err(report) else {
    fail("invalid domain model was accepted")
  }
  assert_eq(report.violations().map(v => Show::to_string(v.path)), [
    "allowed_ip", "phone", "name",
  ])
}

///|
test "default codec preserves fields without a format conversion" {
  let wire : @models.Address = { code: "JP", }
  let codec = @models.Address::codec()
  guard @garde_api.decode(wire, codec) is Ok(decoded) else {
    fail("expected a decoded address")
  }
  let decoded : @models.AddressDecoded = decoded
  assert_eq(decoded.code, "JP")
  guard @garde_api.encode(decoded, codec) is Ok(encoded) else {
    fail("expected an encoded address")
  }
  assert_eq(encoded.code, "JP")
}
