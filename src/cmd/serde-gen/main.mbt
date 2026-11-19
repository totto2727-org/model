///|
const PACKAGE_OPTION = "package"

///|
const OUTPUT_OPTION = "output"

///|
const USAGE =
  #|Usage: serde-gen [--validate] INPUT... --output OUTPUT
  #|       serde-gen [--validate] --package DIR

///|
priv suberror CliError {
  Usage
  RefuseOverwrite(String)
  NotPackage(String)
}

///|
priv enum GenerateOptions {
  Package(String)
  Files(ReadOnlyArray[String], String)
}

///|
priv enum Mode {
  JsonCodecs
  Validation
}

///|
async fn run(args : ArrayView[String], mode : Mode) -> Unit {
  // Preserve the existing grammar and usage status before core argparse can exit.
  let package_flag = "--" + PACKAGE_OPTION
  let output_flag = "--" + OUTPUT_OPTION
  let argv = match args {
    [flag, directory] if flag == package_flag && !directory.is_empty() =>
      [package_flag + "=" + directory]
    [.. inputs, flag, output] if flag == output_flag &&
      !inputs.is_empty() &&
      !output.is_empty() &&
      !output.has_prefix("-") &&
      inputs.all(input => {
        !input.is_empty() && !input.has_prefix("-") && input != output
      }) => args.to_owned()
    _ => raise Usage
  }
  let inputs = @admiral.position_strings("INPUT")
  let output = @admiral.string(OUTPUT_OPTION)
  let package_dir = @admiral.string(PACKAGE_OPTION)
  let app = @admiral.CliApp::CliApp(
    name="serde-gen",
    positionals=[inputs],
    options=[output, package_dir],
    run=Some(ctx => {
      let options : GenerateOptions = match ctx.get_string(package_dir) {
        Some(directory) => Package(directory)
        None => Files(ctx.get_strings(inputs), ctx.get_string_required(output))
      }
      match options {
        Package(directory) => generate_package(directory, mode)
        Files(inputs, output) => generate_files(inputs, output, mode)
      }
    }),
  )
  app.run(argv=Some(argv))
}

///|
fn generate_files(
  inputs : ReadOnlyArray[String],
  output : String,
  mode : Mode,
) -> Unit raise {
  let sources : Array[(String, String)] = []
  for input in inputs {
    sources.push((input, @fs.read_file_to_string(input)))
  }
  generate(sources, output, mode)
}

///|
fn generate(
  sources : Array[(String, String)],
  output : String,
  mode : Mode,
) -> Unit raise {
  let (header, generated) = match mode {
    JsonCodecs => (@codegen.GENERATED_HEADER, @codegen.generate_many(sources))
    Validation =>
      (@garde_codegen.GENERATED_HEADER, @garde_codegen.generate_many(sources))
  }
  if @fs.path_exists(output) {
    let previous = @fs.read_file_to_string(output)
    if previous == generated {
      return
    }
    if !previous.has_prefix(header + "\n") ||
      sources.any(fn(source) { source.1 == previous }) {
      raise RefuseOverwrite(output)
    }
  }
  @fs.write_string_to_file(output, generated)
}

///|
#cfg(target="js")
fn command_arguments() -> ArrayView[String] {
  // Node's argv includes both the executable and the script path.
  @env.args()[2:]
}

///|
#cfg(not(target="js"))
fn command_arguments() -> ArrayView[String] {
  @env.args()[1:]
}

///|
async fn main {
  let args = command_arguments()
  if args is ["--help" | "-h"] {
    println(USAGE)
    return
  }
  let (mode, args) = match args {
    ["--validate", .. rest] => (Validation, rest)
    _ => (JsonCodecs, args)
  }
  run(args, mode) catch {
    Usage => {
      eprintln(USAGE)
      @sys.exit(2)
    }
    RefuseOverwrite(path) => {
      eprintln("serde-gen: refusing to overwrite \{path}")
      @sys.exit(1)
    }
    NotPackage(path) => {
      eprintln("serde-gen: \{path}: expected a MoonBit package with moon.pkg")
      @sys.exit(1)
    }
    @codegen.GenerateError(message)
    | @garde_codegen.GenerateError(message)
    | @fs.IOError(message) => {
      eprintln("serde-gen: \{message}")
      @sys.exit(1)
    }
    error => {
      eprintln("serde-gen: \{error}")
      @sys.exit(1)
    }
  }
}
