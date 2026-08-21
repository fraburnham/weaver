defmodule Weaver.Application do
  @moduledoc """
  The entrypoint for the cli application
  """

  use Application

  alias Weaver.History
  alias Weaver.Tools
  alias Weaver.LLM
  alias Weaver.TUI
  alias Weaver.Personas

  @impl true
  def start(_type, _args) do
    case System.argv() do
      ["--workdir", workdir] ->
        File.cd!(workdir)

      _ ->
        nil
    end

    personas = struct!(Personas, Application.get_env(:weaver, :personas))
    system_prompt = Personas.system_prompt(personas)
    {model, api} = Personas.model(personas)
    tools_available = Personas.tools_available(personas)
    context_window = Personas.context_window(personas)

    children = [
      {DynamicSupervisor, name: Weaver.DynamicSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Weaver.ToolTaskSupervisor},
      {Phoenix.PubSub, name: Weaver.PubSub},
      {History, struct!(History, Application.get_env(:weaver, :history))},
      {Tools, struct!(Tools, Application.get_env(:weaver, :tools))},
      {LLM,
       struct!(LLM, [
         {:model, model},
         {:api, api},
         {:system_prompt, system_prompt},
         {:tools_available, tools_available},
         {:context_window, context_window}
         | Application.get_env(:weaver, :llm, [])
       ])},
      {TUI, struct!(TUI, Application.get_env(:weaver, :tui))}
    ]

    opts = [strategy: :one_for_one, name: Weaver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
