# Validate a decoded value

The [`garde`](https://docs.rs/garde/latest/garde/) style validator runs on MoonBit values, not JSON. Serde reads the JSON and checks its shape. Call `@garde.validate` separately to check application rules. The same call works on values you construct without Serde.

## Add validation to a model

Use `#custom.garde` on a struct and on the fields you want to validate. Use `#custom.serde` independently when the same type also needs JSON codecs.

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

## Supported rules

| Rule | Checks |
| --- | --- |
| `length(min="1", max="8")` | UTF-8 bytes for `String`, or the number of items in `Array`, `ReadOnlyArray`, and `FixedArray`. |
| `range(min="-1", max="10")` | Inclusive bounds on `Int` values. |
| `required` | An `Option` must be `Some`. Other rules skip `None`. |
| `dive` | Run a nested value's `Validate` implementation and keep its field paths. |
| `inner(...)` | Apply one or more rules to each array item. Combine with `dive` to validate nested records. |
| `custom(check_name)` | Call a function in the model's package. It accepts the field value and returns `None` on success or `Some(message)` on failure. |
| `skip` | Do not validate this field. Use it alone. |

Write numeric bounds as quoted decimal integers because MoonBit's attribute parser does not accept bare integer literals in these rules. You can specify `min`, `max`, both, or `equal` by itself.

By default, every field in an annotated struct must have a rule or `skip`. Use `#custom.garde(allow_unvalidated)` on the struct to allow unmarked fields. Code generation supports non-generic record structs. Enums, context parameters, and the remaining Rust garde rules are not supported.
