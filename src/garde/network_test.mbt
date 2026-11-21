///|
test "url validates absolute WHATWG URLs" {
  for
    value in [
      "https://example.org/path?q=moon#section", "HTTP://localhost:8080", "http://[::1]",
      "http://127.1", "ftp://example.org/file", "file:///tmp/example", "mailto:moon@example.org",
      "urn:isbn:0451450523", "data:text/plain,hello", "custom+scheme:opaque", "https://例え.example/",
    ] {
    assert_true(@garde.url(value) is None, msg=value)
  }
  for
    value in [
      "", "not a url", "//example.org", "/relative", "https://", "https://bad host",
      "https://example.org:65536", "http://[::g]", "https://256.1.1.1",
    ] {
    assert_true(@garde.url(value) is Some(_), msg=value)
  }
}

///|
test "ipv4 accepts dotted decimal literals only" {
  for value in ["0.0.0.0", "127.0.0.1", "192.0.2.1", "255.255.255.255"] {
    assert_true(@garde.ipv4(value) is None, msg=value)
    assert_true(@garde.ip(value) is None, msg=value)
    assert_true(@garde.ipv6(value) is Some(_), msg=value)
  }
  for
    value in [
      "", ".", "localhost", "127.1", "2130706433", "0x7f.0.0.1", "127.0.0.01", "0127.0.0.1",
      "127.0.0.1.", "+127.0.0.1", " 127.0.0.1", "127.0.0.1:80", "256.0.0.1", "192.0.2.1/24",
    ] {
    assert_true(@garde.ipv4(value) is Some(_), msg=value)
    assert_true(@garde.ip(value) is Some(_), msg=value)
  }
}

///|
test "ipv6 accepts bare literals including mixed IPv4 forms" {
  for
    value in [
      "::", "::1", "2001:db8::", "2001:DB8::1", "1:2:3:4:5:6:7:8", "::ffff:192.0.2.1",
      "1:2:3:4:5:6:192.0.2.1",
    ] {
    assert_true(@garde.ipv6(value) is None, msg=value)
    assert_true(@garde.ip(value) is None, msg=value)
    assert_true(@garde.ipv4(value) is Some(_), msg=value)
  }
  for
    value in [
      "", "[::1]", "[::1]:443", "fe80::1%en0", "1::2::3", "1:2:3:4:5:6:7", "1:2:3:4:5:6:7:8::",
      "12345::", ":::", "::ffff:192.0.02.1", "::ffff:192.0.2.256", "2001:db8::/32",
    ] {
    assert_true(@garde.ipv6(value) is Some(_), msg=value)
    assert_true(@garde.ip(value) is Some(_), msg=value)
  }
}
