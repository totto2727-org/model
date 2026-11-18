///|
const USAGE =
  #|Usage: serde-gen INPUT... --output OUTPUT
  #|       serde-gen --package DIR

///|
priv suberror CliError {
  Usage
  RefuseOverwrite(String)
  NotPackage(String)
}

///|
fn run(args : ArrayView[String]) -> Unit raise {
  if args is ["--package", directory] && !directory.is_empty() {
    generate_package(directory)
    return
  }
  guard args is [.. inputs, "--output", output] &&
    !inputs.is_empty() &&
    !output.is_empty() &&
    !output.has_prefix("-") else {
    raise Usage
  }
  let sources : Array[(String, String)] = []
  for input in inputs {
    if input.is_empty() || input.has_prefix("-") || input == output {
      raise Usage
    }
    sources.push((input, @fs.read_file_to_string(input)))
  }
  generate(sources, output)
}

///|
fn generate(sources : Array[(String, String)], output : String) -> Unit raise {
  let generated = @codegen.generate_many(sources)
  if @fs.path_exists(output) {
    let previous = @fs.read_file_to_string(output)
    if previous == generated {
      return
    }
    if !previous.has_prefix(@codegen.GENERATED_HEADER + "\n") ||
      sources.any(fn(source) { source.1 == previous }) {
      raise RefuseOverwrite(output)
    }
  }
  @fs.write_string_to_file(output, generated)
}

///|
fn main {
  let args = @env.args()
  if args[:] is [_, "--help" | "-h"] {
    println(USAGE)
    return
  }
  run(args[1:]) catch {
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
    @codegen.GenerateError(message) | @fs.IOError(message) => {
      eprintln("serde-gen: \{message}")
      @sys.exit(1)
    }
    error => {
      eprintln("serde-gen: \{error}")
      @sys.exit(1)
    }
  }
}
