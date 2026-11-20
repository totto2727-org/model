# Serde for MoonBit

Serde generates JSON encoders and decoders for MoonBit types.
Add `#custom.serde` to a type to control how it reads and writes JSON.

This project is inspired by Rust's [Serde](https://serde.rs/) for serialization and [garde](https://docs.rs/garde/latest/garde/) for validation.
For application rules that run after decoding, see [Validate a decoded value](docs/validation.md).

## Usage

After [setup](#setup), put this code in `src/models.mbt`:

```mbt nocheck
///|
#custom.serde(rename_all="camelCase")
struct Profile {
  display_name : String
  #custom.serde(skip_serializing_if="Option::is_none")
  avatar_url : String?
}
```

Put this test in `src/models_wbtest.mbt`:

```mbt nocheck
///|
test "encode a profile without an avatar" {
  let profile : Profile = @json.from_json({ "displayName": "Aki" })
  assert_eq(ToJson::to_json(profile), { "displayName": "Aki" })
}
```

Run `serde-gen --package src && moon test src`.
The generator discovers annotated files in `src` and writes `src/serde.generated.mbt` before the test runs.

## Key features

- Use the standard MoonBit `ToJson` and `@json.FromJson` traits.
- Generate codecs for records, enums, newtypes, and tuple structs, including generic types.
- Set JSON field names, aliases, defaults, and nested object paths.
- Select external, internal, adjacent, or untagged enum representations.
- Get source locations for generation errors and JSON paths for decoding errors.

## Prerequisites

- **MoonBit:** Use version `0.1.20261117` or a compatible version.
- **Nix:** Enable flakes to run the generator on Apple Silicon macOS or x86-64 Linux.

## Setup

> [!NOTE]
> These instructions apply to the published release. Serde is not yet available on Mooncakes.

From the root of your MoonBit module, add the library:

```sh
moon add totto2727/serde
```

### Run without installing

```sh
moonx totto2727/serde-gen --help
nix run github:totto2727-org/serde -- --help
```

### Install

```sh
nix profile add github:totto2727-org/serde
```

Add the `bin` directory of your Nix profile to `PATH` if your shell cannot find `serde-gen`.

### Nix flake

Use the Serde overlay to add `serde-gen` to your development shell.
Set `system` to `aarch64-darwin` or `x86_64-linux`.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    serde.url = "github:totto2727-org/serde";
  };

  outputs = { nixpkgs, serde, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ serde.overlays.default ];
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

`src/moon.pkg`:

```mbt nocheck
import {
  "moonbitlang/core/json",
  "totto2727/serde",
}
```

From the module root, run the generator before `moon check`, `moon build`, or `moon test`.
For example:

```sh
serde-gen --package src && moon check
```

Use `moonx totto2727/serde-gen --package src` when the CLI is available on Mooncakes.
Pass the package directory, not a list of model files.

## API

- [Attribute reference](docs/reference.md#customserde-attributes): Supported types, attributes, and JSON representations.
- [`serde-gen` reference](docs/reference.md#serde-gen): Inputs, package mode, and exit statuses.

## Development

For project structure and development commands, see [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)

_This README follows the [share-artifact guidance](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/SKILL.md) and [README template](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/readme/template.md)._
