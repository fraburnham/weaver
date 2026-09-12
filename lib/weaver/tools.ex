defmodule Weaver.Tools.Tool do
  @moduledoc """
  A behaviour for implementing tools as elixir modules
  """

  @callback start_link() :: GenServer.on_start()
  @callback run(tool_call :: Weaver.tool_call()) :: binary
  @callback definition() :: Weaver.Tools.definition()
end

defmodule Weaver.Tools do
  @moduledoc """
  Manages tool execution and responses.

  `Weaver.Tools` handles calling tools via a STDIO interface or by invoking Elixir modules
  that implement the `Weaver.Tools.Tool` behaviour. It broadcasts a list of tool response
  messages to the `"messages"` topic, or broadcasts to `"commands"` if a terminal tool
  call is encountered.

  #### STDIO Interface

  A STDIO tool requires:
  - A `definition.json` file in the tool's directory
  - A `run` executable/script that accepts JSON input via STDIN
  - An optional `init` that is called before the tool's definition is fetched
  - Output to STDIO is sent to the llm verbatim
  - The tool's path will be built like `<weaver.tools.base_dir>/<tool name>/`

  #### Behaviour

  An elixir tool must implement the `Weaver.Tool` behaviour.

  #### Config

  | Key | Description |
  |-----|-------------|
  | `:base_dir` | The directory containing STDIO tools |
  | `:tool_modules` | A map of tool names to elixir modules |
  """
  use GenServer

  alias Weaver.Tools

  defstruct base_dir: nil,
            tool_definitions: nil,
            tool_modules: %{}

  @type t :: %Tools{
          base_dir: String.t() | nil,
          tool_definitions: list() | nil,
          tool_modules: map()
        }

  @type json_schema :: map()

  @type definition :: %{
          type: String.t(),
          function: %{
            name: String.t(),
            description: String.t(),
            parameters: json_schema()
          }
        }

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %Tools{base_dir: _}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, config}
  end

  #
  # public api handlers
  #

  @impl true
  def handle_call(
        {:get_tool_definitions, tools},
        _from,
        config = %Tools{base_dir: base_dir, tool_modules: tool_modules}
      ) do
    tool_definitions =
      Enum.map(tools, fn tool ->
        if Map.has_key?(tool_modules, tool) do
          init_module_tool(tool_modules[tool])
          tool_modules[tool].definition()
        else
          init_stdio_tool(base_dir, tool)
          get_stdio_tool_definition(base_dir, tool)
        end
      end)

    {:reply, tool_definitions, %Tools{config | tool_definitions: tool_definitions}}
  end

  #
  # "messages" handlers
  #

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

  #
  # private
  #

  @spec get_stdio_tool_definition(String.t(), String.t()) :: definition()
  defp get_stdio_tool_definition(base_dir, tool) do
    [base_dir, tool, "definition.json"]
    |> Path.join()
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
  end

  @spec init_module_tool(module()) :: :ok
  defp init_module_tool(tool) do
    case tool.start_link() do
      :ignore -> :ok
      {:ok, _} -> :ok
    end
  end

  @spec init_stdio_tool(String.t(), String.t()) :: term()
  defp init_stdio_tool(base_dir, tool) do
    init =
      [
        [base_dir, tool, "init"]
        |> Path.join()
        |> Path.expand()
      ]

    if File.exists?(init) do
      Exile.stream(init,
        stderr: :redirect_to_stdout,
        exit_timeout: :infinity
      )
      |> Enum.into([])
    end
  end

  @spec call_stdio_tool(String.t(), String.t(), Weaver.tool_call()) :: String.t()
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

  @spec call_tool(t(), String.t(), Weaver.tool_call()) :: String.t()
  defp call_tool(%Tools{base_dir: base_dir, tool_modules: tool_modules}, name, tool_call) do
    if Map.has_key?(tool_modules, name) do
      tool_modules[name].run(tool_call)
    else
      call_stdio_tool(base_dir, name, tool_call)
    end
  end

  #
  # public api
  #

  @doc """
  Retrieves the definitions for the given list of tools.

  Returns a list of tool definition maps. If a tool is registered as an Elixir
  module, its `c:Weaver.Tools.Tool.definition/0` callback is invoked. Otherwise,
  the definition is loaded from the tool's `definition.json` file via the STDIO interface.
  """
  @spec get_tool_definitions([String.t()]) :: [definition()]
  def get_tool_definitions(tools) do
    GenServer.call(__MODULE__, {:get_tool_definitions, tools})
  end
end
