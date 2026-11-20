# Validate a decoded value

The [`garde`](https://docs.rs/garde/latest/garde/) style validator runs on MoonBit values, not JSON. Serde reads the JSON and checks its shape. Call `@garde.validate` separately to check application rules. The same call works on values you construct without Serde.

## Add validation to a model

Use `#custom.garde` on a type and mark the fields that need validation. Use `#custom.serde` independently when the same type also needs JSON codecs.

```moonbit
#custom.serde
#custom.garde
pub(all) struct Signup {
  #custom.serde(rename="displayName")
  #custom.garde(length(min="3"))
  name : String
  #custom.garde(required)
  email : String?
  #custom.garde(inner(length(min="1")))
  roles : Array[String]
}
```

Add the validation import and build rule to `moon.pkg`. If your package also generates JSON codecs, keep its existing Serde import and rule.

```moonbit
import {
  "moonbitlang/core/json",
  "totto2727/serde",
  "totto2727/serde/garde",
}

rule(name: "serde", command: "serde-gen $input --output $output")
rule(name: "garde", command: "serde-gen --validate $input --output $output")

dev_build(rule: "serde", input: "models.mbt", output: "models.serde.generated.mbt")
dev_build(rule: "garde", input: "models.mbt", output: "models.garde.generated.mbt")
```

Alternatively, run `serde-gen --validate --package ./path/to/package` to write `garde.generated.mbt` without changing `serde.generated.mbt`.

## Run validation

```moonbit
let signup : Signup = @json.from_json({ "displayName": "x", "roles": [""] })
match @garde.validate(signup) {
  Ok(()) => println("Valid signup")
  Err(report) =>
    for issue in report.violations() {
      println("\{issue.path}: \{issue.message}")
    }
}
```

The JSON decodes successfully. Validation reports `name`, `email`, and `roles[0]`. Report paths use MoonBit field names, not Serde aliases or renamed JSON keys. Use `issue.path.segments()` to read the typed `Field` and `Index` segments.

## Tuple structs, enums, and generics

On a tuple struct or newtype, select each payload by its zero-based position. On an enum, put `#custom.garde` on the enum and select payloads on each variant. Use `name` for a labeled payload and `index` for a positional payload.

```moonbit
#custom.garde(field(index="0", ascii, prefix("ID-")))
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

Only the active variant is checked. A newtype payload reports `[0]`, a positional enum payload reports `Replace[0]`, and a labeled payload reports `Rename.label`. Unit variants have nothing to validate.

Generic parameters get `@garde.Validate` bounds when used by `dive` and `@garde.Length` bounds when checked directly by `length`. Unused or skipped parameters need no bound. If a nested generic validator requires different bounds, override the inference for that parameter with `bounds(T, [Length])`, `bounds(T, [Validate, Length])`, or `bounds(T, [])`.

## Supply a validation context

Use `context=Policy` to generate `value.validate_with(policy)` instead of an `@garde.Validate` implementation. Use `custom_with(check)` to pass the context to a field check. The check takes `(field_value, context)` and returns `String?`. Use `dive_with` to pass the same context to a nested validator. Ordinary rules and context-free `dive` still work on the same model.

```moonbit
pub(all) struct Policy {
  max_count : Int32
}

#custom.serde
#custom.garde(context=Policy)
pub(all) struct Allocation {
  #custom.garde(range(min="0"), custom_with(check_count))
  count : Int32
}

fn check_count(count : Int32, policy : Policy) -> String? {
  if count > policy.max_count { Some("exceeds quota") } else { None }
}
```

Decode `Allocation` as usual, then call `allocation.validate_with({ max_count: 5 })`. Serde never reads the policy or calls the validator.

## Supported rules

| Rule | Checks |
| --- | --- |
| `length(min="1", max="8")` | UTF-8 bytes for `String`, or the number of items in `Array`, `ReadOnlyArray`, and `FixedArray`. Other types can implement `@garde.Length`. |
| `range(min="-1", max="10")` | Inclusive bounds on `Int` values. |
| `required` | An `Option` must be `Some`. Other rules skip `None`. |
| `dive` | Run a nested value's `Validate` implementation and keep its field paths. |
| `dive_with` | Run a nested validator with the current context and keep its field paths. |
| `inner(...)` | Apply one or more rules to each array item. Combine with `dive` or `dive_with` to check nested values. |
| `custom(check_name)` | Call a function in the model's package. It accepts the field value and returns `None` on success or `Some(message)` on failure. |
| `custom_with(check_name)` | Like `custom`, but also passes the current context. |
| `ascii`, `alphanumeric` | Require ASCII characters, or only ASCII letters and digits, respectively. Use `length(min="1")` to also reject empty strings. |
| `contains("text")`, `prefix("text")`, `suffix("text")` | Check for a case-sensitive substring, prefix, or suffix. String arguments use JSON-compatible escapes. |
| `skip` | Do not validate this field, payload, or variant. Use it alone. |

Write numeric bounds as quoted decimal integers because MoonBit's attribute parser does not accept bare integer literals in these rules. You can specify `min`, `max`, both, or `equal` by itself.

By default, every field or payload in an annotated type must have a rule or `skip`. Use `#custom.garde(allow_unvalidated)` on the type or variant to allow unmarked fields. This library follows garde's explicit validation model, not its full Rust rule set.
