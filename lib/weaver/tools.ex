defmodule Weaver.Tools do
  use GenServer

  alias Weaver.Tools

  defstruct base_dir: nil

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  def init(config = %Tools{base_dir: _}), do: {:ok, config}

  def handle_call({:get_tool_definitions, tools}, _from, config = %Tools{base_dir: base_dir}) do
    {:reply,
     Enum.map(tools, fn tool ->
       [base_dir, tool, "definition.json"]
       |> Path.join()
       |> Path.expand()
       |> File.read!()
       |> Jason.decode!(keys: :atoms)
     end), config}
  end

  def get_tool_definitions(tools) do
    GenServer.call(__MODULE__, {:get_tool_definitions, tools})
  end
end
