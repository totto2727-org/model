///|
fn call(func : @syntax.Expr, args : Array[@syntax.Expr]) -> @syntax.Expr {
  ast_call(func, args.map(ast_arg))
}

///|
fn dot_call(
  receiver : @syntax.Expr,
  name : String,
  args : Array[@syntax.Expr],
) -> @syntax.Expr {
  ast_dot_call(receiver, name, args.map(ast_arg))
}

///|
fn match_expr(
  expr : @syntax.Expr,
  cases : Array[(@syntax.Pattern, @syntax.Expr)],
) -> @syntax.Expr {
  ast_match(
    expr,
    cases.map(fn(case_) {
      let (pat, body) = case_
      ast_case(pat, body)
    }),
  )
}

///|
fn variant_expr(
  name : String,
  args : Array[(String?, @syntax.Expr)],
) -> @syntax.Expr {
  let ctor = ast_ctor(name)
  if args.is_empty() {
    ctor
  } else {
    ast_call(
      ctor,
      args.map(fn(arg) {
        let (label, value) = arg
        match label {
          Some(label) => ast_named_arg(label, value)
          None => ast_arg(value)
        }
      }),
    )
  }
}

///|
fn variant_pat(
  name : String,
  args : Array[(String?, @syntax.Pattern)],
) -> @syntax.Pattern {
  ast_ctor_pat(
    name,
    args.map(fn(arg) {
      let (label, pat) = arg
      ast_pat_arg(pat, label?)
    }),
  )
}

///|
fn string_array(values : Array[String]) -> @syntax.Expr {
  ast_array(values.map(ast_string))
}

///|
fn serde_call(name : String, args : Array[@syntax.Expr]) -> @syntax.Expr {
  call(ast_ident(name, pkg="serde"), args)
}

///|
fn json_call(name : String, args : Array[@syntax.Expr]) -> @syntax.Expr {
  call(ast_method("Json", name), args)
}

///|
fn field_local(index : Int32) -> String {
  "f\{index}"
}

///|
fn encode_value(value : @syntax.Expr, depth : Int32) -> @syntax.Expr {
  if depth == 0 {
    call(ast_method("ToJson", "to_json"), [value])
  } else {
    let inner = "option_\{depth}"
    match_expr(value, [
      (variant_pat("None", []), json_call("null", [])),
      (
        variant_pat("Some", [(None, ast_bind(inner))]),
        encode_value(ast_ident(inner), depth - 1),
      ),
    ])
  }
}

///|
fn decode_value(
  value : @syntax.Expr,
  path : @syntax.Expr,
  depth : Int32,
) -> @syntax.Expr {
  if depth == 0 {
    ast_call(ast_ident("from_json", pkg="json"), [
      ast_arg(value),
      ast_named_arg("path", path),
    ])
  } else {
    let inner = "option_\{depth}"
    match_expr(value, [
      (variant_pat("Null", []), variant_expr("None", [])),
      (
        ast_bind(inner),
        variant_expr("Some", [
          (None, decode_value(ast_ident(inner), path, depth - 1)),
        ]),
      ),
    ])
  }
}

///|
fn key_path(key : String) -> @syntax.Expr {
  dot_call(ast_ident("path"), "add_key", [ast_string(key)])
}

///|
fn missing(
  field : Field,
  path : @syntax.Expr,
  key : @syntax.Expr,
) -> @syntax.Expr {
  if field.default_with is Some(hook) {
    call(hook_expr(hook), [])
  } else if field.optional {
    variant_expr("None", [])
  } else if field.default || field.skip || field.skip_deserializing {
    call(ast_method("Default", "default"), [])
  } else {
    serde_call("missing_field", [path, key])
  }
}

///|
fn hook_expr(hook : Hook) -> @syntax.Expr {
  match hook {
    Function(pkg, name) => ast_ident(name, pkg?)
    Method(pkg, name, method_name) => ast_method(name, method_name, pkg?)
  }
}

///|
fn decode_field_value(
  field : Field,
  value : @syntax.Expr,
  path : @syntax.Expr,
) -> @syntax.Expr {
  match field.deserialize_with {
    Some(hook) => call(hook_expr(hook), [value, path])
    None => decode_value(value, path, field.option_depth)
  }
}

