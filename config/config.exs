import Config

config :ex_aws,
  json_codec: Weaver.Api.Bedrock.Json

config :ex_aws, :hackney_opts,
  recv_timeout: 180_000

config :weaver,
  pubsub: Weaver.PubSub,
  processes: [
    DynamicSupervisor,
    Phoenix.PubSub,
    Weaver.History,
    Weaver.Tools,
    Weaver.LLM,
    Weaver.CLI
  ]

import_config "#{config_env()}.exs"
