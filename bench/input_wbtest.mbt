///|
let fixture : String =
  #|{"requestId":"req-2026-0001","version":7,"timestamp":"2026-07-31T12:00:00Z","region":"ap-northeast-1","environment":"production","user":{"id":"user-42","name":"Ada Lovelace","active":true,"age":37,"score":98.75,"email":"ada@example.com","role":"admin","locale":"en-GB","timezone":"Europe/London","metadata":{"team":"compiler","plan":"enterprise","tags":["owner","reviewer","operator"]}},"project":{"id":"project-7","name":"Lens benchmark","archived":false,"visibility":"private","memberCount":24},"metrics":{"latencyMs":12.5,"attempts":3,"cached":true,"bytes":65536},"payload":{"title":"Benchmark payload","kind":"analysis","items":[{"id":1,"value":"alpha"},{"id":2,"value":"beta"},{"id":3,"value":"gamma"}],"checksum":"sha256:0123456789abcdef"},"flags":{"trace":false,"preview":true,"audit":true}}

///|
let expected : Request = {
  request_id: "req-2026-0001",
  version: 7,
  user: {
    name: "Ada Lovelace",
    active: true,
    age: 37,
    score: 98.75,
    metadata: { tags: ["owner", "reviewer", "operator"], },
  },
  project: { id: "project-7", archived: false, },
  metrics: { latency_ms: 12.5, attempts: 3, },
  payload: { title: "Benchmark payload", },
}