///|
fn scalar_success_cases(
  field : Field,
) -> Array[(@syntax.Pattern, @syntax.Expr)] {
  // Only direct, reserved builtin types without a user decoder can skip the context.
  guard field.deserialize_with is None &&
    field.ty is Name(constr_id={ id: Ident(name~), .. }, tys~, ..) &&
    tys.is_empty() else {
    return []
  }
  fn present(pat : @syntax.Pattern) -> @syntax.Pattern {
    variant_pat("Some", [(None, pat)])
  }
  match name {
    "String" =>
      [
        (
          present(variant_pat("String", [(None, ast_bind("value"))])),
          ast_ident("value"),
        ),
      ]
    "Bool" =>
      [true, false].map(flag => {
        let pat = present(variant_pat(if flag { "True" } else { "False" }, []))
        (pat, @syntax.Expr::Constant(c=Bool(flag), loc=@syntax.no_location))
      })
    _ => []
  }
}

///|
fn decode_field(field : Field) -> @syntax.Expr {
  let field_path = key_path(field.wire_name)
  let value = ast_ident("value")
  let some = variant_pat("Some", [(None, ast_bind("value"))])
  let none = variant_pat("None", [])
  if field.flatten {
    decode_value(ast_ident("remaining"), ast_ident("path"), 0)
  } else if field.skip || field.skip_deserializing {
    missing(field, field_path, ast_string(field.wire_name))
  } else if !field.path.is_empty() {
    let at = ast_ident("at")
    let missing_parts = if field.optional ||
      field.default ||
      field.default_with is Some(_) {
      [none, ast_any(), ast_any()]
    } else {
      [none, ast_bind("at"), ast_bind("key")]
    }
    match_expr(
      serde_call("read_path", [
        ast_ident("obj"),
        string_array(field.path),
        ast_ident("path"),
      ]),
      [
        (
          ast_tuple_pat([some, ast_bind("at"), ast_any()]),
          decode_field_value(field, value, at),
        ),
        (ast_tuple_pat(missing_parts), missing(field, at, ast_ident("key"))),
      ],
    )
  } else {
    let obj = ast_ident("obj")
    let key = ast_string(field.wire_name)
    let lookup = if field.aliases.is_empty() {
      dot_call(obj, "get", [key])
    } else {
      serde_call("field", [
        obj,
        key,
        string_array(field.aliases),
        ast_ident("path"),
      ])
    }
    let cases = scalar_success_cases(field)
    cases.push((some, decode_field_value(field, value, field_path)))
    cases.push((none, missing(field, field_path, key)))
    match_expr(lookup, cases)
  }
}

///|
fn deny_unknown(fields : Array[Field]) -> @syntax.Expr {
  let allowed : Array[Array[String]] = []
  for field in fields {
    if field.skip_deserializing {
      continue
    }
    allowed.push(
      if field.path.is_empty() {
        [field.wire_name]
      } else {
        field.path
      },
    )
    for alternate in field.aliases {
      allowed.push([alternate])
    }
  }
  if allowed.all(keys => keys.length() == 1) {
    serde_call("deny_unknown", [
      ast_ident("obj"),
      string_array(allowed.map(keys => keys[0])),
      ast_ident("path"),
    ])
  } else {
    serde_call("deny_unknown_paths", [
      ast_ident("obj"),
      ast_array(allowed.map(string_array)),
      ast_ident("path"),
    ])
  }
}

///|
fn direct_keys(fields : Array[Field], decode~ : Bool) -> @syntax.Expr {
  let keys = []
  for field in fields {
    if !field.flatten &&
      !(if decode { field.skip_deserializing } else { field.skip_serializing }) {
      keys.push(
        if field.path.is_empty() {
          field.wire_name
        } else {
          field.path[0]
        },
      )
      for alternate in field.aliases {
        keys.push(alternate)
      }
    }
  }
  string_array(keys)
}

///|
fn decode_fields(
  fields : Array[Field],
  deny : Bool,
  result : @syntax.Expr,
) -> @syntax.Expr {
  let mut body = result
  for i = fields.length() - 1; i >= 0; i = i - 1 {
    let field = fields[i]
    body = ast_let(
      ast_bind(field_local(i)),
      decode_field(field),
      body,
      ty=field.ty,
    )
  }
  if deny {
    body = ast_seq([deny_unknown(fields)], body)
  }
  if fields.any(field => field.flatten) {
    body = ast_let(
      ast_bind("remaining"),
      serde_call("flattened_remainder", [
        ast_ident("obj"),
        direct_keys(fields, decode=true),
      ]),
      body,
    )
  }
  ast_let(
    ast_bind("obj"),
    serde_call("object", [ast_ident("value"), ast_ident("path")]),
    body,
  )
}

