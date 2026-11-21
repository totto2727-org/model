///|
#custom.serde
#custom.garde(codec)
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
