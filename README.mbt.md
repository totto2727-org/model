# Model for MoonBit

Model provides two packages: Serde for JSON codecs and Garde for validation and typed model conversion.
Add `#custom.serde` to a type to control how it reads and writes JSON.

This project is inspired by Rust's [Serde](https://serde.rs/) for serialization and [garde](https://docs.rs/garde/latest/garde/) for validation.

## Usage

After [setup](#setup), define the JSON model in `src/models/endpoint.mbt`.

```mbt nocheck
///|
#custom.serde
pub(all) struct Endpoint {
  #custom.serde(rename="endpointUrl")
  url : String
}
```

Put this test in `src/models/endpoint_wbtest.mbt`.

```mbt nocheck
///|
test "round-trip an endpoint with Serde" {
  let input : Json = { "endpointUrl": "https://EXAMPLE.org:443/docs" }
  let wire : Endpoint = @json.from_json(input)
  assert_eq(ToJson::to_json(wire), input)
}
```

`@json.from_json` and `ToJson::to_json` use the generated Serde implementations.
Both use the JSON key `endpointUrl` and preserve the URL string as written.

## Key features

- Use the standard MoonBit `ToJson` and `@json.FromJson` traits.
- Generate codecs for records, enums, newtypes, and tuple structs, including generic types.
- Set JSON field names, aliases, defaults, and nested object paths.
- Select external, internal, adjacent, or untagged enum representations.
- Get source locations for generation errors and JSON paths for decoding errors.
- Run Garde validation separately from JSON decoding.

## Prerequisites

- Use Moon `0.1.20261117` or a compatible version to check the generated code.
- To use a Nix setup option, enable flakes on Apple Silicon macOS or x86-64 Linux.

## Setup

From the root of your MoonBit module, add the [Model library](https://mooncakes.io/docs/totto2727/model):

```sh
moon add totto2727/model
```

### Run without installing

Use `moonx` when the CLI is available on Mooncakes, or use Nix:

```sh
moonx totto2727/serde-gen --help
nix run github:totto2727-org/model -- --help
```

### Install

```sh
nix profile add github:totto2727-org/model
```

Add the `bin` directory of your Nix profile to `PATH` if your shell cannot find `serde-gen`.

### Nix flake

Use the Serde overlay to add `serde-gen` to your development shell.
Set `system` to `aarch64-darwin` or `x86_64-linux`.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    model.url = "github:totto2727-org/model";
  };

  outputs = { nixpkgs, model, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ model.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.serde-gen ];
      };
    };
}
```

### Generate code before a build

`src/models/moon.pkg`:

```mbt nocheck
///|
import {
  "moonbitlang/core/json",
  "totto2727/model/serde",
}
```

From the module root, run the generator before `moon check`, `moon build`, or `moon test`.
Pass the package directory, not a list of model files.

```sh
serde-gen --package src/models
```

One invocation discovers both `#custom.serde` and `#custom.garde` and writes all generated code to `serde.generated.mbt`.
Import `totto2727/model/garde` only if the package uses Garde attributes.

### Migrate from `totto2727/serde`

Replace the module dependency with `totto2727/model`, then switch the old runtime import to `totto2727/model/serde` and the old Garde import to `totto2727/model/garde`.
The `@serde` and `@garde` aliases, attributes, and `serde-gen` command are unchanged.
Remove the old generated `serde.generated.mbt` files, then re-run `serde-gen` after updating the imports.

## API

Use the Mooncakes version selector to read the documentation for the version you installed.

- [Serde API](https://mooncakes.io/docs/totto2727/model/serde): Runtime helpers used by generated JSON codecs.
- [Serde attributes](https://mooncakes.io/docs/totto2727/model/serde-codegen): `#custom.serde` examples and generated codec excerpts.
- [Garde API and attributes](https://mooncakes.io/docs/totto2727/model/garde): Validation types, `#custom.garde` examples, and generated validator excerpts.

For command-line options, see the [`serde-gen` package README](https://mooncakes.io/docs/totto2727/serde-gen) after the CLI release is available on Mooncakes.

## Development

See the [Rust Serde and garde feature matrix](docs/upstream-feature-matrix.md) for supported features, differences, and the source versions used for comparison.

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/model/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/model/blob/main/LICENSE)

_This README follows the [share-artifact guidance](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/SKILL.md) and [README template](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/readme/template.md)._
