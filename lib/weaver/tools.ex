defmodule Weaver.Tools do
  use GenServer
  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)
  def init(_), do: {:ok, %{}}
end
