# Serde reference

For installation and a complete example, see the [README](../README.md).

## `#custom.serde` attributes

Serde generates `ToJson` and `@json.FromJson` implementations for record structs, newtypes, tuple structs, and enums.
Do not derive the same trait on a type that uses `#custom.serde`.
Use `#custom.serde(decode_only)` to generate only `@json.FromJson`.

For a generic type, Serde generates the JSON trait bounds for the type parameters used in each direction.
A non-optional field with `default` or `skip` can also add a `Default` bound.
A skipped field does not require a JSON trait.
Serde supports only JSON. It does not support custom hooks or flattening.

### Record fields

A record is a JSON object.
A field of type `T?` or `Option[T]` reads a missing key or `null` as `None`.
`Some(value)` writes the inner value.
`None` writes `null` unless the field uses `skip_serializing_if="Option::is_none"`.

| Argument | Target | Effect |
| --- | --- | --- |
| `rename="new_name"` | Field or variant | Use this name to read and write the field or variant. |
| `path=["part", "state", "status"]` | Record field | Read and write the field at a fixed object path. |
| `aliases=["old_name"]` | Record field | Also read these names. Reject an object that contains more than one accepted name for the field. |
| `default` | Record field | Use `Default` for a missing field. Pass an explicit `null` to the field's decoder. |
| `skip` | Record field | Do not read or write the field. Restore `None` or the type's `Default` value. |
| `skip_serializing_if="Option::is_none"` | Optional record field | Omit a field with value `None`. |
| `deny_unknown_fields` | Record | Reject keys that do not identify a field. |
| `rename_all="camelCase"` | Record or enum | Rename record fields or enum variant tags. `rename` takes precedence. |

The `rename_all` values are `lowercase`, `UPPERCASE`, `PascalCase`, `camelCase`, `snake_case`, `SCREAMING_SNAKE_CASE`, `kebab-case`, and `SCREAMING-KEBAB-CASE`.

The same `Option` rules apply to enum variant arguments and tuple struct elements with type `T?` or `Option[T]`.
`None` and `Some(None)` both write `null` and read back as `None`.
The first non-optional type uses its own JSON traits.
For example, the generated code delegates `Array[T?]` to MoonBit's array codec.

#### Fixed object paths

Use `path` to map a record field to a nested JSON object.
This type reads and writes `{"part":{"state":{"status":"completed"}}}`:

```mbt nocheck
///|
#custom.serde
struct ToolEvent {
  #custom.serde(path=["part", "state", "status"])
  status : String
}
```

Each path element is a literal object key, not an array index.
A path requires at least one key.
It takes precedence over `rename_all` and excludes `rename` and `aliases` on the same field.

Fields can share parent objects.
A path cannot be the same as another field path or a prefix of that path.
This restriction includes flat names and aliases.

On write, Serde creates parent objects as needed.
If Serde omits a field, it does not create parent objects for that field.
On read, a missing parent or leaf uses the field's rule for missing values.
A parent that is present must be an object, even for an optional field.
`deny_unknown_fields` also checks parent objects.
Values at leaf paths use their own decoders.

### Newtypes and tuple structs

A newtype encodes as its inner value.
For example, `struct Distance(Int)` reads and writes `12`.
A tuple struct with two or more elements encodes as a fixed-length JSON array in declaration order.
For example, `struct Measurement(Distance, String?)` reads and writes `[12,"m"]` or `[12,null]`.
An optional element requires an array slot with `null` for `None`.

Tuple structs accept `decode_only`, but do not accept arguments for named fields or enum tags.

### Enums

| Representation | Enum attribute | Unit variant `Idle` | Payload variant |
| --- | --- | --- | --- |
| External tag | `#custom.serde` | `"Idle"` | `{"Text":"hello"}` |
| Internal tag | `#custom.serde(tag="type")` | `{"type":"Idle"}` | `{"type":"Named","text":"hello"}` |
| Adjacent tags | `#custom.serde(tag="type", content="data")` | `{"type":"Idle"}` | `{"type":"Text","data":"hello"}` |
| Untagged | `#custom.serde(untagged)` | `null` | `"hello"` |

A single positional argument writes its value.
Multiple positional arguments write a JSON array.
Labeled arguments write a JSON object.
Internal tagging supports unit variants and variants with labeled arguments.
An untagged enum selects the first variant that decodes successfully, in declaration order.
Use a tagged representation when more than one variant accepts the same value.

With `decode_only`, an internally tagged enum can also have variants with one non-optional positional argument.
The decoder for that argument receives the original object, including the tag, at the original JSON path.

### Errors

A generation error gives the MoonBit file and source range.
For example, `models.mbt-3:3-4:14: path must be a non-empty array of string keys` identifies an empty field path.
A duplicate annotated type reports both definitions.

`@json.JsonDecodeError((path, message))` contains a JSON Pointer and a reason.
If `/part` is missing, the decoder reports `/part` and `missing field: part`, not the full field path `/part/state/status`.
If no untagged variant matches, the message gives the JSON Pointer and reason for each variant.

## `serde-gen`

```console
$ serde-gen --help
Usage: serde-gen INPUT... --output OUTPUT
       serde-gen --package DIR
```

All explicit inputs and the output must be in the same MoonBit package.
The generator does not overwrite a hand-written file or rewrite an output file that has not changed.
After a generator update, run `serde-gen` again or delete the generated file to make Moon run the build rule again.

| Exit status | Meaning |
| --- | --- |
| `0` | Generation succeeded or the command printed help. |
| `1` | A file or generation error occurred. |
| `2` | The arguments do not match either invocation. |

Help goes to standard output. Errors go to standard error.

### Package mode

Run `serde-gen --package DIR` before Moon, in place of a `dev_build` rule for the same package.
For example:

```sh
serde-gen --package src/models && moon check
```

Package mode refreshes `serde.generated.mbt` when source files change.
It reads `.mbt` files in `DIR` but does not enter child packages.
It skips hidden files, generated files with the `.generated.mbt` suffix, tests, and files with backend suffixes.
Use explicit inputs and a matching output for files that apply only to some targets, including files that `moon.pkg` restricts to those targets.

The official MoonBit parser checks files with the `#custom.serde` marker for attributes.
A marker in a comment or a string does not generate code.

Moon's `dev_build` rule does not expand wildcards.
If the rule takes a directory as input, changes to existing files do not trigger the rule.
To avoid a list of filenames, put the package command before Moon in your task runner.
