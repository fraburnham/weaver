import Config

config :weaver,
  pubsub: Weaver.PubSub

import_config "#{config_env()}.exs"
