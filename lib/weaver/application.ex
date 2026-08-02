defmodule Weaver.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Weaver.PubSub},
      {Weaver.History, Application.get_env(:weaver, :history)},
      {Weaver.Tools, Application.get_env(:weaver, :tools)},
      {Weaver.LLM, Application.get_env(:weaver, :llm)},
      {Weaver.TUI, Application.get_env(:weaver, :tui)}
    ]

    opts = [strategy: :one_for_one, name: Weaver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
