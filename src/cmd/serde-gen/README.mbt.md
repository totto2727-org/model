# serde-gen

`serde-gen` scans a MoonBit package for `#custom.serde` and `#custom.garde` attributes.
It generates JSON codecs and validators without decoding or validating values.

## Usage

After [setup](#setup), put the annotated types in the `src/models` package.
From the module root, run:

```sh
serde-gen --package src/models && moon check
```

The generator writes `src/models/serde.generated.mbt`.
`moon check` checks the generated code and the other source files in the module.
Run the generator again after you add, change, or remove models.

## Key features

- Find annotated source files without listing them on the command line.
- Generate JSON codecs and validators in the same file in one run.
- Report invalid attributes with the source file and location.

## Prerequisites

- Use Moon `0.1.20261117` or a compatible version to check the generated code.
- To use a Nix setup option, enable flakes on Apple Silicon macOS or x86-64 Linux.

## Setup

Add the [Serde library](https://mooncakes.io/docs/totto2727/serde) to your MoonBit module and [configure your model package](https://github.com/totto2727-org/serde#generate-code-before-a-build).
Use a release that includes the attributes in your models.

### Run without installing

Use `moonx` when the CLI is available on Mooncakes, or use Nix:

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

Use the [Serde overlay example](https://github.com/totto2727-org/serde#nix-flake) to add `serde-gen` to a development shell.

## API

For annotated models and generated code, see [Serde attributes](https://mooncakes.io/docs/totto2727/serde/serde-codegen) and [Garde attributes](https://mooncakes.io/docs/totto2727/serde/garde).

### Command reference

```console
$ serde-gen --help
Usage: serde-gen --package DIR
       serde-gen INPUT... --output OUTPUT
```

`--package DIR` reads `.mbt` files directly in `DIR` in filename order.
It skips hidden files, generated files, test files, and files with backend suffixes.
An attribute name in a comment or string does not generate code.

Use `INPUT... --output OUTPUT` to select specific source files, such as files for one backend.
This form also generates both codecs and validators.
Keep the output in the same MoonBit package as the input types.

The generator writes the output on every successful run, even when the content is the same.
It does not overwrite handwritten files.
For duplicate annotated types, the error identifies both definitions.

| Exit status | Meaning |
| --- | --- |
| `0` | The generator succeeded or printed help. |
| `1` | A file or generation error occurred. |
| `2` | The arguments do not match either form of the command. |

The generator writes help to standard output and errors to standard error.

## Development

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/serde/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/serde/blob/main/LICENSE)
