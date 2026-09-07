import Config

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
