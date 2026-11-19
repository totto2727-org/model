///|
fn common_source(name : String) -> Bool {
  guard name.strip_suffix(".mbt") is Some(stem) else { return false }
  !name.has_prefix(".") &&
  !stem.has_suffix(".generated") &&
  !stem.has_suffix("_test") &&
  !stem.has_suffix("_wbtest") &&
  ![".native", ".llvm", ".js", ".wasm", ".wasm-gc"].any(suffix => {
    stem.has_suffix(suffix)
  })
}

///|
fn generate_package(directory : String, mode : Mode) -> Unit raise {
  let package_path = @path.Path(directory)
  fn in_package(name : String) -> String {
    package_path.join(@path.Path(name)).to_string()
  }

  let manifest = in_package("moon.pkg")
  guard @fs.path_exists(manifest) && @fs.is_file(manifest) else {
    raise NotPackage(directory)
  }
  let entries = @fs.read_dir(directory).to_owned()
  entries.sort()
  let (marker, output) = match mode {
    JsonCodecs => ("#custom.serde", "serde.generated.mbt")
    Validation => ("#custom.garde", "garde.generated.mbt")
  }
  let sources : Array[(String, String)] = []
  for name in entries {
    if common_source(name) {
      let input = in_package(name)
      if @fs.is_file(input) {
        let source = @fs.read_file_to_string(input)
        // The lexer requires contiguous `#namespace.name`. Only the AST confirms an attribute.
        if source.contains(marker) {
          sources.push((input, source))
        }
      }
    }
  }
  generate(sources, in_package(output), mode)
}
