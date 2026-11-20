///|
test "official AST selects marked types and preserves nested options and aliases" {
  let source =
    #|struct Ignored { x : Int }
    #|// #custom.serde
    #|struct AlsoIgnored { y : Int }
    #|#serde
    #|struct Unqualified { y : Int }
    #|#other.serde
    #|struct WrongNamespace { y : Int }
    #|#custom.serde(rename_all = "camelCase", deny_unknown_fields)
    #|struct Event {
    #|  event_id : Int
    #|  #custom.serde(rename = "nested", aliases = ["old_name", "legacy"], skip_serializing_if = "Option::is_none")
    #|  nested_value : Option[String?]
    #|  #custom.serde(default)
    #|  count : Int
    #|  #custom.serde(skip)
    #|  ignored_value : Int
    #|}
  let definitions = @serde_codegen.parse(source) catch {
    @serde_codegen.GenerateError(message) => fail(message)
  }
  guard definitions is [Record(record)] else {
    fail("expected a single record")
  }
  assert_eq(record.name, "Event")
  assert_true(record.deny_unknown_fields)
  assert_eq(record.fields[0].wire_name, "eventId")
  assert_eq(record.fields[1].wire_name, "nested")
  assert_eq(record.fields[1].aliases, ["old_name", "legacy"])
  assert_true(
    record.fields[1].ty is Name(tys~, ..) &&
    tys.head() is Some(Option(ty=Name(..), ..)),
  )
  assert_eq(record.fields[1].option_depth, 2)
  assert_true(record.fields[1].optional && record.fields[1].omit_none)
  assert_true(record.fields[2].default)
  assert_true(record.fields[3].skip)
}

///|
test "attribute key escapes are decoded before comparing paths" {
  let source =
    #|#custom.serde
    #|struct Escaped {
    #|  #custom.serde(rename="quote\"", aliases=["tab\t", "\u0061"])
    #|  first : Int
    #|  #custom.serde(path=["root", "line\n"])
    #|  second : String
    #|}
  let definitions = @serde_codegen.parse(source)
  guard definitions is [Record(record)] else { fail("expected a record") }
  assert_eq(record.fields[0].wire_name, "quote\"")
  assert_eq(record.fields[0].aliases, ["tab\t", "a"])
  assert_eq(record.fields[1].path, ["root", "line\n"])
  assert_invalid_serde(
    (
      #|#custom.serde
      #|struct Collision {
      #|  #custom.serde(rename="\u0061")
      #|  b : Int
      #|  a : Int
      #|}
    ),
    "duplicate wire key: a",
  )
}

///|
test "official AST distinguishes unit, labeled, and positional enum variants" {
  let source =
    #|#custom.serde(tag = "kind", content = "payload", rename_all = "snake_case")
    #|enum Event {
    #|  NotStarted
    #|  NewHTTPEvent(code~ : Int, message~ : String?)
    #|  #custom.serde(rename = "tuple")
    #|  Unnamed(Int, String)
    #|}
  let definitions = @serde_codegen.parse(source) catch {
    @serde_codegen.GenerateError(message) => fail(message)
  }
  guard definitions is [Sum(sum)] else { fail("expected a single enum") }
  assert_true(sum.repr is Adjacent("kind", "payload"))
  assert_eq(sum.variants[0].wire_name, "not_started")
  assert_true(sum.variants[0].fields.is_empty())
  assert_eq(sum.variants[1].wire_name, "new_http_event")
  assert_eq(sum.variants[1].fields[0].label, Some("code"))
  assert_true(sum.variants[1].fields[1].optional)
  assert_eq(sum.variants[2].wire_name, "tuple")
  assert_eq(sum.variants[2].fields[1].label, None)
  assert_eq(sum.variants[2].fields[1].name, "1")
}

///|
fn assert_invalid_serde(source : String, reason : String) -> Unit raise {
  let result = Ok(@serde_codegen.parse(source, name="broken.mbt")) catch {
    e => Err(e)
  }
  guard result is Err(@serde_codegen.GenerateError(message)) else {
    fail("expected GenerateError: \{reason}")
  }
  assert_true(message.contains("broken.mbt"), msg=message)
  assert_true(message.contains(reason), msg=message)
}

