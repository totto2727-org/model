///|
let validation_group : ValidationGroup = {
  label: "maintainers",
  members: [
    { name: "Ada", age: 37, },
    { name: "Lin", age: 42, },
    { name: "Sam", age: 29, },
  ],
}

///|
fn validation_model() -> @moonmodel.Model {
  let member_model = @moonmodel.Model::new("ValidationMember", [
    @moonmodel.Field::new(
      "name",
      Text,
      check=@moonmodel.Check::new(shortest=2, longest=32),
    ),
    @moonmodel.Field::new(
      "age",
      Int,
      check=@moonmodel.Check::new(least=18, most=120),
    ),
  ])
  @moonmodel.Model::new("ValidationGroup", [
    @moonmodel.Field::new(
      "label",
      Text,
      check=@moonmodel.Check::new(shortest=1, longest=24),
    ),
    @moonmodel.Field::new(
      "members",
      List(Nest(member_model)),
      check=@moonmodel.Check::new(shortest=1, longest=8),
    ),
  ])
}

///|
test "Garde and MoonModel agree on the validation fixture and its constraints" {
  let schema = @verify.schema(validation_model())
  let valid_json = validation_group.to_json()
  let decoded : ValidationGroup = @json.from_json(valid_json)
  assert_eq(decoded, validation_group)
  for
    (group, count) in [
      (decoded, 0),
      (
        {
          label: "x",
          members: [{ name: "Al", age: 18, }, { name: "Li", age: 120, }],
        },
        0,
      ),
      ({ label: "", members: validation_group.members, }, 1),
      ({ label: "maintainers", members: [], }, 1),
      (
        {
          label: "maintainers",
          members: Array::make(9, { name: "Ada", age: 37, }),
        },
        1,
      ),
      ({ label: "maintainers", members: [{ name: "A", age: 17, }], }, 2),
      ({ label: "maintainers", members: [{ name: "Ada", age: 121, }], }, 1),
    ] {
    let garde_count = match @garde.validate(group) {
      Ok(_) => 0
      Err(report) => report.violations().length()
    }
    assert_eq(garde_count, count)
    assert_eq(schema.faults(group.to_json()).length(), count)
  }
}

///|
test "Validation only: prebuilt values" (b : @bench.T) {
  let input = validation_group.to_json()
  let schema = @verify.schema(validation_model())
  b.bench(name="garde", fn() { b.keep(@garde.validate(validation_group)) })
  b.bench(name="moonmodel", fn() { b.keep(schema.faults(input)) })
}

///|
test "Validation with JSON text: parse and build a typed model" (b : @bench.T) {
  let input = validation_group.to_json().stringify()
  let schema = @verify.schema(validation_model())
  b.bench(name="garde", fn() {
    let json = try! @json.parse(input)
    let group : ValidationGroup = try! @json.from_json(json)
    guard @garde.validate(group) is Ok(_) else {
      abort("invalid Garde fixture")
    }
    b.keep(group)
  })
  b.bench(name="moonmodel", fn() {
    let json = try! @json.parse(input)
    guard schema.faults(json).is_empty() else {
      abort("invalid MoonModel fixture")
    }
    let group : ValidationGroup = try! @json.from_json(json)
    b.keep(group)
  })
}
