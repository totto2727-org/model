# Serde development

See [README.md](README.md) for consumer setup and the JSON representations.

The Nix and CI setup comes from [template-moonbit-simple](https://github.com/totto2727-org/template-moonbit-simple/tree/c7d7f703669add8a4db6752925b2b8302bdbde6f). The Nix shell puts the packaged native generator on `PATH` for the round-trip build rule and the CLI tests. The module defaults to native so the shared `moon test` runs both.

Keep the template's CI triggers and shared action references unless a project requirement calls for a change. Keep publication disabled until explicitly enabled for this project. Do not replace a template publication trigger on pushes to `main` with a tag or release trigger.

## Package layout

- `src/`: runtime helpers called by generated JSON implementations.
- `src/codegen/`: attribute validation and source generation from the official MoonBit AST.
- `src/garde/` and `src/garde_codegen/`: independent value validation and the `#custom.garde` generator used by `serde-gen --validate`.
- `src/cmd/serde-gen/`: Admiral command for native, linear Wasm, and JavaScript on Node.js that reads MoonBit source and writes a codec file. It is a separate Moon module so users of the codec library do not need Admiral. `package.nix` uses checksum-pinned Mooncakes archives without changing the local registry cache. Until Admiral 0.7.0 is available in the pinned Mooncakes index, the flake supplies a locked Admiral source as a Moon workspace member.
- `src/test/roundtrip/`: build rule and tests that compile and run the generated code.
- `src/test/validation/`: test both generators together and verify that JSON decoding does not run validation.

## Validation

Run these commands from the repository root with the MoonBit toolchain on `PATH`. Use `nix develop .#ci` for the pinned toolchain:

```sh
moon check --deny-warn
moon test
moon test --target js
```

To build the CLI from source, put the Serde library, `src/cmd/serde-gen`, and the pinned Admiral checkout in a Moon workspace. From the workspace root, run `moon build --target wasm --release ./src/cmd/serde-gen` for linear Wasm or `moon build --target js --release ./src/cmd/serde-gen` for Node.js. These commands assume the workspace root is the Serde checkout. The Nix package remains native.

After changing a generator, re-enter the Nix shell to use the rebuilt executable. Remove the affected `*.generated.mbt` files under `src/test/roundtrip/` and `src/test/validation/` so Moon runs the rules again. A test package's `dev_build` rule must not run a nested `moon` command while the build is active.

Run `moon fmt` after editing MoonBit code and `(cd src/cmd/serde-gen && moon fmt)` after editing the CLI. Run `moon info` to inspect public signatures locally. Do not commit generated package interfaces or integration fixtures. To change a wire-format behavior, update the generator and check it through a compiled fixture, not just through a source snapshot.
