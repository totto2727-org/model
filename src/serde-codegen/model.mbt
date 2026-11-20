///|
#derive(@debug.Debug)
pub suberror GenerateError {
  GenerateError(String)
}

///|
#deprecated
pub extend GenerateError with @debug.Debug::{to_repr}

///|
pub(all) enum Definition {
  Record(RecordDef)
  Sum(EnumDef)
  TupleStruct(TupleDef)
}

///|
pub(all) struct RecordDef {
  name : String
  params : Array[String]
  fields : Array[Field]
  deny_unknown_fields : Bool
  decode_only : Bool
  encode_only : Bool
  is_private : Bool
}

///|
pub(all) struct TupleDef {
  name : String
  params : Array[String]
  elements : Array[@syntax.Type]
  decode_only : Bool
  encode_only : Bool
  is_private : Bool
}

///|
pub(all) struct EnumDef {
  name : String
  params : Array[String]
  variants : Array[Variant]
  repr : Representation
  decode_only : Bool
  encode_only : Bool
  is_private : Bool
}

///|
pub(all) enum Representation {
  External
  Internal(String)
  Adjacent(String, String)
  Untagged
}

///|
pub(all) struct Variant {
  name : String
  wire_name : String
  fields : Array[Field]
}

///|
pub(all) struct Field {
  name : String
  label : String?
  wire_name : String
  aliases : Array[String]
  path : Array[String]
  ty : @syntax.Type
  optional : Bool
  option_depth : Int32
  default : Bool
  skip : Bool
  omit_none : Bool
  flatten : Bool
  serialize_with : Hook?
  deserialize_with : Hook?
}

///|
pub(all) enum Hook {
  Function(String?, String)
  Method(String?, String, String)
}
