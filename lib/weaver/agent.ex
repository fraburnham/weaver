defmodule Weaver.Agent do
  use Supervisor

  @impl true
  def start_link(init), do: Supervisor.start_link(__MODULE__, init, name: __MODULE__)

  @impl true
  def init(_args) do
    children = [
      {Weaver.Agent.LLM, []},
      {Weaver.Agent.Tools, []},
      {Weaver.TUI, []}
    ]

    opts = [strategy: :one_for_one, name: Weaver.Agent]
    Supervisor.init(children, opts)
  end
end