///|
fn encode_fields(fields : Array[Field], record : Bool) -> Array[@syntax.Expr] {
  let writes = []
  let obj = ast_ident("obj")
  for i, field in fields {
    if field.skip || field.skip_serializing {
      continue
    }
    let value = if record {
      ast_field(ast_ident("self"), field.name)
    } else {
      ast_ident(field_local(i))
    }
    let encoded = match field.serialize_with {
      Some(hook) => call(hook_expr(hook), [value])
      None => encode_value(value, field.option_depth)
    }
    let write = if field.flatten {
      serde_call("write_flattened", [
        obj,
        encoded,
        direct_keys(fields, decode=false),
      ])
    } else if field.path.is_empty() {
      dot_call(obj, "set", [ast_string(field.wire_name), encoded])
    } else {
      serde_call("write_path", [obj, string_array(field.path), encoded])
    }
    writes.push(
      if field.omit_none {
        ast_if(ast_is(value, variant_pat("Some", [(None, ast_any())])), write)
      } else if field.skip_serializing_if is Some(hook) {
        let predicate = call(hook_expr(hook), [value])
        ast_if(
          ast_infix(
            "==",
            predicate,
            Constant(c=Bool(false), loc=@syntax.no_location),
          ),
          write,
        )
      } else {
        write
      },
    )
  }
  writes
}

///|
fn map_type() -> @syntax.Type {
  ast_type("Map", args=[ast_type("String"), ast_type("Json")])
}

///|
fn with_object(
  writes : Array[@syntax.Expr],
  result : @syntax.Expr,
) -> @syntax.Expr {
  ast_let(
    ast_bind("obj"),
    variant_expr("Map", [(None, ast_array([]))]),
    ast_seq(writes, result),
    ty=map_type(),
  )
}

///|
fn uses_type_param(ty : @syntax.Type, param : String) -> Bool {
  match ty {
    Name(constr_id={ id: Ident(name~), .. }, tys~, ..) if tys.is_empty() =>
      name == param
    Name(tys~, ..) | Tuple(tys~, ..) => {
      for child in tys {
        if uses_type_param(child, param) {
          return true
        }
      }
      false
    }
    Option(ty~, ..) => uses_type_param(ty, param)
    _ => false
  }
}

///|
fn codec_quantifiers(
  params : Array[String],
  types : Array[@syntax.Type],
  defaults~ : Array[@syntax.Type] = [],
  decode~ : Bool,
) -> Array[@syntax.TypeVarBinder] {
  let loc = @syntax.no_location
  params.map(name => {
    let constraints : Array[@syntax.TypeVarConstraint] = []
    if types.any(ty => uses_type_param(ty, name)) {
      let trait_ = if decode {
        ast_long_ident("FromJson", Some("json"))
      } else {
        ast_long_ident("ToJson", None)
      }
      constraints.push({ trait_, loc, })
    }
    if defaults.any(ty => uses_type_param(ty, name)) {
      constraints.push({ trait_: ast_long_ident("Default", None), loc, })
    }
    { name, name_loc: loc, constraints: @list.List(constraints), }
  })
}

///|
fn field_quantifiers(
  params : Array[String],
  fields : Array[Field],
  decode~ : Bool,
) -> Array[@syntax.TypeVarBinder] {
  let types = []
  let defaults = []
  for field in fields {
    if !field.skip &&
      !(if decode { field.skip_deserializing } else { field.skip_serializing }) &&
      (if decode { field.deserialize_with } else { field.serialize_with })
      is None {
      types.push(field.ty)
    }
    if decode &&
      !field.optional &&
      field.default_with is None &&
      (field.skip || field.skip_deserializing || field.default) {
      defaults.push(field.ty)
    }
  }
  codec_quantifiers(params, types, defaults~, decode~)
}

///|
fn applied_type(name : String, params : Array[String]) -> @syntax.Type {
  ast_type(name, args=params.map(param => ast_type(param)))
}

///|
fn encode_impl(
  name : String,
  params : Array[String],
  quantifiers : Array[@syntax.TypeVarBinder],
  is_private : Bool,
  body : @syntax.Expr,
) -> @syntax.Impl {
  ast_impl(
    ast_type_name("ToJson"),
    applied_type(name, params),
    quantifiers,
    "to_json",
    [ast_param("self")],
    body,
    is_private,
  )
}

