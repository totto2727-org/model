# Serde development

See [README.md](README.md) for consumer setup and the JSON representations.

The Nix and CI setup comes from [template-moonbit-simple](https://github.com/totto2727-org/template-moonbit-simple/tree/c7d7f703669add8a4db6752925b2b8302bdbde6f). The Nix shell puts the packaged native generator on `PATH` for the round-trip build rule and the CLI tests. The module defaults to native so the shared `moon test` runs both.

Keep the template's CI triggers and shared action references unless a project requirement calls for a change. Keep publication disabled until explicitly enabled for this project. Do not replace a template publication trigger on pushes to `main` with a tag or release trigger.

## Package layout

- `src/`: runtime helpers called by generated JSON implementations.
- `src/codegen/`: attribute validation and source generation from the official MoonBit AST.
- `src/cmd/serde-gen/`: native command that reads MoonBit source and writes a codec file.
- `src/test/roundtrip/`: build rule and tests that compile and run the generated code.

## Validation

Run these commands from the repository root with the MoonBit toolchain on `PATH`. Use `nix develop .#ci` for the pinned toolchain:

```sh
moon check --deny-warn
moon test
moon test --target js
```

After changing the generator, re-enter the Nix shell to use the rebuilt executable. Remove `src/test/roundtrip/fixture_serde.generated.mbt` before testing generator changes so Moon runs the rule again. The test package's `dev_build` rule must not run a nested `moon` command while the build is active.

Run `moon fmt` after editing MoonBit code and `moon info` after changing public signatures. Do not commit the generated codegen interface or integration fixtures. To change a wire-format behavior, update the generator and check it through a compiled fixture, not just through a source snapshot.
