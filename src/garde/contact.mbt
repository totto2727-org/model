///|
let email_domain : @string.Regex = re"^[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(?:[.][a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"

///|
fn valid_email_domain(domain : StringView) -> Bool {
  if email_domain.execute(domain) is Some(m) &&
    m.content().length() == domain.length() {
    true
  } else if domain is ['[', .. host, ']'] {
    ip(host.to_owned()) is None
  } else {
    false
  }
}

///|
/// Check a bare mailbox address with Garde's local and domain length limits.
pub fn email(value : String, international~ : Bool = false) -> String? {
  let invalid = Some("invalid email address")
  guard value.length() <= 320 else { return invalid }
  let parsed = @moonmail.parse_address(value[:]) catch { _ => return invalid }
  guard parsed is Mailbox({ name: None, address, }) &&
    address == value &&
    value.rev_split_once("@") is Some((local_part, domain)) &&
    local_part.length() <= 64 &&
    local_part.iter().all(char => char.is_ascii() && !char.is_ascii_control()) &&
    domain.length() <= 255 else {
    return invalid
  }
  if valid_email_domain(domain) {
    return None
  }
  if international && @utf8.encode(domain).length() <= 255 {
    let ascii = @moonurl.domain(domain) catch { _ => return invalid }
    if valid_email_domain(ascii[:]) {
      return None
    }
  }
  invalid
}

///|
pub using @dialnumber {type PhoneNumber}

///|
/// Parse a valid international phone number without assuming a default region.
pub fn parse_phone_number(value : String) -> PhoneNumber? {
  guard @dialnumber.parse(value, "") is Some(number) &&
    @dialnumber.is_valid(number) else {
    return None
  }
  Some(number)
}

///|
/// Check a phone number against its numbering plan without assuming a default region.
pub fn phone_number(value : String) -> String? {
  if parse_phone_number(value) is Some(_) {
    None
  } else {
    Some("invalid phone number")
  }
}
