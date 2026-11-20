# Validate a decoded value

The [`garde`](https://docs.rs/garde/latest/garde/) style validator runs on MoonBit values, not JSON. Serde reads the JSON and checks its shape. Call `@garde.validate` separately to check application rules. The same call works on values you construct without Serde.

For the API and generated code examples for each rule, see [Garde on Mooncakes](https://mooncakes.io/docs/totto2727/serde/garde) in a release that includes Garde.

## Add validation to a model

Use `#custom.garde` on a type and mark the fields that need validation. Use `#custom.serde` independently when the same type also needs JSON codecs.

```moonbit
#custom.serde
#custom.garde
pub(all) struct Signup {
  #custom.serde(rename="displayName")
  #custom.garde(length(min="3"))
  name : String
  #custom.garde(length(min="1"))
  email : String
  #custom.garde(inner(length(min="1")))
  roles : Array[String]
}
```

Add the validation import to the package's `moon.pkg`. If your package also generates JSON codecs, keep its existing Serde and JSON imports.

```moonbit
import {
  "moonbitlang/core/json",
  "totto2727/serde",
  "totto2727/serde/garde",
}
```

Run the generator once before Moon. For example, for a package in `src/models`:

```sh
serde-gen --package src/models && moon check
```

The command discovers annotated source files without a file list and writes codecs and validators to `serde.generated.mbt`. See [package mode](reference.md#package-mode) for which files are included.

## Run validation

```moonbit
let signup : Signup = @json.from_json({ "displayName": "x", "email": "", "roles": [""] })
match @garde.validate(signup) {
  Ok(()) => println("Valid signup")
  Err(report) =>
    for issue in report.violations() {
      println("\{issue.path}: \{issue.message}")
    }
}
```

The JSON decodes successfully. Validation reports `name`, `email`, and `roles[0]`. A missing `email` would fail decoding because its type is `String`. Report paths use MoonBit field names, not Serde aliases or renamed JSON keys. Use `issue.path.segments()` to read the typed `Field` and `Index` segments.
