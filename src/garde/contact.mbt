///|
let email_local : @string.Regex = re"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~\-]+$"

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
/// Check the HTML email address syntax with Garde's local and domain length limits.
pub fn email(value : String, international~ : Bool = false) -> String? {
  let invalid = Some("invalid email address")
  guard value.split_once("@") is Some((local_part, domain)) &&
    local_part.length() <= 64 &&
    domain.length() <= 255 &&
    email_local.execute(local_part[:]) is Some(m) &&
    m.content().length() == local_part.length() else {
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
// Order matters: card-validate prioritizes specific debit prefixes over credit prefixes.
let card_brands : ReadOnlyArray[(@string.Regex, Int32, Int32)] = [
  (re"^4(026|17500|405|508|844|91[37])", 16, 16),
  (re"^(5(018|0[23]|[68])|6(39|7))", 12, 19),
  (re"^600", 16, 16),
  (re"^5019", 16, 16),
  (re"^4", 13, 16),
  (re"^220[0-4]", 16, 19),
  (re"^(5[1-5]|2[2-7])", 16, 16),
  (re"^3[47]", 15, 15),
  (re"^3[0689]", 14, 14),
  (re"^6([045]|22)", 16, 16),
  (re"^(62|88)", 16, 19),
  (re"^35", 16, 16),
]

///|
/// Check the card-validate 2.4.0 brand prefixes, lengths, and Luhn checksum.
pub fn credit_card(value : String) -> String? {
  let length = value.length()
  if length < 12 || length > 19 {
    return Some("invalid credit card number")
  }
  let mut sum = 0
  for i in 0..<length {
    let digit = value[i].to_int() - '0'.to_int()
    if digit < 0 || digit > 9 {
      return Some("invalid credit card number")
    }
    let weighted = if (length - i) % 2 == 0 { 2 * digit } else { digit }
    sum += if weighted > 9 { weighted - 9 } else { weighted }
  }
  if sum % 10 == 0 {
    for brand in card_brands {
      let (regex, min, max) = brand
      if regex.execute(value[:]) is Some(_) {
        if min <= length && length <= max {
          return None
        }
        break
      }
    }
  }
  Some("invalid credit card number")
}

///|
/// Check a phone number against its numbering plan without assuming a default region.
pub fn phone_number(value : String) -> String? {
  if @dialnumber.parse(value, "") is Some(number) &&
    @dialnumber.is_valid(number) {
    None
  } else {
    Some("invalid phone number")
  }
}
