# `serde-gen` command reference

See the [README](../README.mbt.md) for installation and the [Serde](https://mooncakes.io/docs/totto2727/serde/codegen) and [Garde](https://mooncakes.io/docs/totto2727/serde/garde) package pages on Mooncakes for attribute documentation. Select a release that includes the attributes you use.

```console
$ serde-gen --help
Usage: serde-gen --package DIR
       serde-gen INPUT... --output OUTPUT
```

## Package mode

Run one command before Moon to discover the annotated files and generate both JSON codecs and validators in `serde.generated.mbt`:

```sh
serde-gen --package src/models && moon check
```

After the CLI is available on Mooncakes, you can run the same command without installing the executable:

```sh
moonx totto2727/serde-gen --package src/models && moon check
```

The generator reads common `.mbt` files in the package in filename order. It skips child packages, hidden files, `*.generated.mbt`, tests, and files with backend suffixes. A marker in a comment or string does not generate code.

Run the same command after adding, editing, or removing source files. If you used an earlier development build that wrote separate codec and validator files, remove those generated files so Moon does not compile duplicate implementations.

For target-specific files or Moon `dev_build` rules that track explicit dependencies, use `INPUT... --output OUTPUT`. This has the same generation behavior. The input and output must be in the same package.

## Diagnostics

The generator does not overwrite a hand-written file, or rewrite an identical output. A generation error identifies the file and source range. For a duplicate annotated type, it identifies both definitions.

| Exit status | Meaning |
| --- | --- |
| `0` | Generation succeeded or the command printed help. |
| `1` | A file or generation error occurred. |
| `2` | The arguments do not match either invocation. |

Help goes to standard output. Errors go to standard error.
