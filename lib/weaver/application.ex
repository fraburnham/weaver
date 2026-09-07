defmodule Weaver.Application do
  @moduledoc """
  The entrypoint for the application
  """

  use Application

  alias Weaver.History
  alias Weaver.Tools
  alias Weaver.LLM
  alias Weaver.CLI
  alias Weaver.Personas

  @impl true
  def start(_type, _args) do
    case System.argv() do
      ["--workdir", workdir] ->
        File.cd!(workdir)

      _ ->
        nil
    end

    opts = [strategy: :one_for_one, name: Weaver.Supervisor]
    Supervisor.start_link(assemble_children(), opts)
  end

  defp assemble_children do
    personas = struct!(Personas, Application.get_env(:weaver, :personas))
    system_prompt = Personas.system_prompt(personas)
    {model, api} = Personas.model(personas)
    tools_available = Personas.tools_available(personas)
    model_options = Personas.model_options(personas)

    [
      {DynamicSupervisor, name: Weaver.DynamicSupervisor, strategy: :one_for_one},
      {Phoenix.PubSub, name: Weaver.PubSub},
      {History, config: Application.get_env(:weaver, :history)},
      {Tools, struct!(Tools, Application.get_env(:weaver, :tools))},
      {LLM,
       struct!(LLM, [
         {:model, model},
         {:api, api},
         {:system_prompt, system_prompt},
         {:tools_available, tools_available},
         {:model_options, model_options}
         | Application.get_env(:weaver, :llm, [])
       ])},
      {CLI, struct!(CLI, Application.get_env(:weaver, :cli))}
    ]
    |> Enum.filter(fn {module, _} ->
      module in Application.get_env(:weaver, :processes)
    end)
  end
end
