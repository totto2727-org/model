///|
#custom.serde
#custom.garde
pub(all) struct Address {
  #custom.garde(length(equal="2"))
  code : String
}

///|
#custom.serde
#custom.garde
pub(all) struct Account {
  #custom.serde(rename="displayName")
  #custom.garde(length(min="3"), custom(garde_value))
  name : String
  #custom.garde(range(min="-1", max="10"))
  level : Int32
  #custom.garde(required, length(min="2"))
  contact : String?
  #custom.garde(dive)
  address : Address?
  #custom.garde(length(min="1"), inner(dive))
  locations : Array[Address]
  #custom.garde(skip)
  notes : String
}

///|
fn garde_value(name : String) -> String? {
  if name == "x" {
    Some("name is reserved")
  } else {
    None
  }
}

///|
#custom.garde(allow_unvalidated)
pub(all) struct Queue {
  #custom.garde(inner(inner(required, range(min="0"))))
  batches : FixedArray[ReadOnlyArray[Int32?]]
  name : String
}

///|
#custom.serde
#custom.garde(field(index="0", ascii, alphanumeric, prefix("A")))
pub(all) struct Code(String)

///|
pub impl @garde.Length for Code with fn garde_length(self) {
  let Code(text) = self
  text.length()
}

///|
#custom.serde
#custom.garde(field(index="0", dive), field(index="1", required))
pub struct Pair(Code, String?)

///|
#custom.serde
#custom.garde
pub(all) struct Batch[T, U] {
  #custom.garde(inner(dive))
  items : Array[T]
  #custom.garde(skip)
  metadata : U
}

///|
#custom.serde(tag="kind", content="data", rename_all="snake_case")
#custom.garde
pub enum Entry[T] {
  Empty
  #custom.garde(field(index="0", dive), field(index="1", skip))
  CodeEntry(T, Int32)
  #custom.garde(field(name="label", contains("\""), suffix("\u0021")))
  Named(label~ : String)
  #custom.garde(skip)
  Unchecked(String)
}

///|
#custom.garde(field(index="0", length(min="2")))
pub(all) struct Sized[T](T)

///|
#custom.garde(bounds(T, [Length]), field(index="0", dive))
pub(all) struct NestedSized[T](Sized[T])

///|
#custom.garde(field(index="0", length(min="2"), dive))
pub(all) struct Measured[T](T)

///|
pub(all) struct Policy {
  max_count : Int32
}

///|
#custom.serde
#custom.garde(context=Policy)
pub(all) struct Allocation {
  #custom.garde(range(min="0"), custom_with(check_count))
  count : Int32
}

///|
fn check_count(count : Int32, policy : Policy) -> String? {
  if count > policy.max_count {
    Some("exceeds quota")
  } else {
    None
  }
}

///|
#custom.serde
#custom.garde(context=Policy)
pub(all) struct Request {
  #custom.garde(inner(dive_with))
  allocations : Array[Allocation]
}

///|
#custom.serde
#custom.garde
pub(all) struct Confirmation {
  #custom.serde(rename="repeatedCode")
  #custom.garde(matches(code))
  repeated : String?
  #custom.garde(pattern("^ID-[0-9]+\\.$"))
  code : String?
}

///|
#custom.garde
pub(all) struct Same[T] {
  #custom.garde(matches(original))
  repeated : T
  #custom.garde(skip)
  original : T
}

///|
#custom.serde
#custom.garde
pub(all) struct ContactDetails {
  #custom.garde(email)
  email : String
  #custom.garde(url)
  website : String
  #custom.garde(inner(ip))
  addresses : Array[String]
  #custom.garde(ipv4)
  v4 : String?
  #custom.garde(ipv6)
  v6 : String?
  #custom.garde(credit_card)
  card : String?
  #custom.garde(phone_number)
  phone : String?
}

///|
const MINIMUM_WIDE : Int64 = 9007199254740993L

///|
#custom.garde(transparent, field(index="0", pattern(is_uppercase_code)))
pub(all) struct ProductCode(String)

///|
fn is_uppercase_code(value : String) -> Bool {
  value.has_prefix("SKU-")
}

///|
#custom.garde
pub(all) struct OrderChecks {
  #custom.garde(skip)
  strict : Bool
  #custom.garde(when(is_strict, required, dive))
  product : ProductCode?
  #custom.garde(range(min=MINIMUM_WIDE))
  quantity : Int64
  #custom.garde(range(min="0.5", max="2.5"))
  multiplier : Double
  #custom.garde(skip)
  policy : Policy
  #custom.garde(inner(dive_with(policy)))
  allocations : Array[Allocation]
}

///|
fn is_strict(value : OrderChecks) -> Bool {
  value.strict
}

///|
#custom.garde
pub(all) struct NumericRanges {
  #custom.garde(range(min="9007199254740993", max="9007199254740994"))
  wide : Int64
  #custom.garde(range(min="18446744073709551614", max="18446744073709551615"))
  unsigned : UInt64
  #custom.garde(range(equal="1000000000000000000000000000001N"))
  huge : @bigint.BigInt
  #custom.garde(range(min="1.00000002", max="1.00000001"))
  single : Float
  #custom.garde(range(min="-1.25e-1", max="2_000.0"))
  double : Double
  #custom.garde(range(min="0x10", max="0x20"))
  base16 : Int32
}

///|
#custom.garde
pub(all) struct ReversedRange {
  #custom.garde(range(min="9007199254740993", max="9007199254740992"))
  wide : Int64
}
