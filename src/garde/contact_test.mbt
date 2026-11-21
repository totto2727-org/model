///|
test "email accepts bare MoonMail mailboxes without extra domain checks" {
  for
    value in [
      "first+tag@example.org", "u@localhost", "u@sub-domain.org", "\"a@b\"@example.org",
      "a@xn--bcher-kva.example", "u@[192.0.2.1]", "u@[2001:db8::1]", "ü@bücher.example",
      "u@example-.org", "u@example_org", "u@[192.0.2.999]",
    ] {
    assert_true(@garde.email(value) is None, msg=value)
  }
  assert_eq(@garde.email("\{"a".repeat(65)}@example.org"), None)
  assert_eq(@garde.email("a@\{"a".repeat(64)}.org"), None)
}

///|
test "email rejects invalid syntax and mailbox headers" {
  for
    value in [
      "", "no-at.example", "u@@example.org", "u@example.org\n", "u@.example.org",
      "a..b@example.org", "Name <u@example.org>", "<u@example.org>", "u@example.org (comment)",
      "group:u@example.org;", "u@example.org, v@example.org",
    ] {
    assert_true(@garde.email(value) is Some(_), msg=value)
  }
}

///|
test "phone_number requires a valid numbering-plan match without a default region" {
  for value in ["+1 202-555-0123", "+44 20 7946 0958", "+81 3-1234-5678"] {
    assert_eq(@garde.phone_number(value), None)
  }
  for
    value in [
      "020 7946 0958", "+999123456789", "+1 202-155-0123", "+1202", "not a phone number",
    ] {
    assert_true(@garde.phone_number(value) is Some(_))
  }
}
