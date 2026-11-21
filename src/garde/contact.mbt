///|
/// Check a bare mailbox address as parsed by MoonMail.
pub fn email(value : String) -> String? {
  let invalid = Some("invalid email address")
  let parsed = @moonmail.parse_address(value[:]) catch { _ => return invalid }
  if parsed is Mailbox({ name: None, address, }) && address == value {
    None
  } else {
    invalid
  }
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
