# Garde attributes

Use `#custom.garde` to generate validators for MoonBit values.
Generate the code with `serde-gen --validate --package DIR`, where `DIR` contains the annotated models and imports `totto2727/serde/garde`.
The generator discovers models in that directory and writes `garde.generated.mbt`.

Validation does not run during JSON decoding.
After decoding with Serde, call `@garde.validate(value)` or, for a model with a validation context, `value.validate_with(context)`.
You can also validate values that you construct directly.
The report uses MoonBit field names, not JSON keys set by Serde.

The following sections pair each annotation with excerpts from the generated code.
Place the input examples in the same package to use them together.

## `#custom.garde`, `required`, `length`, `range`, and `skip`

The type marker generates an implementation of `@garde.Validate`.
By default, a field must have a validation rule or `skip`.

```mbt nocheck
#custom.garde
pub struct Contact {
  #custom.garde(required, length(min="2", max="80"))
  name : String?
  #custom.garde(range(min="0", max="120"))
  age : Int32
  #custom.garde(skip)
  notes : String
}
```

This is the complete generated implementation.
`required` adds a violation for `None`; `length` runs only on `Some`.
`range` applies inclusive bounds, and `skip` omits `notes` from the implementation.

```mbt nocheck
pub impl @garde.Validate for Contact with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  {
    let garde_value = garde_self.name
    let garde_path = garde_path.field("name")
    if garde_value is None {
      garde_report.add(garde_path, "is required")
    }
    if garde_value is Some(garde_value) {
      if @garde.length(garde_value, Some(2), Some(80)) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
  }
  let garde_value = garde_self.age
  let garde_path = garde_path.field("age")
  if @garde.range(garde_value, Some(0), Some(120)) is Some(message) {
    garde_report.add(garde_path, message)
  }
}
```

`length` counts UTF-8 bytes for strings and items for arrays, or uses your type's `@garde.Length` implementation.
Use quoted decimal bounds with `length` and `range`: `min`, `max`, both, or `equal` alone.
Use `skip` alone on a field, payload, or variant.

## `ascii`, `alphanumeric`, `contains`, `prefix`, `suffix`, and `custom`

`ascii` accepts only ASCII characters, and `alphanumeric` accepts only ASCII letters and digits.
Use `length(min="1")` if an empty string should also fail.
`contains`, `prefix`, and `suffix` are case-sensitive and accept JSON-compatible escapes in their arguments.
A function passed to `custom` receives the field value and returns `None` on success or `Some(message)` on failure.

```mbt nocheck
#custom.garde
pub struct Credentials {
  #custom.garde(ascii, alphanumeric)
  username : String
  #custom.garde(contains("-"), prefix("ref-"), suffix("-ok"))
  reference : String
  #custom.garde(custom(check_code))
  code : String
}

fn check_code(code : String) -> String? {
  if code == "unset" { Some("choose a code") } else { None }
}
```

Each rule can add a separate violation to the same field path.
`custom(check_code)` generates a call to `check_code`, without a runtime lookup by name.

```mbt nocheck
    if @garde.ascii(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.alphanumeric(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.reference
    let garde_path = garde_path.field("reference")
    if @garde.contains(garde_value, "-") is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.prefix(garde_value, "ref-") is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.suffix(garde_value, "-ok") is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  let garde_value = garde_self.code
  let garde_path = garde_path.field("code")
  if check_code(garde_value) is Some(message) {
    garde_report.add(garde_path, message)
  }
```

## `allow_unvalidated`, `dive`, and `inner`

Use `allow_unvalidated` on a type or variant to permit unmarked fields.
Use `dive` to run the nested type's `Validate` implementation.
Use `inner` to apply one or more rules to each array item.

```mbt nocheck
#custom.garde(allow_unvalidated)
pub struct Directory {
  #custom.garde(dive)
  owner : Contact
  #custom.garde(inner(dive))
  contacts : Array[Contact]
  description : String
}
```

The generated implementation does not access `description`.
It passes `owner` directly to `Validate::collect` and loops over `contacts` with its indices, so a violation can be reported at `owner.name` or `contacts[0].name`.

```mbt nocheck
pub impl @garde.Validate for Directory with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  {
    let garde_value = garde_self.owner
    let garde_path = garde_path.field("owner")
    @garde.Validate::collect(garde_value, garde_report, garde_path)
  }
  let garde_value = garde_self.contacts
  let garde_path = garde_path.field("contacts")
  for garde_index, garde_value in garde_value {
    let garde_path = garde_path.index(garde_index)
    @garde.Validate::collect(garde_value, garde_report, garde_path)
  }
}
```