///|
fn decode_impl(
  name : String,
  params : Array[String],
  quantifiers : Array[@syntax.TypeVarBinder],
  is_private : Bool,
  body : @syntax.Expr,
) -> @syntax.Impl {
  ast_impl(
    ast_type_name("FromJson", pkg="json"),
    applied_type(name, params),
    quantifiers,
    "from_json",
    [ast_param("value"), ast_param("path")],
    body,
    is_private,
  )
}

///|
fn emit_record(out : Array[@syntax.Impl], record : RecordDef) -> Unit {
  if !record.decode_only {
    let body = with_object(
      encode_fields(record.fields, true),
      json_call("object", [ast_ident("obj")]),
    )
    let bounds = field_quantifiers(record.params, record.fields, decode=false)
    out.push(
      encode_impl(record.name, record.params, bounds, record.is_private, body),
    )
  }
  if record.encode_only {
    return
  }
  let result = ast_record(
    record.fields.mapi((i, field) => (field.name, ast_ident(field_local(i)))),
  )
  let body = decode_fields(record.fields, record.deny_unknown_fields, result)
  let bounds = field_quantifiers(record.params, record.fields, decode=true)
  out.push(
    decode_impl(record.name, record.params, bounds, record.is_private, body),
  )
}

///|
fn named(variant : Variant) -> Bool {
  !variant.fields.is_empty() && variant.fields[0].label is Some(_)
}

///|
fn constructor_expr(variant : Variant) -> @syntax.Expr {
  variant_expr(
    variant.name,
    variant.fields.mapi((i, field) => (field.label, ast_ident(field_local(i)))),
  )
}

///|
fn constructor_pattern(variant : Variant) -> @syntax.Pattern {
  variant_pat(
    variant.name,
    variant.fields.mapi((i, field) => (field.label, ast_bind(field_local(i)))),
  )
}

///|
fn encode_positional(depths : Array[Int32]) -> @syntax.Expr {
  let values = depths.mapi((i, depth) => {
    encode_value(ast_ident(field_local(i)), depth)
  })
  if values is [single] {
    single
  } else {
    json_call("array", [ast_array(values)])
  }
}

///|
fn decode_positional(
  fields : Array[(@syntax.Type, Int32)],
  result : @syntax.Expr,
) -> @syntax.Expr {
  let value = ast_ident("value")
  let path = ast_ident("path")
  if fields is [(ty, depth)] {
    ast_let(ast_bind("f0"), decode_value(value, path, depth), result, ty~)
  } else {
    let mut body = result
    for i = fields.length() - 1; i >= 0; i = i - 1 {
      let (ty, depth) = fields[i]
      let offset = ast_int(i)
      let item = ast_index(ast_ident("values"), offset)
      let at = dot_call(path, "add_index", [offset])
      body = ast_let(
        ast_bind(field_local(i)),
        decode_value(item, at, depth),
        body,
        ty~,
      )
    }
    ast_let(
      ast_bind("values"),
      serde_call("tuple", [value, ast_int(fields.length()), path]),
      body,
    )
  }
}

///|
fn emit_tuple(out : Array[@syntax.Impl], tuple : TupleDef) -> Unit {
  let fields = tuple.elements.map(ty => (ty, option_depth(ty)))
  if !tuple.decode_only {
    let pattern = variant_pat(
      tuple.name,
      fields.mapi((i, _) => (None, ast_bind(field_local(i)))),
    )
    let payload = encode_positional(fields.map(field => field.1))
    let body = match_expr(ast_ident("self"), [(pattern, payload)])
    let bounds = codec_quantifiers(tuple.params, tuple.elements, decode=false)
    out.push(
      encode_impl(tuple.name, tuple.params, bounds, tuple.is_private, body),
    )
  }
  if tuple.encode_only {
    return
  }
  let result = variant_expr(
    tuple.name,
    fields.mapi((i, _) => (None, ast_ident(field_local(i)))),
  )
  out.push(
    decode_impl(
      tuple.name,
      tuple.params,
      codec_quantifiers(tuple.params, tuple.elements, decode=true),
      tuple.is_private,
      decode_positional(fields, result),
    ),
  )
}

