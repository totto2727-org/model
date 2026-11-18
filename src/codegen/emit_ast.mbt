///|
fn ast_long_ident(name : String, pkg : String?) -> @syntax.LongIdent {
  match pkg {
    Some(pkg) => Dot(pkg~, id=name)
    None => Ident(name~)
  }
}

///|
fn ast_var(name : String, pkg : String?) -> @syntax.Var {
  { name: ast_long_ident(name, pkg), loc: @syntax.no_location, }
}

///|
fn ast_binder(name : String) -> @syntax.Binder {
  { name, loc: @syntax.no_location, }
}

///|
fn ast_label(name : String) -> @syntax.Label {
  { name, loc: @syntax.no_location, }
}

///|
fn ast_type_name(name : String, pkg? : String) -> @syntax.TypeName {
  {
    name: ast_long_ident(name, pkg),
    is_object: false,
    loc: @syntax.no_location,
  }
}

///|
fn ast_type(
  name : String,
  args~ : Array[@syntax.Type] = [],
  pkg? : String,
) -> @syntax.Type {
  let loc = @syntax.no_location
  Name(
    constr_id={ id: ast_long_ident(name, pkg), loc, },
    tys=@list.List(args),
    loc~,
  )
}

///|
fn ast_ident(name : String, pkg? : String) -> @syntax.Expr {
  Ident(id=ast_var(name, pkg), loc=@syntax.no_location)
}

///|
fn ast_method(
  type_name : String,
  method_id : String,
  pkg? : String,
) -> @syntax.Expr {
  Method(
    type_name=ast_type_name(type_name, pkg?),
    method_name=ast_label(method_id),
    loc=@syntax.no_location,
  )
}

///|
fn ast_call(
  func : @syntax.Expr,
  args : Array[@syntax.Argument],
) -> @syntax.Expr {
  Apply(func~, args=@list.List(args), loc=@syntax.no_location)
}

///|
fn ast_arg(value : @syntax.Expr) -> @syntax.Argument {
  { value, kind: Positional, }
}

///|
fn ast_named_arg(name : String, value : @syntax.Expr) -> @syntax.Argument {
  { value, kind: Labelled(ast_label(name)), }
}

///|
fn ast_dot_call(
  receiver : @syntax.Expr,
  method_id : String,
  args : Array[@syntax.Argument],
) -> @syntax.Expr {
  DotApply(
    self=receiver,
    method_name=ast_label(method_id),
    args=@list.List(args),
    return_self=false,
    loc=@syntax.no_location,
  )
}

///|
fn ast_field(receiver : @syntax.Expr, name : String) -> @syntax.Expr {
  Field(
    record=receiver,
    accessor=Label(ast_label(name)),
    loc=@syntax.no_location,
  )
}

///|
fn ast_string_constant(value : String) -> @syntax.Constant {
  // The literal is an escaped lexeme without its surrounding quotes.
  String(value.escape(quote=false))
}

///|
fn ast_string(value : String) -> @syntax.Expr {
  Constant(c=ast_string_constant(value), loc=@syntax.no_location)
}

///|
fn ast_int(value : Int32) -> @syntax.Expr {
  Constant(c=Int(value.to_string()), loc=@syntax.no_location)
}

///|
fn ast_array(exprs : Array[@syntax.Expr]) -> @syntax.Expr {
  Array(exprs=@list.List(exprs), is_iter=false, loc=@syntax.no_location)
}

///|
fn ast_index(array : @syntax.Expr, index : @syntax.Expr) -> @syntax.Expr {
  ArrayGet(array~, index~, loc=@syntax.no_location)
}

///|
fn ast_case(pattern : @syntax.Pattern, body : @syntax.Expr) -> @syntax.Case {
  { pattern, guard_: None, body, }
}

///|
fn ast_match(expr : @syntax.Expr, cases : Array[@syntax.Case]) -> @syntax.Expr {
  let loc = @syntax.no_location
  Match(expr~, cases=@list.List(cases), match_loc=loc, loc~)
}

///|
fn ast_bind(name : String) -> @syntax.Pattern {
  Var(ast_binder(name))
}

///|
fn ast_any() -> @syntax.Pattern {
  Any(loc=@syntax.no_location)
}

///|
fn ast_constructor(name : String) -> @syntax.Constructor {
  let loc = @syntax.no_location
  { name: { name, loc, }, extra_info: NoExtraInfo, loc, }
}

///|
fn ast_ctor(name : String) -> @syntax.Expr {
  Constr(constr=ast_constructor(name), loc=@syntax.no_location)
}

///|
fn ast_ctor_pat(
  name : String,
  args : Array[@syntax.ConstrPatArg],
) -> @syntax.Pattern {
  Constr(
    constr=ast_constructor(name),
    args=if args.is_empty() { None } else { Some(@list.List(args)) },
    is_open=false,
    loc=@syntax.no_location,
  )
}

