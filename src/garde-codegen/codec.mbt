///|
priv struct Conversion {
  ty : String
  parser : String
  printer : String
}

///|
fn field_conversion(
  field : @syntax.FieldDecl,
) -> Conversion? raise GenerateError {
  guard options(field.attrs) is Some((at, props)) else { return None }
  let formats = field_rules(props, at).filter_map(rule => {
    match rule {
      Text("url", None) =>
        Some({ ty: "Url", parser: "parse_url", printer: "encode", })
      Text("ip" | "ipv4" | "ipv6", None) =>
        Some({ ty: "Addr", parser: "parse_ip", printer: "to_string", })
      Text("phone_number", None) =>
        Some({
          ty: "PhoneNumber",
          parser: "parse_phone_number",
          printer: "to_string",
        })
      _ => None
    }
  })
  match formats {
    [] => None
    [conversion] => Some(conversion)
    _ =>
      raise GenerateError(
        "\{at}: garde codec supports one URL, IP, or phone number format per field",
      )
  }
}

///|
fn domain_type(field : @syntax.FieldDecl, name : String) -> @syntax.Type {
  let loc = field.loc
  let ty : @syntax.Type = Name(
    constr_id={ id: Dot(pkg="garde", id=name), loc, },
    tys=@list.List([]),
    loc~,
  )
  if option_value(field.ty) is Some(_) {
    Option(ty~, loc~, question_loc=loc)
  } else {
    ty
  }
}

///|
fn emit_codec(
  out : StringBuilder,
  decl : @syntax.TypeDecl,
  fields : @list.List[@syntax.FieldDecl],
  visibility : String,
  quantifiers : String,
  wire : String,
  p : String,
) -> Unit raise GenerateError {
  let name = decl.tycon
  let decoded = "\{name}Decoded"
  let domain = decoded + wire[name.length():].to_owned()
  let encode_fields : Array[String] = []
  let decode_fields : Array[String] = []
  let decode_body = StringBuilder()
  let domain_fields : Array[@syntax.FieldDecl] = []
  for field in fields {
    let field_name = field.name.label
    let source = "\{p}value.\{field_name}"
    let mut ty = field.ty
    let (read, write) = match field_conversion(field) {
      None => (source, source)
      Some(conversion) => {
        ty = domain_type(field, conversion.ty)
        let binding = "\{p}decoded_\{field_name}"
        let item = "\{p}item"
        let parsed = "\{p}parsed"
        let error = "return Err(@garde.conversion_failure(\"\{field_name}\", \"could not convert validated value\"))"
        if option_value(field.ty) is Some(_) {
          decode_body.write_string(
            "let \{binding} = match \{source} {\nNone => None\nSome(\{item}) => {\nguard @garde.\{conversion.parser}(\{item}) is Some(\{parsed}) else { \{error} }\nSome(\{parsed})\n}\n}\n",
          )
          (binding, "\{source}.map(\{item} => \{item}.\{conversion.printer}())")
        } else {
          decode_body.write_string(
            "guard @garde.\{conversion.parser}(\{source}) is Some(\{binding}) else { \{error} }\n",
          )
          (binding, "\{source}.\{conversion.printer}()")
        }
      }
    }
    decode_fields.push("\{field_name}: \{read}")
    encode_fields.push("\{field_name}: \{write}")
    domain_fields.push({ ..field, ty, attrs: @list.List([]), })
  }
  let domain_decl : @syntax.TypeDecl = {
    ..decl,
    tycon: decoded,
    attrs: @list.List([]),
    deriving: @list.List([]),
    doc: @syntax.DocString::empty(),
    components: Record(fields=@list.List(domain_fields), constr_decl=None),
  }
  out.write_string(@fmt.impls_to_string(@list.List([TopTypeDef(domain_decl)])))
  out.write_string(
    "\n\{visibility}impl\{quantifiers} @garde.Decode for \{wire}\n\{visibility}impl\{quantifiers} @garde.Encode for \{domain}\n",
  )
  out.write_string(
    "\{visibility}fn\{quantifiers} \{name}::codec() -> @garde.Codec[\{wire}, \{domain}] {\n@garde.Codec::new(fn (\{p}value) {\n\{decode_body.to_string()}Ok(\{decoded}::{ \{decode_fields.join(", ")} })\n}, fn (\{p}value) {\n\{name}::{ \{encode_fields.join(", ")} }\n})\n}\n",
  )
}
