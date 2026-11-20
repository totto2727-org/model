///|
#derive(Eq)
pub(all) enum Segment {
  Field(String)
  Index(Int32)
}

///|
struct Path {
  reversed : @list.List[Segment]
}

///|
pub fn Path::field(self : Path, field : String) -> Path {
  { reversed: @list.cons(Field(field), self.reversed), }
}

///|
pub fn Path::index(self : Path, index : Int32) -> Path {
  { reversed: @list.cons(Index(index), self.reversed), }
}

///|
/// Return the typed path segments from the root to the invalid value.
pub fn Path::segments(self : Path) -> ReadOnlyArray[Segment] {
  ReadOnlyArray::from_iter(self.reversed.rev().iter())
}

///|
pub impl Show for Path with fn output(self, out) {
  let mut first = true
  for segment in self.reversed.rev() {
    match segment {
      Field(name) => {
        if !first {
          out.write_char('.')
        }
        out.write_string(name)
      }
      Index(index) => out.write_string("[\{index}]")
    }
    first = false
  }
}

///|
pub struct Violation {
  path : Path
  message : String
}

///|
struct Report {
  violations : Array[Violation]
}

///|
pub impl Show for Report with fn output(self, out) {
  for index, violation in self.violations {
    if index > 0 {
      out.write_char('\n')
    }
    let path = Show::to_string(violation.path)
    if path.is_empty() {
      out.write_string("<root>")
    } else {
      out.write_string(path)
    }
    out.write_string(": ")
    out.write_string(violation.message)
  }
}

///|
/// Add a violation from a hand-written or generated `Validate` implementation.
pub fn Report::add(self : Report, path : Path, message : String) -> Unit {
  self.violations.push({ path, message, })
}

///|
/// Return a snapshot of the violations in validation order.
pub fn Report::violations(self : Report) -> ReadOnlyArray[Violation] {
  ReadOnlyArray::from_array(self.violations[:])
}

///|
pub(open) trait Validate {
  fn collect(Self, Report, Path) -> Unit
}

///|
/// Validate an existing value and return all violations, independently of decoding.
pub fn[T : Validate] validate(value : T) -> Result[Unit, Report] {
  validate_using(value, T::collect)
}

///|
/// Validate with a collector that can capture a typed context.
pub fn[T] validate_using(
  value : T,
  collect : (T, Report, Path) -> Unit,
) -> Result[Unit, Report] {
  let report = { violations: [], }
  collect(value, report, { reversed: @list.List([]), })
  if report.violations.is_empty() {
    Ok(())
  } else {
    Err(report)
  }
}
