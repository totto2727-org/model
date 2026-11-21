# JSON codec and validation benchmarks

## JSON codecs

Compare four ways to decode the same nested request in a native release build.

| Method | Decoding operation |
| --- | --- |
| `pattern` | Match built-in `Json` object, string, Boolean, and array patterns. |
| `lens-per-call` | Build the 12 typed Lens paths and read them on each call. |
| `lens-prebuilt` | Reuse the same 12 typed Lens paths, built before timing. |
| `serde` | Call `@json.from_json` with the implementation from `model_gen`. |

For encoding, compare a hand-written JSON object with the generated `ToJson` implementation for the same request.
Lens is measured on decoding only. Its setters update an existing document, which is a different operation from encoding a typed record into a new one.

## Run the comparison

From the repository root, enter `nix develop .#ci` to use the pinned MoonBit toolchain and build the generator from this checkout.

```sh
cd bench
moon test . --target native --deny-warn
moon bench . --target native --release --deny-warn --no-parallelize
```

The workspace uses Serde and Garde from this checkout, Lens `0.4.4`, and [MoonModel `0.2.1`](https://github.com/moonbitstack/moonmodel/tree/v0.2.1).
Each `dev_build` entry in [`moon.pkg`](moon.pkg) writes a separate generated file for its model source. Do not add the generated files to Git.
Run on an idle machine and repeat the command before drawing conclusions from small differences.

## Codec input and timing

The [Lens benchmark fixture](https://github.com/totto2727-org/lens/blob/main/src/lens_bench_test.mbt) supplies the JSON document in [`input_wbtest.mbt`](input_wbtest.mbt).
All four methods return the same [`Request`](model.mbt), with 12 typed values from the document.
The required containers must be objects. Unknown properties are ignored, and the `tags` array accepts only strings.
All methods use MoonBit's `FromJson` rules for `Int32` and `Double`. The Lens paths use `custom` for those fields because Lens's built-in number decoders accept a different set of inputs.
The tests check the complete typed output and rejection of invalid required data. Error types and messages can differ.

- **JSON text: parse and decode**: Parse the same JSON string on each call, then decode the result.
- **Parsed JSON: decode only**: Decode the same `Json`, parsed before timing.
- **ToJson: encode to JSON value**: Encode the same typed `Request` into a fresh `Json`.
- **ToJson: encode and stringify**: Encode that request and render the resulting `Json` to text.

The benchmarks use MoonBit's standard [`@bench.T`](https://mooncakes.io/docs/moonbitlang/core/bench) and pass each timed result to `b.keep` so the compiler cannot discard the result.
The encoding test checks that both encoders produce the same `Json` and that it decodes to the original record. A decoding error stops the run.

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
`moon bench` controls sampling and prints the statistics for each combination. These fixtures do not measure concurrent throughput or application-level logic.
