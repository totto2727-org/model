///|
#custom.serde(rename_all="camelCase")
#derive(Eq, Debug)
struct Request {
  request_id : String
  version : Int32
  user : User
  project : Project
  metrics : Metrics
  payload : Payload
}

///|
#custom.serde
#derive(Eq, Debug)
struct User {
  name : String
  active : Bool
  age : Int32
  score : Double
  metadata : Metadata
}

///|
#custom.serde
#derive(Eq, Debug)
struct Metadata {
  tags : Array[String]
}

///|
#custom.serde
#derive(Eq, Debug)
struct Project {
  id : String
  archived : Bool
}

///|
#custom.serde(rename_all="camelCase")
#derive(Eq, Debug)
struct Metrics {
  latency_ms : Double
  attempts : Int32
}

///|
#custom.serde
#derive(Eq, Debug)
struct Payload {
  title : String
}
