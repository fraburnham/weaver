defmodule Weaver.ToolsInitTest do
  use ExUnit.Case, async: false

  alias Weaver.Tools

  describe "init/1" do
    test "initializes with config and returns ok tuple" do
      config = %Tools{
        base_dir: "/test/base/dir",
        tool_definitions: nil,
        tool_modules: %{}
      }

      # Note: Phoenix.PubSub.subscribe is internal state management, not an external action.
      # It will execute normally, subscribing the test process to the "messages" topic.
      result = Tools.init(config)

      assert result == {:ok, config}
    end

    test "preserves config state including tool_modules" do
      initial_modules = %{"mock-tool" => MockModule}
      config = %Tools{
        base_dir: "/test/dir",
        tool_definitions: [],
        tool_modules: initial_modules
      }

      {:ok, returned_config} = Tools.init(config)

      assert returned_config.base_dir == "/test/dir"
      assert returned_config.tool_modules == initial_modules
    end
  end
end

defmodule Weaver.ToolsRetrievalTest do
  use ExUnit.Case, async: false

  alias Weaver.Tools

  describe "get_tool_definitions/1" do
    setup do
      # Create a temporary directory structure for STDIO tool testing
      tmp_dir = System.tmp_dir!()
      tool_dir = Path.join([tmp_dir, "test_tools_#{:erlang.unique_integer([:positive])}"])
      File.mkdir_p!(Path.join(tool_dir, "test-stdio-tool"))
      
      definition = %{
        type: "function",
        function: %{
          name: "test-stdio-tool",
          description: "A test STDIO tool",
          parameters: %{type: "object", properties: %{}}
        }
      }

      File.write!(Path.join(tool_dir, "test-stdio-tool/definition.json"), Jason.encode!(definition))

      on_exit(fn ->
        File.rm_rf!(tool_dir)
      end)

      %{tool_dir: tool_dir}
    end

    test "fetches STDIO tool definitions from filesystem", %{tool_dir: tool_dir} do
      config = %Tools{
        base_dir: tool_dir,
        tool_definitions: nil,
        tool_modules: %{}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["test-stdio-tool"])

      assert length(definitions) == 1
      assert hd(definitions)[:type] == "function"
      assert hd(definitions)[:function][:name] == "test-stdio-tool"
      assert hd(definitions)[:function][:description] == "A test STDIO tool"
    end

    test "fetches module-based tool definitions from tool_modules" do
      defmodule MockToolModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "mock-module-tool",
              description: "A test module tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "mock response"
        end
      end

      config = %Tools{
        base_dir: "/tmp/unused",
        tool_definitions: nil,
        tool_modules: %{"mock-module-tool" => MockToolModule}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["mock-module-tool"])

      assert length(definitions) == 1
      assert hd(definitions)[:type] == "function"
      assert hd(definitions)[:function][:name] == "mock-module-tool"
      assert hd(definitions)[:function][:description] == "A test module tool"
    end

    test "returns definitions for both STDIO and module-based tools", %{tool_dir: tool_dir} do
      defmodule MixedMockToolModule do
        @behaviour Weaver.Tools.Tool

        @impl true
        def definition() do
          %{
            type: "function",
            function: %{
              name: "mixed-mock-tool",
              description: "A mixed test tool",
              parameters: %{type: "object", properties: %{}}
            }
          }
        end

        @impl true
        def run(_tool_call) do
          "mixed mock response"
        end
      end

      config = %Tools{
        base_dir: tool_dir,
        tool_definitions: nil,
        tool_modules: %{"mixed-mock-tool" => MixedMockToolModule}
      }

      {:ok, _pid} = Tools.start_link(config)

      definitions = Tools.get_tool_definitions(["test-stdio-tool", "mixed-mock-tool"])

      assert length(definitions) == 2
      
      stdio_def = Enum.find(definitions, fn d -> d[:function][:name] == "test-stdio-tool" end)
      module_def = Enum.find(definitions, fn d -> d[:function][:name] == "mixed-mock-tool" end)

      assert stdio_def != nil
      assert module_def != nil
      assert stdio_def[:function][:description] == "A test STDIO tool"
      assert module_def[:function][:description] == "A mixed test tool"
    end
  end
end
