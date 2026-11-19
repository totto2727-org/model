///|
pub trait Length {
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
