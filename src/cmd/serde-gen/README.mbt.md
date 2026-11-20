# serde-gen

`serde-gen` finds MoonBit models in a package and generates JSON codecs for `#custom.serde` and validators for `#custom.garde`.
It does not run the validators.

See [Serde setup](https://mooncakes.io/docs/totto2727/serde) for installation.
See [Serde attributes](https://mooncakes.io/docs/totto2727/serde/codegen) and [Garde attributes](https://mooncakes.io/docs/totto2727/serde/garde) for models and generated code.
Select a library release that includes the attributes you use.

## Generate a package

Run this command from the module root.
Pass the path to the package that contains the annotated models:

```sh
serde-gen --package src/models && moon check
```

One run writes both codecs and validators to `src/models/serde.generated.mbt`.
Run the same command after you add, change, or remove model files.

`--package` reads common `.mbt` files in filename order.
It skips child packages, hidden files, files ending in `.generated.mbt`, test files, and files with backend suffixes.
An attribute name in a comment or a string does not generate code.

If an earlier development build wrote separate codec and validator files, remove those generated files so Moon does not compile duplicate implementations.

## Command reference

```console
$ serde-gen --help
Usage: serde-gen --package DIR
       serde-gen INPUT... --output OUTPUT
```

For target-specific files, or a Moon `dev_build` rule that tracks explicit dependencies, use `INPUT... --output OUTPUT`.
This form also generates both codecs and validators.
The input and output files must be in the same package.

Each run regenerates all matching models and rewrites the generated output, even if it is unchanged.
The generator does not overwrite a handwritten file.
A generation error identifies the file and source range.
For a duplicate annotated type, it identifies both definitions.

| Exit status | Meaning |
| --- | --- |
| `0` | The generator succeeded or printed help. |
| `1` | A file or generation error occurred. |
| `2` | The arguments do not match either form of the command. |

The generator writes help to standard output and errors to standard error.