///|
fn ast_pat_arg(pat : @syntax.Pattern, label? : String) -> @syntax.ConstrPatArg {
  {
    pat,
    kind: match label {
      Some(name) => Labelled(ast_label(name))
      None => Positional
    },
  }
}

///|
fn ast_string_pat(value : String) -> @syntax.Pattern {
  Constant(c=ast_string_constant(value), loc=@syntax.no_location)
}

///|
fn ast_tuple_pat(pats : Array[@syntax.Pattern]) -> @syntax.Pattern {
  Tuple(pats=@list.List(pats), loc=@syntax.no_location)
}

///|
fn ast_let(
  pattern : @syntax.Pattern,
  expr : @syntax.Expr,
  body : @syntax.Expr,
  ty? : @syntax.Type,
) -> @syntax.Expr {
  let loc = @syntax.no_location
  let pattern = match ty {
    Some(ty) => @syntax.Pattern::Constraint(pat=pattern, ty~, loc~)
    None => pattern
  }
  Let(pattern~, expr~, body~, loc~)
}

///|
fn ast_seq(
  exprs : Array[@syntax.Expr],
  last_expr : @syntax.Expr,
) -> @syntax.Expr {
  if exprs.is_empty() {
    last_expr
  } else {
    Sequence(exprs=@list.List(exprs), last_expr~, loc=@syntax.no_location)
  }
}

///|
fn ast_record(fields : Array[(String, @syntax.Expr)]) -> @syntax.Expr {
  let loc = @syntax.no_location
  let fields : Array[@syntax.FieldDef] = fields.map(fn(field) {
    let (name, expr) = field
    { label: ast_label(name), expr, is_pun: false, loc, }
  })
  Record(type_name=None, fields=@list.List(fields), trailing=Comma, loc~)
}

///|
fn ast_map(elems : Array[(String, @syntax.Expr)]) -> @syntax.Expr {
  let loc = @syntax.no_location
  let elems : Array[@syntax.MapExprElem] = elems.map(fn(elem) {
    let (key, expr) = elem
    { key: ast_string_constant(key), expr, key_loc: loc, loc, }
  })
  Map(elems=@list.List(elems), loc~)
}

///|
fn ast_if(
  cond : @syntax.Expr,
  ifso : @syntax.Expr,
  else_? : @syntax.Expr,
) -> @syntax.Expr {
  If(cond~, ifso~, ifnot=else_, loc=@syntax.no_location)
}

///|
fn ast_is(expr : @syntax.Expr, pat : @syntax.Pattern) -> @syntax.Expr {
  Is(expr~, pat~, loc=@syntax.no_location)
}

///|
fn ast_infix(
  op : String,
  lhs : @syntax.Expr,
  rhs : @syntax.Expr,
) -> @syntax.Expr {
  Infix(op=ast_var(op, None), lhs~, rhs~, loc=@syntax.no_location)
}

///|
fn ast_param(name : String, ty? : @syntax.Type) -> @syntax.Parameter {
  Positional(binder=ast_binder(name), ty~)
}

///|
fn ast_impl(
  trait_ : @syntax.TypeName,
  self_ty : @syntax.Type,
  quantifiers : Array[@syntax.TypeVarBinder],
  method_id : String,
  params : Array[@syntax.Parameter],
  body : @syntax.Expr,
  is_private : Bool,
) -> @syntax.Impl {
  let loc = @syntax.no_location
  TopImpl(
    self_ty=Some(self_ty),
    trait_~,
    method_name=ast_binder(method_id),
    quantifiers=@list.List(quantifiers),
    method_quantifiers=@list.List([]),
    params=@list.List(params),
    ret_ty=None,
    err_ty=NoErrorType,
    nocancel_=None,
    body=DeclBody(expr=body),
    vis=if is_private { Default } else { Pub(attr=None, loc~) },
    loc~,
    attrs=@list.List([]),
    doc=@syntax.DocString::empty(),
  )
}

///|
fn ast_func(
  name : String,
  quantifiers : Array[@syntax.TypeVarBinder],
  params : Array[@syntax.Parameter],
  ret_ty : @syntax.Type,
  err_ty : @syntax.Type,
  body : @syntax.Expr,
) -> @syntax.Impl {
  let loc = @syntax.no_location
  let fun_decl : @syntax.FunDecl = {
    type_name: None,
    name: ast_binder(name),
    is_async: None,
    decl_params: Some(@list.List(params)),
    params_loc: loc,
    quantifiers: @list.List(quantifiers),
    return_type: Some(ret_ty),
    error_type: ErrorType(ty=err_ty),
    nocancel_: None,
    vis: Default,
    attrs: @list.List([]),
    doc: @syntax.DocString::empty(),
    loc,
  }
  TopFuncDef(fun_decl~, decl_body=DeclBody(expr=body), where_clause=None, loc~)
}
