defmodule Weaver.Tools.Tool do
  @moduledoc """
  A behaviour for implementing elixir module based tools
  """
  @callback run(tool_call :: map) :: binary
  @callback definition() :: map
end

defmodule Weaver.Tools do
  @moduledoc """
  Manages tool execution and responses.

  `Weaver.Tools` handles calling tools via a STDIO interface or by invoking Elixir modules
  that implement the `Weaver.Tools.Tool` behaviour. It broadcasts a list of tool response
  messages to the `"messages"` topic, or broadcasts to `"commands"` if a terminal tool
  call is encountered.
  """
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
  def handle_call(
        {:get_tool_definitions, tools},
        _from,
        config = %Tools{base_dir: base_dir, tool_modules: tool_modules}
      ) do
    tool_definitions =
      Enum.map(tools, fn tool ->
        if Map.has_key?(tool_modules, tool) do
          tool_modules[tool].definition()
        else
          get_stdio_tool_definition(base_dir, tool)
        end
      end)

    {:reply, tool_definitions, %Tools{config | tool_definitions: tool_definitions}}
  end

  # Tools don't need to be handled during resume
  @impl true
  def handle_info(%{resume: true}, config) do
    {:noreply, config}
  end

  # Call tools
  @impl true
  def handle_info(
        %{role: role, tool_calls: tool_calls},
        config = %Tools{tool_definitions: tool_definitions}
      )
      when role in ["assistant"] do
    tool_responses =
      Enum.map(tool_calls, fn tool_call ->
        call_id = Map.get(tool_call, :id)
        name = tool_call[:function][:name]
        # TODO: Schema check the function call
        %{
          id: call_id,
          role: "tool",
          content:
            if Enum.any?(tool_definitions, fn definition ->
                 definition[:function][:name] === name
               end) do
              call_tool(config, name, tool_call)
            else
              "Invalid tool call. No tool named `#{name}`."
            end
        }
      end)

    if Enum.all?(
         tool_responses,
         fn
           %{content: {:terminal, _}} -> false
           _ -> true
         end
       ) do
      Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", tool_responses)
    else
      Phoenix.PubSub.broadcast(
        Weaver.PubSub,
        "commands",
        {:terminal_tool_call, tool_responses}
      )
    end

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

  defp get_stdio_tool_definition(base_dir, tool) do
    [base_dir, tool, "definition.json"]
    |> Path.join()
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
  end

  defp call_stdio_tool(base_dir, name, tool_call) do
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

  defp call_tool(%Tools{base_dir: base_dir, tool_modules: tool_modules}, name, tool_call) do
    if Map.has_key?(tool_modules, name) do
      tool_modules[name].run(tool_call)
    else
      call_stdio_tool(base_dir, name, tool_call)
    end
  end

  @doc """
  Retrieves the definitions for the given list of tools.

  Returns a list of tool definition maps. If a tool is registered as an Elixir
  module, its `c:Weaver.Tools.Tool.definition/0` callback is invoked. Otherwise,
  the definition is loaded from the tool's `definition.json` file via the STDIO interface.
  """
  def get_tool_definitions(tools) do
    GenServer.call(__MODULE__, {:get_tool_definitions, tools})
  end
end
