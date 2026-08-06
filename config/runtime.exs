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
    # api: Weaver.Api.Bedrock
    api: Weaver.Api.OllamaMock
    # api: Weaver.Api.Ollama
    # api: Weaver.Api.BedrockMock
  },
  history: %History{
    base_dir: System.get_env("WEAVER_HISTORY_BASE_DIR", ".weaver/history/")
  },
  tools: %Tools{
    base_dir: System.get_env("WEAVER_TOOLS_BASE_DIR")
  },
  tui: %TUI{
    show_thinking:
      if System.get_env("WEAVER_SHOW_THINKING", "no") == "yes" do
        true
      else
        false
      end
  },
  personas: %Personas{
    base_dir: System.get_env("WEAVER_PERSONAS_BASE_DIR"),
    name: System.get_env("WEAVER_PERSONA")
  },
  bedrock: %Request{
    credential_process: &Weaver.Api.Bedrock.Request.awscli_credential_process/0
  },
  ollama: %Ollama{
    base_url: System.get_env("WEAVER_OLLAMA_BASE_URL")
  }

# TODO: optionally pull config details from XDG location?
# TODO: fail fast if a value is missing
