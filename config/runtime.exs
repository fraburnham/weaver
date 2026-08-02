import Config

alias Weaver.LLM
alias Weaver.TUI

config :weaver,
  llm: %LLM{
    model: "gemma4:e2b",
    api: Weaver.Api.OllamaMock,
    # api: Weaver.Api.Ollama,
    base_url: "http://workload.api.llm.skynet/"
  },
  history: %{},
  tools: %{},
  tui: %TUI{
    show_thinking: true
  }
