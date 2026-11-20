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
fn generate_package(directory : String) -> Unit raise {
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
  let sources : Array[(String, String)] = []
  for name in entries {
    if common_source(name) {
      let input = in_package(name)
      if @fs.is_file(input) {
        sources.push((input, @fs.read_file_to_string(input)))
      }
    }
  }
  generate(sources, in_package("serde.generated.mbt"))
}
