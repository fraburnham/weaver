import Config

config :weaver,
  llm: %Weaver.LLM{
    model: "gemma4:e2b",
    api: Weaver.Api.OllamaMock,
    # api: Weaver.Api.Ollama,
    base_url: "http://workload.api.llm.skynet/"
  },
  history: %{},
  tools: %{},
  tui: %{
    show_thinking: true
  }
