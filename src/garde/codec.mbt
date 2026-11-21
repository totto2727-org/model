///|
/// A pair of model conversions. `W` is the wire type and `D` is the domain type.
struct Codec[W, D] {
  to_domain : (W) -> Result[D, Report]
  to_wire : (D) -> W
}

///|
/// Pair conversions between a wire model and a domain model.
pub fn[W, D] Codec::new(
  to_domain : (W) -> Result[D, Report],
  to_wire : (D) -> W,
) -> Codec[W, D] {
  { to_domain, to_wire, }
}

///|
/// A wire model that validates before conversion to a domain model.
pub(open) trait Decode: Validate {
  fn[D] decode_with(Self, Codec[Self, D]) -> Result[D, Report] = _
}

///|
impl Decode with fn decode_with(self, codec) {
  match validate(self) {
    Ok(_) => (codec.to_domain)(self)
    Err(report) => Err(report)
  }
}

///|
/// A domain model that converts to a wire model and validates the result.
pub(open) trait Encode {
  fn[W : Validate] encode_with(Self, Codec[W, Self]) -> Result[W, Report] = _
}

///|
impl Encode with fn encode_with(self, codec) {
  let wire = (codec.to_wire)(self)
  match validate(wire) {
    Ok(_) => Ok(wire)
    Err(report) => Err(report)
  }
}

///|
/// Validate a wire model, then convert it to the paired domain type.
pub fn[W : Decode, D] decode(
  wire : W,
  codec : Codec[W, D],
) -> Result[D, Report] {
  W::decode_with(wire, codec)
}

///|
/// Convert a domain model to the paired wire type, then validate the result.
pub fn[W : Validate, D : Encode] encode(
  domain : D,
  codec : Codec[W, D],
) -> Result[W, Report] {
  D::encode_with(domain, codec)
}

///|
/// Report a conversion failure at a record field.
pub fn conversion_failure(field : String, message : String) -> Report {
  let report = { violations: [], }
  let root = Path::{ reversed: @list.List([]), }
  report.add(root.field(field), message)
  report
}
