# JSON decoding benchmark

Compare four ways to decode the same nested request in a native release build.

| Method | Decoding operation |
| --- | --- |
| `pattern` | Match built-in `Json` object, string, Boolean, and array patterns. |
| `lens-per-call` | Build the 12 typed Lens paths and read them on each call. |
| `lens-prebuilt` | Reuse the same 12 typed Lens paths, built before timing. |
| `serde` | Call `@json.from_json` with the implementation from `serde-gen`. |

## Run the comparison

From the repository root, enter `nix develop .#ci` to use the pinned MoonBit toolchain and build the generator from this checkout.
The reporter requires Python 3 on `PATH`.

```sh
mkdir -p tmp
cd bench
serde-gen --package .
moon test . --target native --deny-warn
moon run . --target native --release --deny-warn > ../tmp/serde-bench.json
python3 report.py < ../tmp/serde-bench.json
```

The workspace uses Serde from this checkout and Lens `0.4.4` from Mooncakes.
The generator writes `serde.generated.mbt` locally. Do not add that file to Git.
Run on an idle machine and keep the raw JSON when you report results.

## Input and timing

The [Lens benchmark fixture](https://github.com/totto2727-org/lens/blob/main/src/lens_bench_test.mbt) supplies the JSON document in [`fixture.mbt`](fixture.mbt).
All four methods return the same [`Request`](model.mbt), with 12 typed values from the document.
The required containers must be objects. Unknown properties are ignored, and the `tags` array accepts only strings.
All methods use MoonBit's `FromJson` rules for `Int32` and `Double`. The Lens paths use `custom` for those fields because Lens's built-in number decoders accept a different set of inputs.
The tests check the complete typed output and rejection of invalid required data. Error types and messages can differ.

- `text`: Parse the same JSON string on each call, then decode the result.
- `json`: Decode the same pre-parsed `Json`. Do not compare this mode directly with `text` to infer a difference between decoders.

The executable checks every decoder's output before timing and passes each timed result to `@bench.Bench::keep`.
A decoding error stops the run. Only valid input contributes to the timing results.
The benchmark runs eight sequential lanes. Each lane runs all eight combinations, with a different starting position so each combination occupies each position once.
The report gives the median and range of the eight lane medians in microseconds per operation, along with the platform and Moon version.
These results cover a single fixture and do not measure encoding, application-level validation, or concurrent throughput.
