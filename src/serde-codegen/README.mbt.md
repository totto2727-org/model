# Serde attributes

Use `#custom.serde` to generate `ToJson` and `@json.FromJson` implementations.
These traits control how a MoonBit type reads and writes JSON.

## Usage

After [setup](#setup), put the [`Profile` record](#record-options) in `src/models/profile.mbt`.
From the module root, run:

```sh
serde-gen --package src/models && moon check
```

The command writes `src/models/serde.generated.mbt`.
See the [JSON input and output](#json-input-and-output) and the [complete generated codec](#complete-generated-codec) for `Profile`.

## Key features

- Generate JSON codecs for records, newtypes, tuple structs, and enums.
- Set JSON field names, read aliases, and nested object paths.
- Choose an enum representation or generate only one codec direction.

## Prerequisites

See the [Serde prerequisites](https://github.com/totto2727-org/serde#prerequisites) for the shared Moon toolchain and generator requirements.

## Setup

Follow the [Serde setup](https://github.com/totto2727-org/serde#setup) and import `moonbitlang/core/json` and `totto2727/serde` in the model package.

## API

Do not derive the same traits on an annotated type.
Serde supports only JSON and does not support custom codec hooks or flattening.

Each section shows a minimal annotated model, the generated MoonBit code or the relevant excerpt, and behavior that is not visible from the code alone.
The examples use the standard MoonBit formatting.
Variable names such as `f0` can change when fields move.

### `#custom.serde`: newtypes and tuple structs

A newtype reads and writes its inner value. A tuple struct uses a fixed-length JSON array in declaration order.
An optional tuple element still needs a slot and writes `null` for `None`.

```mbt nocheck
///|
#custom.serde
struct Id(Int32)

///|
#custom.serde
struct Point(Int32, Int32)
```

Generated code:

```mbt nocheck
///|
pub impl ToJson for Id with fn to_json(self) {
  match self {
    Id(f0) => ToJson::to_json(f0)
  }
}

///|
pub impl @json.FromJson for Id with fn from_json(value, path) {
  let f0 : Int32 = @json.from_json(value, path~)
  Id(f0)
}

///|
pub impl ToJson for Point with fn to_json(self) {
  match self {
    Point(f0, f1) => Json::array([ToJson::to_json(f0), ToJson::to_json(f1)])
  }
}

///|
pub impl @json.FromJson for Point with fn from_json(value, path) {
  let values = @serde.tuple(value, 2, path)
  let f0 : Int32 = @json.from_json(values[0], path=path.add_index(0))
  let f1 : Int32 = @json.from_json(values[1], path=path.add_index(1))
  Point(f0, f1)
}
```

### `decode_only`: generate only a decoder

Use `decode_only` for a model that only reads JSON. Its fields do not need to implement `ToJson`.

```mbt nocheck
///|
#custom.serde(decode_only)
struct InputId(Int32)
```

Generated code (there is no `ToJson` implementation):

```mbt nocheck
///|
pub impl @json.FromJson for InputId with fn from_json(value, path) {
  let f0 : Int32 = @json.from_json(value, path~)
  InputId(f0)
}
```

### `encode_only`: generate only an encoder

```mbt nocheck
///|
#custom.serde(encode_only)
struct OutputId(Int32)
```

Generated code:

```mbt nocheck
///|
pub impl ToJson for OutputId with fn to_json(self) {
  match self {
    OutputId(f0) => ToJson::to_json(f0)
  }
}
```

Use this for a model that only writes JSON. Its fields do not need `@json.FromJson`.
Do not combine `encode_only` and `decode_only`. With neither, Serde generates both traits.

### Record options

This record shows how the options in the sections below work together.

```mbt nocheck
///|
#custom.serde(rename_all="camelCase", deny_unknown_fields)
struct Profile {
  display_name : String
  #custom.serde(rename="email", aliases=["mail"])
  address : String
  #custom.serde(path=["meta", "status"])
  status : String
  #custom.serde(default)
  count : Int32
  #custom.serde(skip)
  cache : Int32
  #custom.serde(skip_serializing_if="Option::is_none")
  locale : String?
}
```

#### JSON input and output

Decode this JSON as `Profile`:

```json
{
  "displayName": "Aki",
  "mail": "a@example.net",
  "meta": { "status": "active" }
}
```

Encode the resulting `Profile` to get this JSON:

```json
{
  "displayName": "Aki",
  "email": "a@example.net",
  "meta": { "status": "active" },
  "count": 0
}
```

The decoder accepts `mail` as an alias and fills missing `count` with `0`.
The encoder writes the canonical key `email`, always omits `cache`, and omits `locale` when it is `None`.

#### Complete generated codec

These are the complete `ToJson` and `@json.FromJson` implementations for `Profile` in the generated file.

```mbt nocheck
///|
pub impl ToJson for Profile with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
  obj.set("displayName", ToJson::to_json(self.display_name))
  obj.set("email", ToJson::to_json(self.address))
  @serde.write_path(obj, ["meta", "status"], ToJson::to_json(self.status))
  obj.set("count", ToJson::to_json(self.count))
  if self.locale is Some(_) {
    obj.set(
      "locale",
      match self.locale {
        None => Json::null()
        Some(option_1) => ToJson::to_json(option_1)
      },
    )
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for Profile with fn from_json(value, path) {
  let obj = @serde.object(value, path)
  @serde.deny_unknown_paths(
    obj,
    [
      ["displayName"],
      ["email"],
      ["mail"],
      ["meta", "status"],
      ["count"],
      ["cache"],
      ["locale"],
    ],
    path,
  )
  let f0 : String = match @serde.field(obj, "displayName", [], path) {
    Some(value) => @json.from_json(value, path=path.add_key("displayName"))
    None => @serde.missing_field(path.add_key("displayName"), "displayName")
  }
  let f1 : String = match @serde.field(obj, "email", ["mail"], path) {
    Some(value) => @json.from_json(value, path=path.add_key("email"))
    None => @serde.missing_field(path.add_key("email"), "email")
  }
  let f2 : String = match @serde.read_path(obj, ["meta", "status"], path) {
    (Some(value), at, _) => @json.from_json(value, path=at)
    (None, at, key) => @serde.missing_field(at, key)
  }
  let f3 : Int32 = match @serde.field(obj, "count", [], path) {
    Some(value) => @json.from_json(value, path=path.add_key("count"))
    None => Default::default()
  }
  let f4 : Int32 = Default::default()
  let f5 : String? = match @serde.field(obj, "locale", [], path) {
    Some(value) =>
      match value {
        Null => None
        option_1 => Some(@json.from_json(option_1, path=path.add_key("locale")))
      }
    None => None
  }
  {
    display_name: f0,
    address: f1,
    status: f2,
    count: f3,
    cache: f4,
    locale: f5,
  }
}
```

#### `rename_all`: change field or variant names

On a record, `rename_all="camelCase"` changes `display_name` to `displayName` in both directions. On an enum, it changes variant tags. An explicit `rename` or field `path` takes precedence.

Generated encoder excerpt:

```mbt nocheck
  obj.set("displayName", ToJson::to_json(self.display_name))
```

Generated decoder excerpt:

```mbt nocheck
///|
let f0 : String = match @serde.field(obj, "displayName", [], path) {
  Some(value) => @json.from_json(value, path=path.add_key("displayName"))
  None => @serde.missing_field(path.add_key("displayName"), "displayName")
}
```

Accepted values: `lowercase`, `UPPERCASE`, `PascalCase`, `camelCase`, `snake_case`, `SCREAMING_SNAKE_CASE`, `kebab-case`, `SCREAMING-KEBAB-CASE`.

#### `rename` and `aliases`: choose write and read names

`rename="email"` sets the name in both directions. `aliases=["mail"]` adds a read-only name. The decoder rejects input that contains both names.

Generated encoder and decoder excerpts:

```mbt nocheck
  obj.set("email", ToJson::to_json(self.address))
```

```mbt nocheck
///|
let f1 : String = match @serde.field(obj, "email", ["mail"], path) {
  Some(value) => @json.from_json(value, path=path.add_key("email"))
  None => @serde.missing_field(path.add_key("email"), "email")
}
```

#### `path`: read and write a nested key

`path=["meta", "status"]` uses the literal object keys `meta` and `status`, not array indices.
It requires at least one key. Multiple fields can share a parent object.
It cannot be combined with `rename` or `aliases` on the same field.
No field path can be equal to or a prefix of another field path, including flat names and aliases.
The encoder creates parent objects only when it writes a field at that path.
The decoder applies the rule for missing values when a parent or leaf is missing, but rejects a present parent that is not an object.

Generated encoder and decoder excerpts:

```mbt nocheck
  @serde.write_path(obj, ["meta", "status"], ToJson::to_json(self.status))
```

```mbt nocheck
///|
let f2 : String = match @serde.read_path(obj, ["meta", "status"], path) {
  (Some(value), at, _) => @json.from_json(value, path=at)
  (None, at, key) => @serde.missing_field(at, key)
}
```

#### `default`: fill a missing field

`default` calls `Default::default()` when a key is missing. JSON `null` is still passed to the field decoder.

Generated decoder excerpt:

```mbt nocheck
///|
let f3 : Int32 = match @serde.field(obj, "count", [], path) {
  Some(value) => @json.from_json(value, path=path.add_key("count"))
  None => Default::default()
}
```

#### `skip`: exclude a field from the codec

`skip` generates no read or write for `cache`. The decoder restores its default. For an optional field, it restores `None`.

Generated decoder excerpt:

```mbt nocheck
///|
let f4 : Int32 = Default::default()
```

#### `skip_serializing_if`: omit an empty optional field

The supported predicate is `skip_serializing_if="Option::is_none"`. It omits `locale` when it is `None`. Without this attribute, the encoder writes `null`. In both cases, a missing key or JSON `null` decodes as `None`.
For a nested `Option`, `None` and `Some(None)` both encode as `null` when written, and `null` decodes back as `None`.
At the first non-optional type, Serde uses that type's own codec. For example, the array codec handles `Array[T?]`.

Generated encoder excerpt:

```mbt nocheck
  if self.locale is Some(_) {
    obj.set(
      "locale",
      match self.locale {
        None => Json::null()
        Some(option_1) => ToJson::to_json(option_1)
      },
    )
  }
```

#### `deny_unknown_fields`: reject unrecognized keys

The decoder accepts canonical names, read aliases, and the declared object paths. A skipped field name is accepted but its value is ignored. When a record has nested paths, the check also applies to the parent objects on those paths.

Generated decoder excerpt:

```mbt nocheck
  @serde.deny_unknown_paths(
    obj,
    [
      ["displayName"],
      ["email"],
      ["mail"],
      ["meta", "status"],
      ["count"],
      ["cache"],
      ["locale"],
    ],
    path,
  )
```

#### `flatten`: expand a child object into its parent

This model reads `{ "label": "desk", "color": "blue" }` and writes the same object.

```mbt nocheck
///|
#custom.serde
pub struct WithExtras {
  label : String
  #custom.serde(flatten)
  extra : Map[String, Json]
}
```

Generated encoder excerpt:

```mbt nocheck
  @serde.write_flattened(obj, ToJson::to_json(self.extra), ["label"])
```

Generated decoder excerpts:

```mbt nocheck
///|
let remaining = @serde.flattened_remainder(obj, ["label"])
```

```mbt nocheck
///|
let f1 : Map[String, Json] = @json.from_json(remaining, path~)
```

The decoder passes the remaining keys to the flattened field after excluding the other fields' keys, aliases, and top-level path segments.
Use one non-optional flattened field per record and do not combine it with `deny_unknown_fields` or other options on the same field.
The MoonBit `ToJson` trait cannot return an encoding error. Encoding aborts if the field produces a non-object value or a key reserved by the parent.

#### `serialize_with` and `deserialize_with`: convert one field

Use either option to replace the trait call in that direction. The other direction keeps the default codec unless it also has a hook.

```mbt nocheck
///|
fn encode_count(value : Int32) -> Json {
  ToJson::to_json(value)
}

///|
fn decode_count(
  value : Json,
  path : @json.JsonPath,
) -> Int32 raise @json.JsonDecodeError {
  @json.from_json(value, path~)
}

///|
#custom.serde
pub struct Count {
  #custom.serde(serialize_with="encode_count", deserialize_with="decode_count")
  count : Int32
}
```

Generated encoder excerpt:

```mbt nocheck
  obj.set("count", encode_count(self.count))
```

Generated decoder excerpt:

```mbt nocheck
    Some(value) => decode_count(value, path.add_key("count"))
```

Use a function name, an imported function such as `@wire.encode`, or a qualified method such as `Wire::encode`.
The encoder receives the complete field value. The decoder receives the present JSON value and its path.
A missing value still uses the field's usual rules for optional values, defaults, or missing-field errors.
An explicit JSON `null` reaches the decoder hook unchanged.

#### `codec`: use a pair of conversion functions

`codec="Wire"` calls `Wire::serialize` and `Wire::deserialize`. `codec="@wire"` calls `@wire.serialize` and `@wire.deserialize` from an imported package.

```mbt nocheck
///|
priv struct Wire(Int32)

///|
fn Wire::serialize(value : Wire) -> Json {
  let Wire(number) = value
  ToJson::to_json(number)
}

///|
fn Wire::deserialize(
  value : Json,
  path : @json.JsonPath,
) -> Wire raise @json.JsonDecodeError {
  Wire(@json.from_json(value, path~))
}

///|
#custom.serde
priv struct Packet {
  #custom.serde(codec="Wire")
  id : Wire
}
```

Generated encoder excerpt:

```mbt nocheck
  obj.set("id", Wire::serialize(self.id))
```

Generated decoder excerpt:

```mbt nocheck
    Some(value) => Wire::deserialize(value, path.add_key("id"))
```

Do not combine `codec` with either individual hook on the same field.
The field type does not need to implement the JSON traits in the directions provided by hooks.

### Enum options

A single positional argument writes its value. Multiple positional arguments write a JSON array. Named arguments write a JSON object.

#### External tag and variant `rename`

With no representation option, a unit variant writes its tag as a JSON string. A payload variant writes an object with the variant tag as its key. Here `Text("hello")` writes `{ "message": "hello" }`.

```mbt nocheck
///|
#custom.serde
pub enum External {
  Idle
  #custom.serde(rename="message")
  Text(String)
}
```

Generated encoder:

```mbt nocheck
///|
pub impl ToJson for External with fn to_json(self) {
  match self {
    Idle => Json::string("Idle")
    Text(f0) => {
      let payload = ToJson::to_json(f0)
      Json::object({ "message": payload })
    }
  }
}
```

#### `tag`: put the tag in the payload object

`tag="type"` adds a tag to the object. A payload must use labeled constructor arguments unless the enum is decode-only. Here `NewMessage(text="hello")` writes `{ "type": "new_message", "text": "hello" }`.

```mbt nocheck
///|
#custom.serde(tag="type", rename_all="snake_case")
pub enum Internal {
  Idle
  NewMessage(text~ : String)
}
```

Generated encoder arm:

```mbt nocheck
    NewMessage(text=f0) => {
      let obj :Map[String, Json] = Map([])
      obj.set("text", ToJson::to_json(f0))
      obj.set("type", Json::string("new_message"))
      Json::object(obj)
    }
```

With `decode_only`, one non-optional positional argument can read the complete object, including its tag.
For example, `{ "type": "Read", "text": "hello" }` decodes as `Read` with `kind` set to `"Read"`.

```mbt nocheck
///|
#custom.serde(decode_only, tag="type")
pub enum InternalInput {
  Read(InternalData)
}

///|
#custom.serde(decode_only, deny_unknown_fields)
pub struct InternalData {
  #custom.serde(rename="type")
  kind : String
  text : String
}
```

Generated decoder arm:

```mbt nocheck
    "Read" => Read(@json.from_json(value, path~))
```

#### `content`: put the payload next to the tag

Combine `tag="type"` with `content="data"` to put the payload under a separate key. `Text("hello")` writes `{ "type": "Text", "data": "hello" }`. `Idle` has no `data` key.

```mbt nocheck
///|
#custom.serde(tag="type", content="data")
pub enum Adjacent {
  Idle
  Text(String)
}
```

Generated encoder arm:

```mbt nocheck
    Text(f0) => {
      let tagged :Map[String, Json] = { "type": Json::string("Text") }
      let payload = ToJson::to_json(f0)
      tagged.set("data", payload)
      Json::object(tagged)
    }
```

#### `untagged`: use only the payload

`untagged` writes the payload without an enum tag. The decoder tries the variants in declaration order and returns the first match. Here `Text("hello")` writes `"hello"` and `Count(5)` writes `5`.
A unit variant writes `null`.

```mbt nocheck
///|
#custom.serde(untagged)
pub enum Untagged {
  Text(String)
  Count(Int32)
}
```

Generated decoder:

```mbt nocheck
///|
pub impl @json.FromJson for Untagged with fn from_json(value, path) {
  @serde.untagged(value, path, [
    ("Text", serde_decode_Untagged_0),
    ("Count", serde_decode_Untagged_1),
  ])
}
```

Use a tagged representation if more than one variant can decode the same JSON value.

### Generic models

The generator adds `ToJson` and `@json.FromJson` bounds for the necessary type parameters in each direction. A `default` or `skip` rule can also require `Default`.
A skipped field does not require a JSON trait.

```mbt nocheck
///|
#custom.serde
pub struct Box[T](T)
```

Generated code:

```mbt nocheck
///|
pub impl[T : ToJson] ToJson for Box[T] with fn to_json(self) {
  match self {
    Box(f0) => ToJson::to_json(f0)
  }
}

///|
pub impl[T : @json.FromJson] @json.FromJson for Box[T] with fn from_json(
  value,
  path,
) {
  let f0 : T = @json.from_json(value, path~)
  Box(f0)
}
```

### Decode errors

`@json.JsonDecodeError((path, message))` contains a JSON Pointer and a reason.
If the example path `["meta", "status"]` is missing because `meta` is absent, the decoder reports `/meta`, not `/meta/status`.
If no untagged variant matches, the message includes the path and reason for each variant.

## Development

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/serde/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/serde/blob/main/LICENSE)
