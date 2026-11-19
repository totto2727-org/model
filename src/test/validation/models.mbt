///|
#custom.serde
#custom.garde
pub(all) struct Address {
  #custom.garde(length(equal="2"))
  code : String
}

///|
#custom.serde
#custom.garde
pub(all) struct Account {
  #custom.serde(rename="displayName")
  #custom.garde(length(min="3"), custom(garde_value))
  name : String
  #custom.garde(range(min="-1", max="10"))
  level : Int32
  #custom.garde(required, length(min="2"))
  contact : String?
  #custom.garde(dive)
  address : Address?
  #custom.garde(length(min="1"), inner(dive))
  locations : Array[Address]
  #custom.garde(skip)
  notes : String
}

///|
fn garde_value(name : String) -> String? {
  if name == "x" {
    Some("name is reserved")
  } else {
    None
  }
}

///|
#custom.garde(allow_unvalidated)
pub(all) struct Queue {
  #custom.garde(inner(inner(required, range(min="0"))))
  batches : FixedArray[ReadOnlyArray[Int32?]]
  name : String
}
