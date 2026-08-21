import Config

alias Weaver.History
alias Weaver.LLM
alias Weaver.Personas
alias Weaver.Tools
alias Weaver.TUI
alias Weaver.Api.Bedrock.Request
alias Weaver.Api.Ollama

defmodule Utils do
  def personas_config do
    config = [{:base_dir, System.get_env("WEAVER_PERSONAS_BASE_DIR")}]

    if System.get_env("WEAVER_PERSONA") do
      [{:name, System.get_env("WEAVER_PERSONA")} | config]
    else
      config
    end
  end
end

config :weaver,
  history: [
    base_dir: System.get_env("WEAVER_HISTORY_BASE_DIR", ".weaver/history/")
  ],
  tools: [
    base_dir: System.get_env("WEAVER_TOOLS_BASE_DIR")
  ],
  tui: [
    show_thinking:
      if System.get_env("WEAVER_SHOW_THINKING", "no") == "yes" do
        true
      else
        false
      end
  ],
  personas: Utils.personas_config(),
  bedrock: [
    credential_process: &Weaver.Api.Bedrock.Request.awscli_credential_process/0
  ],
  ollama: [
    base_url: System.get_env("WEAVER_OLLAMA_BASE_URL")
  ],
  openai: [
    project: System.get_env("WEAVER_OPENAI_PROJECT"),
    api_key: System.get_env("WEAVER_OPENAI_API_KEY")
  ],
  anthropic: [
    project: System.get_env("WEAVER_ANTHROPIC_PROJECT"),
    api_key: System.get_env("WEAVER_ANTHROPIC_API_KEY")
  ]

# TODO: optionally pull config details from XDG location?
# TODO: fail fast if a value is missing