///|
fn with_payload(variant : Variant, body : @syntax.Expr) -> @syntax.Expr {
  let payload = ast_bind("payload")
  if variant.fields.is_empty() {
    ast_let(payload, json_call("null", []), body, ty=ast_type("Json"))
  } else if named(variant) {
    with_object(
      encode_fields(variant.fields, false),
      ast_let(payload, json_call("object", [ast_ident("obj")]), body),
    )
  } else {
    ast_let(
      payload,
      encode_positional(variant.fields.map(f => f.option_depth)),
      body,
    )
  }
}

///|
fn encode_variant(repr : Representation, variant : Variant) -> @syntax.Expr {
  let tag_value = json_call("string", [ast_string(variant.wire_name)])
  let payload = ast_ident("payload")
  match repr {
    External if variant.fields.is_empty() => tag_value
    External =>
      with_payload(
        variant,
        json_call("object", [ast_map([(variant.wire_name, payload)])]),
      )
    Internal(tag) => {
      let obj = ast_ident("obj")
      let writes = encode_fields(variant.fields, false)
      writes.push(dot_call(obj, "set", [ast_string(tag), tag_value]))
      with_object(writes, json_call("object", [obj]))
    }
    Adjacent(tag, content) => {
      let tagged = ast_ident("tagged")
      let result = json_call("object", [tagged])
      let body = if variant.fields.is_empty() {
        result
      } else {
        with_payload(
          variant,
          ast_seq(
            [dot_call(tagged, "set", [ast_string(content), payload])],
            result,
          ),
        )
      }
      ast_let(
        ast_bind("tagged"),
        ast_map([(tag, tag_value)]),
        body,
        ty=map_type(),
      )
    }
    Untagged => with_payload(variant, payload)
  }
}

///|
fn emit_enum_encode(sum : EnumDef) -> @syntax.Impl {
  let cases = sum.variants.map(variant => {
    (constructor_pattern(variant), encode_variant(sum.repr, variant))
  })
  let bounds = enum_quantifiers(sum, decode=false)
  encode_impl(
    sum.name,
    sum.params,
    bounds,
    sum.is_private,
    match_expr(ast_ident("self"), cases),
  )
}

///|
fn enum_quantifiers(
  sum : EnumDef,
  decode~ : Bool,
) -> Array[@syntax.TypeVarBinder] {
  let fields = []
  for variant in sum.variants {
    fields.append(variant.fields)
  }
  field_quantifiers(sum.params, fields, decode~)
}

///|
fn decoder_name(sum : EnumDef, index : Int32) -> String {
  "serde_decode_\{sum.name}_\{index}"
}

///|
fn emit_variant_decoder(
  sum : EnumDef,
  variant : Variant,
  index : Int32,
) -> @syntax.Impl {
  let value = ast_ident("value")
  let path = ast_ident("path")
  let result = constructor_expr(variant)
  let body = if variant.fields.is_empty() {
    ast_seq(
      [
        ast_if(
          ast_infix("!=", value, json_call("null", [])),
          serde_call("invalid", [
            path,
            ast_string("expected null for a unit variant"),
          ]),
        ),
      ],
      result,
    )
  } else if named(variant) {
    decode_fields(variant.fields, false, result)
  } else {
    decode_positional(
      variant.fields.map(field => (field.ty, field.option_depth)),
      result,
    )
  }
  ast_func(
    decoder_name(sum, index),
    field_quantifiers(sum.params, variant.fields, decode=true),
    [
      ast_param("value", ty=ast_type("Json")),
      ast_param("path", ty=ast_type("JsonPath", pkg="json")),
    ],
    applied_type(sum.name, sum.params),
    ast_type("JsonDecodeError", pkg="json"),
    body,
  )
}

///|
fn decode_tagged_variant(
  sum : EnumDef,
  variant : Variant,
  index : Int32,
) -> @syntax.Expr {
  let value = ast_ident("value")
  let path = ast_ident("path")
  let content = ast_ident("content")
  let decode = ast_ident(decoder_name(sum, index))
  match sum.repr {
    Internal(_) if variant.fields.is_empty() => constructor_expr(variant)
    Internal(_) if named(variant) => call(decode, [value, path])
    Internal(_) =>
      variant_expr(variant.name, [(None, decode_value(value, path, 0))])
    _ if variant.fields.is_empty() =>
      ast_seq(
        [serde_call("unit", [content, path])],
        call(decode, [json_call("null", []), path]),
      )
    repr => {
      let payload_path = match repr {
        External => key_path(variant.wire_name)
        Adjacent(_, key) => key_path(key)
        _ => path
      }
      ast_let(
        ast_bind("path"),
        payload_path,
        call(decode, [serde_call("payload", [content, path]), path]),
      )
    }
  }
}

