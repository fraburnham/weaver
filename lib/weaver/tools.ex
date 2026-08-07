defmodule Weaver.Tools do
  use GenServer

  alias Weaver.Tools

  defstruct base_dir: nil,
            tool_definitions: nil,
            tool_modules: %{}

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %Tools{base_dir: _}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, config}
  end

  @impl true
  def handle_call({:get_tool_definitions, tools}, _from, config = %Tools{base_dir: base_dir}) do
    tool_definitions =
      Enum.map(tools, fn tool ->
        [base_dir, tool, "definition.json"]
        |> Path.join()
        |> Path.expand()
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
      end)

    {:reply, tool_definitions, %Tools{config | tool_definitions: tool_definitions}}
  end

  # Call tools
  @impl true
  def handle_info(
        %{role: role, tool_calls: tool_calls},
        config = %Tools{base_dir: base_dir, tool_definitions: tool_definitions}
      )
      when role in ["assistant"] do
    tool_responses =
      Enum.map(tool_calls, fn tool_call ->
        call_id = Map.get(tool_call, :id)
        name = tool_call[:function][:name]
        # TODO: Schema check the function call
        %{
          id: call_id,
          tool_call_id: call_id,
          role: "tool",
          content:
            if Enum.any?(tool_definitions, fn definition ->
                 definition[:function][:name] === name
               end) do
              call_tool(base_dir, name, tool_call)
            else
              "Invalid tool call. No tool named `#{name}`."
            end
        }
      end)

    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", tool_responses)

    {:noreply, config}
  end

  @impl true
  def handle_info(%{role: _}, config) do
    {:noreply, config}
  end

  @impl true
  def handle_info([%{role: _} | _], config) do
    {:noreply, config}
  end

  defp call_tool(base_dir, name, tool_call) do
    tool =
      [
        [base_dir, name, "run"]
        |> Path.join()
        |> Path.expand()
      ]

    Exile.stream(tool,
      input: [Jason.encode_to_iodata!(%{tool_call: tool_call})],
      stderr: :redirect_to_stdout,
      exit_timeout: :infinity
    )
    |> Enum.into([])
    |> Enum.filter(fn chunk ->
      case chunk do
        {:exit, {:status, _}} -> false
        _ -> true
      end
    end)
    |> IO.iodata_to_binary()
  end

  def get_tool_definitions(tools) do
    GenServer.call(__MODULE__, {:get_tool_definitions, tools})
  end
end
