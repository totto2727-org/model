///|
pub(open) trait Length {
  fn garde_length(Self) -> Int32
}

///|
pub impl Length for String with fn garde_length(self) {
  self.length()
}

///|
pub impl[T] Length for Array[T] with fn garde_length(self) {
  self.length()
}

///|
pub impl[T] Length for ReadOnlyArray[T] with fn garde_length(self) {
  self.length()
}

///|
pub impl[T] Length for FixedArray[T] with fn garde_length(self) {
  self.length()
}

///|
pub impl[K, V] Length for Map[K, V] with fn garde_length(self) {
  self.length()
}

///|
pub impl Length for Bytes with fn garde_length(self) {
  self.length()
}

///|
/// Check a string's length in UTF-16 code units or a container's item count.
pub fn[T : Length] length(value : T, min : Int32?, max : Int32?) -> String? {
  let count = T::garde_length(value)
  if min is Some(n) && count < n {
    Some("length must be at least \{n}")
  } else if max is Some(n) && count > n {
    Some("length must be at most \{n}")
  } else {
    None
  }
}

///|
/// Check inclusive bounds using the type's standard comparison.
pub fn[T : Compare + Show] range(value : T, min : T?, max : T?) -> String? {
  if value != value {
    Some("must be comparable to the bounds")
  } else if min is Some(n) && (n != n || compare(value, n) < 0) {
    Some("must be at least \{n}")
  } else if max is Some(n) && (n != n || compare(value, n) > 0) {
    Some("must be at most \{n}")
  } else {
    None
  }
}

///|
pub fn ascii(value : String) -> String? {
  for char in value {
    if char.to_int() > 0x7F {
      return Some("must contain only ASCII characters")
    }
  }
  None
}

///|
pub fn alphanumeric(value : String) -> String? {
  for char in value {
    if !@moonucd.has(char, Alphabetic) &&
      !(@moonucd.category(char) is (Nd | Nl | No)) {
      return Some("must contain only letters and numbers")
    }
  }
  None
}

///|
pub fn contains(value : String, needle : String) -> String? {
  if value.contains(needle) {
    None
  } else {
    Some("must contain '\{needle}'")
  }
}

///|
pub fn prefix(value : String, expected : String) -> String? {
  if value.has_prefix(expected) {
    None
  } else {
    Some("must start with '\{expected}'")
  }
}

///|
pub fn suffix(value : String, expected : String) -> String? {
  if value.has_suffix(expected) {
    None
  } else {
    Some("must end with '\{expected}'")
  }
}

///|
/// Check whether the regular expression matches anywhere in the string.
pub fn pattern(value : String, expression : String) -> String? {
  let regex = @string.Regex(expression[:]) catch {
    _ => return Some("invalid regular expression")
  }
  if regex.execute(value[:]) is Some(_) {
    None
  } else {
    Some("does not match the pattern")
  }
}