///|
fn decode_tagged(sum : EnumDef) -> @syntax.Expr {
  let value = ast_ident("value")
  let path = ast_ident("path")
  let obj = ast_ident("obj")
  let tag = ast_ident("tag")
  let cases = sum.variants.mapi((i, variant) => {
    (ast_string_pat(variant.wire_name), decode_tagged_variant(sum, variant, i))
  })
  let tag_path = match sum.repr {
    Internal(key) | Adjacent(key, _) => key_path(key)
    _ => path
  }
  cases.push(
    (
      ast_any(),
      serde_call("invalid", [
        tag_path,
        ast_infix("+", ast_string("unknown enum variant: "), tag),
      ]),
    ),
  )
  let body = match_expr(tag, cases)
  match sum.repr {
    External =>
      ast_let(
        ast_tuple_pat([ast_bind("tag"), ast_bind("content")]),
        serde_call("external", [value, path]),
        body,
      )
    Internal(key) | Adjacent(key, _) => {
      let body = if sum.repr is Adjacent(_, content) {
        ast_let(
          ast_bind("content"),
          dot_call(obj, "get", [ast_string(content)]),
          body,
        )
      } else {
        body
      }
      ast_let(
        ast_bind("obj"),
        serde_call("object", [value, path]),
        ast_let(
          ast_bind("tag"),
          serde_call("discriminator", [obj, ast_string(key), path]),
          body,
        ),
      )
    }
    Untagged => body
  }
}

///|
fn decode_untagged(sum : EnumDef) -> @syntax.Expr {
  let candidates = sum.variants.mapi((i, variant) => {
    @syntax.make_tuple_expr(
      loc=@syntax.no_location,
      @list.List([ast_string(variant.name), ast_ident(decoder_name(sum, i))]),
    )
  })
  serde_call("untagged", [
    ast_ident("value"),
    ast_ident("path"),
    ast_array(candidates),
  ])
}

///|
fn emit_enum_decode(out : Array[@syntax.Impl], sum : EnumDef) -> Unit {
  for i, variant in sum.variants {
    if !(sum.repr is Internal(_) && !named(variant)) {
      out.push(emit_variant_decoder(sum, variant, i))
    }
  }
  let body = match sum.repr {
    Untagged => decode_untagged(sum)
    _ => decode_tagged(sum)
  }
  out.push(
    decode_impl(
      sum.name,
      sum.params,
      enum_quantifiers(sum, decode=true),
      sum.is_private,
      body,
    ),
  )
}

///|
/// Marker for source files owned by the generator.
pub const GENERATED_HEADER = "// Generated by totto2727/serde. Do not edit."

///|
/// Emit standard ToJson and FromJson implementations. The caller imports @serde and @json in the generated package.
pub fn emit(definitions : Array[Definition]) -> String {
  let out : Array[@syntax.Impl] = []
  for definition in definitions {
    match definition {
      Record(record) => emit_record(out, record)
      TupleStruct(tuple) => emit_tuple(out, tuple)
      Sum(sum) => {
        if !sum.decode_only {
          out.push(emit_enum_encode(sum))
        }
        if !sum.encode_only {
          emit_enum_decode(out, sum)
        }
      }
    }
  }
  GENERATED_HEADER + "\n" + @fmt.impls_to_string(@list.List(out))
}

///|
/// Parse with the official MoonBit AST library, validate attributes, and emit static codecs.
pub fn generate(
  source : String,
  name~ : String = "<input>",
) -> String raise GenerateError {
  generate_many([(name, source)])
}

///|
/// Generate one package's codecs from (source name, source text) pairs in input order.
pub fn generate_many(
  sources : Array[(String, String)],
) -> String raise GenerateError {
  let definitions : Array[Definition] = []
  let seen : Map[String, String] = Map([])
  for pair in sources {
    let (name, source) = pair
    for pair in parse_located(source, name) {
      let (definition, loc) = pair
      let ty = match definition {
        Record(record) => record.name
        TupleStruct(tuple) => tuple.name
        Sum(sum) => sum.name
      }
      if seen.get(ty) is Some(previous) {
        raise GenerateError(
          "\{loc}: duplicate annotated type \{ty} (first defined at \{previous})",
        )
      }
      seen.set(ty, loc)
      definitions.push(definition)
    }
  }
  emit(definitions)
}
