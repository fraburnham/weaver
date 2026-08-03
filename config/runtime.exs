import Config

alias Weaver.History
alias Weaver.LLM
alias Weaver.Personas
alias Weaver.Tools
alias Weaver.TUI

config :weaver,
  llm: %LLM{
    # api: Weaver.Api.OllamaMock,
    # api: Weaver.Api.Ollama,
    api: Weaver.Api.BedrockMock,
    base_url: "http://workload.api.llm.skynet/"
  },
  history: %History{
    base_dir: ".weaver/history/"
  },
  tools: %Tools{
    base_dir: "~/agent/tools/"
  },
  tui: %TUI{
    show_thinking: true
  },
  personas: %Personas{
    base_dir: "~/agent/personas/",
    name: "agent.nu-testing"
  }
