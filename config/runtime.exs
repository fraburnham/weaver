import Config

alias Weaver.History
alias Weaver.LLM
alias Weaver.Personas
alias Weaver.Tools
alias Weaver.TUI
alias Weaver.Api.Bedrock.Request
alias Weaver.Api.Ollama

config :weaver,
  llm: %LLM{
    api: Weaver.Api.Bedrock
    # api: Weaver.Api.OllamaMock
    # api: Weaver.Api.Ollama,
    # api: Weaver.Api.BedrockMock
  },
  history: %History{
    base_dir: ".weaver/history/"
  },
  tools: %Tools{
    base_dir: "~/.agent.nu/tools/"
  },
  tui: %TUI{
    show_thinking: false
  },
  personas: %Personas{
    base_dir: "~/.agent.nu/bedrock-personas/",
    name: "glm5-coding-agent"
  },
  bedrock: %Request{
    credential_process: &Weaver.Api.Bedrock.Request.awscli_credential_process/0
  },
  ollama: %Ollama{
    base_url: "http://example.com/"
  }