## `field(index=...)` and `field(name=...)`

Set `index` to a quoted, zero-based index for a tuple or positional enum payload.
Set `name` to a label for a named enum payload.
On an enum, put the type marker on the enum and the selectors on the variants.

```mbt nocheck
#custom.garde(field(index="0", ascii))
pub struct Id(String)

#custom.garde
pub enum Update[T] {
  NoChange
  #custom.garde(field(index="0", dive))
  Replace(T)
  #custom.garde(field(name="label", length(min="1")))
  Rename(label~ : String)
  #custom.garde(skip)
  Legacy(String)
}
```

The tuple-struct match adds the position to the report path.

```mbt nocheck
    Id(garde_item0) => {
      let garde_value = garde_item0
      let garde_path = garde_path.index(0)
      if @garde.ascii(garde_value) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
```

The enum match validates only the active variant, with paths such as `Replace[0]` or `Rename.label`.
The wildcard arm does nothing for unit and skipped variants.
`dive` on `T` adds a `Validate` bound.

```mbt nocheck
pub impl[T :  @garde.Validate] @garde.Validate for Update[T] with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  match garde_self {
    Replace(garde_item0) => {
      let garde_value = garde_item0
      let garde_path = garde_path.field("Replace").index(0)
      @garde.Validate::collect(garde_value, garde_report, garde_path)
    }
    Rename(label=garde_item0) => {
      let garde_value = garde_item0
      let garde_path = garde_path.field("Rename").field("label")
      if @garde.length(garde_value, Some(1), None) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
    _ => ()
  }
}
```

## `bounds`

A direct `length` check on `T` adds a `Length` bound.
Use `bounds` to specify a parameter's bounds when the needed traits cannot be inferred, for example when `dive` targets a wrapper around `T`.
Valid lists include `[Length]`, `[Validate, Length]`, and `[]` to suppress that parameter's inferred bounds.

```mbt nocheck
#custom.garde(field(index="0", length(min="2")))
pub struct Sized[T](T)

#custom.garde(bounds(T, [Length]), field(index="0", dive))
pub struct Envelope[T](Sized[T])
```

Both implementations have a `Length` bound on `T`.
The bound for `Sized` comes from `length`, and the bound for `Envelope` comes from `bounds`.

```mbt nocheck
pub impl[T :  @garde.Length] @garde.Validate for Sized[T] with fn collect(
```

```mbt nocheck
pub impl[T :  @garde.Length] @garde.Validate for Envelope[T] with fn collect(
```

## `context`, `custom_with`, and `dive_with`

Use `context=Policy` to generate `validate_with` and `collect_with` methods instead of a `Validate` implementation.
`custom_with(check_count)` passes the field value and the context to `check_count`.
`dive_with` passes the same context to a nested validator, including under `inner`.

```mbt nocheck
pub struct Policy { max_count : Int32 }

#custom.garde(context=Policy)
pub struct Allocation {
  #custom.garde(custom_with(check_count))
  count : Int32
}

fn check_count(count : Int32, policy : Policy) -> String? {
  if count > policy.max_count { Some("exceeds quota") } else { None }
}

#custom.garde(context=Policy)
pub struct Request {
  #custom.garde(inner(dive_with))
  allocations : Array[Allocation]
}
```

Call `allocation.validate_with(policy)` to start a report with the policy.
The generated collector passes that policy to your check.

```mbt nocheck
pub fn Allocation::collect_with(
  garde_self : Allocation,
  garde_context : Policy,
  garde_report : @garde.Report,
  garde_path : @garde.Path,
) -> Unit {
  let garde_value = garde_self.count
  let garde_path = garde_path.field("count")
  if check_count(garde_value, garde_context) is Some(message) {
    garde_report.add(garde_path, message)
  }
}
```

```mbt nocheck
pub fn Allocation::validate_with(self : Allocation, context : Policy) -> Result[
  Unit,
  @garde.Report,
] {
  @garde.validate_using(
    self, (value, report, path) => value.collect_with(context, report, path)
  )
}
```

The generated request collector passes the policy and the item path to each allocation.

```mbt nocheck
  let garde_value = garde_self.allocations
  let garde_path = garde_path.field("allocations")
  for garde_index, garde_value in garde_value {
    let garde_path = garde_path.index(garde_index)
    garde_value.collect_with(garde_context, garde_report, garde_path)
  }
```
