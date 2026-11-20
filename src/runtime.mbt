///|
/// Report a wire-format error at the supplied JSON path.
pub fn[T] invalid(
  path : @json.JsonPath,
  message : String,
) -> T raise @json.JsonDecodeError {
  raise @json.JsonDecodeError((path, message))
}

///|
/// Report the key at the first absent path segment.
pub fn[T] missing_field(
  path : @json.JsonPath,
  key : String,
) -> T raise @json.JsonDecodeError {
  invalid(path, "missing field: \{key}")
}

///|
/// Codecs operate on dynamic JSON values because this package implements the serialization boundary itself.
pub fn object(
  value : Json,
  path : @json.JsonPath,
) -> Map[String, Json] raise @json.JsonDecodeError {
  match value {
    Object(fields) => fields
    _ => invalid(path, "expected an object")
  }
}

///|
/// Resolve a field and its aliases, rejecting ambiguous input.
pub fn field(
  fields : Map[String, Json],
  key : String,
  aliases : Array[String],
  path : @json.JsonPath,
) -> Json? raise @json.JsonDecodeError {
  let mut found = fields.get(key)
  for alternate in aliases {
    if fields.get(alternate) is Some(value) {
      if found is Some(_) {
        invalid(path.add_key(key), "duplicate field or alias: \{key}")
      }
      found = Some(value)
    }
  }
  found
}

///|
/// Read fixed object keys and return the value, its location, and the first missing key or leaf key.
pub fn read_path(
  fields : Map[String, Json],
  keys : Array[String],
  path : @json.JsonPath,
) -> (Json?, @json.JsonPath, String) raise @json.JsonDecodeError {
  let mut value = None
  let mut cursor = path
  let mut object_fields = fields
  let mut last_key = ""
  for i, key in keys {
    last_key = key
    cursor = cursor.add_key(key)
    value = object_fields.get(key)
    if i < keys.length() - 1 {
      match value {
        None => return (None, cursor, key)
        Some(child) => object_fields = object(child, cursor)
      }
    }
  }
  (value, cursor, last_key)
}

///|
/// Write a leaf into the generated object's already-validated, non-overlapping paths.
pub fn write_path(
  fields : Map[String, Json],
  keys : Array[String],
  value : Json,
) -> Unit {
  let mut object_fields = fields
  for i, key in keys {
    if i == keys.length() - 1 {
      object_fields[key] = value
    } else {
      match object_fields.get(key) {
        Some(Object(child)) => object_fields = child
        None => {
          let child = Map([])
          object_fields[key] = Json::object(child)
          object_fields = child
        }
        Some(_) => abort("generated JSON field paths overlap")
      }
    }
  }
}

///|
/// Copy the keys that are not claimed by the enclosing record.
pub fn flattened_remainder(
  fields : Map[String, Json],
  reserved : Array[String],
) -> Json {
  let remaining = Map([])
  for key, value in fields {
    if !reserved.contains(key) {
      remaining[key] = value
    }
  }
  Json::object(remaining)
}

///|
/// Expand an object into its parent without overwriting a parent key.
pub fn write_flattened(
  fields : Map[String, Json],
  value : Json,
  reserved : Array[String],
) -> Unit {
  guard value is Object(child) else {
    abort("a flattened Serde field must encode as a JSON object")
  }
  for key, value in child {
    if reserved.contains(key) {
      abort("flattened Serde key collides with the enclosing record: \{key}")
    }
    fields[key] = value
  }
}

///|
/// Reject unexpected keys without changing the caller's object.
pub fn deny_unknown(
  fields : Map[String, Json],
  allowed : Array[String],
  path : @json.JsonPath,
) -> Unit raise @json.JsonDecodeError {
  for key, _ in fields {
    if !allowed.contains(key) {
      invalid(path.add_key(key), "unknown field: \{key}")
    }
  }
}

///|
/// Check unknown keys at each object implied by fixed paths. Leaf decoders validate their own values.
pub fn deny_unknown_paths(
  fields : Map[String, Json],
  paths : Array[Array[String]],
  path : @json.JsonPath,
) -> Unit raise @json.JsonDecodeError {
  deny_unknown_at(fields, paths, path, 0)
}

///|
fn deny_unknown_at(
  fields : Map[String, Json],
  paths : Array[Array[String]],
  path : @json.JsonPath,
  depth : Int32,
) -> Unit raise @json.JsonDecodeError {
  for key, value in fields {
    let matching = paths.filter(keys => keys[depth] == key)
    let field_path = path.add_key(key)
    if matching.is_empty() {
      invalid(field_path, "unknown field: \{key}")
    }
    if value is Object(child) && matching[0].length() > depth + 1 {
      deny_unknown_at(child, matching, field_path, depth + 1)
    }
  }
}

///|
/// Decode the externally tagged representation. None distinguishes a unit tag from an explicit null payload.
pub fn external(
  value : Json,
  path : @json.JsonPath,
) -> (String, Json?) raise @json.JsonDecodeError {
  match value {
    String(tag) => (tag, None)
    Object(fields) if fields.length() == 1 => {
      for tag, payload in fields {
        return (tag, Some(payload))
      }
      invalid(path, "expected one enum variant")
    }
    _ => invalid(path, "expected a variant string or a single-key object")
  }
}

///|
/// Read an internal or adjacent string discriminator.
pub fn discriminator(
  fields : Map[String, Json],
  tag : String,
  path : @json.JsonPath,
) -> String raise @json.JsonDecodeError {
  match fields.get(tag) {
    Some(String(value)) => value
    None => invalid(path.add_key(tag), "missing discriminator: \{tag}")
    Some(_) => invalid(path.add_key(tag), "expected a string discriminator")
  }
}

///|
/// Try candidates in declaration order. If none match, report each candidate's location and reason.
pub fn[T] untagged(
  value : Json,
  path : @json.JsonPath,
  candidates : Array[
    (String, (Json, @json.JsonPath) -> T raise @json.JsonDecodeError),
  ],
) -> T raise @json.JsonDecodeError {
  let details : Array[String] = []
  for candidate in candidates {
    let (name, decode) = candidate
    try {
      return decode(value, path)
    } catch {
      @json.JsonDecodeError((at, reason)) => {
        let pointer = at.to_string()
        let location = if pointer.is_empty() { "<root>" } else { pointer }
        details.push("\{name} at \{location}: \{reason}")
      }
    }
  }
  invalid(path, "no untagged variant matched:\n  " + details.join("\n  "))
}

///|
/// Validate a tuple payload before indexing it.
pub fn tuple(
  value : Json,
  length : Int32,
  path : @json.JsonPath,
) -> Array[Json] raise @json.JsonDecodeError {
  match value {
    Array(values) if values.length() == length => values
    _ => invalid(path, "expected a tuple of length \{length}")
  }
}

///|
/// Require a variant's content, preserving the difference between absent and null.
pub fn payload(
  value : Json?,
  path : @json.JsonPath,
) -> Json raise @json.JsonDecodeError {
  match value {
    Some(value) => value
    None => invalid(path, "missing enum content")
  }
}

///|
/// Require the string form of an external unit variant or an absent adjacent content field.
pub fn unit(
  value : Json?,
  path : @json.JsonPath,
) -> Unit raise @json.JsonDecodeError {
  if value is Some(_) {
    invalid(path, "unit variant must not have content")
  }
}
