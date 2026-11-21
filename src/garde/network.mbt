///|
pub using @moonurl {type Url}

///|
pub using @moonip {type Addr}

///|
/// Parse an absolute WHATWG URL, including non-HTTP schemes.
pub fn parse_url(value : String) -> Url? {
  try Url::decode(value[:], syntax=@moonurl.Whatwg) catch {
    _ => None
  } noraise {
    parsed => if parsed.scheme is Some(_) { Some(parsed) } else { None }
  }
}

///|
/// Check for an absolute WHATWG URL, including non-HTTP schemes.
pub fn url(value : String) -> String? {
  if parse_url(value) is Some(_) {
    None
  } else {
    Some("must be a valid URL")
  }
}

///|
/// Parse a bare IPv4 or IPv6 address without a zone identifier.
pub fn parse_ip(value : String) -> Addr? {
  try Addr::parse(value[:]) catch {
    _ => None
  } noraise {
    address => if address.zone() is None { Some(address) } else { None }
  }
}

///|
fn valid_ipv4(value : String) -> Bool {
  parse_ip(value) is Some(address) && address.is_v4()
}

///|
fn valid_ipv6(value : String) -> Bool {
  parse_ip(value) is Some(address) && address.is_v6()
}

///|
/// Check for a bare IPv4 or IPv6 address.
pub fn ip(value : String) -> String? {
  if parse_ip(value) is Some(_) {
    None
  } else {
    Some("must be a valid IP address")
  }
}

///|
/// Check for a dotted-decimal IPv4 address.
pub fn ipv4(value : String) -> String? {
  if valid_ipv4(value) {
    None
  } else {
    Some("must be a valid IPv4 address")
  }
}

///|
/// Check for a bare IPv6 address without brackets or a zone identifier.
pub fn ipv6(value : String) -> String? {
  if valid_ipv6(value) {
    None
  } else {
    Some("must be a valid IPv6 address")
  }
}
