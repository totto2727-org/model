///|
/// A generated struct codec distinguishes missing fields from explicit null.
#derive(Eq, Debug)
#custom.serde
pub(all) struct Record {
  required : Int32
  optional : String?
  #custom.serde(default)
  count : Int32
  #custom.serde(rename="displayName", aliases="legacy_name")
  name : String
  #custom.serde(skip)
  transient : Int32
  #custom.serde(skip_serializing_if="Option::is_none")
  omitted : Int32?
}

///|
/// Unknown fields are rejected only when the container opts in.
#derive(Eq, Debug)
#custom.serde(deny_unknown_fields)
pub(all) struct StrictRecord {
  value : Int32
}

///|
/// Container casing applies to fields without changing explicit wire names.
#derive(Eq, Debug)
#custom.serde(rename_all="camelCase")
pub(all) struct CamelRecord {
  first_name : String
  #custom.serde(rename="fixed_name")
  last_name : String
}

///|
/// The external representation covers every supported constructor shape.
#derive(Eq, Debug)
#custom.serde(rename_all="snake_case")
pub(all) enum External {
  Idle
  NewValue(Int32)
  Pair(String, Int32)
  Named(label~ : String, child~ : StrictRecord)
  #custom.serde(rename="renamed")
  Special
  #custom.serde(rename="Maybe")
  Maybe(String?)
}

///|
/// Internal tags coexist with named constructor payload fields.
#derive(Eq, Debug)
#custom.serde(tag="type", rename_all="snake_case")
pub(all) enum Internal {
  Idle
  Named(value~ : Int32, note~ : String?)
}

///|
/// Adjacent tags keep discriminator and payload in separate members.
#derive(Eq, Debug)
#custom.serde(tag="type", content="data", rename_all="snake_case")
pub(all) enum Adjacent {
  Idle
  Value(Int32)
  Pair(String, Int32)
  Named(value~ : Int32)
  Maybe(String?)
}

///|
/// Untagged decoding chooses the first matching constructor.
#derive(Eq, Debug)
#custom.serde(untagged)
pub(all) enum Untagged {
  Integer(Int32)
  Text(String)
  Named(value~ : Int32)
}

///|
/// Nested generated codecs preserve collection and field error paths.
#derive(Eq, Debug)
#custom.serde
pub(all) struct Envelope {
  records : Array[StrictRecord]
  event : External?
  nested : String??
}

///|
#custom.serde(decode_only)
#derive(ToJson)
pub struct DecodeOnlyRecord {
  count : Int32
}

///|
#custom.serde(tag="type", rename_all="snake_case", decode_only)
pub enum DecodeOnlyEvent {
  Done
  Data(DecodeOnlyRecord)
  Named(text~ : String)
}

///|
#custom.serde
priv struct PrivateRecord {
  event : PrivateEvent
}

///|
#custom.serde(rename_all="snake_case")
priv enum PrivateEvent {
  Closed
}

///|
test "PrivateRecord - derive codecs without exporting the internal wire type" {
  let input : Json = { "event": "closed" }
  let parsed : PrivateRecord = @json.from_json(input)
  assert_true(parsed.event is Closed)
  assert_eq(ToJson::to_json(parsed), input)
}

///|
#custom.serde(deny_unknown_fields)
pub struct FixedPath {
  #custom.serde(path=["part", "state", "status"])
  status : String
  #custom.serde(path=["part", "state", "count"], default)
  count : Int32
  #custom.serde(path=["part", "note"], skip_serializing_if="Option::is_none")
  note : String?
  #custom.serde(path=["extras", "a/b~.c"], skip_serializing_if="Option::is_none")
  extra : String?
  #custom.serde(path=["extras", "quote\"\\"], skip_serializing_if="Option::is_none")
  escaped : String?
  #custom.serde(aliases="legacy")
  label : String
}

///|
#custom.serde
pub struct Distance(Int32)

///|
#custom.serde
pub struct Measurement(Distance, String?)

///|
#custom.serde(decode_only)
priv struct PrivateTuple(Int32, Bool?)

///|
impl ToJson for PrivateTuple with fn to_json(self) {
  let PrivateTuple(first, second) = self
  { "first": first, "flag": second.unwrap_or(false) }
}

///|
test "private tuple struct - decode_only preserves the handwritten encoder" {
  let decoded : PrivateTuple = @json.from_json([3, true])
  assert_eq(ToJson::to_json(decoded), { "first": 3, "flag": true })
}

///|
#custom.serde
pub struct GenericRecord[T, U] {
  #custom.serde(path=["data", "items"])
  items : Array[T]
  #custom.serde(default)
  fallback : U
}

///|
#custom.serde
pub struct GenericBox[T](T)

///|
#custom.serde
pub struct GenericPair[T, U](GenericBox[T], U?)

///|
#custom.serde(tag="type", content="data")
pub enum GenericAdjacent[T, U] {
  Empty
  Positional(T)
  Named(value~ : U)
}

///|
#custom.serde(untagged)
pub enum GenericUntagged[T] {
  Scalar(T)
  Batch(items~ : Array[T])
}

///|
#custom.serde(decode_only)
pub struct ReadOnlyBox[T](T)

///|
#custom.serde(encode_only)
pub(all) struct WriteOnlyRecord[T] {
  #custom.serde(rename="id")
  identifier : T
}

///|
#custom.serde(encode_only)
pub(all) struct WriteOnlyTuple[T](T, Bool)

///|
#custom.serde(encode_only, tag="type", content="data")
pub(all) enum WriteOnlyEvent[T] {
  Value(T)
}

///|
#derive(Default)
pub struct DefaultOnly(Int32)

///|
#custom.serde
pub struct WithSkipped[T, U] {
  value : T
  #custom.serde(skip)
  hidden : U
}
