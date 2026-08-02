defmodule Weaver.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Weaver.PubSub},
      {Weaver.History, []},
      {Weaver.Tools, []},
      {Weaver.LLM, []},
      {Weaver.TUI, []}
    ]

    opts = [strategy: :one_for_one, name: Weaver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
