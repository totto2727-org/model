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
fn decoded_constructor(
  decl : @syntax.TypeDecl,
  fields : Array[@syntax.FieldDecl],
) -> @syntax.Impl {
  let loc = @syntax.no_location
  let name = decl.tycon
  let id : @syntax.LongIdent = Ident(name~)
  let type_name : @syntax.TypeName = { name: id, is_object: false, loc, }
  let quantifiers : Array[@syntax.TypeVarBinder] = decl.params
    .to_array()
    .map(param => {
      name: param.name.unwrap(),
      name_loc: loc,
      constraints: @list.List([]),
    })
  let type_args = quantifiers.map(param => {
    @syntax.Type::Name(
      constr_id={ id: Ident(name=param.name), loc, },
      tys=@list.List([]),
      loc~,
    )
  })
  let params = fields.map(field => {
    let binder : @syntax.Binder = {
      name: field.name.label,
      loc: field.name.loc,
    }
    let ty = Some(field.ty)
    if fields.length() >= 2 {
      @syntax.Parameter::Labelled(binder~, ty~)
    } else {
      @syntax.Parameter::Positional(binder~, ty~)
    }
  })
  let values : Array[@syntax.FieldDef] = fields.map(field => {
    let name = field.name.label
    {
      label: { name, loc, },
      expr: Ident(id={ name: Ident(name~), loc, }, loc~),
      is_pun: true,
      loc,
    }
  })
  let fun_decl : @syntax.FunDecl = {
    type_name: Some(type_name),
    name: { name, loc, },
    is_async: None,
    decl_params: Some(@list.List(params)),
    params_loc: loc,
    quantifiers: @list.List(quantifiers),
    return_type: Some(
      Name(constr_id={ id, loc, }, tys=@list.List(type_args), loc~),
    ),
    error_type: NoErrorType,
    nocancel_: None,
    vis: decl.type_vis,
    attrs: @list.List([]),
    doc: @syntax.DocString::empty(),
    loc,
  }
  let body : @syntax.Expr = Record(
    type_name=if fields.is_empty() { Some(type_name) } else { None },
    fields=@list.List(values),
    trailing=Comma,
    loc~,
  )
  TopFuncDef(fun_decl~, decl_body=DeclBody(expr=body), where_clause=None, loc~)
}

///|
fn emit_conversion(
  out : StringBuilder,
  decl : @syntax.TypeDecl,
  fields : @list.List[@syntax.FieldDecl],
  visibility : String,
  validate_quantifiers : String,
  json_quantifiers : String?,
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
    type_vis: if decl.type_vis is Priv(..) {
      decl.type_vis
    } else {
      Pub(attr=None, loc=decl.loc)
    },
    attrs: @list.List([]),
    deriving: @list.List([]),
    doc: @syntax.DocString::empty(),
    components: Record(fields=@list.List(domain_fields), constr_decl=None),
  }
  out.write_string(
    @fmt.impls_to_string(
      @list.List([
        TopTypeDef(domain_decl),
        decoded_constructor(domain_decl, domain_fields),
      ]),
    ),
  )
  let value = p + "value"
  out.write_string(
    "\n\{visibility}fn\{validate_quantifiers} \{name}::to_decoded(\{value} : \{wire}) -> Result[\{domain}, @garde.Report] {\nif @garde.validate(\{value}) is Err(report) { return Err(report) }\n\{decode_body.to_string()}Ok(\{decoded}::{ \{decode_fields.join(", ")} })\n}\n",
  )
  out.write_string(
    "\{visibility}fn\{validate_quantifiers} \{decoded}::to_encoded(\{if fields.is_empty() { "_" } else { value }} : \{domain}) -> Result[\{wire}, @garde.Report] {\nlet \{p}encoded = \{name}::{ \{encode_fields.join(", ")} }\nmatch @garde.validate(\{p}encoded) {\nOk(_) => Ok(\{p}encoded)\nErr(report) => Err(report)\n}\n}\n",
  )
  if json_quantifiers is Some(quantifiers) {
    out.write_string(
      "\{visibility}fn\{quantifiers} \{decoded}::to_json(self : \{domain}) -> Result[Json, @garde.Report] {\nself.to_encoded().map(encoded => ToJson::to_json(encoded))\n}\n",
    )
  }
}
