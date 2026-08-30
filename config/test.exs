import Config

config :weaver,
  openai: [api_key: "test-key", project: "test-project"],
  openai_req_options: [plug: {Req.Test, OpenAIMock}]
