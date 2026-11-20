# JSON codec benchmarks

Compare four ways to decode the same nested request in a native release build.

| Method | Decoding operation |
| --- | --- |
| `pattern` | Match built-in `Json` object, string, Boolean, and array patterns. |
| `lens-per-call` | Build the 12 typed Lens paths and read them on each call. |
| `lens-prebuilt` | Reuse the same 12 typed Lens paths, built before timing. |
| `serde` | Call `@json.from_json` with the implementation from `serde-gen`. |

For encoding, compare a hand-written JSON object with the generated `ToJson` implementation for the same request.
Lens is measured on decoding only. Its setters update an existing document, which is a different operation from encoding a typed record into a new one.

## Run the comparison

From the repository root, enter `nix develop .#ci` to use the pinned MoonBit toolchain and build the generator from this checkout.

```sh
cd bench
serde-gen --package .
moon test . --target native --deny-warn
moon bench . --target native --release --deny-warn --no-parallelize
```

The workspace uses Serde from this checkout and Lens `0.4.4` from Mooncakes.
The generator writes `serde.generated.mbt` locally. Do not add that file to Git.
Run on an idle machine and repeat the command before drawing conclusions from small differences.

## Input and timing

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
`moon bench` controls sampling and prints the statistics for each combination.
These results cover a single fixture and do not measure application-level validation or concurrent throughput.
