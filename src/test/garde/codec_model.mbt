///|
#custom.serde
#custom.garde
pub(all) struct Endpoint[T] {
  #custom.serde(rename="endpointUrl")
  #custom.garde(url)
  url : String
  #custom.garde(ipv4)
  allowed_ip : String?
  #custom.garde(phone_number)
  phone : String?
  #custom.garde(length(min="1"))
  name : String
  #custom.garde(skip)
  metadata : T
}

///|
#custom.serde(encode_only)
#custom.garde
pub(all) struct Tagged[T, U] {
  #custom.garde(skip)
  tag : T
  #custom.serde(skip)
  #custom.garde(matches(original))
  repeated : U
  #custom.serde(skip)
  #custom.garde(skip)
  original : U
}
