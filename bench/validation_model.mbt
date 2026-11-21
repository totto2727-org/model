///|
#custom.serde
#custom.garde(validate_only)
#derive(Eq, Debug)
struct ValidationGroup {
  #custom.garde(length(min="1", max="24"))
  label : String
  #custom.garde(length(min="1", max="8"), inner(dive))
  members : Array[ValidationMember]
}

///|
#custom.serde
#custom.garde(validate_only)
#derive(Eq, Debug)
struct ValidationMember {
  #custom.garde(length(min="2", max="32"))
  name : String
  #custom.garde(range(min="18", max="120"))
  age : Int32
}
