# Serde development

See [README.md](README.md) for consumer setup and the JSON representations.

The Nix and CI setup comes from [template-moonbit-simple](https://github.com/totto2727-org/template-moonbit-simple/tree/c7d7f703669add8a4db6752925b2b8302bdbde6f). CI installs the native generator before invoking the shared MoonBit checks, because the round-trip fixture runs it as a build rule.

Keep the template's CI triggers and shared action references unless a project requirement calls for a change. Keep publication disabled until explicitly enabled for this project. Do not replace a template publication trigger on pushes to `main` with a tag or release trigger.

## Package layout

- `src/`: runtime helpers called by generated JSON implementations.
- `src/codegen/`: attribute validation and source generation from the official MoonBit AST.
- `src/cmd/serde-gen/`: native command that reads MoonBit source and writes a codec file.
- `src/test/roundtrip/`: build rule and tests that compile and run the generated code.

## Validation

Run these commands from the repository root with the MoonBit toolchain on `PATH`. Use `nix develop .#ci` for the pinned toolchain:

```sh
moon install ./src/cmd/serde-gen --bin "$PWD/tmp/bin"
export PATH="$PWD/tmp/bin:$PATH"
sh src/cmd/serde-gen/cli_test.sh
moon check --target native
moon test --target native
moon test --target js
```

Install the generator again after changing its source. Remove `src/test/roundtrip/fixture_serde.generated.mbt` before testing generator changes so Moon runs the rule again. The test package's `dev_build` rule uses the installed executable. It must not run a nested `moon` command while the build is active.

Run `moon fmt` after editing MoonBit code and `moon info` after changing public signatures. Do not commit the generated codegen interface or integration fixtures. To change a wire-format behavior, update the generator and check it through a compiled fixture, not just through a source snapshot.
