defmodule Weaver.Tools.Tool do
  @moduledoc """
  A behaviour for implementing elixir module based tools
  """
  @callback run(tool_call :: map) :: binary
  @callback definition() :: map
end

defmodule Weaver.Tools do
  @moduledoc """
  `Weaver.Tools` is responsible for calling tools and formatting their response appropriately. It broadcasts
  a list of messages, never a bare message map.
  """
  use GenServer

  alias Weaver.Tools

  defstruct base_dir: nil,
            tool_definitions: nil,
            tool_modules: %{},
            async: false

  def start_link(config), do: GenServer.start_link(__MODULE__, config, name: __MODULE__)

  @impl true
  def init(config = %Tools{base_dir: _}) do
    Phoenix.PubSub.subscribe(Weaver.PubSub, "messages")

    {:ok, config}
  end

  #
  # api message handling
  #

  @impl true
  def handle_call(
        {:get_tool_definitions, tools},
        _from,
        config = %Tools{base_dir: base_dir, tool_modules: tool_modules}
      ) do
    tool_definitions =
      Enum.map(tools, fn tool ->
        # TODO: this should check if the model has access to the tool if tool_modules will be in the config instead of in the persona
        if Map.has_key?(tool_modules, tool) do
          tool_modules[tool].definition()
        else
          get_stdio_tool_definition(base_dir, tool)
        end
      end)

    {:reply, tool_definitions, %Tools{config | tool_definitions: tool_definitions}}
  end

  #
  # "messages" handling
  #

  # Tools don't need to be handled during resume
  @impl true
  def handle_info(%{resume: true}, config), do: {:noreply, config}

  # Call tools
  @impl true
  def handle_info(
        %{role: role, tool_calls: tool_calls},
        config = %Tools{async: async}
      )
      when role in ["assistant"] do
    Enum.each(tool_calls, fn tool_call ->
      if async do
        Task.Supervisor.start_child(Weaver.ToolTaskSupervisor, fn ->
          call_tool(config, tool_call)
        end)
      else
        call_tool(config, tool_call)
      end
    end)

    {:noreply, config}
  end

  @impl true
  def handle_info(%{role: _}, config), do: {:noreply, config}

  @impl true
  def handle_info([%{role: _} | _], config), do: {:noreply, config}

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

  defp call_tool(
         %Tools{
           tool_definitions: tool_definitions,
           base_dir: base_dir,
           tool_modules: tool_modules
         },
         tool_call
       ) do
    call_id = Map.get(tool_call, :id)
    name = tool_call[:function][:name]

    # TODO: Schema check the function call
    msg = %{
      id: call_id,
      role: "tool",
      content:
        if Enum.any?(tool_definitions, fn definition ->
             definition[:function][:name] === name
           end) do
          if Map.has_key?(tool_modules, name) do
            tool_modules[name].run(tool_call)
          else
            call_stdio_tool(base_dir, name, tool_call)
          end
        else
          "Invalid tool call. No tool named `#{name}`."
        end
    }

    Phoenix.PubSub.broadcast(Weaver.PubSub, "messages", msg)
  end

  def get_tool_definitions(tools) do
    GenServer.call(__MODULE__, {:get_tool_definitions, tools})
  end
end
