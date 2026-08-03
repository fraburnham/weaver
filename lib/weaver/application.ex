defmodule Weaver.Application do
  @moduledoc false

  use Application

  alias Weaver.History
  alias Weaver.Tools
  alias Weaver.LLM
  alias Weaver.TUI
  alias Weaver.Personas

  @impl true
  def start(_type, _args) do
    system_prompt = Personas.system_prompt(Application.get_env(:weaver, :personas))
    model = Personas.model(Application.get_env(:weaver, :personas))
    tools_available = Personas.tools_available(Application.get_env(:weaver, :personas))

    children = [
      {Phoenix.PubSub, name: Weaver.PubSub},
      {History, Application.get_env(:weaver, :history)},
      {Tools, Application.get_env(:weaver, :tools)},
      {LLM, %{Application.get_env(:weaver, :llm) | model: model, system_prompt: system_prompt, tools_available: tools_available}},
      {TUI, Application.get_env(:weaver, :tui)}
    ]

    opts = [strategy: :one_for_one, name: Weaver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
