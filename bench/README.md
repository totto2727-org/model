# JSON codec and validation benchmarks

## JSON codecs

Compare five ways to decode the same nested request from JSON text in a native release build.

| Method | Decoding operation |
| --- | --- |
| `pattern` | Match built-in `Json` object, string, Boolean, and array patterns. |
| `lens-per-call` | Build the 12 typed Lens paths and read them on each call. |
| `lens-prebuilt` | Reuse the same 12 typed Lens paths, built before timing. |
| `serde` | Call `@json.from_json` with the implementation from `model_gen`. |
| `community-serde` | Call community Serde's `@json.from_string` with its generated `Deserialize` implementation. |

For encoding to text, compare a hand-written encoder, the `ToJson` implementation from `model_gen`, and community Serde's generated `Serialize` implementation.
Lens is measured on decoding only. Its setters update an existing document, which is a different operation from encoding a typed record into a new one.

## Run the comparison

From the repository root, enter `nix develop .#ci` to use the pinned MoonBit toolchain and build the generator from this checkout.

```sh
cd bench
moon test . --target native --deny-warn
moon bench . --target native --release --deny-warn --no-parallelize
```

The workspace uses Serde and Garde from this checkout, Lens `0.4.4`, [MoonModel `0.2.1`](https://github.com/moonbitstack/moonmodel/tree/v0.2.1), and [community Serde `0.3.1`](https://github.com/moonbit-community/serde.mbt/tree/0675e0435c35c1b645e5c110936c47c04e981cfe).
Each `dev_build` entry in [`moon.pkg`](moon.pkg) and [`community/moon.pkg`](community/moon.pkg) writes a separate generated file for its model source. Do not add the generated files to Git.
Run on an idle machine and repeat the command before drawing conclusions from small differences.

## Codec input and timing

The [Lens benchmark fixture](https://github.com/totto2727-org/lens/blob/main/src/lens_bench_test.mbt) supplies the JSON document in [`input_wbtest.mbt`](input_wbtest.mbt).
All methods decode the same 12 typed values into equivalent records.
The required containers must be objects. Unknown properties are ignored, and the `tags` array accepts only strings.
The four methods that use core `Json` share MoonBit's `FromJson` rules for `Int32` and `Double`. The Lens paths use `custom` for those fields because Lens's built-in number decoders accept a different set of inputs.
The tests check the complete typed output and rejection of invalid required data. The libraries can differ in their accepted inputs, numeric rules, and errors.

- **JSON text: parse and decode**: Read the same JSON string on each call and return a typed record.
- **Parsed JSON: decode only**: Decode the same core `Json`, parsed before timing.
- **ToJson: encode to JSON value**: Encode the same typed request into a fresh core `Json`.
- **ToJson: encode and stringify**: Write the same typed request as JSON text.

Community Serde reads and writes JSON text directly. Its generic value type is not MoonBit's core `Json`, so it participates only in the text benchmarks.

The benchmarks use MoonBit's standard [`@bench.T`](https://mooncakes.io/docs/moonbitlang/core/bench) and pass each timed result to `b.keep` so the compiler cannot discard the result.
The encoding tests compare the JSON values, not the spelling of the output text, and check that decoding restores the original values. A codec error stops the run.

## Validation input and timing

Both validators check the same [group and member data](validation_model.mbt): label and name lengths, member count, and an inclusive age range for each member.
The fixture uses ASCII strings because Garde measures UTF-16 code units and JSON Schema measures Unicode code points.
The [validation test](validation_bench_wbtest.mbt) checks acceptance, rejection, and the number of diagnostics for invalid input before you run the benchmarks.
The benchmarks time valid input and the APIs that can return all diagnostics, not fail-fast validation.

| Measurement | Garde | MoonModel |
| --- | --- | --- |
| Validation only | Validate an existing typed record. | Check its existing `Json` with `Schema::faults`. |
| JSON text to a validated typed record | Parse with core JSON, decode with Serde, then validate the record. | Parse with core JSON, check the `Json`, then decode with the same Serde implementation. |

MoonModel builds its schema with `@verify.schema` before timing and reuses it in each iteration.
The validation-only rows start from each validator's native input, so they do not measure conversion or identical shape checks.
The JSON text rows start with the same string and return the same typed record.
Community Serde checks required fields and types during deserialization. It has no built-in length or range rules comparable to this workload, so it is not listed as a validator.
`moon bench` controls sampling and prints the statistics for each combination. These fixtures do not measure concurrent throughput or application-level logic.