///|
test "invalid flatten and codec hooks report source errors" {
  for
    (attributes, ty, reason) in [
      (
        "codec=\"Codec\", serialize_with=\"encode\"", "Json", "codec cannot be combined",
      ),
      (
        "deserialize_with=\"decode(value)\"", "Json", "must name a MoonBit function",
      ),
      ("skip, serialize_with=\"encode\"", "Json", "skip cannot be combined"),
      ("flatten", "Map[String, Json]?", "flatten requires a non-optional field"),
      ("flatten, rename=\"keys\"", "Json", "flatten cannot be combined"),
    ] {
    assert_invalid_serde(
      "#custom.serde\nstruct S {\n#custom.serde(\{attributes})\nx : \{ty}\n}",
      reason,
    )
  }
  assert_invalid_serde(
    "#custom.serde(deny_unknown_fields)\nstruct S {\n#custom.serde(flatten)\nx : Map[String, Json]\n}",
    "flatten cannot be combined with deny_unknown_fields",
  )
  assert_invalid_serde(
    "#custom.serde\nstruct S {\n#custom.serde(flatten)\nx : Map[String, Json]\n#custom.serde(flatten)\ny : Map[String, Json]\n}",
    "only one flatten field",
  )
}

///|
test "invalid serde options fail instead of producing codecs" {
  for
    (source, reason) in [
      (
        "#custom.serde(rename_all: \"snake_case\")\nstruct S { x : Int }", "malformed #custom.serde",
      ),
      (
        "#custom.serde(typo)\nstruct S { x : Int }", "unknown #custom.serde option",
      ),
      (
        "#custom.serde(deny_unknown_fields, deny_unknown_fields)\nstruct S { x : Int }",
        "repeated #custom.serde option",
      ),
      (
        "#custom.serde\n#custom.serde\nstruct S { x : Int }", "repeated #custom.serde attribute",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(aliases = \"y\")\nx : Int\ny : Int\n}",
        "duplicate wire key: y",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(skip_serializing_if = \"Option::is_none\")\nx : Int\n}",
        "on an Option field",
      ),
      (
        "#custom.serde(tag=\"type\")\nstruct S(Int)", "tag is not allowed on a tuple struct",
      ),
      (
        "#custom.serde(deny_unknown_fields)\nstruct S(Int, String)", "deny_unknown_fields is not allowed on a tuple struct",
      ),
      (
        "#custom.serde\nstruct S { x : Int } derive(ToJson)", "conflicts with a JSON deriving directive",
      ),
      (
        "#custom.serde(tag = \"kind\", content = \"kind\")\nenum E { V }", "incompatible tag",
      ),
      (
        "#custom.serde(tag = \"kind\")\nenum E { V(kind~ : Int) }", "duplicate wire key: kind",
      ),
      (
        "#custom.serde(tag = \"kind\")\nenum E { V(Int) }", "require decode_only and one non-optional payload",
      ),
      (
        "#custom.serde(tag = \"kind\", decode_only)\nenum E { V(Int, String) }",
        "require decode_only and one non-optional payload",
      ),
      (
        "#custom.serde(tag = \"kind\", decode_only)\nenum E { V(Int?) }", "require decode_only and one non-optional payload",
      ),
      (
        "#custom.serde(decode_only)\nstruct S { x : Int } derive(FromJson)", "conflicts with a JSON deriving directive",
      ),
      (
        "#custom.serde(encode_only)\nstruct S { x : Int } derive(ToJson)", "conflicts with a JSON deriving directive",
      ),
      (
        "#custom.serde(encode_only, decode_only)\nstruct S(Int)", "encode_only and decode_only are mutually exclusive",
      ),
      (
        "#custom.serde\nenum E { V(Int, name~ : Int) }", "mixed named and positional",
      ),
    ] {
    assert_invalid_serde(source, reason)
  }
}

///|
test "fixed paths reject ambiguous or malformed schema mappings" {
  for
    (source, reason) in [
      (
        "#custom.serde\nstruct S {\n#custom.serde(path=[])\nx : Int\n}", "non-empty array of string keys",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(path=[false])\nx : Int\n}", "non-empty array of string keys",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(path=[\"a\"], rename=\"b\")\nx : Int\n}",
        "cannot be combined",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(path=[\"a\", \"x\"])\nx : Int\n#custom.serde(path=[\"a\", \"x\"])\ny : Int\n}",
        "conflicting JSON field paths",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(path=[\"a\", \"x\"])\nx : Int\na : Int\n}",
        "conflicting JSON field paths",
      ),
      (
        "#custom.serde\nstruct S {\n#custom.serde(aliases=\"a\")\nx : Int\n#custom.serde(path=[\"a\", \"b\"])\ny : Int\n}",
        "conflicting JSON field paths",
      ),
    ] {
    assert_invalid_serde(source, reason)
  }
}
