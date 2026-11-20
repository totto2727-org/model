///|
pub(open) trait Length {
  fn garde_length(Self) -> Int32
}

///|
pub impl Length for String with fn garde_length(self) {
  let mut count = 0
  for char in self {
    let code = char.to_int()
    count += if code < 0x80 {
      1
    } else if code < 0x800 {
      2
    } else if code < 0x10000 {
      3
    } else {
      4
    }
  }
  count
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
/// Check the UTF-8 byte length of a string or the number of items in an array.
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
/// Check inclusive bounds on an integer.
pub fn range(value : Int32, min : Int32?, max : Int32?) -> String? {
  if min is Some(n) && value < n {
    Some("must be at least \{n}")
  } else if max is Some(n) && value > n {
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
    match char {
      'a'..<='z' | 'A'..<='Z' | '0'..<='9' => ()
      _ => return Some("must contain only ASCII letters and digits")
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
